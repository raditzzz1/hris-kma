-- ============================================================
-- FASE 20 — Log Aktivitas (jejak audit)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Mencatat SIAPA mengubah APA dan KAPAN, untuk hal-hal yang berdampak:
-- gaji & komponen, periode payroll, persetujuan cuti/izin/koreksi, saldo
-- cuti, absensi yang diubah orang lain, data karyawan (termasuk role &
-- status aktif), pengaturan, penandatangan, dan hari libur.
--
-- KENAPA LEWAT TRIGGER, bukan dicatat dari aplikasi:
-- trigger berjalan di database, jadi perubahan tetap tercatat walau
-- dilakukan langsung lewat dashboard Supabase — bukan hanya lewat aplikasi.
-- Tidak bisa dilewati, dan tidak ikut terlupa saat menambah fitur baru.
--
-- SIFAT LOG: hanya-baca dari sisi aplikasi. Tidak ada satu pun policy
-- INSERT/UPDATE/DELETE, jadi tak seorang pun (termasuk HR Admin) bisa
-- mengubah atau menghapus isinya lewat API. Barisnya hanya bisa ditulis
-- oleh trigger. Ini yang membuatnya layak dipakai sebagai bukti.
-- ============================================================

CREATE TABLE IF NOT EXISTS log_aktivitas (
  id          BIGSERIAL PRIMARY KEY,
  waktu       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  aktor_id    UUID,     -- auth.uid() saat kejadian; NULL bila dari SQL Editor
  -- Nama & NIK DISALIN saat kejadian, bukan direlasikan. Kalau karyawannya
  -- nanti dihapus, jejaknya harus tetap terbaca ("siapa" tak boleh hilang).
  aktor_nama  TEXT,
  aktor_nik   TEXT,

  aksi        TEXT NOT NULL,   -- 'tambah' | 'ubah' | 'hapus'
  tabel       TEXT NOT NULL,
  baris_id    TEXT,            -- id baris yang terpengaruh
  -- Nama orang yang DIKENAI perubahan (mis. karyawan yang gajinya diubah).
  subjek_nama TEXT,

  ringkasan   TEXT,            -- teks siap baca untuk ditampilkan
  perubahan   JSONB            -- {kolom: {lama: ..., baru: ...}}
);

CREATE INDEX IF NOT EXISTS idx_log_aktivitas_waktu ON log_aktivitas (waktu DESC);
CREATE INDEX IF NOT EXISTS idx_log_aktivitas_tabel ON log_aktivitas (tabel);
CREATE INDEX IF NOT EXISTS idx_log_aktivitas_aktor ON log_aktivitas (aktor_id);

COMMENT ON TABLE log_aktivitas IS
  'Jejak audit perubahan penting. Hanya-baca dari aplikasi; diisi oleh trigger.';

ALTER TABLE log_aktivitas ENABLE ROW LEVEL SECURITY;

-- HANYA HR Admin yang boleh MEMBACA. Sengaja TIDAK ada policy tulis/ubah/
-- hapus — lihat catatan "SIFAT LOG" di atas.
DROP POLICY IF EXISTS log_aktivitas_baca_hr ON log_aktivitas;
CREATE POLICY log_aktivitas_baca_hr ON log_aktivitas
  FOR SELECT USING (public.is_hr_admin());

