// seasonal-theme.js — pemuat tema musiman HRIS PT Kawan Menengah Atas
// ================================================================
// Menyalakan tema "Merdeka" (HUT RI) OTOMATIS selama bulan Agustus,
// dan mematikannya sendiri di bulan lain. Tanpa perawatan tahunan:
// angka "ke-N" dihitung dari tahun berjalan (tahun − 1945).
//
// Kalau musim aktif: suntik <link> theme-merdeka.css (dimuat paling
// akhir → menang cascade di semua halaman) lalu sisipkan ucapan sesuai
// jenis halaman. Di luar musim, langsung berhenti — nol dampak.
//
// Override manual (pratinjau / matikan sementara):
//   ?merdeka=1  -> paksa NYALA        ?merdeka=0 -> paksa MATI
// ================================================================
(function () {
  var TAHUN_MERDEKA = 1945;

  var paksa = null;
  try {
    var q = new URLSearchParams(location.search).get('merdeka');
    if (q === '1' || q === 'on')  paksa = true;
    if (q === '0' || q === 'off') paksa = false;
  } catch (e) { /* abaikan */ }

  var now = new Date();
  var aktif = (paksa !== null) ? paksa : (now.getMonth() === 7); // 7 = Agustus
  if (!aktif) return;

  var ke = now.getFullYear() - TAHUN_MERDEKA; // 2026 -> 81

  // 1) Suntik stylesheet tema (paling akhir di <head>)
  if (!document.querySelector('link[data-merdeka]')) {
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'theme-merdeka.css';
    link.setAttribute('data-merdeka', '1');
    document.head.appendChild(link);
  }

  // 2) Sisipkan ucapan setelah DOM siap
  function pasangUcapan() {
    if (document.querySelector('.merdeka-pill, .merdeka-ribbon, .merdeka-login-note')) return;

    // Emoji bendera sengaja tidak dipakai: di sebagian perangkat/OS ia tampil
    // sebagai teks "ID" (kode regional) di depan tulisan, bukan gambar bendera.
    var flag = '';

    // a) Dashboard: pil di dalam banner sambutan (banner sudah jadi hero aset)
    var banner = document.querySelector('.welcome-banner');
    if (banner) {
      var host = banner.querySelector('div') || banner;
      var pill = document.createElement('div');
      pill.className = 'merdeka-pill';
      pill.setAttribute('role', 'status');
      pill.innerHTML = flag + 'Dirgahayu RI ke-' + ke + ' — <b>Merdeka!</b>';
      host.appendChild(pill);
      return;
    }

    // b) Halaman modul: pita di atas konten <main>
    var main = document.querySelector('main');
    if (main) {
      var pita = document.createElement('div');
      pita.className = 'merdeka-ribbon';
      pita.setAttribute('role', 'status');
      pita.innerHTML = flag + 'Dirgahayu Republik Indonesia ke-' + ke + ' · <b>Merdeka!</b>';
      main.insertBefore(pita, main.firstChild);
      return;
    }

    // c) Login: note di panel brand (setelah divider)
    var panel = document.querySelector('.left-panel');
    if (panel) {
      var note = document.createElement('div');
      note.className = 'merdeka-login-note';
      note.innerHTML = flag + 'Dirgahayu RI ke-' + ke + ' — Merdeka!';
      var divider = panel.querySelector('.divider');
      if (divider && divider.parentNode === panel) panel.insertBefore(note, divider.nextSibling);
      else panel.appendChild(note);
      return;
    }

    // d) Fallback: pita fixed di atas body
    var fx = document.createElement('div');
    fx.className = 'merdeka-ribbon merdeka-ribbon--fixed';
    fx.setAttribute('role', 'status');
    fx.innerHTML = flag + 'Dirgahayu Republik Indonesia ke-' + ke + ' · <b>Merdeka!</b>';
    document.body.insertBefore(fx, document.body.firstChild);
  }

  if (document.readyState !== 'loading') pasangUcapan();
  else document.addEventListener('DOMContentLoaded', pasangUcapan);
})();
