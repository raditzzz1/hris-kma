// pwa-register.js — daftarkan service worker agar HRIS bisa di-"Install"
// (Add to Home Screen) di HP/desktop.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => {})
  })
}