-- ============================================================
-- Fungsi trigger
-- ============================================================
-- Kolom yang perubahannya TIDAK perlu dicatat (rutin / berisik).
CREATE OR REPLACE FUNCTION public._log_kolom_diabaikan(t TEXT, k TEXT)
RETURNS BOOLEAN AS $$
  SELECT k IN ('updated_at', 'created_at', 'foto_url')
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION public.catat_aktivitas()
RETURNS TRIGGER AS $$
DECLARE
  v_aksi       TEXT;
  v_baris      JSONB;
  v_lama       JSONB;
  v_baru       JSONB;
  v_ubah       JSONB := '{}'::JSONB;
  v_kunci      TEXT;
  v_aktor      UUID := auth.uid();
  v_aktor_nama TEXT;
  v_aktor_nik  TEXT;
  v_subjek     TEXT;
  v_id         TEXT;
  v_ringkas    TEXT;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    v_aksi := 'tambah'; v_baris := to_jsonb(NEW);
  ELSIF (TG_OP = 'UPDATE') THEN
    v_aksi := 'ubah';   v_baris := to_jsonb(NEW);
    v_lama := to_jsonb(OLD); v_baru := to_jsonb(NEW);
    -- Kumpulkan HANYA kolom yang benar-benar berubah, supaya lognya terbaca
    -- (bukan menyalin seluruh baris tiap kali).
    FOR v_kunci IN SELECT jsonb_object_keys(v_baru) LOOP
      IF (v_lama -> v_kunci) IS DISTINCT FROM (v_baru -> v_kunci)
         AND NOT public._log_kolom_diabaikan(TG_TABLE_NAME, v_kunci) THEN
        v_ubah := v_ubah || jsonb_build_object(
          v_kunci, jsonb_build_object('lama', v_lama -> v_kunci, 'baru', v_baru -> v_kunci));
      END IF;
    END LOOP;
    -- Tak ada kolom penting yang berubah -> tidak usah dicatat.
    IF v_ubah = '{}'::JSONB THEN RETURN NULL; END IF;
  ELSE
    v_aksi := 'hapus';  v_baris := to_jsonb(OLD);
  END IF;

  v_id := COALESCE(v_baris ->> 'id', '');

  SELECT nama_lengkap, nik INTO v_aktor_nama, v_aktor_nik
  FROM karyawan WHERE id = v_aktor;

  -- Siapa yang dikenai perubahan (kalau barisnya menunjuk ke seorang karyawan)
  IF v_baris ? 'karyawan_id' THEN
    SELECT nama_lengkap INTO v_subjek FROM karyawan
    WHERE id = (v_baris ->> 'karyawan_id')::UUID;
  ELSIF TG_TABLE_NAME = 'karyawan' THEN
    v_subjek := v_baris ->> 'nama_lengkap';
  END IF;

  v_ringkas := CASE v_aksi
    WHEN 'tambah' THEN 'Menambah data di ' || TG_TABLE_NAME
    WHEN 'ubah'   THEN 'Mengubah ' || array_to_string(ARRAY(SELECT jsonb_object_keys(v_ubah)), ', ') || ' di ' || TG_TABLE_NAME
    ELSE 'Menghapus data di ' || TG_TABLE_NAME END;
  IF v_subjek IS NOT NULL THEN v_ringkas := v_ringkas || ' — ' || v_subjek; END IF;

  INSERT INTO log_aktivitas (aktor_id, aktor_nama, aktor_nik, aksi, tabel, baris_id, subjek_nama, ringkasan, perubahan)
  VALUES (v_aktor, COALESCE(v_aktor_nama, '(di luar aplikasi)'), v_aktor_nik,
          v_aksi, TG_TABLE_NAME, v_id, v_subjek, v_ringkas, v_ubah);

  RETURN NULL;   -- AFTER trigger
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Khusus absensi: absen masuk/keluar oleh karyawan sendiri itu rutin dan
-- akan membanjiri log. Yang dicatat HANYA bila absensi seseorang disentuh
-- oleh ORANG LAIN (input manual / koreksi oleh HR) — itu yang berkonsekuensi.
CREATE OR REPLACE FUNCTION public.catat_absensi_oleh_orang_lain()
RETURNS TRIGGER AS $$
DECLARE v_pemilik UUID;
BEGIN
  v_pemilik := COALESCE((to_jsonb(NEW) ->> 'karyawan_id')::UUID,
                        (to_jsonb(OLD) ->> 'karyawan_id')::UUID);
  IF auth.uid() IS NOT NULL AND auth.uid() = v_pemilik THEN
    RETURN NULL;   -- perubahan oleh pemiliknya sendiri: lewati
  END IF;
  RETURN public.catat_aktivitas();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- Pasang trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_log_karyawan             ON karyawan;
