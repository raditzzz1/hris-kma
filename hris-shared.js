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

// Selisih hari antara dua tanggal "YYYY-MM-DD". Hasil positif = `sampai`
// masih di depan, negatif = sudah lewat. Sengaja memaksa jam 00:00 waktu
// lokal supaya tak terpengaruh zona waktu / pergantian DST.
function selisihHari (dari, sampai) {
  if (!dari || !sampai) return null
  const a = new Date(dari + 'T00:00:00')
  const b = new Date(sampai + 'T00:00:00')
  return Math.round((b - a) / 86400000)
}

// Tambah (atau kurang, bila n negatif) n hari dari tanggal "YYYY-MM-DD".
function tambahHari (iso, n) {
  const d = new Date((iso || tanggalLokal()) + 'T00:00:00')
  d.setDate(d.getDate() + n)
  return tanggalLokal(d)
}

// Berapa hari lagi menuju ulang tahun berikutnya dari `tanggalLahir`
// ("YYYY-MM-DD"). 0 = hari ini. Tahun kabisat 29 Feb diperlakukan 1 Mar
// pada tahun biasa (perilaku bawaan Date), cukup untuk keperluan pengingat.
function hariMenujuUlangTahun (tanggalLahir, acuan = new Date()) {
  if (!tanggalLahir) return null
  const l = new Date(tanggalLahir + 'T00:00:00')
  const hariIni = new Date(acuan.getFullYear(), acuan.getMonth(), acuan.getDate())
  let next = new Date(hariIni.getFullYear(), l.getMonth(), l.getDate())
  if (next < hariIni) next = new Date(hariIni.getFullYear() + 1, l.getMonth(), l.getDate())
  return Math.round((next - hariIni) / 86400000)
}

// Tanggal "YYYY-MM-DD" -> "13 Agu 2026" (untuk ditampilkan ke pengguna).
function tglIndo (iso, opsi) {
  if (!iso) return '—'
  return new Date(iso + 'T00:00:00').toLocaleDateString('id-ID',
    opsi || { day: 'numeric', month: 'short', year: 'numeric' })
}

// ============================================================
// KEAMANAN TAMPILAN
// ============================================================
// Selalu bungkus data dari database (nama, alasan, judul) dengan ini sebelum
// disisipkan ke innerHTML. Tanpa ini, teks yang mengandung tag HTML bisa
// mengubah/merusak tampilan halaman (XSS tersimpan).
function escHtml (s) {
  return String(s ?? '').replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ))
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
