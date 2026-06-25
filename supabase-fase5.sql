-- ============================================================
-- FASE 5 — Payroll & Kompensasi
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- 1. Tambah kolom status PTKP di tabel karyawan
ALTER TABLE karyawan
  ADD COLUMN IF NOT EXISTS status_ptkp TEXT DEFAULT 'TK/0'
    CHECK (status_ptkp IN ('TK/0','TK/1','TK/2','TK/3','K/0','K/1','K/2','K/3','K/I/0','K/I/1','K/I/2','K/I/3'));

-- 2. Komponen gaji (master tunjangan & potongan)
CREATE TABLE IF NOT EXISTS komponen_gaji (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama        TEXT NOT NULL,
  tipe        TEXT NOT NULL CHECK (tipe IN ('tunjangan','potongan')),
  kena_pajak  BOOLEAN DEFAULT TRUE,   -- apakah masuk perhitungan PPh 21
  aktif       BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Nilai komponen per karyawan
CREATE TABLE IF NOT EXISTS karyawan_komponen (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  komponen_id     UUID NOT NULL REFERENCES komponen_gaji(id) ON DELETE CASCADE,
  nilai           DECIMAL(15,2) DEFAULT 0,
  UNIQUE (karyawan_id, komponen_id)
);

-- 4. Periode payroll (per bulan)
CREATE TABLE IF NOT EXISTS payroll_periode (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bulan       INTEGER NOT NULL CHECK (bulan BETWEEN 1 AND 12),
  tahun       INTEGER NOT NULL,
  status      TEXT DEFAULT 'draft' CHECK (status IN ('draft','final')),
  catatan     TEXT,
  dibuat_oleh UUID REFERENCES karyawan(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (bulan, tahun)
);

-- 5. Slip gaji per karyawan per periode
CREATE TABLE IF NOT EXISTS slip_gaji (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  periode_id            UUID NOT NULL REFERENCES payroll_periode(id) ON DELETE CASCADE,
  karyawan_id           UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,

  -- Pendapatan
  gaji_pokok            DECIMAL(15,2) DEFAULT 0,
  total_tunjangan       DECIMAL(15,2) DEFAULT 0,
  detail_tunjangan      JSONB DEFAULT '[]',  -- [{nama, nilai}]

  -- Potongan wajib
  bpjs_kes_karyawan     DECIMAL(15,2) DEFAULT 0,  -- 1% gaji
  bpjs_jht_karyawan     DECIMAL(15,2) DEFAULT 0,  -- 2% gaji
  bpjs_jp_karyawan      DECIMAL(15,2) DEFAULT 0,  -- 1% gaji (capped)
  pph21                 DECIMAL(15,2) DEFAULT 0,

  -- Potongan lainnya
  total_potongan_lain   DECIMAL(15,2) DEFAULT 0,
  detail_potongan       JSONB DEFAULT '[]',  -- [{nama, nilai}]

  -- Kontribusi perusahaan (informasi, tidak mengurangi gaji)
  bpjs_kes_perusahaan   DECIMAL(15,2) DEFAULT 0,  -- 4% gaji
  bpjs_jht_perusahaan   DECIMAL(15,2) DEFAULT 0,  -- 3.7% gaji
  bpjs_jp_perusahaan    DECIMAL(15,2) DEFAULT 0,  -- 2% gaji (capped)

  -- Total
  total_pendapatan      DECIMAL(15,2) DEFAULT 0,  -- gaji_pokok + total_tunjangan
  total_potongan        DECIMAL(15,2) DEFAULT 0,  -- semua potongan
  gaji_bersih           DECIMAL(15,2) DEFAULT 0,  -- take-home pay

  -- Metadata PPh 21
  status_ptkp           TEXT,
  penghasilan_netto_setahun DECIMAL(15,2) DEFAULT 0,
  ptkp                  DECIMAL(15,2) DEFAULT 0,
  pkp                   DECIMAL(15,2) DEFAULT 0,

  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (periode_id, karyawan_id)
);

-- Trigger updated_at
CREATE TRIGGER update_payroll_periode_updated_at
  BEFORE UPDATE ON payroll_periode
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_slip_gaji_updated_at
  BEFORE UPDATE ON slip_gaji
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE komponen_gaji       ENABLE ROW LEVEL SECURITY;
ALTER TABLE karyawan_komponen   ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_periode     ENABLE ROW LEVEL SECURITY;
ALTER TABLE slip_gaji           ENABLE ROW LEVEL SECURITY;

-- komponen_gaji: semua bisa baca, HR manage
CREATE POLICY "komponen_read_all"   ON komponen_gaji FOR SELECT USING (true);
CREATE POLICY "komponen_hr_manage"  ON komponen_gaji FOR ALL    USING (is_hr_admin());

-- karyawan_komponen: karyawan lihat milik sendiri, HR manage semua
CREATE POLICY "kary_komp_own"       ON karyawan_komponen FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "kary_komp_hr"        ON karyawan_komponen FOR ALL    USING (is_hr_admin());

-- payroll_periode: semua bisa baca, HR manage
CREATE POLICY "periode_read_all"    ON payroll_periode FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "periode_hr_manage"   ON payroll_periode FOR ALL    USING (is_hr_admin());

-- slip_gaji: karyawan lihat milik sendiri, HR lihat & manage semua
CREATE POLICY "slip_read_own"       ON slip_gaji FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "slip_hr_manage"      ON slip_gaji FOR ALL    USING (is_hr_admin());

-- ============================================================
-- DATA AWAL — Komponen Gaji Umum
-- ============================================================

INSERT INTO komponen_gaji (nama, tipe, kena_pajak) VALUES
  ('Tunjangan Transport',   'tunjangan', FALSE),
  ('Tunjangan Makan',       'tunjangan', FALSE),
  ('Tunjangan Jabatan',     'tunjangan', TRUE),
  ('Tunjangan Kehadiran',   'tunjangan', FALSE),
  ('Bonus',                 'tunjangan', TRUE),
  ('Potongan Keterlambatan','potongan',  FALSE),
  ('Potongan Tidak Hadir',  'potongan',  FALSE),
  ('Pinjaman Karyawan',     'potongan',  FALSE)
ON CONFLICT DO NOTHING;

-- ============================================================
-- CATATAN TARIF (edit di payroll.html bagian KONSTANTA):
--
-- BPJS Kesehatan  : karyawan 1%, perusahaan 4%, max gaji 12.000.000
-- BPJS JHT        : karyawan 2%, perusahaan 3.7%
-- BPJS JP         : karyawan 1%, perusahaan 2%, max gaji 10.042.300 (2024)
-- Biaya Jabatan   : 5% penghasilan bruto, max 500.000/bulan
-- PTKP (setahun)  : TK/0=54jt, TK/1=58.5jt, K/0=58.5jt, K/1=63jt,
--                   K/2=67.5jt, K/3=72jt
-- PPh 21 Progresif: 0-60jt=5%, 60-250jt=15%, 250-500jt=25%,
--                   500jt-5M=30%, >5M=35%
-- ============================================================
