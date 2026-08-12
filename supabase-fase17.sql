-- ============================================================
-- FASE 17 — Fondasi: data kontrak & identitas, arsip dokumen,
--            koreksi absen, pengaturan surat
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Isi:
--   1. Kolom baru di `karyawan` (identitas lengkap + masa kontrak PKWT)
--   2. PERBAIKAN KEAMANAN: karyawan tak bisa lagi mengubah kolom sensitif
--      miliknya sendiri (gaji, role, masa kontrak, dll) lewat API langsung
--   3. Tabel `dokumen_karyawan` + bucket PRIVAT (arsip kontrak/KTP/ijazah)
--   4. Tabel `koreksi_absen` (karyawan mengajukan perbaikan absen)
--   5. Tabel `pengaturan` (identitas perusahaan & penandatangan surat)
-- ============================================================


-- ============================================================
-- 1. KOLOM BARU DI TABEL KARYAWAN
-- ============================================================
ALTER TABLE karyawan
  -- Identitas & administrasi (boleh diisi karyawan sendiri)
  ADD COLUMN IF NOT EXISTS nik_ktp               TEXT,
  ADD COLUMN IF NOT EXISTS npwp                  TEXT,
  ADD COLUMN IF NOT EXISTS no_bpjs_kesehatan     TEXT,
  ADD COLUMN IF NOT EXISTS no_bpjs_tk            TEXT,
  ADD COLUMN IF NOT EXISTS kontak_darurat_nama   TEXT,
  ADD COLUMN IF NOT EXISTS kontak_darurat_hp     TEXT,
  ADD COLUMN IF NOT EXISTS kontak_darurat_relasi TEXT,
  -- Data kepegawaian & kontrak (HANYA HR yang boleh ubah — lihat bagian 2)
  ADD COLUMN IF NOT EXISTS department              TEXT,
  ADD COLUMN IF NOT EXISTS atasan_langsung         TEXT,
  ADD COLUMN IF NOT EXISTS tanggal_mulai_kontrak   DATE,
  ADD COLUMN IF NOT EXISTS tanggal_berakhir_kontrak DATE,
  ADD COLUMN IF NOT EXISTS pkwt_ke                 SMALLINT;

COMMENT ON COLUMN karyawan.nik_ktp  IS 'NIK KTP 16 digit (berbeda dari kolom nik = Employee ID)';
COMMENT ON COLUMN karyawan.department IS 'Departemen, lebih spesifik dari divisi (mis. Divisi Marketing > Dept. Creative)';
COMMENT ON COLUMN karyawan.tanggal_berakhir_kontrak IS 'Akhir masa PKWT. Dipakai pengingat & generator kontrak. NULL untuk karyawan tetap.';
COMMENT ON COLUMN karyawan.pkwt_ke IS 'PKWT ke-berapa (1=I, 2=II, 3=III) untuk penomoran & judul kontrak';

-- Index untuk pencarian kontrak yang akan berakhir
CREATE INDEX IF NOT EXISTS idx_karyawan_akhir_kontrak
  ON karyawan (tanggal_berakhir_kontrak)
  WHERE tanggal_berakhir_kontrak IS NOT NULL;


