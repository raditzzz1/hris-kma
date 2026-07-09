-- ============================================================
-- FASE 14 — Modul Marketing/KOL (skema + RLS)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Modul marketing berbagi login & tabel karyawan yang sama dengan HRIS,
-- tapi aksesnya TERPISAH dari role HR (`karyawan.role`). Seorang HR Admin
-- TIDAK otomatis punya akses data marketing — harus ditandai eksplisit
-- lewat `akses_marketing`, karena data fee/budget dianggap sensitif.
-- ============================================================

-- 1. Akses modul Marketing (kolom baru di karyawan, orthogonal thd `role`)
ALTER TABLE public.karyawan
  ADD COLUMN IF NOT EXISTS akses_marketing BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS marketing_role TEXT NOT NULL DEFAULT 'staff'
    CHECK (marketing_role IN ('staff','admin'));

COMMENT ON COLUMN public.karyawan.akses_marketing IS
  'true = karyawan ini bagian tim marketing & boleh buka modul Marketing/KOL. Tidak berkaitan dengan role HR (hr_admin/manager/karyawan).';
COMMENT ON COLUMN public.karyawan.marketing_role IS
  'staff = input & lihat data marketing; admin = plus kelola data KOL master, target/budget, dan boleh ubah/hapus entri siapa pun.';

-- 2. KOL master data (influencer eksternal — BUKAN karyawan/pegawai)
CREATE TABLE IF NOT EXISTS kol (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama_lengkap  TEXT NOT NULL,
  username      TEXT,
  nik           TEXT,
  tempat_lahir  TEXT,
  tanggal_lahir DATE,
  alamat        TEXT,
  npwp          TEXT,
  no_rekening   TEXT,
  no_hp         TEXT,
  rate_card     NUMERIC(15,2) DEFAULT 0,
  status        TEXT DEFAULT 'aktif' CHECK (status IN ('aktif','tidak_aktif')),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS kol_username_unique ON kol (lower(username)) WHERE username IS NOT NULL;

-- 3. Posting log — satu baris = satu konten KOL (pengganti baris Google Sheet)
CREATE TABLE IF NOT EXISTS konten_kol (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kol_id        UUID NOT NULL REFERENCES kol(id) ON DELETE RESTRICT,
  karyawan_id   UUID REFERENCES karyawan(id) ON DELETE SET NULL,  -- PIC
  tanggal       DATE NOT NULL,
  platform      TEXT NOT NULL CHECK (platform IN ('TikTok','Instagram','Facebook','Youtube','Twitter')),
  produk        TEXT,
  tipe_konten   TEXT CHECK (tipe_konten IN ('Hardselling','Softselling','Story Telling','Honest Review','A Day in My Life','Unboxing','Tutorial','Endorsement','Mirroring','Lainnya')),
  status        TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','posted','batal')),
  fee_ratecard  NUMERIC(15,2) DEFAULT 0,
  total_biaya   NUMERIC(15,2) DEFAULT 0,
  views         INTEGER DEFAULT 0,
  likes         INTEGER DEFAULT 0,
  comments      INTEGER DEFAULT 0,
  share         INTEGER DEFAULT 0,
  link          TEXT,
  keterangan    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_konten_kol_tanggal     ON konten_kol(tanggal);
CREATE INDEX IF NOT EXISTS idx_konten_kol_kol_id      ON konten_kol(kol_id);
CREATE INDEX IF NOT EXISTS idx_konten_kol_karyawan_id ON konten_kol(karyawan_id);
CREATE INDEX IF NOT EXISTS idx_konten_kol_status      ON konten_kol(status);

-- 4. Target bulanan (pengganti localStorage — shared antar tim).
--    Kolom `modul` future-proof untuk modul Ads/Konten/Marketplace nanti.
CREATE TABLE IF NOT EXISTS marketing_target (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modul         TEXT NOT NULL DEFAULT 'kol',
  tahun         INT NOT NULL,
  bulan         INT NOT NULL,
  target_views  BIGINT,
  budget        NUMERIC(15,2),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(modul, tahun, bulan)
);

-- Triggers updated_at (reuse fungsi update_updated_at() dari supabase-setup.sql)
CREATE TRIGGER kol_updated_at
  BEFORE UPDATE ON kol
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER konten_kol_updated_at
  BEFORE UPDATE ON konten_kol
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER marketing_target_updated_at
  BEFORE UPDATE ON marketing_target
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
-- SET search_path = public, pg_temp ditambahkan proaktif (pelajaran dari
-- bug handle_new_user() di fase10 — lihat komentar di file itu).
CREATE OR REPLACE FUNCTION is_marketing()
RETURNS BOOLEAN
LANGUAGE SQL SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM karyawan WHERE id = auth.uid() AND akses_marketing = true
  );
$$;

CREATE OR REPLACE FUNCTION is_marketing_admin()
RETURNS BOOLEAN
LANGUAGE SQL SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM karyawan
    WHERE id = auth.uid() AND akses_marketing = true AND marketing_role = 'admin'
  );
$$;

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE kol              ENABLE ROW LEVEL SECURITY;
ALTER TABLE konten_kol       ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketing_target ENABLE ROW LEVEL SECURITY;

-- karyawan: tim marketing saling lihat (dropdown PIC & join nama).
-- WAJIB ada — tanpa ini staf non-hr_admin cuma bisa SELECT baris dirinya
-- sendiri di tabel karyawan (kebijakan lama dari setup.sql), jadi nama PIC
-- rekan kerja lain akan tampil null di modul marketing.
CREATE POLICY "karyawan_select_marketing_team" ON karyawan
  FOR SELECT USING (is_marketing() AND akses_marketing = true);

-- kol: semua tim marketing baca; hanya admin marketing yang kelola
CREATE POLICY "kol_select_marketing" ON kol FOR SELECT USING (is_marketing());
CREATE POLICY "kol_admin_manage"     ON kol FOR ALL    USING (is_marketing_admin());

-- konten_kol: semua tim baca & boleh INPUT atas nama PIC lain (staf boleh
-- input-kan data untuk rekan setim); UBAH/HAPUS hanya PIC pemilik baris
-- atau admin marketing.
CREATE POLICY "konten_kol_select_marketing" ON konten_kol FOR SELECT USING (is_marketing());
CREATE POLICY "konten_kol_insert_marketing" ON konten_kol FOR INSERT WITH CHECK (is_marketing());
CREATE POLICY "konten_kol_update_own_admin" ON konten_kol FOR UPDATE USING (karyawan_id = auth.uid() OR is_marketing_admin());
CREATE POLICY "konten_kol_delete_own_admin" ON konten_kol FOR DELETE USING (karyawan_id = auth.uid() OR is_marketing_admin());

-- marketing_target: semua tim marketing baca; hanya admin kelola
CREATE POLICY "target_select_marketing" ON marketing_target FOR SELECT USING (is_marketing());
CREATE POLICY "target_admin_manage"     ON marketing_target FOR ALL    USING (is_marketing_admin());

-- ============================================================
-- Setelah menjalankan SQL ini:
-- 1. HR Admin buka Data Karyawan -> Edit -> tab Data Pekerjaan -> set
--    "Akses Modul Marketing" = Ya & "Role Marketing" = Admin untuk diri
--    sendiri / admin marketing pertama.
-- 2. Baru admin itu bisa mengatur staf marketing lain & mulai input data
--    di marketing-kol.html.
-- ============================================================
