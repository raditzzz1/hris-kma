-- ============================================================
-- FASE 4 — Cuti & Izin
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- 1. Tabel jenis cuti (contoh: Cuti Tahunan, Sakit, dll)
CREATE TABLE IF NOT EXISTS jenis_cuti (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama        TEXT NOT NULL,           -- "Cuti Tahunan", "Sakit", "Izin"
  kode        TEXT UNIQUE NOT NULL,    -- "tahunan", "sakit", "izin", "melahirkan"
  maks_hari   INTEGER DEFAULT NULL,    -- NULL = tidak dibatasi (misal sakit)
  berbayar    BOOLEAN DEFAULT TRUE,
  aktif       BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Saldo cuti karyawan per jenis & per tahun
-- (Tabel saldo_cuti mungkin sudah ada dari Fase 1, kita alter agar lebih lengkap)
-- Jika belum ada, buat baru:
CREATE TABLE IF NOT EXISTS saldo_cuti (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  jenis_cuti_id   UUID NOT NULL REFERENCES jenis_cuti(id) ON DELETE CASCADE,
  tahun           INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW()),
  saldo_awal      INTEGER DEFAULT 0,
  terpakai        INTEGER DEFAULT 0,
  UNIQUE (karyawan_id, jenis_cuti_id, tahun)
);

-- 3. Tabel pengajuan cuti
CREATE TABLE IF NOT EXISTS pengajuan_cuti (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  jenis_cuti_id   UUID NOT NULL REFERENCES jenis_cuti(id),
  tanggal_mulai   DATE NOT NULL,
  tanggal_selesai DATE NOT NULL,
  jumlah_hari     INTEGER NOT NULL,
  alasan          TEXT,
  status          TEXT DEFAULT 'pending'
                  CHECK (status IN ('pending','disetujui','ditolak','dibatalkan')),
  catatan_hr      TEXT,                -- catatan dari HR saat approve/reject
  approved_by     UUID REFERENCES karyawan(id),
  approved_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger updated_at untuk pengajuan_cuti
CREATE TRIGGER update_pengajuan_cuti_updated_at
  BEFORE UPDATE ON pengajuan_cuti
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE jenis_cuti      ENABLE ROW LEVEL SECURITY;
ALTER TABLE saldo_cuti      ENABLE ROW LEVEL SECURITY;
ALTER TABLE pengajuan_cuti  ENABLE ROW LEVEL SECURITY;

-- jenis_cuti: semua orang bisa baca, hanya HR yang bisa ubah
CREATE POLICY "jenis_cuti_read_all"   ON jenis_cuti FOR SELECT USING (true);
CREATE POLICY "jenis_cuti_hr_modify"  ON jenis_cuti FOR ALL    USING (is_hr_admin());

-- saldo_cuti: karyawan lihat milik sendiri, HR lihat semua
CREATE POLICY "saldo_cuti_own"        ON saldo_cuti FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "saldo_cuti_hr_manage"  ON saldo_cuti FOR ALL    USING (is_hr_admin());

-- pengajuan_cuti: karyawan lihat & buat milik sendiri; HR lihat & ubah semua
CREATE POLICY "pengajuan_read_own"    ON pengajuan_cuti FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "pengajuan_insert_own"  ON pengajuan_cuti FOR INSERT WITH CHECK (karyawan_id = auth.uid());
CREATE POLICY "pengajuan_update_own"  ON pengajuan_cuti FOR UPDATE USING (
  karyawan_id = auth.uid() OR is_hr_admin()
);

-- ============================================================
-- DATA AWAL — Jenis Cuti
-- ============================================================

INSERT INTO jenis_cuti (nama, kode, maks_hari, berbayar) VALUES
  ('Cuti Tahunan',    'tahunan',    12,   TRUE),
  ('Cuti Sakit',      'sakit',      NULL, TRUE),
  ('Izin',            'izin',       NULL, TRUE),
  ('Cuti Melahirkan', 'melahirkan', 90,   TRUE),
  ('Cuti Duka',       'duka',       3,    TRUE)
ON CONFLICT (kode) DO NOTHING;

-- ============================================================
-- Setelah jalankan SQL ini:
-- 1. Buka tabel saldo_cuti di Supabase Table Editor
-- 2. Isi saldo cuti tahunan untuk masing-masing karyawan
--    (karyawan_id, jenis_cuti_id cuti tahunan, tahun 2026, saldo_awal 12)
-- Atau gunakan fitur "Isi Saldo" di halaman cuti.html (HR Admin)
-- ============================================================