-- ============================================================
-- 2. PERBAIKAN KEAMANAN — proteksi kolom sensitif
-- ============================================================
-- MASALAH: policy `karyawan_update_own` (FOR UPDATE USING auth.uid() = id)
-- membolehkan karyawan mengubah SEMUA kolom barisnya sendiri. Lewat UI memang
-- tak bisa, TAPI anon key bersifat publik — siapa pun yang login bisa memanggil
-- API langsung dan mengubah `gaji_pokok`, `role` (jadi hr_admin!), `status`,
-- atau memperpanjang `tanggal_berakhir_kontrak` sendiri.
--
-- SOLUSI: trigger yang menolak perubahan kolom sensitif bila pelakunya bukan
-- HR Admin. Kolom data pribadi (alamat, no HP, NPWP, kontak darurat, dll)
-- tetap boleh diubah sendiri — self-service tetap jalan.
CREATE OR REPLACE FUNCTION cegah_ubah_kolom_sensitif()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- HR Admin bebas mengubah apa pun
  IF public.is_hr_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.nik                      IS DISTINCT FROM OLD.nik
  OR NEW.role                     IS DISTINCT FROM OLD.role
  OR NEW.status                   IS DISTINCT FROM OLD.status
  OR NEW.gaji_pokok               IS DISTINCT FROM OLD.gaji_pokok
  OR NEW.tipe_kontrak             IS DISTINCT FROM OLD.tipe_kontrak
  OR NEW.jabatan_id               IS DISTINCT FROM OLD.jabatan_id
  OR NEW.divisi_id                IS DISTINCT FROM OLD.divisi_id
  OR NEW.tanggal_bergabung        IS DISTINCT FROM OLD.tanggal_bergabung
  OR NEW.status_ptkp              IS DISTINCT FROM OLD.status_ptkp
  OR NEW.jam_masuk_standar        IS DISTINCT FROM OLD.jam_masuk_standar
  OR NEW.jam_kerja_fleksibel      IS DISTINCT FROM OLD.jam_kerja_fleksibel
  OR NEW.tipe_gaji                IS DISTINCT FROM OLD.tipe_gaji
  OR NEW.tarif_per_jam            IS DISTINCT FROM OLD.tarif_per_jam
  OR NEW.wfh_sabtu                IS DISTINCT FROM OLD.wfh_sabtu
  OR NEW.department               IS DISTINCT FROM OLD.department
  OR NEW.atasan_langsung          IS DISTINCT FROM OLD.atasan_langsung
  OR NEW.tanggal_mulai_kontrak    IS DISTINCT FROM OLD.tanggal_mulai_kontrak
  OR NEW.tanggal_berakhir_kontrak IS DISTINCT FROM OLD.tanggal_berakhir_kontrak
  OR NEW.pkwt_ke                  IS DISTINCT FROM OLD.pkwt_ke
  THEN
    RAISE EXCEPTION 'Kolom kepegawaian hanya boleh diubah oleh HR Admin.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS karyawan_cegah_kolom_sensitif ON karyawan;
CREATE TRIGGER karyawan_cegah_kolom_sensitif
  BEFORE UPDATE ON karyawan
  FOR EACH ROW EXECUTE FUNCTION cegah_ubah_kolom_sensitif();


-- ============================================================
-- 3. ARSIP DOKUMEN KARYAWAN
-- ============================================================
CREATE TABLE IF NOT EXISTS dokumen_karyawan (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id   UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  jenis         TEXT NOT NULL DEFAULT 'lainnya'
                CHECK (jenis IN ('kontrak','ktp','npwp','ijazah','sertifikat',
                                 'bpjs','surat','foto','lainnya')),
  judul         TEXT NOT NULL,
  path          TEXT NOT NULL,              -- path di bucket 'dokumen-karyawan'
  nama_file     TEXT,
  ukuran_byte   BIGINT,
  catatan       TEXT,
  berlaku_sampai DATE,                      -- opsional: utk dokumen yg kedaluwarsa
  diunggah_oleh UUID REFERENCES karyawan(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dokumen_karyawan_id ON dokumen_karyawan (karyawan_id);
CREATE INDEX IF NOT EXISTS idx_dokumen_jenis       ON dokumen_karyawan (jenis);

ALTER TABLE dokumen_karyawan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dokumen_select_own ON dokumen_karyawan;
CREATE POLICY dokumen_select_own ON dokumen_karyawan
  FOR SELECT USING (karyawan_id = auth.uid() OR public.is_hr_admin());

DROP POLICY IF EXISTS dokumen_insert ON dokumen_karyawan;
CREATE POLICY dokumen_insert ON dokumen_karyawan
  FOR INSERT WITH CHECK (karyawan_id = auth.uid() OR public.is_hr_admin());

-- Ubah & hapus: HR Admin saja (agar kontrak tak bisa dihapus karyawan)
DROP POLICY IF EXISTS dokumen_update_hr ON dokumen_karyawan;
CREATE POLICY dokumen_update_hr ON dokumen_karyawan
  FOR UPDATE USING (public.is_hr_admin());

DROP POLICY IF EXISTS dokumen_delete_hr ON dokumen_karyawan;
CREATE POLICY dokumen_delete_hr ON dokumen_karyawan
  FOR DELETE USING (public.is_hr_admin());

-- Bucket PRIVAT (berbeda dari 'foto-profil' yang publik) — berisi KTP,
-- kontrak, ijazah. Akses file lewat signed URL, bukan URL publik.
INSERT INTO storage.buckets (id, name, public)
VALUES ('dokumen-karyawan', 'dokumen-karyawan', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "dok_read_own" ON storage.objects;
CREATE POLICY "dok_read_own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'dokumen-karyawan'
    AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_hr_admin())
  );

DROP POLICY IF EXISTS "dok_insert_own" ON storage.objects;
CREATE POLICY "dok_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'dokumen-karyawan'
    AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_hr_admin())
  );

