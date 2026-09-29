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

// ============================================================
// TAB PERAN — "Kelola (HR)" vs "Milik Saya"
// ============================================================
// HR Admin juga seorang karyawan: ikut absen, mengambil cuti, punya slip gaji
// & sertifikat sendiri. Dulu tiap halaman bercabang SALAH SATU
// (renderHR ATAU renderKaryawan), sehingga HR tak pernah bisa membuka
// miliknya sendiri walau kodenya sudah ada.
//
// Tab ini membuka keduanya tanpa "mode" global yang tersembunyi — HR selalu
// melihat di tab mana ia berada. Karyawan biasa tidak pernah melihat tab ini.
//
// Pemakaian:
//   pasangTabPeran('roleTabs', function (tab) {
//     if (tab === 'kelola') renderHR(); else renderKaryawan()
//   })
//
// Catatan sengaja: pilihan TIDAK diingat antar-halaman/antar-kunjungan.
// Setiap halaman selalu terbuka di "Kelola (HR)" supaya perilakunya sama
// dengan sebelumnya dan HR tak pernah kaget menu HR-nya seolah hilang.
function pasangTabPeran (wadahId, onGanti, opsi) {
  const wadah = document.getElementById(wadahId)
  if (!wadah) return

  const o = opsi || {}
  const labelKelola = o.labelKelola || 'Kelola (HR)'
  const labelSaya   = o.labelSaya   || 'Milik Saya'
  let aktif = o.aktif || 'kelola'

  suntikGayaTabPeran()

  function gambar () {
    wadah.innerHTML =
      '<div class="peran-tabs" role="tablist">' +
        tombol('kelola', labelKelola, IKON_KELOLA) +
        tombol('saya',   labelSaya,   IKON_SAYA) +
      '</div>'
    wadah.querySelectorAll('.peran-tab').forEach(function (b) {
      b.onclick = function () {
        if (b.dataset.tab === aktif) return   // klik tab yang sama: jangan render ulang
        aktif = b.dataset.tab
        gambar()
        onGanti(aktif)
      }
    })
  }

  function tombol (id, label, ikon) {
    return '<button type="button" class="peran-tab' + (aktif === id ? ' active' : '') +
      '" data-tab="' + id + '" role="tab" aria-selected="' + (aktif === id) + '">' +
      ikon + ' ' + escHtml(label) + '</button>'
  }

  gambar()
  onGanti(aktif)
}

var IKON_KELOLA = '<svg class="ic" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>'
var IKON_SAYA   = '<svg class="ic" viewBox="0 0 24 24"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>'

// Gaya disuntik dari sini (bukan ditulis ulang di 5 halaman) supaya tab-nya
// pasti seragam. Nama kelas diberi awalan "peran-" agar tidak bentrok dengan
// .tabs/.tab-btn milik Pelatihan yang sudah ada lebih dulu.
function suntikGayaTabPeran () {
  if (document.getElementById('gayaTabPeran')) return
  var s = document.createElement('style')
  s.id = 'gayaTabPeran'
  s.textContent =
    '.peran-tabs{display:flex;gap:.25rem;margin-bottom:1.1rem;background:#fff;border:1px solid var(--border);' +
    'border-radius:10px;padding:.35rem;width:fit-content;max-width:100%;}' +
    '.peran-tab{display:inline-flex;align-items:center;gap:.4rem;padding:.45rem 1rem;border-radius:7px;border:none;' +
    'cursor:pointer;font-family:inherit;font-size:.82rem;font-weight:600;background:none;color:var(--muted);' +
    'white-space:nowrap;transition:all .15s;}' +
    '.peran-tab:hover{color:var(--navy);}' +
    '.peran-tab.active{background:var(--primary);color:#fff;}' +
    '.peran-tab .ic{width:15px;height:15px;}' +
    '@media(max-width:768px){.peran-tabs{width:100%;}.peran-tab{flex:1;justify-content:center;}}' +
    '@media print{.peran-tabs{display:none !important;}}'
  document.head.appendChild(s)
}

