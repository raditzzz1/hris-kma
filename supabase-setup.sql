-- ============================================================
-- HRIS PT KAWAN MENENGAH ATAS — Database Schema
-- Jalankan file ini di Supabase: SQL Editor > New Query
-- ============================================================


-- =====================
-- 1. TABEL DIVISI
-- =====================
CREATE TABLE IF NOT EXISTS divisi (
  id   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama TEXT NOT NULL,
  kode TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- 2. TABEL JABATAN
-- =====================
CREATE TABLE IF NOT EXISTS jabatan (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama      TEXT NOT NULL,
  divisi_id UUID REFERENCES divisi(id) ON DELETE SET NULL,
  level     INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- 3. LOKASI KANTOR (untuk geofencing absensi)
-- =====================
CREATE TABLE IF NOT EXISTS lokasi_kantor (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama         TEXT NOT NULL,
  alamat       TEXT,
  latitude     DECIMAL(10, 8) NOT NULL,
  longitude    DECIMAL(11, 8) NOT NULL,
  radius_meter INTEGER DEFAULT 100,  -- radius dalam meter (default 100m)
  aktif        BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- 4. TABEL KARYAWAN (terhubung ke auth.users Supabase)
-- =====================
CREATE TABLE IF NOT EXISTS karyawan (
  id                UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nik               TEXT UNIQUE NOT NULL,
  nama_lengkap      TEXT NOT NULL,
  email             TEXT NOT NULL,
  no_hp             TEXT,
  tempat_lahir      TEXT,
  tanggal_lahir     DATE,
  jenis_kelamin     TEXT CHECK (jenis_kelamin IN ('L', 'P')),
  alamat            TEXT,
  jabatan_id        UUID REFERENCES jabatan(id) ON DELETE SET NULL,
  divisi_id         UUID REFERENCES divisi(id) ON DELETE SET NULL,
  tanggal_bergabung DATE,
  tipe_kontrak      TEXT DEFAULT 'tetap' CHECK (tipe_kontrak IN ('tetap', 'kontrak', 'magang', 'freelance')),
  status            TEXT DEFAULT 'aktif' CHECK (status IN ('aktif', 'tidak_aktif', 'cuti_panjang')),
  role              TEXT DEFAULT 'karyawan' CHECK (role IN ('karyawan', 'hr_admin', 'manager')),
  foto_url          TEXT,
  gaji_pokok        DECIMAL(15, 2) DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- 5. TABEL ABSENSI
-- =====================
CREATE TABLE IF NOT EXISTS absensi (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  karyawan_id      UUID REFERENCES karyawan(id) ON DELETE CASCADE NOT NULL,
  tanggal          DATE NOT NULL,
  waktu_masuk      TIMESTAMPTZ,
  lat_masuk        DECIMAL(10, 8),
  lng_masuk        DECIMAL(11, 8),
  waktu_keluar     TIMESTAMPTZ,
  lat_keluar       DECIMAL(10, 8),
  lng_keluar       DECIMAL(11, 8),
  durasi_kerja_menit INTEGER,
  status           TEXT DEFAULT 'hadir' CHECK (status IN ('hadir', 'terlambat', 'pulang_awal', 'tidak_hadir', 'izin', 'cuti')),
  keterangan       TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(karyawan_id, tanggal)   -- 1 record per karyawan per hari
);

-- =====================
-- 6. TABEL PENGAJUAN CUTI (untuk Fase 4 nanti)
-- =====================
CREATE TABLE IF NOT EXISTS cuti (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  karyawan_id    UUID REFERENCES karyawan(id) ON DELETE CASCADE NOT NULL,
  jenis_cuti     TEXT NOT NULL,  -- tahunan, sakit, melahirkan, dll
  tanggal_mulai  DATE NOT NULL,
  tanggal_selesai DATE NOT NULL,
  jumlah_hari    INTEGER,
  alasan         TEXT,
  status         TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'disetujui', 'ditolak', 'dibatalkan')),
  disetujui_oleh UUID REFERENCES karyawan(id),
  catatan_hr     TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- 7. SALDO CUTI KARYAWAN
-- =====================
CREATE TABLE IF NOT EXISTS saldo_cuti (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  karyawan_id UUID REFERENCES karyawan(id) ON DELETE CASCADE NOT NULL,
  tahun       INTEGER NOT NULL,
  jenis_cuti  TEXT NOT NULL,
  total_hari  INTEGER DEFAULT 12,
  terpakai    INTEGER DEFAULT 0,
  sisa        INTEGER GENERATED ALWAYS AS (total_hari - terpakai) STORED,
  UNIQUE(karyawan_id, tahun, jenis_cuti)
);


-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- Divisi
INSERT INTO divisi (nama, kode) VALUES
  ('Human Resource', 'HR'),
  ('Finance & Accounting', 'FA'),
  ('Marketing', 'MKT'),
  ('Operations', 'OPS'),
  ('Information Technology', 'IT')
ON CONFLICT (kode) DO NOTHING;

-- Jabatan
INSERT INTO jabatan (nama, divisi_id) VALUES
  ('HR Manager',       (SELECT id FROM divisi WHERE kode = 'HR')),
  ('HR Staff',         (SELECT id FROM divisi WHERE kode = 'HR')),
  ('Finance Manager',  (SELECT id FROM divisi WHERE kode = 'FA')),
  ('Staff Accounting', (SELECT id FROM divisi WHERE kode = 'FA')),
  ('Marketing Manager',(SELECT id FROM divisi WHERE kode = 'MKT')),
  ('Marketing Staff',  (SELECT id FROM divisi WHERE kode = 'MKT')),
  ('IT Developer',     (SELECT id FROM divisi WHERE kode = 'IT')),
  ('IT Support',       (SELECT id FROM divisi WHERE kode = 'IT'));

-- Lokasi Kantor (ganti dengan koordinat kantor Anda yang sebenarnya)
-- Cara dapat koordinat: buka Google Maps, klik lokasi kantor, salin lat & lng
INSERT INTO lokasi_kantor (nama, alamat, latitude, longitude, radius_meter) VALUES
  ('Kantor Pusat', 'Jakarta Selatan', -6.2297, 106.8295, 100);


-- ============================================================
-- ROW LEVEL SECURITY (RLS) — Keamanan data per user
-- ============================================================

ALTER TABLE karyawan     ENABLE ROW LEVEL SECURITY;
ALTER TABLE absensi      ENABLE ROW LEVEL SECURITY;
ALTER TABLE divisi       ENABLE ROW LEVEL SECURITY;
ALTER TABLE jabatan      ENABLE ROW LEVEL SECURITY;
ALTER TABLE lokasi_kantor ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuti         ENABLE ROW LEVEL SECURITY;
ALTER TABLE saldo_cuti   ENABLE ROW LEVEL SECURITY;

-- Helper function: cek apakah user adalah HR Admin
CREATE OR REPLACE FUNCTION is_hr_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM karyawan
    WHERE id = auth.uid() AND role = 'hr_admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER;

-- Helper function: cek apakah user adalah Manager
CREATE OR REPLACE FUNCTION is_manager()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM karyawan
    WHERE id = auth.uid() AND role IN ('hr_admin', 'manager')
  );
$$ LANGUAGE SQL SECURITY DEFINER;

-- KARYAWAN: semua karyawan bisa lihat data diri sendiri
CREATE POLICY "karyawan_select_own" ON karyawan
  FOR SELECT USING (auth.uid() = id);

-- KARYAWAN: HR Admin bisa lihat semua karyawan
CREATE POLICY "hr_admin_select_all_karyawan" ON karyawan
  FOR SELECT USING (is_hr_admin());

-- KARYAWAN: HR Admin bisa insert/update karyawan
CREATE POLICY "hr_admin_manage_karyawan" ON karyawan
  FOR ALL USING (is_hr_admin());

-- KARYAWAN: Karyawan bisa update data diri sendiri (data terbatas)
CREATE POLICY "karyawan_update_own" ON karyawan
  FOR UPDATE USING (auth.uid() = id);

-- ABSENSI: Karyawan lihat absensi sendiri
CREATE POLICY "absensi_select_own" ON absensi
  FOR SELECT USING (karyawan_id = auth.uid());

-- ABSENSI: Karyawan bisa absen (insert)
CREATE POLICY "absensi_insert_own" ON absensi
  FOR INSERT WITH CHECK (karyawan_id = auth.uid());

-- ABSENSI: Karyawan bisa update absensi sendiri (untuk checkout)
CREATE POLICY "absensi_update_own" ON absensi
  FOR UPDATE USING (karyawan_id = auth.uid());

-- ABSENSI: HR Admin lihat semua absensi
CREATE POLICY "hr_admin_select_all_absensi" ON absensi
  FOR SELECT USING (is_hr_admin());

-- ABSENSI: HR Admin manage semua absensi
CREATE POLICY "hr_admin_manage_absensi" ON absensi
  FOR ALL USING (is_hr_admin());

-- DIVISI & JABATAN: semua karyawan bisa lihat
CREATE POLICY "all_select_divisi" ON divisi
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "all_select_jabatan" ON jabatan
  FOR SELECT USING (auth.role() = 'authenticated');

-- DIVISI & JABATAN: HR Admin bisa manage
CREATE POLICY "hr_admin_manage_divisi" ON divisi
  FOR ALL USING (is_hr_admin());

CREATE POLICY "hr_admin_manage_jabatan" ON jabatan
  FOR ALL USING (is_hr_admin());

-- LOKASI KANTOR: semua karyawan bisa lihat (untuk absensi)
CREATE POLICY "all_select_lokasi" ON lokasi_kantor
  FOR SELECT USING (auth.role() = 'authenticated');

-- LOKASI KANTOR: HR Admin bisa manage
CREATE POLICY "hr_admin_manage_lokasi" ON lokasi_kantor
  FOR ALL USING (is_hr_admin());

-- CUTI: Karyawan lihat cuti sendiri
CREATE POLICY "cuti_select_own" ON cuti
  FOR SELECT USING (karyawan_id = auth.uid());

-- CUTI: Karyawan bisa ajukan cuti
CREATE POLICY "cuti_insert_own" ON cuti
  FOR INSERT WITH CHECK (karyawan_id = auth.uid());

-- CUTI: Manager/HR bisa lihat semua cuti
CREATE POLICY "manager_select_all_cuti" ON cuti
  FOR SELECT USING (is_manager());

-- CUTI: Manager/HR bisa approve/reject cuti
CREATE POLICY "manager_manage_cuti" ON cuti
  FOR ALL USING (is_manager());

-- SALDO CUTI: Karyawan lihat saldo sendiri
CREATE POLICY "saldo_select_own" ON saldo_cuti
  FOR SELECT USING (karyawan_id = auth.uid());

-- SALDO CUTI: HR Admin manage semua saldo
CREATE POLICY "hr_admin_manage_saldo" ON saldo_cuti
  FOR ALL USING (is_hr_admin());


-- ============================================================
-- TRIGGER: auto-update kolom updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER karyawan_updated_at
  BEFORE UPDATE ON karyawan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER cuti_updated_at
  BEFORE UPDATE ON cuti
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- SETUP AWAL — BACA INI SETELAH MENJALANKAN SQL DI ATAS:
-- ============================================================
-- 1. Buka Supabase Dashboard → Authentication → Users → "Invite user"
-- 2. Masukkan email Anda sendiri (sebagai HR Admin pertama)
-- 3. Klik link di email dan set password Anda
-- 4. Setelah login ke HRIS, buka Supabase → Table Editor → tabel "karyawan"
-- 5. Isi data Anda (nik, nama_lengkap, email) dan set kolom "role" = 'hr_admin'
-- ============================================================
