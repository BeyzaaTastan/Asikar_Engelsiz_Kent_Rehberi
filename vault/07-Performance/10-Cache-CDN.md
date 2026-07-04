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
- **İlk yükleme gecikmesi (ÇÖZÜLDÜ — *2026-06-29*, O11):** Önceden POI çekimi **yalnızca** `MapEventMoveEnd` + `zoom ≥ 15` olayına bağlıydı; bu olay ilk render'da tetiklenmediği için **harita açıldığında mekanlar hiç yüklenmiyordu** — kullanıcı haritayı elle oynatıp yakınlaştırana kadar boş kalıyordu ("çok geç yükleniyor" şikâyetinin asıl kaynağı). Düzeltme (`map_screen.dart`): **(1)** `MapOptions.onMapReady` ile ilk açılışta otomatik POI çekimi (`_fetchPoisForVisibleArea(..., immediate: true)`, 800ms debounce atlanır), `initialZoom` 14→**15** (POI'ler zoom ≥ 15'te gösterilir). **(2) Varsayılan filtre daraltması:** Filtre seçilmemişken Overpass 21 + Foursquare 12 kategorinin tamamını sorgulamak yerine yalnızca `quickFilterCategories` (7 kategori) sorgulanır → en pahalı Overpass sorgusu önlenir, yanıt hızlanır, ücretsiz kota korunur. **(3) Loading takılması:** Gösterge eskiden yalnızca Foursquare `onResult`'una bağlıydı; Foursquare API key'i boşsa (`fetchNearby` erken `return`) "Mekanlar yükleniyor..." sonsuza kadar takılıyordu → artık iki kaynak ayrı `_overpassLoading`/`_fsqLoading` bayrağıyla izlenir ve key boşken servis `onLoadingChanged(false)` çağırır. Detay UI tarafı: [[01-On-Yuz]] · "Harita ekranı".
- **Hibrit POI cache (Overpass + Foursquare):** Harita ekranı POI'leri **iki kaynaktan paralel** çeker (bkz. [[01-On-Yuz]] · "Harita & POI"). Her kaynak **kendi 800ms debounce'u + cache'i** ile çalışır:
  - **Foursquare** (`FoursquarePlacesService`): merkez+yarıçap bazlı, cache anahtarı `lat(3 ondalık),lon(3 ondalık),kategoriler,radius`. Güncel **iş yeri** verisi için. ~111m hassasiyet → aynı bölge oynatıldığında ağ isteği yok.
  - **Overpass** (`OverpassPoiService`): bounding-box bazlı, cache anahtarı `s,w,n,e` (3 ondalık). Yaya yolu/footway katmanları + erişilebilirlik node'ları için. *(Not: map_screen'in erişilebilirlik katmanı sorguları — yaya/tekerlekli sandalye/hissedilebilir/asansör/**engelli otoparkı** — artık saf, birim testli `overpass_query_builder.dart` ile üretilir; bkz. [[07-CI-CD]], [[01-On-Yuz]].)*
  - **Birleştirme (`_mergePois`):** **Foursquare öncelikli**; ikinci listeden gelenler 4-ondalık koordinat **ve** 40m içi isim benzerliğiyle dedup edilir → aynı mekan iki kaynaktan tekrarlanmaz. **Neden çift kaynak:** Foursquare güncel işletme ismi/kategorisi verir ama ücretsiz kota sınırlı; Overpass bedava + erişilebilirlik tag'leri zengin (bkz. [[03-Veritabani]] · "Harici POI modeli"). İkisi birleşince kapsama artar, kota korunur.
- **POI zoom kapısı + declutter = daha az çekim ve çizim (*2026-07-01*, O13):** POI'ler yalnızca `_poiFetchMinZoom = 15` üstünde çekilir **ve** çizilir; altında (şehir ölçeği) çekilmez → geniş viewport'ta yüzlerce POI indirilmez, ücretsiz kota korunur (debounce + cache aynen). Üstünde hangi POI'nin isim/nokta/gizli olacağına Google tarzı **declutter** karar verir (`map/poi_declutter.dart`, öncelik `map/poi_priority.dart`) — bu **saf render optimizasyonu**, veri çekimini/çağrı sayısını değiştirmez (bkz. [[01-On-Yuz]] · "kademeli görünürlük", [[11-Olcekleme]] · render ölçeği). Marker kümeleme denendi, elendi (uzak zoom'da kümeler de örtüyordu).
- **Temel harita karo cache'i:**
  - **Varsayılan mod = OpenFreeMap Liberty VEKTÖR karo (*2026-07-04*):** "Varsayılan" harita türü artık raster PNG yerine **vektör karo** ile çizilir (`vector_map_tiles` ^9.0.0-beta.8; Google'a yakın palet gerekçesi [[01-On-Yuz]] · "Google tarzı görünüm"). `vector_map_tiles`'ın kendi **iki katmanlı cache'i** ile ücretsiz OpenFreeMap servisine yük en aza iner: **dosya cache'i** (varsayılan 30 gün TTL, ~50MB tavan → aynı bölge tekrar açılınca `.pbf` yeniden indirilmez) + **bellek cache'i** (çözümlenmiş karo). Stil (`StyleReader`) açılışta bir kez indirilir. Vektör overzoom (kaynak maxzoom 14 → harita 18) ekstra ağ isteği doğurmaz — aynı `.pbf` yakınlaştırılarak çizilir → uzak/orta zoom'da daha az tile indirilir (raster'a göre kota avantajı). Stil yüklenene/başarısız olana kadar **CartoDB Voyager raster fallback** (harita boş kalmaz).
  - **Uydu/Arazi + fallback = raster tile cache:** `flutter_map` raster tile'ları (Esri uydu, OpenTopoMap arazi, Voyager fallback) cihazda önbelleğe alınır → aynı bölge tekrar açıldığında yeniden indirilmez.
  - **OMT POI karo çekimi + cache (*2026-07-05*):** Vektör karonun kendi `poi` etiketleri gizlenip o mekanlar **kendi tıklanabilir POI katmanımıza** taşındı (`OmtPoiService` — bkz. [[01-On-Yuz]] · "vektör POI etiketleri gizlendi"). Servis aynı OpenMapTiles karolarını `VectorTileProvider.provide` ile çeker (harita ile AYNI kaynak; render katmanının kendi cache'i ayrı olduğundan bu POI çekimi **kendi tile başına cache'ini** tutar: bir z14 karosu oturumda **bir kez** indirilip ayrıştırılır, panning aynı karo içinde ağ/CPU doğurmaz). Ayrıştırma `compute` ile arka planda (MVT decode CPU; frame düşmez). z14 karosu ~2.4 km² kapsar → görünür alanda 1–4 karo, `maxTiles=12` tavanı. Debounce 800ms (diğer POI kaynaklarıyla aynı ritim). Ekstra servis/anahtar yok, $0 (OpenFreeMap CDN).
- **Arama cache'i (`MapSearchService`):** Nominatim + Overpass birleşik arama 500ms debounce ile çalışır (bkz. [[01-On-Yuz]] · "Arama"). Tekrarlanan sorgu ağ trafiğini azaltır.
- **SharedPreferences:** Erişilebilirlik ayarları + favori rotalar + son 5 arama cihazda kalıcı → açılışta ağ gerekmez.

**CDN (var ama "bedava gelen"):**
- **OSM tile'ları** zaten OSM/3. parti tile sunucusu üzerinden (coğrafi dağıtık).
- **Firebase Hosting** (web kullanılırsa) global CDN + edge cache ile gelir (bkz. [[05-Barindirma]]).
- **Firebase Storage/CDN:** Mekân görselleri için kullanılırsa Google'ın edge cache'i devrede.

**Bilinçli minimalizm:** ~~Dedike bir CDN (Cloudflare/CloudFront) **yok** ve gerekmiyor. Trafik tek şehir~~ → **GÜNCELLENDİ (*2026-06-29*, O12):** Proje Türkiye geneli production'a taşınınca bu varsayım düştü. Artık **Cloudflare edge cache + R2 mimari bir bileşen**: Türkiye geneli **2.16M POI** taban katmanı z12 tile JSON'ları olarak **R2**'de durur (egress $0), Worker `/pois?bbox=` kapsayan tile'ları okuyup bbox'a süzer ve yanıtı **edge'de cache'ler** (aynı bölgeyi gezen kullanıcılar paylaşır) → istek başına maliyet $0 (bkz. [[03-Veritabani]] · "POI taban katmanı", [[06-Bulut]], [[11-Olcekleme]]). Firestore tarafı için ise hâlâ dedike CDN gereksiz (içerik dinamik/realtime).

**Neden agresif cache yok:** Veri tazeliği önemli — erişilebilirlik skoru/çağrı durumu **anlık** olmalı. Bunları cache'lemek tehlikeli (eski skor = yanlış bilgi). Cache yalnızca "ucuz ve değişmeyen" katmanlarda (tile, POI, ayar) uygulanır.

## MVP Kapsamı
**VAR:**
- Hibrit POI cache: Foursquare (koordinat/kategori) + Overpass (bbox), her biri 800ms debounce
- `_mergePois` ile Foursquare-öncelikli dedup (koordinat + 40m isim benzerliği)
- **Foursquare + OSM + OpenMapTiles görünür atıf** (3. parti lisans şartı, *2026-07-02*, OpenMapTiles *2026-07-04*): `map/map_attribution.dart` tek kaynak — haritada köşe rozeti (`MapAttributionBadge`) + POI detay panelinde kaynağa göre satır (`SheetAttributionLine`). "Powered by Foursquare" FSQ POI göründükçe, "© OpenStreetMap katkıda bulunanlar" OSM içeriği göründükçe, **"© OpenMapTiles"** varsayılan vektör taban (OpenFreeMap Liberty) aktifken (`showOpenMapTiles`). Widget testli (`test/widget/map_attribution_test.dart`). Bkz. [[09-Rate-Limiting]], [[08-Guvenlik]], [[07-CI-CD]]
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
- [~] Karo-sağlayıcı atıfları (Esri uydu / CARTO Voyager / OpenTopoMap kendi şartları) — Foursquare/OSM **veri** atfından ayrı. Varsayılan vektör taban için **OpenMapTiles** atfı eklendi (*2026-07-04*); Esri/CARTO/OpenTopoMap (uydu/arazi/fallback) sağlayıcı atıfları hâlâ eksik

---

## İlgili Notlar
- [[Architecture-Overview]] — önbellek katmanının yeri (stub)
- [[PRD]] — POI keşfi performans gereksinimi
- [[01-On-Yuz]] — POI/tile/arama cache'in UI'ı
- [[03-Veritabani]] — salt-okunur POI cache
- [[05-Barindirma]] — Hosting CDN/edge cache
- [[09-Rate-Limiting]] — kota koruyan debounce
- [[12-Loglama]] — cache hit/miss metriği
