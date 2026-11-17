const CACHE_NAME = 'suvlasnik-pro-v1';
const ASSETS = [
  './',
  './index.html',
  './logo.png',
  './manifest.json'
];

// Instalacija i spremanje osnovnih datoteka u cache
self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  self.skipWaiting();
});

// Aktivacija i čišćenje starog cachea
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Dohvaćanje podataka (Network First, Cache Fallback)
self.addEventListener('fetch', (e) => {
  // Ne presreći Supabase pozive i sl.
  if (e.request.url.includes('supabase.co')) return;
  
  e.respondWith(
    fetch(e.request).catch(() => caches.match(e.request))
  );
});const CACHE='suvlasnik-pro-1-1';const FILES=['./','./index.html','./manifest.json','./config.js'];self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES))));self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(a=>Promise.all(a.filter(x=>x!==CACHE).map(x=>caches.delete(x))))));self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(fetch(e.request).then(r=>{if(r.ok&&new URL(e.request.url).origin===location.origin){let q=r.clone();caches.open(CACHE).then(c=>c.put(e.request,q))}return r}).catch(()=>caches.match(e.request).then(r=>r||caches.match('./index.html'))))});