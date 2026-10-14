/* ==================================================================
   DataLens — Service Worker
   Offline-first shell for the installable PWA / Android TWA.

   Strategy
     navigations  -> network-first, fall back to cached shell (offline works)
     static       -> cache-first, populate cache on first fetch
     cross-origin -> network only, never cached (no API keys live here)

   Bump CACHE_VERSION on every release so old shells are evicted cleanly.
   ================================================================== */

const CACHE_VERSION = 'datalens-v6';
const SHELL_CACHE   = `${CACHE_VERSION}-shell`;
const RUNTIME_CACHE = `${CACHE_VERSION}-runtime`;

/* The app is a single self-contained document, so the shell is small. */
const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './config.js',
  './icons/icon-192.png',
  './icons/icon-384.png',
  './icons/icon-512.png',
  './icons/icon-maskable-192.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon.png',
  './icons/favicon-64.png',
  './offline.html'
];

/* ---------- install: precache the shell ---------- */
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .catch((err) => {
        /* Never fail the install because one asset 404'd. The shell still works online. */
        console.warn('[SW] precache incomplete:', err);
      })
      .then(() => self.skipWaiting())
  );
});

/* ---------- activate: drop stale caches, take control ---------- */
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith('datalens-') && k !== SHELL_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

/* ---------- fetch ---------- */
self.addEventListener('fetch', (event) => {
  const req = event.request;

  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never cache cross-origin traffic. Keeps third-party requests honest
  // and means an API token can never end up persisted on the device.
  if (url.origin !== self.location.origin) return;

  // The Supabase Edge Function must never be cached. A stale triage
  // verdict shown to a user is worse than an honest error.
  if (url.pathname.indexOf('/functions/v1/') !== -1) return;

  /* Navigations: try the network so testers get updates, fall back to the
     cached shell so the app still opens with no connection. */
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(SHELL_CACHE).then((c) => c.put('./index.html', copy));
          return res;
        })
        .catch(() => caches.match('./index.html').then((hit) => hit || caches.match('./offline.html')))
    );
    return;
  }

  /* Static assets: cache-first. They're content-stable per cache version. */
  event.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      return fetch(req)
        .then((res) => {
          if (res && res.status === 200 && res.type === 'basic') {
            const copy = res.clone();
            caches.open(RUNTIME_CACHE).then((c) => c.put(req, copy));
          }
          return res;
        })
        .catch(() => caches.match('./offline.html'));
    })
  );
});

/* ---------- allow the page to trigger an immediate update ---------- */
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});