-- ============================================================================
-- Türkiye geneli POI çıkarma — Foursquare Open Source Places (Apache 2.0)
-- ----------------------------------------------------------------------------
-- Açık veri setinden (100M+ global POI) yalnızca Türkiye'deki ve uygulamada
-- gösterdiğimiz kategorilerdeki mekanları süzüp Cloudflare D1'e yüklenecek bir
-- SQLite dosyası üretir. İstek başına ücreti olmayan kalıcı $0 omurga için
-- "bir kez işle → CDN/edge'den dağıt" modelinin ilk adımıdır.
--
-- Çalıştırma (DuckDB ≥ 1.1):
--   duckdb < tools/poi_pipeline/extract_turkey_pois.sql
-- Çıktılar:
--   tools/poi_pipeline/turkey_pois.db  (SQLite — re-run cache'i)
--   tools/poi_pipeline/tiles/x=../y=../data_0.json  (R2'ye yüklenecek z12 tile'lar)
--
-- ⚠️ KAYNAK: Ungated (kimlik doğrulama YOK) tek dosyalık HF aynası.
--   - Resmî foursquare/fsq-os-places HF yolu GATED (token ister).
--   - Resmî s3://fsq-os-places-us-east-1 bucket'ında ANONİM LİSTELEME kapalı →
--     `*.parquet` glob'u genişlemiyor (aws s3 ls / DuckDB glob boş döner).
--   Bu ayna TEK dosyadır → listeleme gerekmez, doğrudan HTTPS range-read ile okunur.
--   (FSQ ile aynı 26 sütunlu şema; ~Kasım 2024 anlık görüntüsü. Aylık tazeleme için
--   resmî kaynağa token'la geçilebilir — bkz. README.)
--
-- NOT: Sütun sırası D1 schema.sql ile AYNI olmalı (INSERT'ler pozisyonel yüklenir):
--   id, name, lat, lon, category, address, tel, website
-- ============================================================================

INSTALL httpfs;      LOAD httpfs;
INSTALL sqlite;      LOAD sqlite;

-- ── Kaynak parquet (ungated, tek dosya, HTTPS) ─────────────────────────────
SET VARIABLE fsq_src =
  'https://huggingface.co/datasets/do-me/foursquare_places_100M/resolve/main/foursquare_places.parquet';

ATTACH 'tools/poi_pipeline/turkey_pois.db' AS out (TYPE SQLITE);

-- ── Süzme + kategori normalizasyonu ────────────────────────────────────────
-- category = uygulamadaki amenityType slug'ı (OsmPoi.categoryToTurkish ile uyumlu).
-- İndeksler bilinçli olarak BURADA üretilmez — D1 tarafında schema.sql ile kurulur.
CREATE OR REPLACE TABLE out.pois AS
WITH src AS (
  SELECT
    fsq_place_id                              AS id,
    name,
    latitude                                  AS lat,
    longitude                                 AS lon,
    NULLIF(address, '')                       AS address,
    NULLIF(tel, '')                           AS tel,
    NULLIF(website, '')                       AS website,
    -- Kategori etiketleri list<string> → tek metne indir (LIKE için)
    lower(COALESCE(array_to_string(fsq_category_labels, ' | '), '')) AS labels
  FROM read_parquet(getvariable('fsq_src'))
  WHERE country = 'TR'
    AND name IS NOT NULL AND name <> ''
    AND latitude IS NOT NULL AND longitude IS NOT NULL
    AND date_closed IS NULL
),
mapped AS (
  SELECT
    id, name, lat, lon,
    CASE
      WHEN labels LIKE '%coffee%' OR labels LIKE '%café%' OR labels LIKE '%cafe%' OR labels LIKE '%tea house%' THEN 'cafe'
      WHEN labels LIKE '%fast food%' OR labels LIKE '%burger%' OR labels LIKE '%pizza%'                         THEN 'fast_food'
      WHEN labels LIKE '%restaurant%' OR labels LIKE '%dining%' OR labels LIKE '%bistro%' OR labels LIKE '%steakhouse%' THEN 'restaurant'
      WHEN labels LIKE '%pharmacy%' OR labels LIKE '%drugstore%'                                                THEN 'pharmacy'
      WHEN labels LIKE '%supermarket%' OR labels LIKE '%grocery%' OR labels LIKE '%market%'                     THEN 'supermarket'
      WHEN labels LIKE '%hospital%' OR labels LIKE '%medical center%' OR labels LIKE '%emergency%'              THEN 'hospital'
      WHEN labels LIKE '%bank%' OR labels LIKE '%atm%'                                                          THEN 'bank'
      WHEN labels LIKE '%hotel%' OR labels LIKE '%motel%' OR labels LIKE '%hostel%' OR labels LIKE '%resort%'   THEN 'tourism_hotel'
      WHEN labels LIKE '%park%' OR labels LIKE '%playground%' OR labels LIKE '%garden%'                         THEN 'leisure_park'
      WHEN labels LIKE '%museum%'                                                                               THEN 'tourism_museum'
      WHEN labels LIKE '%school%' OR labels LIKE '%university%' OR labels LIKE '%college%'                       THEN 'school'
      WHEN labels LIKE '%library%'                                                                              THEN 'library'
      WHEN labels LIKE '%gas station%' OR labels LIKE '%fuel%' OR labels LIKE '%petrol%'                        THEN 'fuel'
      WHEN labels LIKE '%parking%'                                                                              THEN 'parking'
      WHEN labels LIKE '%mosque%' OR labels LIKE '%place of worship%' OR labels LIKE '%church%'                 THEN 'place_of_worship'
      WHEN labels LIKE '%bakery%' OR labels LIKE '%pastry%'                                                     THEN 'shop_bakery'
      WHEN labels LIKE '%police%'                                                                               THEN 'police'
      WHEN labels LIKE '%post office%'                                                                          THEN 'post_office'
      ELSE NULL
    END AS category,
    address, tel, website
  FROM src
)
SELECT id, name, lat, lon, category, address, tel, website
FROM mapped
WHERE category IS NOT NULL;        -- yalnızca tanınan kategoriler

-- ── Tile koordinatlı ND-JSON üretimi (z12 slippy XYZ) ───────────────────────
-- Her POI z12 tile'ına (x,y) atanır ve TEK ND-JSON dosyasına, tile'a göre SIRALI yazılır.
-- 2.16M POI D1 yazma kotasına (100k/gün) sığmadığı için R2 + tile JSON yolu seçildi
-- (egress $0, satır sınırı yok). Sıralı ND-JSON → `split_tiles.mjs` onu tile dosyalarına
-- böler (bellek-güvenli akış). NOT: PARTITION_BY bazı DuckDB sürümlerinde JSON'da
-- desteklenmediği için bilinçli olarak ND-JSON + Node betiği kullanılır.
COPY (
  SELECT
    CAST(floor((lon + 180.0) / 360.0 * 4096) AS INTEGER)                                  AS x,
    CAST(floor((1 - ln(tan(radians(lat)) + 1.0 / cos(radians(lat))) / pi()) / 2 * 4096) AS INTEGER) AS y,
    id,
    -- ND-JSON satır-bazlı olduğu için string alanlardaki CR/LF'leri boşlukla değiştir
    -- (yoksa çok-satırlı adres kaydı satırı bölüp betiği bozar).
    regexp_replace(name,    '[\r\n]+', ' ', 'g') AS name,
    lat, lon, category,
    regexp_replace(address, '[\r\n]+', ' ', 'g') AS address,
    tel, website
  FROM out.pois
  ORDER BY x, y          -- aynı tile satırları ardışık → betik tek tile'ı bellekte tutar
) TO 'tools/poi_pipeline/pois_with_tiles.json' (FORMAT JSON);

-- ── Özet ────────────────────────────────────────────────────────────────────
SELECT category, count(*) AS adet FROM out.pois GROUP BY category ORDER BY adet DESC;
SELECT count(*) AS toplam_poi FROM out.pois;
