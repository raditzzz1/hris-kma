-- ============================================================
-- FASE 13 — WFH otomatis tiap Sabtu (per karyawan)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Kebijakan:
--  - Karyawan yang ditandai wfh_sabtu = true boleh absen dari LUAR radius
--    setiap hari Sabtu TANPA perlu mengajukan "Izin Absen Luar" & tanpa
--    menunggu persetujuan HR (mode tercatat sebagai WFH).
--  - Karyawan wfh_sabtu = false (default) TETAP wajib absen di dalam radius
--    kantor pada hari Sabtu — geofence tetap berlaku untuk mereka.
--  - Pengecualian dadakan (mis. orang kantor sesekali WFH, sakit, dinas)
--    tetap memakai alur "Izin Absen Luar" yang lama.
-- ============================================================

ALTER TABLE public.karyawan
  ADD COLUMN IF NOT EXISTS wfh_sabtu boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.karyawan.wfh_sabtu IS
  'true = karyawan WFH otomatis tiap Sabtu (boleh absen di luar radius tanpa izin/persetujuan HR).';

-- ============================================================
-- Setelah menjalankan SQL ini:
-- - HR buka Data Karyawan -> Edit -> tab "Data Pekerjaan" -> set
--   "WFH Otomatis tiap Sabtu" = Ya untuk karyawan yang WFH tiap Sabtu.
-- - Di hari Sabtu, karyawan tsb bisa langsung Absen Masuk/Keluar dari luar
--   radius (tombol aktif, mode WFH) tanpa mengajukan izin.
-- ============================================================
