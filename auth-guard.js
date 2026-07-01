// auth-guard.js — blokir akses bila akun karyawan berstatus tidak aktif (resign)
// Dipakai di semua halaman aplikasi (bukan index.html/reset-password.html).
async function guardKaryawanAktif (sb, status) {
  if (status && status !== 'aktif') {
    await sb.auth.signOut()
    try { sessionStorage.setItem('hris_login_msg', 'Akun Anda sudah tidak aktif. Hubungi HR jika ini keliru.') } catch (e) {}
    window.location.href = 'index.html'
    return false
  }
  return true
}
