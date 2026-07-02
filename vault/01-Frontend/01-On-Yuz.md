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
- Tek kod tabanı → küçük ekibin iki platforma da yetişmesinin tek gerçekçi yolu (kısıtlı ekip/zaman).
- Native erişim: kamera, konum, push, CallKit — hepsi olgun paketlerle mevcut.
- `Semantics` widget'ı ile erişilebilirlik birinci sınıf; ekran okuyucu desteği zahmetsiz.

**State yönetimi:** **Riverpod (flutter_riverpod ^2.5.1)** — `settingsServiceProvider` `ProviderScope.overrides` ile inject edilir; async başlatılan `SettingsService` test edilebilir şekilde enjekte edilir. **Neden Riverpod:** compile-time güvenli, BuildContext'e bağımsız, global ayar (tema/erişilebilirlik) için ideal.

**Routing:** Merkezi `AppRouter` + `AppRoutes` sabitleri, `onGenerateRoute`. **Kural:** String literal route yazılmaz, hep `AppRoutes` sabiti. **Neden:** Kayıt akışı 8 ekran zinciri; tek yerden yönetilmezse parametre geçişi (userType, interests) hata kaynağı olur.
- **Durum (O3 — *2026-06-29*):** Önceden `AppRouter` tanımlıydı ama hiç `pushNamed` kullanılmıyordu (tüm gezinme elle `MaterialPageRoute` ile → merkezi router ölü koddu). Denetimle düzeltildi: tüm geçişler `pushNamed`/`pushReplacementNamed`/`pushNamedAndRemoveUntil`'e taşındı; kayıt zinciri argümanları (`userType:String`, `selectedInterests:Set<String>`, `isVolunteer:bool`) ve `routeScreen` (`destinationLocation:LatLng`) AppRouter case'leriyle birebir; iki eksik route eklendi (`addVenue`, `venueDetail{venueId}`). `flutter analyze` temiz, 62 test yeşil. **Bilinçli istisna:** **CallScreen** `navigatorKey` + 15-deneme retry + `pendingCallId` fallback ile `MaterialPageRoute` üzerinden push edilir (bkz. Zorunlu Kalıplar) — `AppRoutes`'a alınmadı; bu kritik çağrı akışı kuralı bilinçli atlar.

**Tema:** Dinamik — yüksek kontrast × karanlık mod = 4 kombinasyon. Yüksek kontrast karanlıkta `sarı üzerine siyah` (0xFFFFFF00), açıkta `koyu lacivert üzerine beyaz` (0xFF000080). **Kural:** Inline `Color(...)` yasak; hep `AppColors`.

**Erişilebilirlik mekanikleri:**
- Yazı boyutu uygulama içi `TextScaler.linear(fontScale)` ile (0.8x–1.4x); sistem ayarından bağımsız.
- Kritik widget'larda `Semantics(label: ...)` (YARDIM İSTE, rota butonları, çağrı sonlandır). Haritadaki `MapActionButton` (Yol Tarifi/Ara/Paylaş) buton rolü + etiket taşır, iç ikon+metin `ExcludeSemantics` ile çift okunmaz (*2026-06-29*, O10; widget testli — bkz. [[07-CI-CD]]).

