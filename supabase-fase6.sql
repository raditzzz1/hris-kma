-- ============================================================
-- FASE 6 — Pelatihan & Pengembangan SDM
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- 1. Program Pelatihan
CREATE TABLE IF NOT EXISTS program_pelatihan (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama          TEXT NOT NULL,
  deskripsi     TEXT,
  kategori      TEXT DEFAULT 'internal'
                CHECK (kategori IN ('internal','eksternal','online','sertifikasi')),
  divisi_id     UUID REFERENCES divisi(id) ON DELETE SET NULL,  -- NULL = semua divisi
  durasi_jam    INTEGER DEFAULT 0,
  instruktur    TEXT,
  maks_peserta  INTEGER DEFAULT NULL,   -- NULL = tidak dibatasi
  aktif         BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Materi / Modul Pelatihan
CREATE TABLE IF NOT EXISTS materi_pelatihan (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id    UUID NOT NULL REFERENCES program_pelatihan(id) ON DELETE CASCADE,
  judul         TEXT NOT NULL,
  deskripsi     TEXT,
  urutan        INTEGER DEFAULT 1,
  tipe          TEXT DEFAULT 'dokumen'
                CHECK (tipe IN ('dokumen','video','link','quiz')),
  url_konten    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Peserta Pelatihan (enrollment)
CREATE TABLE IF NOT EXISTS peserta_pelatihan (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id      UUID NOT NULL REFERENCES program_pelatihan(id) ON DELETE CASCADE,
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  status          TEXT DEFAULT 'terdaftar'
                  CHECK (status IN ('terdaftar','sedang_berlangsung','selesai','tidak_lulus')),
  tanggal_daftar  DATE DEFAULT CURRENT_DATE,
  tanggal_selesai DATE,
  nilai           INTEGER,              -- 0-100
  catatan         TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (program_id, karyawan_id)
);

-- 4. Sertifikasi Karyawan
CREATE TABLE IF NOT EXISTS sertifikasi (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  program_id      UUID REFERENCES program_pelatihan(id) ON DELETE SET NULL,
  nama_sertifikat TEXT NOT NULL,
  lembaga_penerbit TEXT,
  tanggal_terbit  DATE,
  tanggal_expired DATE,                -- NULL = tidak expired
  nomor_sertifikat TEXT,
  url_dokumen     TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Triggers
CREATE TRIGGER update_program_pelatihan_updated_at
  BEFORE UPDATE ON program_pelatihan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_peserta_pelatihan_updated_at
  BEFORE UPDATE ON peserta_pelatihan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE program_pelatihan  ENABLE ROW LEVEL SECURITY;
ALTER TABLE materi_pelatihan   ENABLE ROW LEVEL SECURITY;
ALTER TABLE peserta_pelatihan  ENABLE ROW LEVEL SECURITY;
ALTER TABLE sertifikasi        ENABLE ROW LEVEL SECURITY;

-- Program: semua karyawan bisa lihat yang aktif, HR manage semua
CREATE POLICY "program_read_all"   ON program_pelatihan FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "program_hr_manage"  ON program_pelatihan FOR ALL    USING (is_hr_admin());

-- Materi: semua karyawan bisa lihat, HR manage
CREATE POLICY "materi_read_all"    ON materi_pelatihan FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "materi_hr_manage"   ON materi_pelatihan FOR ALL    USING (is_hr_admin());

-- Peserta: karyawan lihat milik sendiri, HR lihat & manage semua
CREATE POLICY "peserta_read_own"   ON peserta_pelatihan FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "peserta_hr_manage"  ON peserta_pelatihan FOR ALL    USING (is_hr_admin());

-- Sertifikasi: karyawan lihat milik sendiri, HR lihat & manage semua
CREATE POLICY "sertif_read_own"    ON sertifikasi FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "sertif_hr_manage"   ON sertifikasi FOR ALL    USING (is_hr_admin());

-- ============================================================
-- DATA AWAL — Contoh Program Pelatihan
-- ============================================================
INSERT INTO program_pelatihan (nama, deskripsi, kategori, durasi_jam, instruktur) VALUES
  ('Orientasi Karyawan Baru',   'Pengenalan perusahaan, budaya, dan prosedur kerja',             'internal', 8,  'Tim HR'),
  ('K3 (Keselamatan Kerja)',    'Pelatihan keselamatan dan kesehatan kerja wajib semua karyawan', 'internal', 4,  'Tim HSE'),
  ('Microsoft Office Lanjutan', 'Excel, Word, dan PowerPoint tingkat lanjut',                    'internal', 16, 'Tim IT')
ON CONFLICT DO NOTHING;
