// notify.js — notifikasi browser saat pengajuan cuti / izin absen luar
// disetujui atau ditolak HR.
//
// CATATAN PENTING: ini notifikasi sisi-browser (via Supabase Realtime +
// Notification API), BUKAN push notification server. Hanya berfungsi
// SELAMA tab/app ini masih terbuka (boleh di-minimize/background),
// TIDAK muncul kalau app/browser sudah ditutup total.

let _notifChannel = null

function notifSupported () {
  return typeof Notification !== 'undefined'
}

function notifPermissionGranted () {
  return notifSupported() && Notification.permission === 'granted'
}

async function requestNotifPermission () {
  if (!notifSupported()) return false
  if (Notification.permission === 'granted') return true
  if (Notification.permission === 'denied') return false
  try {
    const res = await Notification.requestPermission()
    return res === 'granted'
  } catch (e) {
    return false
  }
}

function showNotif (title, body) {
  if (!notifPermissionGranted()) return
  try { new Notification(title, { body, icon: 'icon-192.png' }) } catch (e) {}
}

// Dengarkan perubahan status milik karyawan sendiri, tampilkan notifikasi
// browser + jalankan callback opsional (mis. untuk refresh toast di halaman).
function startNotifListener (sb, karyawanId, onEvent) {
  if (!karyawanId || !sb || _notifChannel) return
  _notifChannel = sb.channel('notif-' + karyawanId)
    .on('postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'pengajuan_cuti', filter: `karyawan_id=eq.${karyawanId}` },
      (payload) => {
        const s = payload.new?.status
        if (s === 'disetujui') { showNotif('Cuti Disetujui', 'Pengajuan cuti Anda telah disetujui HR.'); onEvent && onEvent('cuti', 'disetujui') }
        else if (s === 'ditolak') { showNotif('Cuti Ditolak', 'Pengajuan cuti Anda ditolak. Cek catatan HR di halaman Cuti.'); onEvent && onEvent('cuti', 'ditolak') }
      })
    .on('postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'izin_absen_luar', filter: `karyawan_id=eq.${karyawanId}` },
      (payload) => {
        const s = payload.new?.status
        if (s === 'disetujui') { showNotif('Izin Absen Luar Disetujui', 'Anda kini bisa absen dari luar kantor pada tanggal yang diajukan.'); onEvent && onEvent('izin', 'disetujui') }
        else if (s === 'ditolak') { showNotif('Izin Absen Luar Ditolak', 'Pengajuan izin absen luar Anda ditolak HR.'); onEvent && onEvent('izin', 'ditolak') }
      })
    .subscribe()
}
