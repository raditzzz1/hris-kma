-- ============================================================
-- FASE 8 — Foto Profil (Supabase Storage)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- 1. Bucket publik untuk foto profil
INSERT INTO storage.buckets (id, name, public)
VALUES ('foto-profil', 'foto-profil', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Policy akses file (tabel storage.objects)
-- Baca: publik (agar <img src> bisa tampil di mana saja)
CREATE POLICY "foto_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'foto-profil');

-- Upload: hanya ke folder milik sendiri (folder = auth.uid()) atau HR Admin
CREATE POLICY "foto_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'foto-profil'
    AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_hr_admin())
  );

-- Ganti foto (upsert)
CREATE POLICY "foto_update_own" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'foto-profil'
    AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_hr_admin())
  );

-- Hapus foto
CREATE POLICY "foto_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'foto-profil'
    AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_hr_admin())
  );

-- ============================================================
-- Catatan: kolom karyawan.foto_url sudah ada sejak skema awal.
-- Aplikasi menyimpan path: <karyawan_id>/avatar di bucket ini, lalu
-- menyimpan public URL-nya ke karyawan.foto_url.
-- ============================================================
