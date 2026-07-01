-- ============================================================
-- FASE 10 — NIK otomatis (format KMA-001, KMA-002, ...)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Kebijakan:
--  - NIK karyawan baru diisi OTOMATIS saat invite diterima (format KMA-XXX).
--  - NIK TIDAK PERNAH dipakai ulang, walau karyawan resign/nonaktif —
--    nomor urut hanya naik, tidak pernah mundur/diisi celah kosong.
-- ============================================================

-- 1. Sequence generator nomor urut NIK
CREATE SEQUENCE IF NOT EXISTS nik_seq;

-- 2. Kalibrasi: lanjutkan dari NIK "KMA-xxx" tertinggi yang sudah ada
--    (aman dijalankan walau tabel karyawan sudah berisi data)
SELECT setval('nik_seq', COALESCE((
  SELECT MAX(substring(nik from 'KMA-(\d+)')::int)
  FROM karyawan WHERE nik ~ '^KMA-\d+$'
), 0));

-- 3. Update trigger: NIK sementara "NEW-xxxxxx" diganti generator KMA-XXX
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_nik TEXT;
BEGIN
  v_nik := 'KMA-' || LPAD(nextval('nik_seq')::text, 3, '0');
  -- Jaga-jaga bila nomor itu kebetulan sudah dipakai (mis. pernah diisi
  -- manual oleh HR) -> lompat ke nomor berikutnya yang belum dipakai.
  -- Sequence tidak pernah mundur, jadi NIK tidak pernah terpakai ulang.
  WHILE EXISTS (SELECT 1 FROM karyawan WHERE nik = v_nik) LOOP
    v_nik := 'KMA-' || LPAD(nextval('nik_seq')::text, 3, '0');
  END LOOP;

  INSERT INTO public.karyawan (id, nik, nama_lengkap, email)
  VALUES (
    NEW.id,
    v_nik,
    COALESCE(
      NEW.raw_user_meta_data->>'nama_lengkap',
      split_part(NEW.email, '@', 1)
    ),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on_auth_user_created dari Fase 2 tetap dipakai (fungsi di atas
-- di-CREATE OR REPLACE, jadi trigger yang sudah terpasang otomatis ikut
-- memakai versi baru ini — tidak perlu drop/create ulang triggernya).

-- ============================================================
-- Setelah menjalankan SQL ini:
-- - Undangan karyawan baru (Supabase Auth -> Invite user) akan otomatis
--   mendapat NIK berformat KMA-XXX, HR tidak perlu isi manual lagi.
-- - HR tetap BISA mengedit NIK secara manual di Data Karyawan jika perlu
--   (mis. migrasi data lama) — cukup pastikan formatnya tidak bentrok.
-- - Karyawan resign (status tidak aktif) TETAP menyimpan NIK lamanya
--   selamanya; nomor tsb tidak akan pernah diberikan ke karyawan lain.
-- ============================================================
