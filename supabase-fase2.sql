-- ============================================================
-- FASE 2 — Tambahan SQL untuk Fase 2 (Data Karyawan)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- Trigger: otomatis buat row karyawan saat user baru diundang & register
-- Ini penting agar karyawan baru langsung muncul di daftar setelah terima invite

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.karyawan (id, nik, nama_lengkap, email)
  VALUES (
    NEW.id,
    'NEW-' || substr(NEW.id::text, 1, 6),        -- NIK sementara, HR akan edit nanti
    COALESCE(
      NEW.raw_user_meta_data->>'nama_lengkap',    -- jika ada di metadata
      split_part(NEW.email, '@', 1)               -- fallback: ambil dari email
    ),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;  -- jika sudah ada (misal HR Admin), skip
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasang trigger ke auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- Setelah menjalankan SQL ini:
-- - Setiap kali Anda invite karyawan baru via Supabase Dashboard
--   → Authentication → Users → Invite user
-- - Setelah karyawan terima link dan set password,
--   baris mereka otomatis muncul di tabel karyawan
-- - HR Admin tinggal buka karyawan.html dan lengkapi datanya
-- ============================================================
