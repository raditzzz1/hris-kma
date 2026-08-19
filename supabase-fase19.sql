-- ============================================================
-- FASE 19 — BPJS & PPh 21 dapat ditetapkan manual (per karyawan)
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Tujuan: HR bisa MENETAPKAN sendiri angka potongan BPJS dan/atau PPh 21
-- per karyawan, menggantikan hasil hitung otomatis dari tarif persentase.
--
-- ATURAN NILAI (penting):
--   NULL / kosong  -> dihitung OTOMATIS dari tarif (perilaku lama)
--   terisi angka   -> pakai angka itu (termasuk bila diisi 0)
-- Jadi HR cukup mengisi yang sudah diketahui nominalnya; sisanya dibiarkan
-- kosong dan tetap otomatis, bisa diisi kapan saja nanti tanpa mengubah kode.
--
-- Kenapa tabel sendiri, bukan lewat komponen gaji biasa?
-- Karena Bukti Potong 1721-A1 merekap setahun dengan MENJUMLAHKAN kolom
-- khusus di slip_gaji (bpjs_kes_karyawan, bpjs_jht_karyawan,
-- bpjs_jp_karyawan, pph21). Kalau BPJS/PPh21 dijadikan komponen "potongan
-- lain", kolom-kolom itu jadi 0 dan bukti potong tahunan ikut kosong.
-- Dengan tabel ini, angka manual tetap masuk ke kolom yang sama — slip dan
-- bukti potong tidak berubah bentuknya sama sekali.
--
-- Nilainya disimpan PER KARYAWAN (bukan per bulan), jadi cukup diisi sekali
-- dan otomatis terpakai di periode-periode berikutnya sampai diubah.
-- ============================================================

CREATE TABLE IF NOT EXISTS karyawan_potongan_manual (
  karyawan_id          UUID PRIMARY KEY REFERENCES karyawan(id) ON DELETE CASCADE,

  -- Potongan karyawan (mengurangi gaji). NULL = hitung otomatis.
  bpjs_kes_karyawan    DECIMAL(15,2),
  bpjs_jht_karyawan    DECIMAL(15,2),
  bpjs_jp_karyawan     DECIMAL(15,2),
  pph21                DECIMAL(15,2),

  -- Kontribusi perusahaan (informasi di slip, tidak mengurangi gaji).
  bpjs_kes_perusahaan  DECIMAL(15,2),
  bpjs_jht_perusahaan  DECIMAL(15,2),
  bpjs_jp_perusahaan   DECIMAL(15,2),

  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Penyelarasan bila tabel sudah ada dari rancangan SEBELUMNYA
-- ------------------------------------------------------------
-- Rancangan awal fase19 memakai saklar boolean (bpjs_manual/pph21_manual)
-- dan kolom angka NOT NULL DEFAULT 0. Itu diganti: sekarang NULL-lah yang
-- menandai "hitung otomatis", jadi kolom angka HARUS boleh NULL dan saklar
-- boolean tidak dipakai lagi.
--
-- Blok ini membuat berkas ini aman dijalankan berulang: di database baru
-- tidak ada efeknya, di database yang sudah kena rancangan lama ia
-- membetulkannya. Tanpa ini, CREATE TABLE IF NOT EXISTS di atas akan
-- dilewati dan tabel tetap memakai bentuk lama — penyimpanan akan gagal
-- karena kode menulis NULL ke kolom NOT NULL.
ALTER TABLE karyawan_potongan_manual
  DROP COLUMN IF EXISTS bpjs_manual,
  DROP COLUMN IF EXISTS pph21_manual,
  ALTER COLUMN bpjs_kes_karyawan   DROP NOT NULL,
  ALTER COLUMN bpjs_kes_karyawan   DROP DEFAULT,
  ALTER COLUMN bpjs_jht_karyawan   DROP NOT NULL,
  ALTER COLUMN bpjs_jht_karyawan   DROP DEFAULT,
  ALTER COLUMN bpjs_jp_karyawan    DROP NOT NULL,
  ALTER COLUMN bpjs_jp_karyawan    DROP DEFAULT,
  ALTER COLUMN pph21               DROP NOT NULL,
  ALTER COLUMN pph21               DROP DEFAULT,
  ALTER COLUMN bpjs_kes_perusahaan DROP NOT NULL,
  ALTER COLUMN bpjs_kes_perusahaan DROP DEFAULT,
  ALTER COLUMN bpjs_jht_perusahaan DROP NOT NULL,
  ALTER COLUMN bpjs_jht_perusahaan DROP DEFAULT,
  ALTER COLUMN bpjs_jp_perusahaan  DROP NOT NULL,
  ALTER COLUMN bpjs_jp_perusahaan  DROP DEFAULT;

COMMENT ON TABLE karyawan_potongan_manual IS
  'Angka BPJS/PPh21 yang ditetapkan manual HR per karyawan. NULL = dihitung otomatis dari tarif.';

ALTER TABLE karyawan_potongan_manual ENABLE ROW LEVEL SECURITY;

-- HANYA HR Admin. Ini angka yang menentukan potongan gaji, jadi karyawan
-- tidak boleh membaca apalagi mengubahnya lewat API. Karyawan tetap melihat
-- hasil akhirnya di slip gaji masing-masing.
DROP POLICY IF EXISTS potongan_manual_hr ON karyawan_potongan_manual;
CREATE POLICY potongan_manual_hr ON karyawan_potongan_manual
  FOR ALL USING (public.is_hr_admin()) WITH CHECK (public.is_hr_admin());

-- ============================================================
-- Penanda di slip: baris mana yang tadi ditetapkan manual?
-- ============================================================
-- Perlu disimpan DI SLIP (bukan cuma di tabel di atas) karena slip lama
-- harus tetap tampil apa adanya. Kalau HR nanti mengisi/mengubah angka
-- manual, slip bulan-bulan sebelumnya tetap tercetak dengan label yang benar.
--
-- Isinya daftar nama kolom yang manual, mis. {"bpjs_kes_karyawan": true}.
-- Dipakai untuk menentukan apakah label persentase "(1%)" boleh ditampilkan
-- di baris itu — persentase hanya benar bila angkanya memang dari tarif.
ALTER TABLE slip_gaji
  ADD COLUMN IF NOT EXISTS potongan_manual JSONB NOT NULL DEFAULT '{}';

-- ============================================================
-- Selesai. Setelah dijalankan:
--   • Payroll > Komponen Gaji punya bagian "BPJS & PPh 21"
--   • Kolom yang dibiarkan kosong tetap dihitung otomatis seperti biasa
--   • Slip yang sudah terbit TIDAK berubah
-- ============================================================
