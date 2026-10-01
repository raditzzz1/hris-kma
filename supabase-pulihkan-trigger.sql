-- ============================================================
-- PEMULIHAN MENDESAK — kembalikan cegah_ubah_kolom_sensitif() KMA
-- Jalankan di Supabase: SQL Editor > New Query  (database KMA)
-- ============================================================
-- APA YANG TERJADI: `supabase-keamanan.sql` milik HRIS-Klien-01 terlanjur
-- dijalankan di database KMA. Berkas itu disusun untuk skema salinan klien
-- yang LEBIH TUA, sehingga daftar kolom di dalamnya lebih pendek.
--
-- Karena perintahnya CREATE OR REPLACE, fungsi milik KMA tertimpa versi
-- klien, dan 6 kolom kehilangan perlindungannya:
--
--     wfh_sabtu, department, atasan_langsung,
--     tanggal_mulai_kontrak, tanggal_berakhir_kontrak, pkwt_ke
--
-- Yang PALING berdampak: `wfh_sabtu`. Kolom itu menentukan seseorang boleh
-- absen dari luar radius kantor tiap Sabtu — kalau bisa diubah sendiri,
-- aturan absen bisa dilonggarkan tanpa sepengetahuan HR. Sisanya menyangkut
-- masa kontrak PKWT (ikut dipakai pengingat kontrak & surat PKWT).
--
-- KABAR BAIKNYA: role, status, gaji_pokok dan nik TETAP terlindungi —
-- keduanya ada di versi klien juga. Jadi tidak ada jalan untuk mengangkat
-- diri jadi HR Admin atau menaikkan gaji sendiri.
--
-- Berkas ini mengembalikan daftar kolom versi KMA (fase17) apa adanya.
-- Aman dijalankan berulang. Tidak menghapus data apa pun.
-- ============================================================

CREATE OR REPLACE FUNCTION public.cegah_ubah_kolom_sensitif()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- HR Admin bebas mengubah apa pun
  IF public.is_hr_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.nik                      IS DISTINCT FROM OLD.nik
  OR NEW.role                     IS DISTINCT FROM OLD.role
  OR NEW.status                   IS DISTINCT FROM OLD.status
  OR NEW.gaji_pokok               IS DISTINCT FROM OLD.gaji_pokok
  OR NEW.tipe_kontrak             IS DISTINCT FROM OLD.tipe_kontrak
  OR NEW.jabatan_id               IS DISTINCT FROM OLD.jabatan_id
  OR NEW.divisi_id                IS DISTINCT FROM OLD.divisi_id
  OR NEW.tanggal_bergabung        IS DISTINCT FROM OLD.tanggal_bergabung
  OR NEW.status_ptkp              IS DISTINCT FROM OLD.status_ptkp
  OR NEW.jam_masuk_standar        IS DISTINCT FROM OLD.jam_masuk_standar
  OR NEW.jam_kerja_fleksibel      IS DISTINCT FROM OLD.jam_kerja_fleksibel
  OR NEW.tipe_gaji                IS DISTINCT FROM OLD.tipe_gaji
  OR NEW.tarif_per_jam            IS DISTINCT FROM OLD.tarif_per_jam
  OR NEW.wfh_sabtu                IS DISTINCT FROM OLD.wfh_sabtu
  OR NEW.department               IS DISTINCT FROM OLD.department
  OR NEW.atasan_langsung          IS DISTINCT FROM OLD.atasan_langsung
  OR NEW.tanggal_mulai_kontrak    IS DISTINCT FROM OLD.tanggal_mulai_kontrak
  OR NEW.tanggal_berakhir_kontrak IS DISTINCT FROM OLD.tanggal_berakhir_kontrak
  OR NEW.pkwt_ke                  IS DISTINCT FROM OLD.pkwt_ke
  THEN
    RAISE EXCEPTION 'Kolom kepegawaian hanya boleh diubah oleh HR Admin.';
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger dipasang ulang supaya pasti menunjuk fungsi di atas.
DROP TRIGGER IF EXISTS karyawan_cegah_kolom_sensitif ON karyawan;
CREATE TRIGGER karyawan_cegah_kolom_sensitif
  BEFORE UPDATE ON karyawan
  FOR EACH ROW EXECUTE FUNCTION public.cegah_ubah_kolom_sensitif();

-- ============================================================
-- PERIKSA: keenam kolom tadi harus muncul lagi
-- ============================================================
SELECT
  (prosrc LIKE '%wfh_sabtu%')                AS lindungi_wfh_sabtu,
  (prosrc LIKE '%department%')               AS lindungi_department,
  (prosrc LIKE '%atasan_langsung%')          AS lindungi_atasan,
  (prosrc LIKE '%tanggal_mulai_kontrak%')    AS lindungi_mulai_kontrak,
  (prosrc LIKE '%tanggal_berakhir_kontrak%') AS lindungi_akhir_kontrak,
  (prosrc LIKE '%pkwt_ke%')                  AS lindungi_pkwt_ke,
  (prosrc LIKE '%gaji_pokok%')               AS lindungi_gaji,
  (prosrc LIKE '%role%')                     AS lindungi_role
FROM pg_proc
WHERE proname = 'cegah_ubah_kolom_sensitif'
  AND pronamespace = 'public'::regnamespace;
-- Kedelapannya harus TRUE.

-- CATATAN: is_hr_admin() & is_manager() TIDAK perlu dipulihkan. Versi klien
-- isinya identik dengan fase22/fase23 yang sudah Anda jalankan, jadi
-- keduanya tetap benar.