// ============================================================
// TAB PANEL — beberapa panel jadi tab menyamping
// ============================================================
// Halaman admin gampang menumpuk banyak panel besar berturut-turut
// (Absensi: Rekap, Izin, Koreksi, Lembur, Hari Libur). Di HP itu berarti
// menggulir sangat jauh. Tab membuat hanya satu panel tampil.
//
// PENTING — kenapa ada angka penanda: kalau panel PERSETUJUAN disembunyikan
// di balik tab, pengajuan yang menunggu bisa tak terlihat sama sekali dan
// terlewat. Angka di tab membuatnya tetap kelihatan tanpa membuka tabnya.
//
// Pemakaian:
//   pasangTabPanel('absTabs', [
//     { id: 'rekap', label: 'Rekap Kehadiran', panel: 'panelRekap' },
//     { id: 'izin',  label: 'Izin Absen Luar', panel: 'panelIzin' },
//   ], function (id) { /* opsional: dipanggil tiap ganti tab */ })
//
// Mengembalikan objek { tandai(idTab, jumlah), aktif() }.
function pasangTabPanel (wadahId, daftar, onGanti) {
  const wadah = document.getElementById(wadahId)
  if (!wadah || !daftar || !daftar.length) return null
  suntikGayaTabPanel()

  let aktif = daftar[0].id
  const jumlah = {}

  function gambar () {
    wadah.innerHTML = '<div class="panel-tabs" role="tablist">' + daftar.map(function (t) {
      const n = jumlah[t.id]
      return '<button type="button" class="panel-tab' + (t.id === aktif ? ' active' : '') +
        '" data-tab="' + t.id + '" role="tab" aria-selected="' + (t.id === aktif) + '">' +
        escHtml(t.label) +
        (n ? '<span class="panel-tab-n">' + n + '</span>' : '') +
        '</button>'
    }).join('') + '</div>'

    wadah.querySelectorAll('.panel-tab').forEach(function (b) {
      b.onclick = function () { pilih(b.dataset.tab) }
    })
    // Panel yang tak aktif disembunyikan (bukan dihapus) supaya isinya yang
    // sudah dimuat tidak hilang saat berpindah-pindah tab.
    daftar.forEach(function (t) {
      const p = document.getElementById(t.panel)
      if (p) p.style.display = (t.id === aktif) ? '' : 'none'
    })
  }

  function pilih (id) {
    if (id === aktif) return
    aktif = id
    gambar()
    // Tab yang baru dipilih digeser ke area pandang di HP (bar tab bisa
    // lebih lebar dari layar dan digeser mendatar).
    const btn = wadah.querySelector('.panel-tab.active')
    if (btn && btn.scrollIntoView) btn.scrollIntoView({ block: 'nearest', inline: 'nearest' })
    if (onGanti) onGanti(id)
  }

  gambar()
  if (onGanti) onGanti(aktif)

  return {
    // tandai('izin', 3) -> muncul angka 3 di tab itu; 0/null menghapusnya.
    tandai: function (id, n) { jumlah[id] = n; gambar() },
    aktif: function () { return aktif }
  }
}

