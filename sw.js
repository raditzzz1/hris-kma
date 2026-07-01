// sw.js — service worker minimal untuk HRIS PT Kawan Menengah Atas
// Tujuan utama: syarat teknis agar app bisa di-"Install"/Add to Home Screen.
// SENGAJA tidak nge-cache halaman/JS secara agresif (app ini aktif dikembangkan
// — cache halaman bisa bikin user "nyangkut" di versi lama setelah update).
// Hanya menyediakan halaman cadangan sederhana saat benar-benar offline.

const CACHE = 'hris-shell-v1'
const OFFLINE_URL = 'offline.html'

self.addEventListener('install', (event) => {
  self.skipWaiting()
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll([OFFLINE_URL, 'logo-KMA.png']))
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

// Hanya tangani navigasi halaman (buka/refresh halaman), bukan API/aset lain
// -> selalu ambil versi TERBARU dari jaringan; fallback ke halaman offline
// hanya kalau jaringan benar-benar tidak tersedia.
self.addEventListener('fetch', (event) => {
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(OFFLINE_URL))
    )
  }
})
