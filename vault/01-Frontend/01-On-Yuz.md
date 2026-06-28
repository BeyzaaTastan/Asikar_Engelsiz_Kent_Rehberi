---
katman: Ön Yüz
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[04-Auth]], [[03-Veritabani]], [[02-API-Arka-Uc]], [[10-Cache-CDN]]
---

# 01 · Ön Yüz (Frontend)

## Neden önemli
Ön yüz ürünün tek temas noktası; engelli kullanıcı için erişilebilirlik burada ya vardır ya yoktur, ortası yoktur. Atlanırsa (kötü tasarlanırsa) görme engelli kullanıcı "YARDIM İSTE" butonunu bulamaz ve ürünün varlık sebebi çöker.

## Karar (ne + NEDEN)
**Ne:** **Flutter (Dart, SDK ^3.9.2)** ile tek kod tabanlı, Android + iOS native + Web çıktısı.

**Neden Flutter:**
- Tek kod tabanı → tek geliştiricinin iki platforma da yetişmesinin tek gerçekçi yolu (düşük bütçe/zaman).
- Native erişim: kamera, konum, push, CallKit — hepsi olgun paketlerle mevcut.
- `Semantics` widget'ı ile erişilebilirlik birinci sınıf; ekran okuyucu desteği zahmetsiz.

**State yönetimi:** **Riverpod (flutter_riverpod ^2.5.1)** — `settingsServiceProvider` `ProviderScope.overrides` ile inject edilir; async başlatılan `SettingsService` test edilebilir şekilde enjekte edilir. **Neden Riverpod:** compile-time güvenli, BuildContext'e bağımsız, global ayar (tema/erişilebilirlik) için ideal.

**Routing:** Merkezi `AppRouter` + `AppRoutes` sabitleri, `onGenerateRoute`. **Kural:** String literal route yazılmaz, hep `AppRoutes` sabiti. **Neden:** Kayıt akışı 8 ekran zinciri; tek yerden yönetilmezse parametre geçişi (userType, interests) hata kaynağı olur.

**Tema:** Dinamik — yüksek kontrast × karanlık mod = 4 kombinasyon. Yüksek kontrast karanlıkta `sarı üzerine siyah` (0xFFFFFF00), açıkta `koyu lacivert üzerine beyaz` (0xFF000080). **Kural:** Inline `Color(...)` yasak; hep `AppColors`.

**Erişilebilirlik mekanikleri:**
- Yazı boyutu uygulama içi `TextScaler.linear(fontScale)` ile (0.8x–1.4x); sistem ayarından bağımsız.
- Kritik widget'larda `Semantics(label: ...)` (YARDIM İSTE, rota butonları, çağrı sonlandır).

## MVP Kapsamı
**VAR:**
- 3 sekmeli `IndexedStack` navigasyon (Topluluk / Ana Sayfa / Harita)
- **Topluluk sekmesi** (`community_screen.dart`): kullanıcı katkılı `venues` mekânlarının keşfi — realtime `venuesStreamProvider` + **client-side** arama, kategori ve **erişilebilirlik seviyesi** filtresi (`filteredVenuesProvider`). PRD'deki "Sakin/Turist mekân keşfi" akışının UI'ı (bkz. [[PRD]], [[03-Veritabani]])
- Kullanıcı tipine göre dinamik ana sayfa (Disabled/Volunteer/Standard)
- `AccessibilityDrawer` (yazı, kontrast, ses, karanlık mod)
- Harita ekranı (`map_screen.dart`, flutter_map + OSM tile): **hibrit POI** (Overpass + Foursquare paralel, Foursquare-öncelikli birleştirme — bkz. [[10-Cache-CDN]]), erişilebilirlik katmanları (footway/tekerlekli sandalye yolları, hissedilebilir yüzey node'ları), kategori filtresi
- **Birleşik arama** (`map_search_service.dart`): Nominatim (adres/metin) + Overpass (kategori) paralel, 500ms debounce, koordinat bazlı dedup
- **Rota / yol tarifi** (`route_screen.dart`): **OSRM** tabanlı (birincil `routing.openstreetmap.de` yaya+araç, yedek `router.project-osrm.org` yalnız araç); GeoJSON geometri, API düşerse düz-çizgi fallback. Mesafe/süre gösterimi, rota ters çevirme/paylaşma
- CallScreen (Agora), mekân ekleme/detay. **Çağrı kabulü** (`notification_service`): kanal adı yalnızca event'ten okunur (`_validChannelName`); geçersizse çağrı **kabul edilmez** — paylaşılan sabite fallback yok (yanlış görüşme önlenir, bkz. [[02-API-Arka-Uc]])
- **Çağrı zaman aşımı (arayan):** `CallScreen` 45 sn içinde gönüllü bulamazsa transaction ile `zaman_asimi` yazar ve "Şu anda uygun bir gönüllü bulunamadı" + "Tekrar Dene" ekranını gösterir (`Semantics(liveRegion: true)` ile ekran okuyucu anında seslendirir). Gönüllü tam zamanında üstlenirse görüşme normal sürer (bkz. [[02-API-Arka-Uc]], [[03-Veritabani]])
- Splash + tam kayıt akışı

**YOK:**
- Offline-first / yerel veri senkronu (sadece `SharedPreferences` ayarları kalıcı)
- Animasyon/onboarding turu
- Tablet/responsive özel layout
- Web'e özel uyarlama (mevcut layout web'de "çalışır ama optimize değil")