DROP POLICY IF EXISTS "dok_update_hr" ON storage.objects;
CREATE POLICY "dok_update_hr" ON storage.objects
  FOR UPDATE USING (bucket_id = 'dokumen-karyawan' AND public.is_hr_admin());

DROP POLICY IF EXISTS "dok_delete_hr" ON storage.objects;
CREATE POLICY "dok_delete_hr" ON storage.objects
  FOR DELETE USING (bucket_id = 'dokumen-karyawan' AND public.is_hr_admin());


-- ============================================================
-- 4. PENGAJUAN KOREKSI ABSEN
-- ============================================================
CREATE TABLE IF NOT EXISTS koreksi_absen (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id       UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  tanggal           DATE NOT NULL,
  jam_masuk_usulan  TIME,
  jam_keluar_usulan TIME,
  alasan            TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'menunggu'
                    CHECK (status IN ('menunggu','disetujui','ditolak')),
  catatan_hr        TEXT,
  diproses_oleh     UUID REFERENCES karyawan(id) ON DELETE SET NULL,
  diproses_pada     TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_koreksi_karyawan ON koreksi_absen (karyawan_id, tanggal);
CREATE INDEX IF NOT EXISTS idx_koreksi_status   ON koreksi_absen (status);

ALTER TABLE koreksi_absen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS koreksi_select_own ON koreksi_absen;
CREATE POLICY koreksi_select_own ON koreksi_absen
  FOR SELECT USING (karyawan_id = auth.uid() OR public.is_hr_admin());

-- Karyawan hanya boleh mengajukan untuk dirinya sendiri
DROP POLICY IF EXISTS koreksi_insert_own ON koreksi_absen;
CREATE POLICY koreksi_insert_own ON koreksi_absen
  FOR INSERT WITH CHECK (karyawan_id = auth.uid() OR public.is_hr_admin());

-- Keputusan (setujui/tolak) hanya HR
DROP POLICY IF EXISTS koreksi_update_hr ON koreksi_absen;
CREATE POLICY koreksi_update_hr ON koreksi_absen
  FOR UPDATE USING (public.is_hr_admin());

DROP POLICY IF EXISTS koreksi_delete_hr ON koreksi_absen;
CREATE POLICY koreksi_delete_hr ON koreksi_absen
  FOR DELETE USING (public.is_hr_admin());


-- ============================================================
-- 5. PENGATURAN (identitas perusahaan & penandatangan surat)
-- ============================================================
CREATE TABLE IF NOT EXISTS pengaturan (
  kunci      TEXT PRIMARY KEY,
  nilai      TEXT,
  keterangan TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE pengaturan ENABLE ROW LEVEL SECURITY;

-- Semua yang login boleh BACA (dipakai kop surat), hanya HR boleh UBAH
DROP POLICY IF EXISTS pengaturan_read ON pengaturan;
CREATE POLICY pengaturan_read ON pengaturan
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS pengaturan_manage_hr ON pengaturan;
CREATE POLICY pengaturan_manage_hr ON pengaturan
  FOR ALL USING (public.is_hr_admin()) WITH CHECK (public.is_hr_admin());

INSERT INTO pengaturan (kunci, nilai, keterangan) VALUES
  ('perusahaan_nama',        'PT Kawan Menengah Atas', 'Nama perusahaan di kop surat'),
  ('perusahaan_alamat',      'Jl. Kemang Soka Raya Blok Z No.17, Kemang Pratama 2, Bekasi', 'Alamat di kop surat'),
  ('perusahaan_kota',        'Bekasi', 'Kota penandatanganan surat'),
  ('penandatangan_nama',     'Satrio Buwono Wicaksono', 'Nama Pihak Pertama di kontrak/surat'),
  ('penandatangan_jabatan',  'Marketing Director',      'Jabatan penandatangan'),
  ('jam_kerja_senin_jumat',  '09.00 s/d 17.00 WIB (WFO)', 'Teks jam kerja di kontrak'),
  ('jam_kerja_sabtu',        '09.00 s/d 16.00 WIB (WFH)', 'Teks jam kerja Sabtu di kontrak'),
  ('cuti_tahunan_hari',      '12', 'Jumlah hari cuti tahunan di kontrak')
ON CONFLICT (kunci) DO NOTHING;

-- Realtime untuk notifikasi koreksi absen (pola sama dgn cuti/izin di fase12)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE koreksi_absen;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

-- ============================================================
-- Selesai. Setelah dijalankan:
--   • Data Karyawan punya isian identitas & masa kontrak baru
--   • Karyawan TIDAK bisa lagi mengubah gaji/role/kontraknya sendiri
--   • Siap untuk: arsip dokumen, generator PKWT & surat, koreksi absen
-- ============================================================
