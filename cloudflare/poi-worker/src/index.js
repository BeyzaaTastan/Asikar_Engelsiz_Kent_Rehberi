/**
 * Türkiye POI taban katmanı — Cloudflare Worker + R2 (tile JSON).
 *
 * GET /pois?bbox=south,west,north,east[&cats=cafe,restaurant][&limit=300]
 *   → görünür alandaki POI'leri JSON dizisi olarak döner.
 *
 * Veri R2'de z12 slippy tile'ları olarak durur: pois/x=<x>/y=<y>/data_0.json
 * (her dosya o tile'daki POI'lerin JSON dizisi). Worker bbox'ı kapsayan tile'ları
 * R2'den okur, bbox + kategoriye göre süzer, birleştirir. Yanıt edge'de cache'lenir.
 *
 * $0 omurga: R2 egress ücretsiz + 10M okuma/ay + edge cache + Workers free 100k istek/gün.
 * (2.16M POI D1 yazma kotasına sığmadığı için tile JSON yolu seçildi.)
 */

const Z = 12;            // depolama tile zoom'u (pipeline ile AYNI olmalı)
const N = 2 ** Z;        // 4096

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function lon2x(lon) {
  return Math.floor(((lon + 180) / 360) * N);
}
function lat2y(lat) {
  const r = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * N);
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    const url = new URL(request.url);
    if (url.pathname !== '/pois') return json({ error: 'not_found' }, 404);

    // ── bbox doğrula ─────────────────────────────────────────────────────
    const bbox = (url.searchParams.get('bbox') || '').split(',').map(Number);
    if (bbox.length !== 4 || bbox.some((n) => Number.isNaN(n))) {
      return json({ error: 'bbox gerekli: south,west,north,east' }, 400);
    }
    let [south, west, north, east] = bbox;
    if (south > north) [south, north] = [north, south];
    if (west > east) [west, east] = [east, west];

    // Aşırı geniş alan = çok tile → reddet (zoom ≥ 15 client'ta zaten zorunlu)
    if (north - south > 0.25 || east - west > 0.25) {
      return json({ pois: [], note: 'alan_cok_genis' }, 200);
    }

    const limit = Math.min(parseInt(url.searchParams.get('limit') || '300', 10), 500);
    const cats = new Set(
      (url.searchParams.get('cats') || '').split(',').map((s) => s.trim()).filter(Boolean),
    );

    // ── Edge cache anahtarı (bbox'ı yuvarla) ─────────────────────────────
    const r = (n) => n.toFixed(3);
    const cacheUrl = new URL(request.url);
    cacheUrl.search =
      `bbox=${r(south)},${r(west)},${r(north)},${r(east)}` +
      `&cats=${[...cats].join(',')}&limit=${limit}`;
    const cacheKey = new Request(cacheUrl.toString(), { method: 'GET' });
    const cache = caches.default;
    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    // ── Kapsayan z12 tile'ları hesapla ───────────────────────────────────
    const x0 = lon2x(west);
    const x1 = lon2x(east);
    const y0 = lat2y(north); // kuzey = küçük y
    const y1 = lat2y(south);

    const keys = [];
    for (let x = x0; x <= x1; x++) {
      for (let y = y0; y <= y1; y++) {
        keys.push(`pois/x=${x}/y=${y}/data_0.json`);
      }
    }

    // ── R2'den tile'ları paralel oku ─────────────────────────────────────
    const pois = [];
    await Promise.all(
      keys.map(async (key) => {
        const obj = await env.POI_BUCKET.get(key);
        if (!obj) return;
        let arr;
        try {
          arr = await obj.json();
        } catch {
          return;
        }
        for (const p of arr) {
          if (p.lat < south || p.lat > north || p.lon < west || p.lon > east) continue;
          if (cats.size > 0 && !cats.has(p.category)) continue;
          pois.push(p);
          if (pois.length >= limit) break;
        }
      }),
    );

    const response = new Response(JSON.stringify({ pois: pois.slice(0, limit) }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=86400', // taban veri günlük güncellenir
        ...CORS,
      },
    });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}
