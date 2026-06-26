/* ================================================================
   responsive-tables.js — ubah tabel jadi kartu di layar kecil
   PT Kawan Menengah Atas HRIS (Fase E)

   Cara kerja: tiap <table> yang punya <thead> diberi kelas "cardify",
   lalu tiap <td> di body diberi atribut data-label sesuai judul kolomnya.
   CSS (theme.css, @media <=768px) yang menyulapnya jadi kartu.

   Tabel di HRIS dirender ulang secara dinamis (innerHTML) setelah data
   Supabase termuat, jadi kita pakai MutationObserver agar pelabelan
   otomatis terpasang ulang tiap kali isi tabel berubah.
   ================================================================ */
(function () {
  function labelize (table) {
    var ths = table.querySelectorAll('thead th');
    if (!ths.length) return;
    var labels = Array.prototype.map.call(ths, function (th) {
      return (th.textContent || '').trim();
    });
    table.classList.add('cardify');
    var rows = table.querySelectorAll('tbody tr, tfoot tr');
    for (var r = 0; r < rows.length; r++) {
      var cells = rows[r].children;
      for (var c = 0; c < cells.length; c++) {
        var cell = cells[c];
        if (cell.tagName !== 'TD') continue;
        // lewati sel gabungan (mis. baris "belum ada data")
        if (cell.hasAttribute('colspan') && +cell.getAttribute('colspan') > 1) continue;
        if (labels[c]) cell.setAttribute('data-label', labels[c]);
      }
    }
  }

  function run () {
    document.querySelectorAll('table').forEach(labelize);
  }

  var scheduled = false;
  function schedule () {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(function () { scheduled = false; run(); });
  }

  function init () {
    run();
    var mo = new MutationObserver(schedule);
    mo.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
