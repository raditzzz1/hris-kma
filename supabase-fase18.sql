-- ============================================================
-- FASE 18 — Penandatangan & tanda tangan digital
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Tujuan: surat/kontrak bisa dibubuhi tanda tangan otomatis sesuai
-- penandatangan yang dipilih (mis. Satrio atau Moammer).
--
-- CATATAN KEAMANAN: berkas tanda tangan disimpan di bucket PRIVAT.
-- Tanda tangan yang bisa diunduh publik = risiko pemalsuan, karena bisa
-- ditempel ke dokumen apa pun. Bucket privat + signed URL berumur pendek
-- membuatnya hanya bisa dimuat oleh pengguna yang sudah login.
-- ============================================================

CREATE TABLE IF NOT EXISTS penandatangan (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama        TEXT NOT NULL,
  jabatan     TEXT NOT NULL,
  ttd_path    TEXT,               -- path di bucket 'tanda-tangan'
  aktif       BOOLEAN NOT NULL DEFAULT TRUE,
  urutan      SMALLINT DEFAULT 0, -- untuk mengatur mana yang tampil lebih dulu
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE penandatangan IS
  'Daftar pejabat penandatangan surat/kontrak beserta berkas tanda tangannya.';

CREATE INDEX IF NOT EXISTS idx_penandatangan_aktif ON penandatangan (aktif, urutan);

ALTER TABLE penandatangan ENABLE ROW LEVEL SECURITY;

-- Semua yang login boleh MEMBACA (dipakai saat merender surat),
-- tapi hanya HR Admin yang boleh menambah/mengubah/menghapus.
DROP POLICY IF EXISTS penandatangan_read ON penandatangan;
CREATE POLICY penandatangan_read ON penandatangan
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS penandatangan_manage_hr ON penandatangan;
CREATE POLICY penandatangan_manage_hr ON penandatangan
  FOR ALL USING (public.is_hr_admin()) WITH CHECK (public.is_hr_admin());

-- ============================================================
-- Bucket PRIVAT untuk berkas tanda tangan
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('tanda-tangan', 'tanda-tangan', false)
ON CONFLICT (id) DO NOTHING;

-- Dibaca oleh semua yang login (lewat signed URL) supaya karyawan tetap bisa
-- melihat surat miliknya yang sudah bertanda tangan.
DROP POLICY IF EXISTS "ttd_read_login" ON storage.objects;
CREATE POLICY "ttd_read_login" ON storage.objects
  FOR SELECT USING (bucket_id = 'tanda-tangan' AND auth.uid() IS NOT NULL);

-- Hanya HR Admin yang boleh mengunggah/mengganti/menghapus tanda tangan.
DROP POLICY IF EXISTS "ttd_insert_hr" ON storage.objects;
CREATE POLICY "ttd_insert_hr" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'tanda-tangan' AND public.is_hr_admin());

DROP POLICY IF EXISTS "ttd_update_hr" ON storage.objects;
CREATE POLICY "ttd_update_hr" ON storage.objects
  FOR UPDATE USING (bucket_id = 'tanda-tangan' AND public.is_hr_admin());

DROP POLICY IF EXISTS "ttd_delete_hr" ON storage.objects;
CREATE POLICY "ttd_delete_hr" ON storage.objects
  FOR DELETE USING (bucket_id = 'tanda-tangan' AND public.is_hr_admin());

-- ============================================================
-- Isi awal: penandatangan yang sudah dipakai selama ini.
-- Berkas tanda tangannya diunggah lewat aplikasi (Data Karyawan >
-- Buat Surat > Kelola Penandatangan), bukan lewat SQL.
-- ============================================================
INSERT INTO penandatangan (nama, jabatan, urutan)
SELECT 'Satrio Buwono Wicaksono', 'Marketing Director', 1
WHERE NOT EXISTS (SELECT 1 FROM penandatangan WHERE nama = 'Satrio Buwono Wicaksono');

-- ============================================================
-- Selesai. Setelah dijalankan:
--   • HR bisa mengelola daftar penandatangan + unggah tanda tangan
--   • Tanda tangan tampil otomatis di PKWT, Surat Keterangan Kerja,
--     dan Bukti Potong 1721-A1 sesuai penandatangan yang dipilih
-- ============================================================
