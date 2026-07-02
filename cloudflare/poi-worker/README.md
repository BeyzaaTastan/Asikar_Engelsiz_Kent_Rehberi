# Türkiye POI Taban Katmanı — Cloudflare Worker + R2 (tile JSON)

Foursquare Open Source Places (Apache 2.0) verisinden üretilen **2.16M** Türkiye POI'sini
**istek başına ücretsiz** sunan backend. Uygulama bunu `POI_API_BASE_URL` ile tüketir
(`lib/services/fsq_poi_service.dart`).

```
FSQ OS Places (parquet)
   │  DuckDB ile süz + z12 tile'lara böl   → tools/poi_pipeline/
   ▼
tiles/x=../y=../data_0.json   (her tile = POI JSON dizisi)
   │  rclone → R2 (pois/ prefix)
   ▼
Cloudflare R2  ──  Worker /pois?bbox=  ──(bbox süz + edge cache)──▶  Flutter haritası
```

**Neden R2, D1 değil:** 2.16M POI, D1 ücretsiz yazma kotasına (100k satır/gün) sığmaz
(~22 gün). R2'de satır limiti yok, **egress ücretsiz**, 10M okuma/ay free → tek şehir
değil **Türkiye geneli production'da $0**.

---

## SENİN YAPMAN GEREKENLER (runbook)

### 0. Önkoşullar (bir kez)
- **Cloudflare hesabı** (ücretsiz): https://dash.cloudflare.com/sign-up
- **Node + Wrangler:** `npm install -g wrangler` → `wrangler login`
- **rclone** (R2'ye toplu yükleme için): https://rclone.org/downloads/

### 1. Tile'ları üret (DuckDB + Node — yerel)
```bash
# a) DuckDB: süz + tile koordinatlı sıralı ND-JSON üret
duckdb < tools/poi_pipeline/extract_turkey_pois.sql
# b) Node: ND-JSON'u tile dosyalarına böl (bağımlılık yok)
node tools/poi_pipeline/split_tiles.mjs
# Çıktı: tools/poi_pipeline/tiles/x=../y=../data_0.json  (binlerce z12 tile)
```
> `split_tiles.mjs` her çalıştığında `tiles/` klasörünü sıfırlar (eski tile kalmaz).

### 2. R2 bucket oluştur
```bash
cd cloudflare/poi-worker
wrangler r2 bucket create asikar-poi
```

### 3. Tile'ları R2'ye yükle (rclone)
R2, S3-uyumlu. Önce rclone'a R2 remote'u tanıt (bir kez):
```bash
# Cloudflare Dashboard → R2 → "Manage API Tokens" ile Access Key + Secret üret.
rclone config create r2 s3 provider=Cloudflare \
  access_key_id=<KEY> secret_access_key=<SECRET> \
  endpoint=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```
Sonra tüm tile'ları `pois/` prefix'ine kopyala:
```bash
rclone copy ../../tools/poi_pipeline/tiles r2:asikar-poi/pois --transfers=32 --progress
```
> R2 free: 10GB depo + 1M yazma/ay. Binlerce tile bunun çok altında.

### 4. Worker'ı deploy et
```bash
wrangler deploy
# Çıktı: https://asikar-poi-worker.<subdomain>.workers.dev
```

### 5. Uygulamaya bağla
`.env`:
```
POI_API_BASE_URL=https://asikar-poi-worker.<subdomain>.workers.dev
```
`flutter run` — harita artık Türkiye geneli taban katmanını gösterir.
(URL boşken servis no-op; bağlamadan önce uygulama davranışı değişmez.)

### 6. Aylık tazeleme (opsiyonel)
FSQ aylık güncellenir. Adım 1 + 3'ü tekrarla (rclone değişen tile'ları senkronlar).
İleride GitHub Actions cron ile otomatikleştirilebilir.

---

## Test (deploy sonrası)
```bash
curl "https://asikar-poi-worker.<subdomain>.workers.dev/pois?bbox=40.76,29.94,40.79,30.00&cats=cafe"
```

## Mimari notlar
- **Tile zoom = 12** (`src/index.js` `Z` sabiti pipeline ile AYNI olmalı). Worker bbox'ı
  kapsayan tile'ları okur, bbox + kategoriye göre süzer → client sadece görünür POI'leri alır.
- **Dosya adı `data_0.json`:** DuckDB partition başına tek dosya yazar. Farklı isimlendirme
  görürsen Worker'daki anahtarı (`pois/x=../y=../data_0.json`) ona göre güncelle.

## Attribution (lisans şartı — ZORUNLU)

Uygulama iki Foursquare kaynağı kullanır; ikisi de görünür atıf ister:

1. **Foursquare Places API v3** (canlı, `foursquare_places_service.dart`) — [Places API License Agreement](https://foursquare.com/legal/terms/apilicenseagreement/):
   veri göründüğü **her ekranda** markalı **"Powered by Foursquare"** atıfı zorunlu.
2. **Foursquare OS Places** (bu backend'in taban katmanı, Apache 2.0) — API dağıtımı için
   aşağıdaki NOTICE içeriği geliştirici dokümanında **belirgin** tutulmalı.

Uygulama içi atıf tek kaynaktan yönetilir: `lib/screens/map/map_attribution.dart`
(`MapAttributionBadge` harita köşesinde + `SheetAttributionLine` POI detay panelinde).
OSM/Overpass verisi için ayrı ODbL atfı: **"© OpenStreetMap katkıda bulunanlar"**.

### FSQ OS Places — NOTICE (Apache 2.0)
Kaynak: https://opensource.foursquare.com/places-notice-txt/

```
© 2026 Foursquare Labs, Inc. All rights reserved.

This dataset is licensed under the Apache License, Version 2.0
(http://www.apache.org/licenses/LICENSE-2.0).

Kullanırken: (1) lisansın bir kopyasını sağla, (2) veride yaptığın
değişiklikleri belirgin biçimde bildir, (3) bu NOTICE.txt içeriğini ve
Foursquare atfını koru.
```
> Karo sağlayıcı (Esri uydu / CARTO Voyager / OpenTopoMap) atıfları ayrı bir konudur
> ve henüz eklenmedi — bkz. [[10-Cache-CDN]] TODO.