## MVP Kapsamı
**VAR:**
- 3 sekmeli `IndexedStack` navigasyon (Topluluk / Ana Sayfa / Harita)
- **Topluluk sekmesi** (`community_screen.dart`): kullanıcı katkılı `venues` mekânlarının keşfi — realtime `venuesStreamProvider` + **client-side** arama, kategori ve **erişilebilirlik seviyesi** filtresi (`filteredVenuesProvider`). PRD'deki "Sakin/Turist mekân keşfi" akışının UI'ı (bkz. [[PRD]], [[03-Veritabani]])
- Kullanıcı tipine göre dinamik ana sayfa (Disabled/Volunteer/Standard)
- `AccessibilityDrawer` (yazı, kontrast, ses, karanlık mod)
- Harita ekranı (`map_screen.dart`, flutter_map + OSM tile): **hibrit POI** (Overpass + Foursquare paralel, Foursquare-öncelikli birleştirme — bkz. [[10-Cache-CDN]]), erişilebilirlik katmanları (footway/tekerlekli sandalye yolları, hissedilebilir yüzey + asansör + **engelli otoparkı** node'ları), kategori filtresi
  - **Erişilebilirlik katmanları tek yerde — harita filtreleme modalı (*2026-07-02*):** Erişilebilirlik katmanları yalnızca **katman seçici modalında** (`_showLayerPicker` → `MapOverlayChip`) toggle edilir: Hissedilebilir Yüzey · Tekerlekli Sandalye · Asansör · **Engelli Otoparkı** (+ Toplu Taşıma/Bisiklet/Yürüyüş). Aktif katmanlar `_fetchOverpassLayer` ile Overpass'tan çekilip polyline/marker olarak çizilir (`_showTactile/_showWheelchair/_showElevator/_showParking` bayrakları). Engelli otoparkı `amenity=parking|parking_space` + `wheelchair=yes|designated` node'ları (indigo `AppColors.mapParking`, `Icons.local_parking`); marker sınıflandırmasında otopark kontrolü wheelchair'dan **önce** gelir (aksi hâlde otopark node'u tekerlekli sandalye markerı gibi görünürdü). Sorgu üretimi saf/birim testli: `accessibilityOverpassQuery(..., parking:)` (bkz. [[10-Cache-CDN]], [[07-CI-CD]]).
    - **Kaldırılan tekrar:** Arama çubuğu açıkken altında gösterilen erişilebilirlik filtre çipleri (`MapFilterChip` → Tekerlekli Sandalye/Hissedilebilir Yüzey/Asansör/Engelli Otoparkı) kaldırıldı — aynı katmanlar zaten harita filtreleme modalında yer alıyordu ve arama akışına bir etkileri yoktu (yalnızca `_activeFilter` state'ini değiştiriyorlardı). `MapFilterChip` widget'ı + widget testi silindi; arama overlay'i yalnızca sonuç listesi gösterir.
  - **İlk yükleme hızı (O11 — *2026-06-29*):** Açılışta mekanlar artık `onMapReady` ile **otomatik ve debounce'suz** çekilir (`initialZoom` 15); önceden yalnızca kullanıcı haritayı oynatınca tetiklendiği için "mekanlar çok geç yükleniyor" hissi vardı. Filtre yokken sorgu 21/12 kategori yerine 7 sık kategoriyle sınırlanır; "Mekanlar yükleniyor..." göstergesi iki kaynağı ayrı izleyerek (FSQ key'i boşsa bile) takılmaz. Nedenler + cache gerekçesi: [[10-Cache-CDN]] · "İlk yükleme gecikmesi".
  - **Açılışta kullanıcı konumu (*2026-07-02*):** Harita önce Sakarya merkezinde (`_sakaryaCenter`) açılır; kullanıcı **daha önce (bir kerelik) konum iznini verdiyse** açılışta **tekrar izin sormadan** konumuna ortalanır. `_initLocationOnStart` önce hızlı **son bilinen konum** (`getLastKnownPosition`, cache'li → anında) sonra **güncel konum** (`getCurrentPosition`) ile tazeler; harita henüz hazır değilse `onMapReady` `_currentLocation`'a taşır. İzin verilmemişse **hiç istenmez** (Sakarya merkezi fallback kalır) — sistem izin diyaloğu yalnızca "Konumum" butonunda (`_getCurrentLocation`) çıkar. **Gizlilik:** açılışta izin dayatılmaz, konum loglanmaz (KVKK — bkz. [[08-Guvenlik]]).
    - **Yumuşak geçiş:** Konuma ortalanma ani sıçrama değil **kayan geçiş** (`_animatedMapMove` · `Tween` + `AnimationController`, easeInOut 700ms) — flutter_map yerleşik animasyon sunmadığı için harici bağımlılık eklemeden yazıldı. Üst üste binen geçişler iptal edilir (son bilinen → güncel konum arası titremesin); POI çekimi geçiş **bitince** (`onFinished` → `_fetchPoisAfterMove`) yapılır, böylece debounce/cache/kota mantığı korunur (bkz. [[10-Cache-CDN]], [[11-Olcekleme]]). Aynı yardımcı "Konumum" butonunda da kullanılır (tutarlılık).
  - **Marker yoğunluğu — Google tarzı kademeli görünürlük (O13 — *2026-07-01*):** Eski hâlde tüm POI'ler her zoom'da aynı anda ikon+isimle çiziliyordu → isimler üst üste binip haritayı örtüyordu. Google Haritalar gibi **kademeli görünürlük**e geçildi: aynı zoom'da yalnızca öne çıkan mekanlar isimle, bir kısmı küçük **nokta**, gerisi **gizli**; yaklaştıkça daha fazlası isme yükselir. İki saf/birim-testli katman:
    - **Öncelik + zoom eşikleri** (`map/poi_priority.dart`): `poiPriority` kategori → önem ağırlığı (3 yüksek: hastane/eczane/otel/market/benzin/ibadet/üniversite/müze/park/sinema; 2 orta: restoran/kafe/banka/okul; 1 düşük: küçük dükkanlar). `poiLabelMinZoom`/`poiDotMinZoom` her önceliğe **isim** ve **nokta** için ayrı en-düşük-zoom verir → kademeli görünürlük: **isim** 3→z15, 2→z17, 1→z18; **nokta** 3→yok (düşük zoom'da nokta kalabalığı olmasın), 2→z16, 1→z17. Yani z15'te yalnız yüksek öncelik isimle, z16-17'de orta/düşük nokta→isim, z18'de neredeyse hepsi isim.
    - **Declutter** (`map/poi_declutter.dart` · `declutterPois`): ekran-uzayında açgözlü yerleştirme — öncelik sırasına göre, POI **isim uygunsa** (`canLabel`) ve etiket kutusu çakışmıyorsa `label`; değilse **nokta uygunsa** (`canDot`) ve yeterince uzaksa `dot`; hiçbiri olmazsa `hidden`. `canLabel`/`canDot` yukarıdaki zoom eşikleriyle map_screen'de hesaplanır. Deterministik (eşit öncelikte küçük id kazanır → titremez).
    - **Çizim** (`map_screen._buildPoiMarkers`): `_mapController.camera.latLngToScreenOffset` ile POI'ler pikselе projekte edilir, declutter çağrılır; sonuç `PoiMarker` (ikon+isim) veya `PoiDot` (küçük renkli nokta önizleme) olarak çizilir. Her ikisi de `Semantics(button, excludeSemantics)`'li. Seçili POI çakışsa bile isimle gösterilir. Çok yoğun bölgelerde öncelik sırasına göre `_poiDeclutterCap = 700` ile kırpılır. Relayout `MapEventMoveEnd`'de (setState → build) yapılır.
    - **Veri kapısı:** `_poiFetchMinZoom = 15` — bu zoom'un altında POI çekilmez/gösterilmez (şehir ölçeğinde boş harita, kota korunur); üstünde ne gösterileceğine declutter karar verir. `_fetchPoisForVisibleArea` (800ms debounce + cache) ve Foursquare/Overpass çağrı sayısı **değişmedi** (bkz. [[10-Cache-CDN]], [[11-Olcekleme]]).
    - **Venue (Firestore) marker'ları** bilinçli olarak declutter dışında, her zoom'da görünür (ürünün skorlu çekirdek içeriği). **Not:** Marker kümeleme (`flutter_map_marker_cluster`) önce denendi, elendi — kümeler de uzak zoom'da haritayı örtüyordu; declutter daha çok Google'a benziyor.
  - **Monolit bölme (sürüyor):** Sunum parçaları `lib/screens/map/`'e çıkarılıyor — `MapVisuals`, `MapActionButton`, `VenueSheet`, `OsmPoiSheet`, `MapSearchItem`, `UnknownPointSheet`, `SmartResultsOverlay`, `MapTypeCard`, `MapOverlayChip`, `PoiMarker`/`PoiDot`, ve saf birimler `poiPriority`/`declutterPois`. (`MapFilterChip` çıkarılmıştı ama 2026-07-02'de arama çipleriyle birlikte tamamen kaldırıldı — yukarı bkz.) Saf sunum widget'ları widget testli (state mutasyonu/Navigator/fetch map_screen'de thin wrapper'da kalır); `map_screen.dart` 1716→1488 satır. Katman seçici (`_showLayerPicker`) modal + StatefulBuilder ekranda kaldı (yaprak kart/çip görselleri çıkarıldı) (bkz. [[07-CI-CD]] "Widget testleri")
- **Birleşik arama** (`map_search_service.dart`): Nominatim (adres/metin) + Overpass (kategori) paralel, 500ms debounce, koordinat bazlı dedup
  - **Arama overlay'i** (`SmartResultsOverlay`): arama boşken başlık **"Son Aramalar"**, yazarken **"Arama Sonuçları"** (*2026-07-02* — eski "Önerilen Mekanlar" yanıltıcıydı; gösterilen içerik gerçek arama sonucudur). **Son aramalar statik değil** — kullanıcının gerçek geçmişi `SharedPreferences`'tan (`recentMapSearchesParsed`) yüklenir; bir sonuca dokununca `addRecentMapSearch` ile kaydedilir (maks. 5, dedup), boşsa "Henüz arama geçmişi yok". Başlıkta opsiyonel **"Temizle"** eylemi geçmişi siler (`clearRecentMapSearches` → prefs `remove`). Widget testli (`test/widget/smart_results_overlay_test.dart`).
  - **Sesli arama (*2026-07-02*):** Arama çubuğu **boşken** sağda mikrofon (`VoiceSearchButton`), **metin varken** × (temizle). Mikrofona dokununca cihazın **yerleşik OS konuşma tanıyıcısı** (`speech_to_text` → `VoiceSearchService`, `tr_TR`) dinler; tanınan metin arama kutusuna yazılır → mevcut arama akışı (`_onSearchChanged`) kendiliğinden tetiklenir. Dinlerken mikrofon **kırmızı + nabız**, "Dinleniyor…" göstergesi `Semantics(liveRegion)` ile ekran okuyucuya duyurulur. **Ücretsiz/anahtarsız** — API anahtarı/kota yok, $0 (bkz. [[09-Rate-Limiting]]). **Erişilebilirlik:** motor/görme engelli kullanıcı elle yazmadan arayabilir → ürünün varlık sebebiyle örtüşür; `Semantics` etiketli, widget testli (`test/widget/voice_search_button_test.dart`). Mikrofon izni/KVKK: [[08-Guvenlik]].
- **Rota / yol tarifi** (`route_screen.dart`): **OSRM** tabanlı (birincil `routing.openstreetmap.de` yaya+araç, yedek `router.project-osrm.org` yalnız araç); GeoJSON geometri, API düşerse düz-çizgi fallback. Mesafe/süre gösterimi, rota ters çevirme/paylaşma
- CallScreen (Agora), mekân ekleme/detay. **Çağrı kabulü** (`notification_service`): kanal adı yalnızca event'ten okunur (`validChannelName`, saf doğrulama → `lib/utils/channel_validator.dart`, birim testiyle korunur — bkz. [[07-CI-CD]]); geçersizse çağrı **kabul edilmez** — paylaşılan sabite fallback yok (yanlış görüşme önlenir, bkz. [[02-API-Arka-Uc]])
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
- [~] En büyük dosya `map_screen.dart` bölme (**2603 → 1458 satır, −%44**) — `lib/screens/map/` klasörü; çıkarılan saf sunum widget'ları artık widget testli (bkz. [[07-CI-CD]]):
  - **Aşama 1 ✅:** durumsuz görsel eşleyiciler + `mergePois` → `map_visuals.dart` (`MapVisuals`); tekrar eden iki renk fonksiyonu birleştirildi; POI paleti `AppColors`'a taşındı.
  - **Aşama 2 ✅:** OSM POI detay paneli → `osm_poi_sheet.dart` (`OsmPoiSheet`, `onClose` callback'i ile durumsuz); paylaşılan aksiyon butonu → `map_action_button.dart` (`MapActionButton`, venue + POI sheet ortak).
  - **Aşama 3 ✅:** DB mekan detay paneli + yorum kutucuğu → `venue_sheet.dart` (`VenueSheet`, `onClose` ile durumsuz).
  - **Aşama 4 ✅ (Slice 1):** saf sunum çipi/satırı → `map_filter_chip.dart` (`MapFilterChip`) *(2026-07-02'de kaldırıldı — arama çipleri harita filtreleme modalıyla tekrar ediyordu)*, `map_search_item.dart` (`MapSearchItem`); state mutasyonu thin wrapper'da.
  - **Aşama 5 ✅ (Slice 2):** bilinmeyen nokta sheet'i → `unknown_point_sheet.dart` (`UnknownPointSheet`); akıllı arama overlay'i → `smart_results_overlay.dart` (`SmartResultsOverlay`); `_buildSearchItem` wrapper'ı `_onSearchItemTapped`'e indi.
  - **Aşama 6 ✅ (Slice 3):** katman seçici yaprak görselleri → `map_type_card.dart` (`MapTypeCard`), `map_overlay_chip.dart` (`MapOverlayChip`); `_showLayerPicker` modal + StatefulBuilder ekranda kaldı.
  - **Aşama 7 ✅ (Slice 4 — kısmi):** Overpass **sorgu/bbox üreteçleri** saf dosyaya çıkarıldı → `lib/services/overpass_query_builder.dart` (`overpassBoundingBox`, `hikingOverpassQuery`, `accessibilityOverpassQuery`), birim testli (`test/unit/overpass_query_builder_test.dart`); tekrarlanan bbox kodu birleşti. **Bilinçli ekranda kalan:** HTTP çağrısı + JSON→UI (Polyline/Marker) eşlemesi + setState (`_fetchHikingLayer`/`_fetchOverpassLayer`/`_fetchPoisForVisibleArea`) — koruyucu test yok, UI-kuplajlı (bkz. [[10-Cache-CDN]] · debounce/cache).
- [x] **Inline renk temizliği (O2 — *2026-06-29*):** `lib/` genelindeki 27 inline `Color(0xFF...)` (map_screen 16, route_screen 4, settings_provider 3 HC, registration_complete 2, register 1, profile 1) `AppColors`'a taşındı — aynı hex korunarak (davranış değişmedi). Eklenen sabitler: harita katman/overlay paleti (`mapSteps`/`mapFootway`/`mapWheelchair`/`mapElevator`/`mapType*`/`mapTransit`/`mapCycling`), rota modu (`routeWalk`/`routeWheelchair`/`routeTransit`), `divider`/`success*`/`error`, yüksek kontrast (`hcYellow`/`hcNavy`). `flutter analyze` temiz, 62 test yeşil. Artık `lib/`'de `AppColors` dışında inline renk YOK (CLAUDE.md "Asla Yapma" #3 sağlandı).
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
