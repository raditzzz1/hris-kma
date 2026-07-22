-- ============================================================
-- FASE 16 — Statistik foto profil (untuk pengingat & papan skor)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Catatan penomoran: fase 14 & 15 dulu dipakai modul Marketing/KOL yang
-- akhirnya DIBATALKAN (objeknya sudah di-DROP, filenya dihapus dari repo).
-- Nomor itu sengaja TIDAK dipakai ulang supaya tidak rancu saat membaca
-- riwayat commit lama. Lanjut dari 16.
-- ============================================================
-- Masalah: karyawan biasa hanya boleh SELECT barisnya sendiri di tabel
-- `karyawan` (policy `karyawan_select_own`). Jadi mereka tidak bisa
-- menghitung "berapa karyawan yang sudah pasang foto" untuk papan skor.
--
-- Solusi: satu fungsi SECURITY DEFINER yang HANYA mengembalikan dua
-- ANGKA agregat (total & sudah). Tidak membocorkan nama, foto, gaji,
-- atau data pribadi apa pun — jadi aman dibuka untuk semua yang login.
--
-- `SET search_path = public, pg_temp` dipasang sesuai pelajaran dari bug
-- handle_new_user() di fase10 (lihat komentar di file itu).
-- ============================================================

CREATE OR REPLACE FUNCTION statistik_foto_profil()
RETURNS TABLE (total BIGINT, sudah BIGINT)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    COUNT(*)::BIGINT AS total,
    COUNT(*) FILTER (
      WHERE foto_url IS NOT NULL AND btrim(foto_url) <> ''
    )::BIGINT AS sudah
  FROM karyawan
  WHERE status = 'aktif';
$$;

COMMENT ON FUNCTION statistik_foto_profil() IS
  'Jumlah karyawan aktif & berapa yang sudah pasang foto profil. Hanya angka agregat (tanpa data pribadi), dipakai papan skor pengingat foto di Dashboard.';

-- Boleh dipanggil semua akun yang sudah login (bukan publik/anon)
REVOKE ALL ON FUNCTION statistik_foto_profil() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION statistik_foto_profil() TO authenticated;

-- ============================================================
-- Setelah menjalankan SQL ini:
-- Karyawan yang belum pasang foto akan melihat pengingat di Dashboard
-- lengkap dengan progres "X dari Y karyawan sudah pasang foto".
-- Pengingat bisa ditutup, tapi muncul lagi tiap buka Dashboard sampai
-- fotonya dipasang. Tidak ada fitur yang dikunci (absen tetap aman).
-- ============================================================
