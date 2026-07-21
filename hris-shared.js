// hris-shared.js — helper bersama HRIS PT Kawan Menengah Atas
// Dipakai di semua halaman aplikasi (bukan index.html/reset-password.html).
//
// Tujuan file ini: satu sumber kebenaran untuk hal-hal yang dulu ditulis
// ulang di tiap halaman dan diam-diam jadi beda (drift). Kalau aturannya
// berubah, ubah DI SINI saja — jangan tulis ulang di halaman.

// ============================================================
// TANGGAL & WAKTU
// ============================================================
// PENTING: jangan pakai `new Date().toISOString().split('T')[0]` untuk
// mendapatkan "tanggal hari ini". toISOString() memberi tanggal UTC,
// sedangkan kita di WIB (UTC+7) — antara 00:00–06:59 WIB, tanggal UTC
// masih HARI SEBELUMNYA. Efeknya pernah nyata: absen dini hari tercatat
// di tanggal kemarin, dan rentang laporan bulanan mundur satu hari.
// Pakai tanggalLokal() yang membaca tanggal apa adanya di zona browser.
function tanggalLokal (d = new Date()) {
  const y  = d.getFullYear()
  const m  = String(d.getMonth() + 1).padStart(2, '0')
  const hh = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${hh}`
}

// Tanggal 1 pada bulan yang sama dengan `d` (untuk rentang "bulan ini").
function awalBulanLokal (d = new Date()) {
  return tanggalLokal(new Date(d.getFullYear(), d.getMonth(), 1))
}

// ============================================================
// ATURAN ABSEN
// ============================================================
// Dipakai bersama oleh dashboard.html (absen cepat) & absensi.html.
// Dulu logika ini ditulis terpisah di dua file dan sempat beda: fitur
// "WFH otomatis tiap Sabtu" cuma masuk ke absensi.html, dan dashboard
// tidak punya pengecualian HR Admin sama sekali — akibatnya orang bisa
// absen dari halaman Absensi tapi diblokir dari Dashboard.

// Sabtu (getDay 6) & karyawan ditandai WFH otomatis -> boleh absen dari
// luar radius tanpa izin/persetujuan HR.
function isSabtuWFH (karyw) {
  return new Date().getDay() === 6 && !!karyw?.wfh_sabtu
}

// Boleh absen walau di LUAR radius kantor?
// HR Admin selalu boleh; selain itu butuh izin absen luar yang disetujui,
// atau sedang Sabtu-WFH-otomatis.
function bolehAbsenDiLuarRadius ({ isAdmin, izinLuarAktif, karyw }) {
  return !!isAdmin || !!izinLuarAktif || isSabtuWFH(karyw)
}

// Mode kerja yang tercatat di record absensi.
// Sesudah absen masuk: ikut mode yang sudah tersimpan (jangan berubah
// di tengah hari). Sebelum masuk: ditentukan radius/izin/WFH Sabtu.
function modeAbsenEfektif ({ absensiHariIni, dalamRadius, izinLuarAktif, karyw }) {
  if (absensiHariIni?.waktu_masuk) return absensiHariIni.mode_kerja || 'kantor'
  if (dalamRadius) return 'kantor'
  if (izinLuarAktif) return izinLuarAktif.tipe
  if (isSabtuWFH(karyw)) return 'wfh'
  return 'kantor'
}

// Status absen masuk: 'hadir' atau 'terlambat'.
// Karyawan berjam-kerja-fleksibel tidak pernah dihitung terlambat.
function hitungStatusMasuk (karyw, waktu = new Date()) {
  if (karyw?.jam_kerja_fleksibel) return 'hadir'
  const [sh, sm] = (karyw?.jam_masuk_standar || '09:00').slice(0, 5).split(':').map(Number)
  return (waktu.getHours() * 60 + waktu.getMinutes()) > (sh * 60 + sm) ? 'terlambat' : 'hadir'
}
