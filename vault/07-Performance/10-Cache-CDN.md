---
katman: Cache / CDN
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[01-On-Yuz]], [[09-Rate-Limiting]], [[05-Barindirma]], [[03-Veritabani]]
---

# 10 · Cache / CDN

## Neden önemli
Cache, hem kullanıcı deneyimini (harita gecikmesi) hem maliyeti (API/okuma sayısı) doğrudan etkiler; bu projede ücretsiz kotaları korumanın en pratik yolu. Atlanırsa her harita hareketi yeni API çağrısı doğurur, gecikme artar ve ücretsiz kota erkenden tükenir.

## Karar (ne + NEDEN)
**Uygulama içi cache (var):**
- **Hibrit POI cache (Overpass + Foursquare):** Harita ekranı POI'leri **iki kaynaktan paralel** çeker (bkz. [[01-On-Yuz]] · "Harita & POI"). Her kaynak **kendi 800ms debounce'u + cache'i** ile çalışır:
  - **Foursquare** (`FoursquarePlacesService`): merkez+yarıçap bazlı, cache anahtarı `lat(3 ondalık),lon(3 ondalık),kategoriler,radius`. Güncel **iş yeri** verisi için. ~111m hassasiyet → aynı bölge oynatıldığında ağ isteği yok.
  - **Overpass** (`OverpassPoiService`): bounding-box bazlı, cache anahtarı `s,w,n,e` (3 ondalık). Yaya yolu/footway katmanları + erişilebilirlik node'ları için.
  - **Birleştirme (`_mergePois`):** **Foursquare öncelikli**; ikinci listeden gelenler 4-ondalık koordinat **ve** 40m içi isim benzerliğiyle dedup edilir → aynı mekan iki kaynaktan tekrarlanmaz. **Neden çift kaynak:** Foursquare güncel işletme ismi/kategorisi verir ama ücretsiz kota sınırlı; Overpass bedava + erişilebilirlik tag'leri zengin (bkz. [[03-Veritabani]] · "Harici POI modeli"). İkisi birleşince kapsama artar, kota korunur.
- **OSM tile cache:** `flutter_map` tile'ları cihazda önbelleğe alır → aynı bölge tekrar açıldığında tile yeniden indirilmez.
- **Arama cache'i (`MapSearchService`):** Nominatim + Overpass birleşik arama 500ms debounce ile çalışır (bkz. [[01-On-Yuz]] · "Arama"). Tekrarlanan sorgu ağ trafiğini azaltır.
- **SharedPreferences:** Erişilebilirlik ayarları + favori rotalar + son 5 arama cihazda kalıcı → açılışta ağ gerekmez.

**CDN (var ama "bedava gelen"):**
- **OSM tile'ları** zaten OSM/3. parti tile sunucusu üzerinden (coğrafi dağıtık).
- **Firebase Hosting** (web kullanılırsa) global CDN + edge cache ile gelir (bkz. [[05-Barindirma]]).
- **Firebase Storage/CDN:** Mekân görselleri için kullanılırsa Google'ın edge cache'i devrede.

**Bilinçli minimalizm:** Dedike bir CDN (Cloudflare/CloudFront) **yok** ve gerekmiyor. Trafik tek şehir; içerik çoğunlukla dinamik (Firestore realtime). Statik varlık az.

**Neden agresif cache yok:** Veri tazeliği önemli — erişilebilirlik skoru/çağrı durumu **anlık** olmalı. Bunları cache'lemek tehlikeli (eski skor = yanlış bilgi). Cache yalnızca "ucuz ve değişmeyen" katmanlarda (tile, POI, ayar) uygulanır.

## MVP Kapsamı
**VAR:**
- Hibrit POI cache: Foursquare (koordinat/kategori) + Overpass (bbox), her biri 800ms debounce
- `_mergePois` ile Foursquare-öncelikli dedup (koordinat + 40m isim benzerliği)
- Birleşik arama (`MapSearchService`) 500ms debounce
- OSM tile cache (flutter_map varsayılan)
- SharedPreferences yerel kalıcılık
- (web'de) Firebase Hosting CDN

**YOK:**
- Firestore okuma cache katmanı (realtime istendiği için kasıtlı yok — ama Firestore SDK'nın yerel persistence'ı açılabilir)
- Dedike CDN (Cloudflare vb.)
- Görsel için boyut/format optimizasyonu (thumbnail, WebP)
- API yanıtlarının disk cache'i (bellek cache yeterli)

## Açık Sorular
- Firestore **offline persistence** açık mı? Açıksa zayıf bağlantıda UX iyileşir ama çağrı durumu tazeliği riski doğar — hangisi öncelikli?
- Foursquare bellek cache'i uygulama kapanınca uçuyor; disk cache değer katar mı yoksa karmaşıklık mı?
- Mekân görselleri nerede barındırılıyor (URL'ler dışarıda mı)? Optimize edilmiyorsa mobil veride pahalı.

## TODO
- [ ] Firestore offline persistence kararını ver; çağrı koleksiyonunu istisna tut
- [ ] Mekân görselleri için thumbnail/WebP stratejisi (mobil veri tasarrufu)
- [ ] OSM tile kullanımının adil-kullanım sınırında olup olmadığını kontrol et → [[09-Rate-Limiting]]
- [ ] Cache hit/miss'i ölçmek için basit metrik → [[12-Loglama]]

---

## İlgili Notlar
- [[Architecture-Overview]] — önbellek katmanının yeri (stub)
- [[PRD]] — POI keşfi performans gereksinimi
- [[01-On-Yuz]] — POI/tile/arama cache'in UI'ı
- [[03-Veritabani]] — salt-okunur POI cache
- [[05-Barindirma]] — Hosting CDN/edge cache
- [[09-Rate-Limiting]] — kota koruyan debounce
- [[12-Loglama]] — cache hit/miss metriği