function suntikGayaTabPanel () {
  if (document.getElementById('gayaTabPanel')) return
  var s = document.createElement('style')
  s.id = 'gayaTabPanel'
  s.textContent =
    '.panel-tabs{display:flex;gap:.25rem;margin-bottom:1rem;background:#fff;border:1px solid var(--border);' +
    'border-radius:10px;padding:.35rem;overflow-x:auto;scrollbar-width:thin;}' +
    '.panel-tabs::-webkit-scrollbar{height:4px;}' +
    '.panel-tab{display:inline-flex;align-items:center;gap:.4rem;padding:.45rem .85rem;border-radius:7px;' +
    'border:none;cursor:pointer;font-family:inherit;font-size:.8rem;font-weight:600;background:none;' +
    'color:var(--muted);white-space:nowrap;flex:0 0 auto;transition:all .15s;}' +
    '.panel-tab:hover{color:var(--navy);}' +
    '.panel-tab.active{background:var(--primary);color:#fff;}' +
    // Angka penanda: merah supaya "ada yang menunggu" benar-benar menarik mata.
    '.panel-tab-n{display:inline-grid;place-items:center;min-width:18px;height:18px;padding:0 5px;' +
    'border-radius:9px;background:#dc2626;color:#fff;font-size:.68rem;font-weight:700;}' +
    '.panel-tab.active .panel-tab-n{background:#fff;color:var(--primary);}' +
    '@media print{.panel-tabs{display:none !important;}}'
  document.head.appendChild(s)
}

// ============================================================
// BATASI BARIS TABEL — tampil 10 dulu, sisanya "Muat lebih banyak"
// ============================================================
// Tabel admin bisa memuat puluhan baris sekaligus; di HP itu berarti
// menggulir sangat jauh. Baris dibatasi, TAPI sisanya tidak dibuang —
// selalu ada tombol untuk menampilkan berikutnya, supaya tidak ada data
// yang hilang diam-diam (penting untuk daftar persetujuan).
//
// Dipanggil SESUDAH tbody diisi: batasiBaris('izinAdminBody', 10)
//
// AMAN-CETAK: baris disembunyikan lewat KELAS, bukan style.display inline.
// Kalau memakai inline style, baris yang tersembunyi juga tak ikut tercetak
// dan hasil cetak jadi tidak lengkap tanpa disadari. Dengan kelas, aturan
// @media print bisa menampilkannya kembali.
//
// JANGAN dipakai di halaman Absensi. Tabel absensi diedit berkali-kali dalam
// satu sesi (mengisi jam keluar yang terlewat), dan setiap simpan memuat ulang
// tabelnya — batasnya ikut kembali ke 10, jadi baris yang tadi sudah dibuka
// tersembunyi lagi DAN halaman melompat ke atas karena isinya menciut.
// Dicoba, lalu dicabut lagi 2026-09-29 atas permintaan user.
function batasiBaris (tbodyId, batas) {
  const tb = document.getElementById(tbodyId)
  if (!tb) return
  batas = batas || 10
  suntikGayaBatasBaris()

  // Bersihkan penanda dari pemanggilan sebelumnya, lalu ambil baris data saja.
  tb.querySelectorAll('tr[data-lebih]').forEach(function (tr) { tr.remove() })
  const baris = Array.prototype.slice.call(tb.querySelectorAll('tr'))
  // Baris "belum ada data" (satu sel colspan) tidak perlu dibatasi.
  if (baris.length === 1 && baris[0].children.length === 1) return
  baris.forEach(function (tr) { tr.classList.remove('baris-lewat-batas') })
  if (baris.length <= batas) return

  let tampil = batas
  const kolom = (baris[0].children.length) || 1
  const tr = document.createElement('tr')
  tr.setAttribute('data-lebih', '1')
  tb.appendChild(tr)

  function terapkan () {
    baris.forEach(function (b, i) { b.classList.toggle('baris-lewat-batas', i >= tampil) })
    const sisa = baris.length - tampil
    if (sisa <= 0) { tr.remove(); return }
    tr.innerHTML = '<td colspan="' + kolom + '" style="text-align:center;padding:.75rem;">' +
      '<button type="button" class="btn-sec btn-secondary" style="font-size:.78rem;padding:.35rem .9rem;">' +
      'Muat lebih banyak (' + sisa + ' lagi)</button></td>'
    tr.querySelector('button').onclick = function () { tampil += batas; terapkan() }
  }
  terapkan()
}

