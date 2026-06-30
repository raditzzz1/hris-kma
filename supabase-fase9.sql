-- ============================================================
-- FASE 9 — Jam kerja per-karyawan & gaji per-jam (freelance)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

ALTER TABLE karyawan
  ADD COLUMN IF NOT EXISTS jam_masuk_standar   TIME DEFAULT '09:00',
  ADD COLUMN IF NOT EXISTS jam_kerja_fleksibel BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS tipe_gaji           TEXT DEFAULT 'bulanan'
       CHECK (tipe_gaji IN ('bulanan','per_jam')),
  ADD COLUMN IF NOT EXISTS tarif_per_jam       NUMERIC(15,2) DEFAULT 0;

-- ============================================================
-- Penjelasan:
-- - jam_masuk_standar  : ambang "terlambat" per karyawan (default 09:00).
-- - jam_kerja_fleksibel: TRUE = jam berubah-ubah/rolling -> TIDAK pernah
--   ditandai terlambat, hanya catat jam aktual (mis. Live staff Marketing).
-- - tipe_gaji          : 'bulanan' (default) atau 'per_jam' (freelance).
-- - tarif_per_jam      : upah per jam untuk tipe_gaji='per_jam'.
--
-- Payroll untuk tipe_gaji='per_jam': gaji = total jam kerja pada periode
-- (dari tabel absensi) x tarif_per_jam, DIBAYAR BERSIH (tanpa BPJS/PPh).
-- ============================================================
