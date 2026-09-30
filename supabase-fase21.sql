-- ============================================================
-- FASE 21 — PENATAAN JENIS CUTI
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Yang dikerjakan:
--   1. "Cuti Tahunan & Sakit"  ->  "Cuti Tahunan"
--   2. Jenis cuti kini bisa ditandai TIDAK memotong saldo Cuti Tahunan
--      (Melahirkan, WFA, WFH, Izin) — sebelumnya jenis tanpa saldo hanya
--      memunculkan peringatan "belum diatur", yang terbaca seolah salah setelan
--   3. Batas lama cuti per jenis, dalam HARI KALENDER (Melahirkan: 3 bulan)
--   4. Menambahkan pilihan "Izin"
--
-- Aman dijalankan berulang. Tidak menghapus data apa pun.
-- ============================================================


-- ============================================================
-- 1. KOLOM BARU DI jenis_cuti
-- ============================================================

-- TRUE  = pengajuan jenis ini memotong saldo (dicatat di saldo_cuti)
-- FALSE = tidak ada saldo yang dipotong sama sekali
--
-- Sebelum ini, "tidak memotong saldo" hanya terjadi secara kebetulan: karena
-- tak ada baris di saldo_cuti, tak ada yang bisa dikurangi. Itu rapuh — begitu
-- HR tak sengaja mengatur saldo untuk WFH, WFH langsung mulai memotong.
-- Dengan kolom ini, sifatnya jadi keputusan yang tercatat, bukan efek samping.
ALTER TABLE jenis_cuti ADD COLUMN IF NOT EXISTS pakai_saldo BOOLEAN NOT NULL DEFAULT TRUE;

-- Batas lama satu pengajuan, dalam HARI KALENDER. NULL = tidak dibatasi.
--
-- Sengaja HARI KALENDER, bukan hari kerja: cuti melahirkan di UU
-- Ketenagakerjaan dihitung 3 BULAN (1,5 bulan sebelum + 1,5 bulan sesudah
-- melahirkan), bukan "90 hari kerja". Kalau dibatasi 90 hari KERJA, rentang
-- kalendernya jadi sekitar 3,5 bulan — lebih longgar dari yang dimaksud.
--
-- Kolom lama `maks_hari` dibiarkan apa adanya: tidak pernah dipakai di mana
-- pun sejak dibuat, dan tidak dihapus supaya tidak ada yang rusak diam-diam.
ALTER TABLE jenis_cuti ADD COLUMN IF NOT EXISTS maks_hari_kalender INTEGER;

COMMENT ON COLUMN jenis_cuti.pakai_saldo        IS 'TRUE = memotong saldo_cuti. FALSE = tidak memotong saldo apa pun.';
COMMENT ON COLUMN jenis_cuti.maks_hari_kalender IS 'Batas lama satu pengajuan dalam HARI KALENDER (bukan hari kerja). NULL = tak dibatasi.';
COMMENT ON COLUMN jenis_cuti.maks_hari          IS 'TIDAK DIPAKAI. Digantikan maks_hari_kalender sejak fase21.';


-- ============================================================
-- 2. GANTI NAMA & ATUR SIFAT TIAP JENIS
-- ============================================================

-- Cuti Tahunan & Sakit -> Cuti Tahunan
UPDATE jenis_cuti
   SET nama = 'Cuti Tahunan'
 WHERE kode = 'tahunan';

-- Satu-satunya jenis yang memotong saldo.
UPDATE jenis_cuti
   SET pakai_saldo = TRUE, maks_hari_kalender = NULL
 WHERE kode = 'tahunan';

-- Cuti melahirkan: 3 bulan kalender, TIDAK memotong saldo Cuti Tahunan.
UPDATE jenis_cuti
   SET pakai_saldo = FALSE, maks_hari_kalender = 90
 WHERE kode = 'melahirkan';

-- WFA & WFH: tetap bekerja, hanya beda tempat. Tidak memotong saldo,
-- dan tidak ada batas lamanya.
UPDATE jenis_cuti
   SET pakai_saldo = FALSE, maks_hari_kalender = NULL
 WHERE kode IN ('wfa', 'wfh');


-- ============================================================
-- 3. TAMBAHKAN PILIHAN "IZIN"
-- ============================================================
-- Baris 'izin' sebenarnya sudah dibuat sejak fase4, tetapi dinonaktifkan.
-- ON CONFLICT dipakai supaya perintah ini benar apa pun keadaannya: baris
-- belum ada -> dibuat; sudah ada tapi mati -> dihidupkan lagi.
INSERT INTO jenis_cuti (nama, kode, maks_hari, berbayar, aktif, pakai_saldo, maks_hari_kalender)
VALUES ('Izin', 'izin', NULL, TRUE, TRUE, FALSE, NULL)
ON CONFLICT (kode) DO UPDATE
   SET nama               = 'Izin',
       aktif              = TRUE,
       pakai_saldo        = FALSE,
       maks_hari_kalender = NULL;


-- ============================================================
-- 4. PERIKSA HASILNYA
-- ============================================================
-- Jalankan ini sesudahnya untuk melihat susunan akhirnya.
SELECT nama,
       kode,
       aktif,
       pakai_saldo,
       maks_hari_kalender,
       CASE WHEN pakai_saldo THEN 'memotong saldo'
            ELSE 'tidak memotong saldo' END AS keterangan
  FROM jenis_cuti
 ORDER BY aktif DESC, nama;

-- Yang diharapkan tampil sebagai aktif:
--   Cuti Melahirkan  melahirkan  t  f  90    tidak memotong saldo
--   Cuti Tahunan     tahunan     t  t  NULL  memotong saldo
--   Izin             izin        t  f  NULL  tidak memotong saldo
--   WFA ...          wfa         t  f  NULL  tidak memotong saldo
--   WFH ...          wfh         t  f  NULL  tidak memotong saldo
