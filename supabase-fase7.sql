-- ============================================================
-- FASE 7 (Revisi) — Izin Absen Luar Lokasi + Lembur
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================

-- 1. IZIN ABSEN LUAR LOKASI (pra-persetujuan)
--    Karyawan ajukan -> HR setujui -> baru bisa absen di luar radius
--    pada rentang tanggal tsb (WFH/WFA/dinas/lainnya).
CREATE TABLE IF NOT EXISTS izin_absen_luar (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id     UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  tanggal_mulai   DATE NOT NULL,
  tanggal_selesai DATE NOT NULL,
  tipe            TEXT NOT NULL DEFAULT 'wfh'
                  CHECK (tipe IN ('wfh','wfa','dinas','lainnya')),
  alasan          TEXT,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','disetujui','ditolak','dibatalkan')),
  catatan_hr      TEXT,
  approved_by     UUID REFERENCES karyawan(id),
  approved_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER izin_absen_luar_updated_at
  BEFORE UPDATE ON izin_absen_luar
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 2. LEMBUR (dicatat karyawan; TIDAK memengaruhi payroll otomatis)
CREATE TABLE IF NOT EXISTS lembur (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  karyawan_id  UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  tanggal      DATE NOT NULL,
  jam_mulai    TIME NOT NULL,
  jam_selesai  TIME NOT NULL,
  durasi_jam   NUMERIC(5,2),
  alasan       TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE izin_absen_luar ENABLE ROW LEVEL SECURITY;
ALTER TABLE lembur          ENABLE ROW LEVEL SECURITY;

-- izin_absen_luar: karyawan lihat & ajukan milik sendiri; HANYA HR yang
-- boleh ubah status (mencegah self-approve). HR akses penuh.
CREATE POLICY "ial_select_own" ON izin_absen_luar
  FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "ial_insert_own" ON izin_absen_luar
  FOR INSERT WITH CHECK (karyawan_id = auth.uid());
CREATE POLICY "ial_hr_manage" ON izin_absen_luar
  FOR ALL USING (is_hr_admin());

-- lembur: karyawan catat & lihat milik sendiri (boleh hapus milik sendiri);
-- HR lihat & kelola semua.
CREATE POLICY "lembur_select_own" ON lembur
  FOR SELECT USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "lembur_insert_own" ON lembur
  FOR INSERT WITH CHECK (karyawan_id = auth.uid());
CREATE POLICY "lembur_delete_own" ON lembur
  FOR DELETE USING (karyawan_id = auth.uid() OR is_hr_admin());
CREATE POLICY "lembur_hr_manage" ON lembur
  FOR ALL USING (is_hr_admin());

-- ============================================================
-- Setelah menjalankan SQL ini:
-- 1. Karyawan dapat mengajukan "Izin Absen Luar Lokasi" (WFH/WFA/dinas)
--    dari halaman Absensi; absen di luar radius hanya bisa bila ada izin
--    DISETUJUI untuk tanggal tsb.
-- 2. Karyawan dapat mencatat "Lembur" (jam mulai-selesai + alasan).
--    Data lembur TIDAK otomatis masuk payroll/slip — HR input manual.
-- ============================================================
