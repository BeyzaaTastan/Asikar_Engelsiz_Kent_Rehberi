# POI Pipeline — FSQ Open Source Places → Türkiye alt-kümesi

`extract_turkey_pois.sql` DuckDB betiği, Foursquare Open Source Places (Apache 2.0,
100M+ global POI) veri setinden **yalnızca Türkiye'deki ve uygulamada gösterdiğimiz
kategorilerdeki** mekanları süzüp Cloudflare D1'e yüklenecek bir SQLite dosyası üretir.

## Çalıştırma
```bash
# (Önce erişimi + şemayı doğrula — hızlı, ilk row group'u okur:)
duckdb -c "INSTALL httpfs; LOAD httpfs; SELECT country, name, fsq_category_labels FROM read_parquet('https://huggingface.co/datasets/do-me/foursquare_places_100M/resolve/main/foursquare_places.parquet') LIMIT 3;"

# Sonra tam çıkarma:
duckdb < tools/poi_pipeline/extract_turkey_pois.sql
```

> **Kaynak = ungated tek dosyalık HF aynası** (`do-me/foursquare_places_100M`,
> FSQ ile aynı 26 sütunlu şema, ~Kasım 2024). Neden resmî kaynak değil:
> - foursquare/fsq-os-places HF yolu **gated** (token ister).
> - `s3://fsq-os-places-us-east-1` bucket'ında **anonim listeleme kapalı** →
>   `*.parquet` glob'u genişlemez (`aws s3 ls` / DuckDB `glob()` boş döner).
>
> Tek dosya → listeleme gerekmez, HTTPS range-read ile okunur. İlk okuma
> `country='TR'` süzerken birkaç GB tarar (sütun projeksiyonu sayesinde tüm
> 10.6 GB değil); çıktı (`turkey_pois.db`) küçüktür. Aylık tazeleme için resmî
> kaynağa token'la geçilebilir.

## Çıktı (iki adım)
1. `duckdb < extract_turkey_pois.sql` →
   - `turkey_pois.db` — `pois(...)` tablosu (re-run cache'i)
   - `pois_with_tiles.json` — tile koordinatlı (x,y) **sıralı** ND-JSON
   - konsola kategori başına adet + toplam POI özeti
2. `node split_tiles.mjs` →
   - `tiles/x=../y=../data_0.json` — **R2'ye yüklenecek z12 tile JSON'ları**

> 2.16M POI D1 yazma kotasına (100k/gün) sığmadığı için **R2 + tile JSON** yolu seçildi
> (egress $0, satır sınırı yok). PARTITION_BY bazı DuckDB sürümlerinde JSON'da
> desteklenmediğinden tile bölme Node betiğiyle yapılır. Yükleme + deploy:
> `cloudflare/poi-worker/README.md`.

## Kategori eşlemesi
FSQ kategori etiketleri → `category` slug'ı (CASE ile), uygulamadaki
`OsmPoi.categoryToTurkish` ve `OverpassPoiService.categoryFilters` ile uyumlu
(cafe, restaurant, pharmacy, supermarket, hospital, bank, tourism_hotel,
leisure_park, school, library, fuel, parking, place_of_worship, shop_bakery,
police, post_office, tourism_museum).

Tanınmayan kategoriler düşürülür → satır sayısı (ve maliyet) kontrol altında.
Daha fazla/az kapsam için SQL'deki CASE bloğunu düzenle.

## Sorun giderme
- **`HTTP 0` / dosya bulunamadı:** `dt=` tarihi S3'te yok. Geçerli sürümleri listele
  (AWS CLI ile, kimlik gerekmez):
  ```bash
  aws s3 ls s3://fsq-os-places-us-east-1/release/ --no-sign-request
  ```
  Çıkan en güncel `dt=YYYY-MM-DD` değerini `extract_turkey_pois.sql`'e yaz.
- **`hf://` denemeyin:** veri seti gated; S3 yolu kullanılır (yukarıda).
- **Kimlik bilgisi hatası:** DuckDB public bucket'ı imzasız okur; yalnızca
  `SET s3_region='us-east-1';` yeterli (betikte var).

> Sonraki adım (D1 oluştur, import, deploy): `cloudflare/poi-worker/README.md`.