function suntikGayaBatasBaris () {
  if (document.getElementById('gayaBatasBaris')) return
  var s = document.createElement('style')
  s.id = 'gayaBatasBaris'
  s.textContent =
    '.baris-lewat-batas{display:none;}' +
    // Saat DICETAK semua baris ditampilkan kembali (hasil cetak harus utuh),
    // dan tombol "Muat lebih banyak" disembunyikan.
    '@media print{.baris-lewat-batas{display:table-row !important;}' +
    'tr[data-lebih]{display:none !important;}}'
  document.head.appendChild(s)
}

// ============================================================
// PROFIL SIDEBAR — tampil seketika, tanpa menunggu server
// ============================================================
// Tiap halaman menanyakan nama/jabatan/foto pengguna ke server hanya untuk
// mengisi sidebar. Akibatnya sidebar kosong dulu ("Memuat…") setiap kali
// berpindah halaman. Nilainya disimpan sebentar di browser supaya bisa
// langsung terisi, lalu DITIMPA oleh data asli begitu jawabannya datang.
//
// SIFAT PENTING — ini hanya mempercepat TAMPILAN, bukan menggantikan data:
// pengisian dari hasil query tetap berjalan seperti semula. Jadi kalau isi
// simpanan salah/basi sekalipun, hasil akhir yang terlihat tetap yang benar.
//
// TIDAK BOLEH dipakai untuk menentukan hak akses (mis. memunculkan menu HR).
// Hak akses tetap ditentukan hasil query segar + RLS di database, supaya
// orang yang baru dicabut haknya tak bisa melihat apa pun yang bukan haknya.
//
// Memakai sessionStorage: hilang saat tab ditutup, dan tidak terbawa ke tab
// atau perangkat lain.
var KUNCI_PROFIL_SIDEBAR = 'hris.profil.sidebar'

function simpanProfilSidebar (userId, p) {
  if (!userId || !p) return
  try {
    sessionStorage.setItem(KUNCI_PROFIL_SIDEBAR, JSON.stringify({
      id: userId, nama: p.nama_lengkap || '', role: p.role || '', foto: p.foto_url || ''
    }))
  } catch (e) { /* penyimpanan penuh/diblokir — bukan hal wajib, abaikan */ }
}

function ambilProfilSidebar (userId) {
  try {
    const s = sessionStorage.getItem(KUNCI_PROFIL_SIDEBAR)
    if (!s) return null
    const p = JSON.parse(s)
    // DIIKAT ke ID pengguna: kalau tab ini sempat dipakai akun lain,
    // simpanannya diabaikan supaya tidak muncul nama orang lain.
    return (p && p.id === userId) ? p : null
  } catch (e) { return null }
}

function hapusProfilSidebar () {
  try { sessionStorage.removeItem(KUNCI_PROFIL_SIDEBAR) } catch (e) {}
}

// Mengisi nama/jabatan/foto di sidebar. Nama elemennya berbeda-beda antar
// halaman (sidebarName/sbName, sidebarAvatar/sbAvatar/sbAv), jadi dicari
// yang tersedia — dengan begitu satu fungsi ini bisa dipakai semua halaman.
function isiSidebarProfil (p) {
  if (!p) return
  const pilih = function (ids) {
    for (let i = 0; i < ids.length; i++) {
      const el = document.getElementById(ids[i])
      if (el) return el
    }
    return null
  }
  const elNama = pilih(['sidebarName', 'sbName'])
  const elRole = pilih(['sidebarRole', 'sbRole'])
  const elAv   = pilih(['sidebarAvatar', 'sbAvatar', 'sbAv'])

  if (elNama && p.nama) elNama.textContent = p.nama
  if (elRole && p.role) elRole.textContent = ({ hr_admin: 'HR Admin', karyawan: 'Karyawan' })[p.role] || p.role
  if (elAv) {
    elAv.innerHTML = p.foto
      ? '<img src="' + p.foto + '" alt="">'
      : escHtml((p.nama || '?').trim().split(/\s+/).slice(0, 2).map(function (s) { return s[0] }).join('').toUpperCase())
  }
}
