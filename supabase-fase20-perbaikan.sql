-- ============================================================
-- FASE 20 — PERBAIKAN MENDESAK
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- MASALAH: fase20 memasang fungsi pembungkus catat_absensi_oleh_orang_lain()
-- yang memanggil catat_aktivitas() seperti fungsi biasa. PostgreSQL melarang
-- itu dan menolak dengan:
--     "trigger functions can only be called as triggers"
--
-- Karena triggernya menyala pada SETIAP penulisan ke tabel absensi, akibatnya
-- SEMUA penyimpanan absensi gagal -- bukan cuma HR mengedit, tapi juga absen
-- masuk/keluar karyawan biasa.
--
-- PERBAIKAN: aturan "hanya catat bila absensi disentuh orang lain" dipindah
-- KE DALAM catat_aktivitas(), dan fungsi pembungkusnya dihapus.
--
-- Aman dijalankan berulang. Tidak menghapus satu pun isi log yang sudah ada.
-- ============================================================

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
  v_pemilik    UUID;
BEGIN
  -- ABSENSI: absen masuk/keluar oleh karyawan sendiri itu rutin dan akan
  -- membanjiri log. Yang dicatat HANYA bila absensi seseorang disentuh oleh
  -- ORANG LAIN (input manual / koreksi oleh HR) — itu yang berkonsekuensi.
  --
  -- Aturan ini DI DALAM fungsi ini, bukan di fungsi pembungkus terpisah:
  -- fungsi ber-RETURNS TRIGGER tidak boleh dipanggil seperti fungsi biasa
  -- (PostgreSQL menolak dengan "trigger functions can only be called as
  -- triggers"), dan itu membuat SELURUH penulisan ke tabel absensi gagal —
  -- termasuk absen masuk karyawan biasa.
  IF TG_TABLE_NAME = 'absensi' THEN
    v_pemilik := COALESCE((to_jsonb(NEW) ->> 'karyawan_id')::UUID,
                          (to_jsonb(OLD) ->> 'karyawan_id')::UUID);
    IF v_aktor IS NOT NULL AND v_aktor = v_pemilik THEN
      RETURN NULL;   -- diubah pemiliknya sendiri: tidak dicatat
    END IF;
  END IF;

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

-- Arahkan trigger absensi ke fungsi yang sudah benar.
DROP TRIGGER IF EXISTS trg_log_absensi ON absensi;
CREATE TRIGGER trg_log_absensi AFTER INSERT OR UPDATE OR DELETE ON absensi
  FOR EACH ROW EXECUTE FUNCTION public.catat_aktivitas();

-- Buang fungsi pembungkus yang bermasalah.
DROP FUNCTION IF EXISTS public.catat_absensi_oleh_orang_lain() CASCADE;

-- ============================================================
-- Sesudah ini: absen masuk/keluar & edit absensi kembali berfungsi.
-- Absen oleh karyawan sendiri TIDAK dicatat di log (memang disengaja);
-- absensi yang diubah HR tetap tercatat.
-- ============================================================
