-- ============================================================
-- FASE 12 — Notifikasi browser (cuti/izin disetujui-ditolak)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Mengaktifkan Supabase Realtime pada 2 tabel, agar aplikasi bisa "dengar"
-- perubahan status pengajuan secara langsung dan menampilkan notifikasi
-- browser ke karyawan (SELAMA tab/app-nya masih terbuka, tidak saat app
-- ditutup total — itu perlu push notification server yang lebih berat).
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'pengajuan_cuti'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE pengajuan_cuti;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'izin_absen_luar'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE izin_absen_luar;
  END IF;
END $$;

-- ============================================================
-- Setelah menjalankan SQL ini:
-- - Karyawan yang mengaktifkan notifikasi (tombol lonceng di Dashboard) akan
--   dapat notifikasi browser saat pengajuan cuti / izin absen luar mereka
--   disetujui atau ditolak HR, selama tab/app masih terbuka (boleh minimize).
-- ============================================================
