-- ============================================================
-- FASE 11 — Hari Libur Nasional (pindah dari hardcode ke database)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Sebelumnya daftar hari libur ditulis manual di kode (absensi.html & cuti.html),
-- terpisah 2 tempat dan hanya sampai tahun 2026. Sekarang HR bisa kelola sendiri
-- lewat halaman Absensi (khusus HR Admin), tanpa perlu edit kode lagi.
-- ============================================================

CREATE TABLE IF NOT EXISTS hari_libur (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tanggal     DATE NOT NULL UNIQUE,
  nama        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE hari_libur ENABLE ROW LEVEL SECURITY;

-- Semua karyawan yang login boleh baca (dipakai absensi & hitung cuti)
CREATE POLICY "hari_libur_read_all" ON hari_libur
  FOR SELECT USING (auth.role() = 'authenticated');

-- Hanya HR Admin yang boleh tambah/ubah/hapus
CREATE POLICY "hari_libur_hr_manage" ON hari_libur
  FOR ALL USING (is_hr_admin());

-- ============================================================
-- Migrasi data: 19 hari libur 2026 yang sebelumnya hardcode di kode
-- (aman dijalankan ulang — ON CONFLICT DO NOTHING)
-- ============================================================
INSERT INTO hari_libur (tanggal, nama) VALUES
  ('2026-01-01', 'Tahun Baru Masehi 2026'),
  ('2026-01-16', 'Isra Mi''raj Nabi Muhammad SAW 1447H'),
  ('2026-02-17', 'Tahun Baru Imlek 2577'),
  ('2026-03-19', 'Hari Raya Nyepi'),
  ('2026-03-20', 'Cuti Bersama Idul Fitri'),
  ('2026-03-21', 'Hari Raya Idul Fitri 1447H'),
  ('2026-03-22', 'Hari Raya Idul Fitri 1447H'),
  ('2026-03-23', 'Cuti Bersama Idul Fitri'),
  ('2026-03-24', 'Cuti Bersama Idul Fitri'),
  ('2026-04-03', 'Wafat Isa Al Masih'),
  ('2026-05-01', 'Hari Buruh Internasional'),
  ('2026-05-14', 'Kenaikan Isa Al Masih'),
  ('2026-05-27', 'Hari Raya Idul Adha 1447H'),
  ('2026-05-31', 'Hari Raya Waisak'),
  ('2026-06-01', 'Hari Lahir Pancasila'),
  ('2026-06-16', 'Tahun Baru Islam 1448H'),
  ('2026-08-17', 'HUT RI ke-81'),
  ('2026-08-25', 'Maulid Nabi Muhammad SAW 1448H'),
  ('2026-12-25', 'Hari Natal')
ON CONFLICT (tanggal) DO NOTHING;

-- ============================================================
-- Setelah menjalankan SQL ini:
-- - Halaman Absensi (HR Admin) punya panel "Kelola Hari Libur" untuk
--   tambah/hapus tanggal libur tahun berapa pun.
-- - Absensi & perhitungan hari cuti otomatis memakai data ini (bukan lagi
--   daftar hardcode di kode).
-- ============================================================
