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
-- PENTING: SET search_path = public, pg_temp WAJIB di sini.
-- Trigger ini dijalankan oleh Supabase Auth sebagai role `supabase_auth_admin`
-- yang search_path-nya hanya `auth` (bukan `public`). Tanpa baris SET ini,
-- referensi `nik_seq` & `karyawan` dicari di skema `auth` -> tidak ketemu ->
-- trigger error -> muncul "Database error creating new user" saat menambah user.
-- (Semua objek juga di-qualify `public.` sebagai pengaman ganda.)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nik TEXT;
BEGIN
  v_nik := 'KMA-' || LPAD(nextval('public.nik_seq')::text, 3, '0');
  -- Jaga-jaga bila nomor itu kebetulan sudah dipakai (mis. pernah diisi
  -- manual oleh HR) -> lompat ke nomor berikutnya yang belum dipakai.
  -- Sequence tidak pernah mundur, jadi NIK tidak pernah terpakai ulang.
  WHILE EXISTS (SELECT 1 FROM public.karyawan WHERE nik = v_nik) LOOP
    v_nik := 'KMA-' || LPAD(nextval('public.nik_seq')::text, 3, '0');
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
$$;

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