## Açık Sorular
- `TextScaler` 1.4x'te en uzun butonlar taşıyor mu? (overflow testi yapılmadı)
- Görme engelli kullanıcı haritayı nasıl kullanacak? Harita doğası gereği görsel — sesli alternatif (liste modu) gerekli mi?
- Web'de Agora/CallKit davranışı doğrulanmadı; web "ikincil" derken çağrı dahil mi?
- **Rota erişilebilirliği:** `route_screen` OSRM'in yaya/araç profillerini kullanıyor; **tekerlekli sandalyeye özel profil yok**. Engelli birey için "erişilebilir rota" (rampa/kaldırım dikkate alan) gerçek anlamda sunulmuyor — ürünün varlık sebebiyle çelişir mi? (bkz. [[PRD]])

## TODO
- [~] En büyük dosya `map_screen.dart` bölme (**2603 → 1716 satır, −%34**) — `lib/screens/map/` klasörü:
  - **Aşama 1 ✅:** durumsuz görsel eşleyiciler + `mergePois` → `map_visuals.dart` (`MapVisuals`); tekrar eden iki renk fonksiyonu birleştirildi; POI paleti `AppColors`'a taşındı.
  - **Aşama 2 ✅:** OSM POI detay paneli → `osm_poi_sheet.dart` (`OsmPoiSheet`, `onClose` callback'i ile durumsuz); paylaşılan aksiyon butonu → `map_action_button.dart` (`MapActionButton`, venue + POI sheet ortak).
  - **Aşama 3 ✅:** DB mekan detay paneli + yorum kutucuğu → `venue_sheet.dart` (`VenueSheet`, `onClose` ile durumsuz).
  - **Kalan (opsiyonel):** `_buildUnknownPointSheet`, `_buildSmartResultsOverlay`/`_buildSearchItem`, harita katman seçici (`_showLayerPicker`) ve Overpass katman çekme metotları da ayrılabilir — test olmadığı için adım adım + `flutter analyze` ile
- [ ] Tüm kritik akışları TalkBack + VoiceOver ile elle test et
- [ ] `font_scale` 1.4x için overflow regresyon testi
- [ ] Harita için "liste görünümü" erişilebilir alternatifini değerlendir → [[PRD]]'ye ekle

---

## İlgili Notlar
- [[Architecture-Overview]] — Frontend'in sistemdeki yeri
- [[Vision]] — erişilebilirlik vizyonunun temas noktası
- [[PRD]] — ekranların gereksinim kaynağı
- [[02-API-Arka-Uc]] — çağrı/token için backend
- [[03-Veritabani]] — realtime veri + mekân kaynağı
- [[04-Auth]] — giriş ve kullanıcı tipi yönlendirmesi
- [[05-Barindirma]] — uygulamanın dağıtım hedefi
- [[10-Cache-CDN]] — POI/tile/arama önbelleği
