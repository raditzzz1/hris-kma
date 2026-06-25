-- ============================================================
-- BUGFIX & DATA UPDATE — PT Kawan Menengah Atas HRIS
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================


-- ============================================================
-- BAGIAN 1: UPDATE DATA JABATAN & DIVISI
-- ============================================================

-- [1a] Hapus jabatan "Marketing Staff" di divisi Marketing
DELETE FROM jabatan
  WHERE nama = 'Marketing Staff'
    AND divisi_id = (SELECT id FROM divisi WHERE nama = 'Marketing');

-- [1b] Tambah jabatan di divisi Operations
INSERT INTO jabatan (nama, divisi_id)
SELECT v.nama, d.id
FROM (VALUES
  ('Operation Manager'),
  ('Packaging Leader'),
  ('Packaging Staff')
) AS v(nama)
CROSS JOIN (SELECT id FROM divisi WHERE nama = 'Operations') AS d
ON CONFLICT DO NOTHING;

-- [1c] Tambah jabatan di divisi Marketing
INSERT INTO jabatan (nama, divisi_id)
SELECT v.nama, d.id
FROM (VALUES
  ('KOL Specialist Leader'),
  ('KOL Specialist Staff'),
  ('Creative Leader'),
  ('Creative Staff - Content Creator'),
  ('Creative Staff - Videographer'),
  ('Creative Staff - Design'),
  ('Creative Staff - Social Media Specialist'),
  ('Creative Staff - Copywriting'),
  ('Ads Leader'),
  ('Ads Staff'),
  ('CRM (Customer Relationship Manager)'),
  ('Marketplace Specialist'),
  ('Affiliate Specialist Leader'),
  ('Affiliate Specialist Staff'),
  ('Live Staff'),
  ('Affiliate Internal Staff')
) AS v(nama)
CROSS JOIN (SELECT id FROM divisi WHERE nama = 'Marketing') AS d
ON CONFLICT DO NOTHING;

-- [1d] Hapus Divisi Information Technology
--   Langkah: null-kan divisi karyawan → hapus jabatan → hapus divisi

UPDATE karyawan
  SET divisi_id = NULL, jabatan_id = NULL
  WHERE divisi_id = (SELECT id FROM divisi WHERE nama = 'Information Technology');

DELETE FROM jabatan
  WHERE divisi_id = (SELECT id FROM divisi WHERE nama = 'Information Technology');

DELETE FROM divisi WHERE nama = 'Information Technology';


-- ============================================================
-- BAGIAN 2: UPDATE JENIS CUTI
-- ============================================================

-- [2a] Hapus Cuti Duka — migrasikan pengajuan ke Cuti Tahunan
UPDATE pengajuan_cuti
  SET jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'tahunan')
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'duka');
DELETE FROM saldo_cuti
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'duka');
DELETE FROM jenis_cuti WHERE kode = 'duka';

-- [2b] Hapus Izin — migrasikan pengajuan ke Cuti Tahunan
UPDATE pengajuan_cuti
  SET jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'tahunan')
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'izin');
DELETE FROM saldo_cuti
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'izin');
DELETE FROM jenis_cuti WHERE kode = 'izin';

-- [2c] Merge Cuti Sakit → Cuti Tahunan (jadikan satu saldo)
UPDATE pengajuan_cuti
  SET jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'tahunan')
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'sakit');
DELETE FROM saldo_cuti
  WHERE jenis_cuti_id = (SELECT id FROM jenis_cuti WHERE kode = 'sakit');
DELETE FROM jenis_cuti WHERE kode = 'sakit';

-- Ganti nama Cuti Tahunan agar mencerminkan cakupannya
UPDATE jenis_cuti
  SET nama = 'Cuti Tahunan & Sakit', maks_hari = 12
  WHERE kode = 'tahunan';

-- [2d] Tambah jenis cuti WFH dan WFA
INSERT INTO jenis_cuti (nama, kode, maks_hari, berbayar, aktif) VALUES
  ('WFH (Work from Home)',    'wfh', NULL, TRUE, TRUE),
  ('WFA (Work from Anywhere)','wfa', NULL, TRUE, TRUE)
ON CONFLICT (kode) DO NOTHING;


-- ============================================================
-- BAGIAN 3: UPDATE TABEL ABSENSI — tambah kolom mode_kerja
-- ============================================================

ALTER TABLE absensi
  ADD COLUMN IF NOT EXISTS mode_kerja TEXT DEFAULT 'kantor';

-- Set nilai mode_kerja untuk record lama
UPDATE absensi SET mode_kerja = 'kantor' WHERE mode_kerja IS NULL;


-- ============================================================
-- SELESAI — Ringkasan perubahan:
-- 1. Jabatan Operations: +3 (Mgr, Packaging Leader, Staff)
-- 2. Jabatan Marketing: -1 (Marketing Staff), +16 jabatan baru
-- 3. Divisi IT: dihapus (karyawan di-unassign)
-- 4. Jenis cuti: hapus Duka, Izin, Sakit; merge ke Cuti Tahunan & Sakit
-- 5. Tambah jenis cuti WFH, WFA
-- 6. Tabel absensi: kolom baru mode_kerja (kantor/wfh/wfa)
-- ============================================================
