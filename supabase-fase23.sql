-- ============================================================
-- FASE 23 — tutup pintu belakang kembaran: is_manager()
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- Fase 22 menambal is_hr_admin() supaya ikut memeriksa status. Tapi ada
-- fungsi kembarannya yang luput: is_manager(). Isinya
--
--     role IN ('hr_admin', 'manager')
--
-- jadi ia juga meloloskan HR Admin — dan juga TANPA memeriksa status, serta
-- tanpa SET search_path. Persis celah yang sama, cuma lewat pintu lain.
--
-- DAMPAK NYATANYA KECIL, dan itu perlu dikatakan apa adanya:
--   * peran 'manager' sudah dihapus dari sistem ini, jadi tak ada yang
--     memilikinya;
--   * fungsi ini cuma dipakai 2 policy, keduanya atas tabel `cuti` —
--     peninggalan lama; aplikasinya memakai `pengajuan_cuti`.
-- Jadi praktis tak ada yang lolos lewat sini sekarang.
--
-- Tetap ditutup karena: (1) pintu belakang yang menganggur hari ini bisa
-- terbuka begitu ada yang menghidupkan lagi peran manager atau tabel cuti;
-- (2) salinan sistem ini ikut dipakai klien lain, dan di sana isinya bisa
-- berbeda.
--
-- Aman dijalankan berulang. Tidak menghapus apa pun.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_manager()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.karyawan
     WHERE id = auth.uid()
       AND role IN ('hr_admin', 'manager')
       AND status = 'aktif'      -- <— tambahannya, sama seperti is_hr_admin()
  );
$$ LANGUAGE SQL SECURITY DEFINER SET search_path = public, pg_temp;

COMMENT ON FUNCTION public.is_manager() IS
  'TRUE hanya bila pengguna saat ini HR Admin atau Manager YANG MASIH AKTIF. Peran manager sudah tak dipakai; fungsi ini tersisa untuk 2 policy lama atas tabel cuti.';


-- ============================================================
-- PERIKSA
-- ============================================================
-- Sama seperti fase22: JANGAN diuji dengan `SELECT public.is_manager();`
-- di SQL Editor — di sana auth.uid() selalu kosong, jadi hasilnya selalu
-- false walau semuanya sehat.
--
-- Periksa definisinya saja:
SELECT proname AS nama_fungsi, prosrc AS isi_fungsi
  FROM pg_proc
 WHERE proname IN ('is_hr_admin', 'is_manager')
   AND pronamespace = 'public'::regnamespace
 ORDER BY proname;

-- Keduanya harus memuat baris `AND status = 'aktif'`.