DROP TRIGGER IF EXISTS trg_log_karyawan_komponen    ON karyawan_komponen;
DROP TRIGGER IF EXISTS trg_log_komponen_gaji        ON komponen_gaji;
DROP TRIGGER IF EXISTS trg_log_payroll_periode      ON payroll_periode;
DROP TRIGGER IF EXISTS trg_log_pengajuan_cuti       ON pengajuan_cuti;
DROP TRIGGER IF EXISTS trg_log_saldo_cuti           ON saldo_cuti;
DROP TRIGGER IF EXISTS trg_log_izin_absen_luar      ON izin_absen_luar;
DROP TRIGGER IF EXISTS trg_log_absensi              ON absensi;
DROP TRIGGER IF EXISTS trg_log_pengaturan           ON pengaturan;

CREATE TRIGGER trg_log_karyawan          AFTER INSERT OR UPDATE OR DELETE ON karyawan
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_karyawan_komponen AFTER INSERT OR UPDATE OR DELETE ON karyawan_komponen
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_komponen_gaji     AFTER INSERT OR UPDATE OR DELETE ON komponen_gaji
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_payroll_periode   AFTER INSERT OR UPDATE OR DELETE ON payroll_periode
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_pengajuan_cuti    AFTER UPDATE OR DELETE ON pengajuan_cuti
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_saldo_cuti        AFTER INSERT OR UPDATE OR DELETE ON saldo_cuti
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_izin_absen_luar   AFTER UPDATE OR DELETE ON izin_absen_luar
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
CREATE TRIGGER trg_log_pengaturan        AFTER INSERT OR UPDATE OR DELETE ON pengaturan
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();

-- absensi memakai penyaring "hanya bila disentuh orang lain"
CREATE TRIGGER trg_log_absensi           AFTER INSERT OR UPDATE OR DELETE ON absensi
  FOR EACH ROW EXECUTE FUNCTION public.catat_absensi_oleh_orang_lain();

-- Tabel berikut baru ada sejak fase17/18/19 — dipasang hanya bila tabelnya
-- memang ada, supaya berkas ini tetap bisa dijalankan di pemasangan lama.
DO $$
BEGIN
  IF to_regclass('public.koreksi_absen') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_log_koreksi_absen ON koreksi_absen;
    CREATE TRIGGER trg_log_koreksi_absen AFTER UPDATE OR DELETE ON koreksi_absen
      FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
  END IF;
  IF to_regclass('public.penandatangan') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_log_penandatangan ON penandatangan;
    CREATE TRIGGER trg_log_penandatangan AFTER INSERT OR UPDATE OR DELETE ON penandatangan
      FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
  END IF;
  IF to_regclass('public.karyawan_potongan_manual') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_log_potongan_manual ON karyawan_potongan_manual;
    CREATE TRIGGER trg_log_potongan_manual AFTER INSERT OR UPDATE OR DELETE ON karyawan_potongan_manual
      FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
  END IF;
  IF to_regclass('public.hari_libur') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_log_hari_libur ON hari_libur;
    CREATE TRIGGER trg_log_hari_libur AFTER INSERT OR DELETE ON hari_libur
      FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();
  END IF;
END $$;

-- ============================================================
-- Selesai. Setelah dijalankan:
--   • Menu "Log Aktivitas" muncul di sidebar untuk HR Admin
--   • Perubahan penting mulai tercatat SEJAK SAAT INI (tidak surut)
--   • slip_gaji sengaja TIDAK dipasangi trigger: satu periode membuat
--     puluhan baris sekaligus sehingga log akan tenggelam. Yang dicatat
--     adalah periodenya (dibuat / difinalisasi / dibatalkan / dihapus).
-- ============================================================
