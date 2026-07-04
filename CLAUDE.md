# CLAUDE.md

Bu dosya, bu repoda çalışan AI asistanları (Claude Code vb.) içindir. Kod yazmadan önce buradaki kurallara uy. Mimari kararların gerekçeleri ayrı bir Obsidian vault'tadır (bkz. **Mimari Bilgi Tabanı**).

---

## Proje

**Aşikar Engelsiz Kent Rehberi** — engelli bireyleri gönüllülerle buluşturan Flutter + Firebase mobil erişilebilirlik uygulaması. **Gerçek ürün / canlı production**: **Sakarya'da pilot** olarak sahaya çıkar, **Türkiye geneli** kullanıma açılır. Maliyet disiplini korunur — altyapıda kalıcı **$0/düşük katman** hedefi (bütçe kısıtı değil, bilinçli tercih).

- Engelli birey → tek tuşla gönüllüye **görüntülü** bağlanır (Agora + FCM).
- Gönüllü → çağrıyı push ile alır, görüntülü destek verir.
- Sakin/Turist → erişilebilirlik skorlu mekânları keşfeder, yorum yapar.

Paket: `asikar_engelsiz_kent_rehberi` · Versiyon: `1.0.0+1` · Hedef: Android + iOS (web ikincil).

---

## Komutlar

```bash
# Flutter
flutter pub get               # bağımlılıklar
flutter run                   # debug çalıştır
flutter analyze               # lint — COMMIT/PR öncesi ZORUNLU
flutter test                  # birim + widget testleri (test/unit, test/widget)
bash tool/run_rules_tests.sh  # firestore.rules emulator testleri (claim/timeout regresyonu)
flutter build appbundle       # Android yayın (Play Store)
flutter build apk             # Android APK
flutter build ios             # iOS

# Firebase (npx ile, global kurulum gerekmez)
npx firebase-tools use asikar-engelsiz-kent-rehberi
npx firebase-tools deploy --only firestore:rules        # kural deploy — DİKKATLİ
npx firebase-tools deploy --only functions              # Cloud Functions
npx firebase-tools functions:log                        # canlı log

# FlutterFire (sadece gerekirse)
flutterfire configure --project=asikar-engelsiz-kent-rehberi
```

> Değişiklik sonrası daima `flutter analyze` çalıştır. Firestore kuralı deploy'u veri güvenliğini doğrudan etkiler — emin olmadan deploy etme.

---

## Teknoloji Yığını

| Alan | Teknoloji |
|---|---|
| Mobil | Flutter (Dart ^3.9.2) |
| State | flutter_riverpod ^2.5.1 |
| Auth | Firebase Authentication (e-posta + Google) |
| Uygulama doğrulama | Firebase App Check ^0.4.5 (Play Integrity / DeviceCheck) |
| Veri | Cloud Firestore (realtime) |
| Push | Firebase Cloud Messaging (FCM) |
| Gözlemlenebilirlik | Firebase Crashlytics + Analytics (KVKK: anonim event, debug'da kapalı) — `lib/services/analytics_service.dart` |
| Backend | Firebase Cloud Functions (Node.js), bölge `europe-west3` |
| Görüntülü | agora_rtc_engine ^6.5.4 |
| Gelen çağrı UI | flutter_callkit_incoming ^3.0.0 |
| Harita | flutter_map + vector_map_tiles (varsayılan mod: OpenFreeMap Liberty VEKTÖR karo — Google'a yakın palet, ücretsiz/anahtarsız; uydu/arazi raster) |
| POI | Foursquare Places v3 + OSM Overpass |
| Konum | geolocator ^14.0.2 |
| Sesli arama | speech_to_text ^7.4.0 (cihaz OS tanıyıcısı — ücretsiz/anahtarsız, harita aramasında) |
| Sesli yönerge | flutter_tts ^4.2.3 (cihaz OS TTS'i — ücretsiz/anahtarsız; sesli arama panelinde yönergeyi seslendirir) |
| Yerel depo | shared_preferences ^2.3.5 |
| Env | flutter_dotenv ^5.2.1 |

---

## ⛔ Asla Yapma (sert kurallar)

1. **Agora App Certificate'ı ASLA Flutter tarafına koyma.** Token yalnızca `generateAgoraToken` Cloud Function'ında üretilir. Sertifika sadece `functions/.env`'de yaşar.
2. **`.env`, `functions/.env`, keystore dosyalarını repoya ekleme.** `.gitignore`'da olduklarını doğrula. Sırları koda gömme.
3. **Inline `Color(0xFF...)` yazma.** Her renk `AppColors` sınıfından (`lib/constants/app_colors.dart`).
4. **String literal route yazma.** Her route `AppRoutes` sabiti üzerinden (`lib/router/app_router.dart`); gezinme `Navigator.pushNamed` ailesiyle yapılır (2026-06-29 O3'te tüm ekranlar buna taşındı). **Tek bilinçli istisna:** CallScreen — `navigatorKey` + retry + `pendingCallId` ile `MaterialPageRoute` üzerinden push edilir (aşağıdaki Navigator-retry kalıbı); bunu `AppRoutes`'a çevirme, kritik çağrı akışını bozar.
5. **`users`, `cagrilar`, `venues` için silme kodu/kuralı ekleme.** Silme bilinçli olarak her koleksiyonda yasaktır.
6. **Loglara konum/kişisel veri yazma** (KVKK). Konum + engellilik durumu özel nitelikli veridir.

---

## ✅ Zorunlu Kalıplar (konvansiyonlar)

- **FCM arka plan handler** (`_firebaseMessagingBackgroundHandler`) sınıf dışında **top-level** fonksiyon olmalı ve `@pragma('vm:entry-point')` anotasyonu taşımalı (Firebase gereği).
- **`settingsServiceProvider`** `main()` içinde `SettingsService.create()` ile async oluşturulup `ProviderScope.overrides` ile inject edilir. Provider gövdesi `throw UnimplementedError` ile korunur.
- **Oku-değiştir-yaz** gereken her yerde (örn. yorum ekleme → ortalama puan + skor güncelleme) `runTransaction()` kullan. Yarış koşulunu önler. **Çağrı üstlenme de** transaction + `cagri_durumu == 'bekliyor'` ön koşulludur (`_claimCallAndNavigate`); ayrıca `firestore.rules` `isCagriClaim` ile kilitli.
- **CallKit listener tek kez** kurulur — `_listenerInitialized` static bool flag'i ile çift kurulumu engelle.
- **Çağrı tipine göre FCM yönlendirmesi (2026-07-02).** Çağrı `cagri_tipi ∈ {'fiziksel','uzaktan'}` taşır (`lib/constants/call_types.dart` → `CagriTipi`; string literal yazma). **`fiziksel`** (yerinde yardım/şehir rehberliği) yalnızca `volunteers_<sehir>` topic'ine, **`uzaktan`** (görüntülü) global `volunteers`'a gider. `sehir` = arayanın **anlık GPS** konumundan çözülen slug (`lib/utils/city_slug.dart` · `citySlug`, saf/testli → `test/unit/city_slug_test.dart`; reverse-geocode `lib/services/city_lookup_service.dart`). İstemcinin iki tarafı (arayan `disabled_home` + gönüllü aboneliği `notification_service.subscribeToVolunteers` iki topic'e abone) AYNI slug'ı üretmeli; `functions/index.js` + `firestore.rules` `isValidNewCagri` aynı slug regex'iyle (`^[a-z0-9_-]+$`) doğrular. Fiziksel ama `sehir` yok/geçersizse global'e düş (çağrı kaybolmasın). Bu kuralı bozma: slug helper'ını çatallamak (iki taraf farklı slug → çağrı ulaşmaz) veya fiziksel çağrıyı global broadcast'e çevirmek (ulusal ölçekte maliyet + yanlış eşleştirme). ⚠️ Değişiklikte functions + rules deploy edilmeli.
- **Çağrı kanalı (channel_name) için sabit fallback YAZMA.** Kanal yalnızca event/payload'dan okunur (`validChannelName`, saf/test edilebilir → `lib/utils/channel_validator.dart`, birim testi `test/unit/channel_validator_test.dart`); yok/boşsa çağrı gösterilmez/kabul edilmez. `'aktif_cagri'`/`'yardim_kanali'` gibi paylaşılan sabitler eşzamanlı çağrılarda yanlış görüşmeye yol açar (hem istemci hem `functions/index.js` bu kurala uyar).
- **Navigator hazır değilken** CallScreen yönlendirmesi: 300ms aralıkla 15 deneme retry; başarısızsa `pendingCallId` static alanına yaz, `MainWrapper.didChangeAppLifecycleState` yakalar.
- **Foursquare çağrıları** 800ms debounce + koordinat/kategori cache ile yapılır. Ücretsiz kotayı korumak için bunu bozma.
- **Harita POI marker'ları Google tarzı kademeli** (declutter). POI'ler `_MapScreenState._poiFetchMinZoom = 15` altında çekilmez/çizilmez (şehir ölçeğinde boş harita, kota korunur). Üstünde, hangi POI'nin isim/nokta/gizli olacağına **declutter** karar verir: `map/poi_declutter.dart` (`declutterPois`, saf/testli) ekran-uzayında öncelik (`map/poi_priority.dart` · `poiPriority`, saf/testli) sırasına göre açgözlü yerleştirir — çakışmayan öncelikli POI `PoiMarker` (ikon+isim), çakışan `PoiDot` (nokta), sığmayan gizli. Kademeli görünürlük **zoom eşikleriyle**: `poiLabelMinZoom`/`poiDotMinZoom` her önceliğe isim/nokta için ayrı en-düşük-zoom verir (yüksek öncelik uzaktan isimle, düşük öncelik yalnız en yakında; yüksek önceliğin nokta aşaması yok). Eşikleri düşürüp tüm POI'leri erken/hepsini isimle gösterme — haritayı örter. `map_screen._buildPoiMarkers` `camera.latLngToScreenOffset` ile projekte edip çizer; relayout `MapEventMoveEnd`'de. **Bu davranışı bozma:** tüm POI'leri her zoom'da/hepsini isimle çizme (haritayı örter), declutter'ı atlama, `_fetchPoisForVisibleArea` debounce/cache mantığını değiştirme. Marker/nokta `Semantics(button, excludeSemantics)` + `AppColors`, widget testli. Venue (Firestore) marker'ları bilinçli olarak declutter dışında her zoom'da görünür. (Marker kümeleme denendi, elendi.)
- **Varsayılan harita tabanı = OpenFreeMap Liberty VEKTÖR karo** (`vector_map_tiles`, Google'a yakın palet, $0/anahtarsız). Stil `initState`'te `_loadVectorStyle` → `StyleReader(uri: _libertyStyleUrl).read()` ile **async** yüklenir (`_vectorStyle`); yüklenene/yüklenemezse **CartoDB Voyager raster fallback** çizilir (`_vectorStyle == null` → `TileLayer`). **Vektör karonun kendi `poi` etiket katmanı GİZLENİR** (stil JSON'ından `source-layer=='poi'` çıkarılıp `vtr.ThemeReader` ile tema yeniden kurulur → `_vectorTheme`); o mekanlar bunun yerine **kendi tıklanabilir POI katmanımızda** gösterilir (`OmtPoiService`, aşağıdaki kalıp). **Bunu bozma:** (1) fallback'i kaldırma (stil gelene kadar harita boş kalır); (2) Uydu/Arazi modlarını vektöre çevirme (bilinçli raster); (3) Google'ın kendi karolarını (`mt*.google.com`) ekleme — ToS ihlali, canlı production'da yasak; (4) vektör taban aktifken **`showOpenMapTiles`** atfını kaldırma (OpenMapTiles lisans şartı); (5) `poi` katmanı gizlemeyi geri açma (vektör etiketler tıklanamaz + POI pin'leriyle çakışır). Sürüm kilidi bilinçli: `vector_map_tiles 9.0.0-beta.8` (flutter_map 8.x uyumlu, `flutter_gpu` bağımlılığı YOK — 10.x'e yükseltme Impeller gerektirir); `vector_tile`/`vector_tile_renderer` transitive→direct (MVT decode + tema filtresi). Gerekçe: [[01-On-Yuz]] · "Google tarzı görünüm", [[10-Cache-CDN]].
- **Harita POI'leri 4 kaynaktan birleşir** (`_fetchPoisForVisibleArea` → `MapVisuals.mergePois`): canlı Foursquare (en güncel, öncelik) + FSQ taban (Türkiye geneli, `fsq_os`) + Overpass (OSM) + **OMT** (`OmtPoiService` — vektör karonun `poi` feature'ları, `osmType='omt'`). OMT, vektör karoda görünüp de diğer kaynaklarda olmayan mekanları TIKLANABILIR yapar (kullanıcının gördüğü her yer detay paneli açar). Aynı OpenMapTiles karolarını `VectorTileProvider.provide` ile çeker (harita ile aynı kaynak), `compute` ile arka planda MVT decode eder, tile başına cache tutar. Saf/testli: `omtTilesForBounds`/`omtRawType` (`omt_poi_parser.dart` → `test/unit/omt_poi_parser_test.dart`). **Bozma:** OMT'yi öncelikli merge etme (gap-filler'dır; Overpass/FSQ daha zengin veri taşır), isimsiz feature filtresini kaldırma (gürültü), debounce/tile-cache mantığını değiştirme (bkz. [[10-Cache-CDN]], [[01-On-Yuz]]).
- **Kritik widget'larda `Semantics(label: ...)`** zorunlu (YARDIM İSTE, rota butonları, çağrı kontrolleri). Erişilebilirlik ürünün varlık sebebi.
- **Foursquare verisi gösterilen her yüzeyde görünür atıf zorunlu** (Places API lisans şartı). "Powered by Foursquare" markalı atıf, FSQ POI'lerin göründüğü her yerde bulunmalı: harita köşe rozeti + POI detay paneli. Tüm atıf metni/widget'ı **tek kaynaktan**: `lib/screens/map/map_attribution.dart` (`kFoursquareAttribution` / `kOsmAttribution` / `kOpenMapTilesAttribution` sabitleri, `MapAttributionBadge`, `SheetAttributionLine`). Kaynak ayrımı `OsmPoi.isFoursquare` ile (`foursquare` = canlı API v3, `fsq_os` = OS Places). OSM/Overpass verisi **ayrı** ODbL şartı ("© OpenStreetMap katkıda bulunanlar") — ikisini karıştırma; her kaynağın atıfını doğru yere koy. Varsayılan **vektör taban** (OpenFreeMap Liberty) aktifken "© OpenMapTiles" atfı OSM'in yanında zorunlu (`showOpenMapTiles`). Uydu (Esri) karolarında OSM atfını gösterme (yanlış beyan). Atıf her zaman görünür/okunur olmalı, marker kalabalığına gömme. `AppColors` + `Semantics` zorunlu. Foursquare OS Places (Apache 2.0) NOTICE'ı ayrıca `cloudflare/poi-worker/README.md`'de korunur.

---

## Mimari (özet)

Serverless + BaaS. Kendi sunucumuz yok. Client çoğunlukla doğrudan Firestore'a yazar; **tek güvenlik sınırı Firestore kurallarıdır** (`firestore.rules`). Backend 3 fonksiyon (2 çekirdek + 1 scheduled):

1. `cagriBildirimiGonder` (Firestore `onWrite` trigger) → `cagri_durumu == 'bekliyor'` olunca FCM `volunteers` topic'ine push.
2. `generateAgoraToken` (HTTPS Callable) → `context.auth` kontrolü + 1 saatlik Agora token.
3. `cagriZamanAsimiTemizle` (scheduled, her dk) → terk edilmiş `bekliyor` çağrıları (>90sn) `zaman_asimi` yapar.

**Çağrı durum makinesi:** `bekliyor → cevaplandi → bitti`; `bekliyor → zaman_asimi` (gönüllü yok). `bitti`/`zaman_asimi` terminal, geri dönüş yok. Firestore'da realtime dinlenir; geçişler `firestore.rules` durum makinesiyle kilitli.

**Kullanıcı tipi yönlendirmesi** (`MainWrapper`): auth yoksa Login → `users/{uid}` yoksa kayıt anketi → `isVolunteer` ise VolunteerHome → `Özel Gereksinimli` ise DisabledHome → diğer StandardHome.

---

## Önemli Dosyalar

```
lib/
├── main.dart                 # giriş: dotenv → Firebase → AppCheck → Settings → Notifications → runApp
├── main_wrapper.dart         # auth + kullanıcı tipi yönlendirmesi (2 iç içe StreamBuilder)
├── constants/app_colors.dart # TÜM renkler buradan
├── router/app_router.dart    # AppRoutes + AppRouter (merkezi route)
├── services/
│   ├── auth_service.dart
│   ├── venue_service.dart        # CRUD + transaction'lı skor (venue_aggregates kullanır)
│   ├── notification_service.dart # FCM + CallKit (channel_validator kullanır)
│   ├── agora_token_service.dart  # Cloud Function üzerinden güvenli token
│   ├── accessibility_score.dart  # SAF/birim testli: erişilebilirlik skoru formülü
│   ├── venue_aggregates.dart     # SAF/birim testli: yorum→ortalama+skor yeniden hesaplama
│   ├── overpass_query_builder.dart # SAF/birim testli: Overpass bbox + QL sorgu üretimi
│   ├── omt_poi_service.dart      # OpenMapTiles vektör karo poi feature'ları → tıklanabilir OsmPoi (4. kaynak)
│   ├── omt_poi_parser.dart       # SAF/birim testli: kutu→tile + class/subclass→kategori (MVT ayrıştırma)
│   └── city_lookup_service.dart  # Nominatim reverse-geocode → şehir; çağrı yönlendirmesi (anlık GPS)
├── constants/call_types.dart     # CagriTipi (fiziksel/uzaktan) — çağrı yönlendirme sabitleri
├── utils/channel_validator.dart  # SAF/birim testli: Agora kanal adı doğrulaması
├── utils/city_slug.dart          # SAF/birim testli: şehir → FCM topic-güvenli slug (volunteers_<sehir>)
├── screens/map_screen.dart   # en büyük dosya (~1800 satır) — hibrit POI + arama; widget'lara bölme sürüyor
└── screens/map/              # map_screen'den çıkarılan parçalar (saf sunum widget'ları widget testli):
    ├── map_visuals.dart      #   MapVisuals: POI ikon/renk, wheelchair, mergePois (durumsuz)
    ├── map_action_button.dart#   MapActionButton: venue + POI sheet ortak aksiyon butonu
    ├── osm_poi_sheet.dart    #   OsmPoiSheet: harici POI detay paneli (onClose callback'li)
    ├── venue_sheet.dart      #   VenueSheet: DB mekan detay paneli + yorum kutucuğu (onClose)
    ├── map_search_item.dart  #   MapSearchItem: arama sonuç/son arama satırı
    ├── unknown_point_sheet.dart  # UnknownPointSheet: bilinmeyen nokta sheet'i (onClose/onDirections)
    ├── smart_results_overlay.dart# SmartResultsOverlay: arama sonuç cam paneli (items/onItemTap)
    ├── map_type_card.dart    #   MapTypeCard: katman seçici harita türü kartı (selected/onTap)
    ├── map_overlay_chip.dart #   MapOverlayChip: katman seçici ayrıntı çipi (isActive/onTap)
    ├── poi_marker.dart       #   PoiMarker (ikon+isim) + PoiDot (nokta önizleme), Semantics'li
    ├── poi_priority.dart     #   SAF/testli: kategori → önem ağırlığı (declutter sırası)
    └── poi_declutter.dart    #   SAF/testli: Google tarzı açgözlü etiket yerleşimi (label/dot/hidden)
functions/index.js            # 3 Cloud Function (bildirim, token, zaman aşımı)
firestore.rules               # tek güvenlik sınırı
.env / functions/.env         # sırlar — repoda OLMAMALI
```

---

## Bilinen Açık Konular (kod yazarken farkında ol)

- **Çağrı kapma yarışı (ÇÖZÜLDÜ + TEST ALTINDA — 2026-06-28):** `volunteers` topic broadcast → birden çok gönüllü aynı çağrıyı görür. Cevaplama `NotificationService._claimCallAndNavigate` içinde `runTransaction` + `cagri_durumu == 'bekliyor'` ön koşuluyla, ayrıca `firestore.rules` `isCagriClaim` geçişiyle kilitli. **Kural değişikliği canlıya deploy edilmeli.** Emulator regresyon testi eklendi: `test/firestore-rules/cagrilar_rules.test.js` (ikinci gönüllü reddi dahil 10 senaryo); `bash tool/run_rules_tests.sh` ile çalışır.
- **Çağrı zaman aşımı (ÇÖZÜLDÜ + TEST ALTINDA — 2026-06-28):** Arayan `CallScreen`'de 45sn gönüllü bulamazsa `zaman_asimi` + "gönüllü bulunamadı" ekranı; terk edilmiş çağrılar için `cagriZamanAsimiTemizle` scheduled function (90sn). Kural `isCagriTimeout` ile kilitli; `test/firestore-rules/cagrilar_rules.test.js` ile regresyon altında. **Functions + rules deploy edilmeli.**
- **App Check (ENFORCE AKTİF + DOĞRULANDI — 2026-06-28):** İstemci `main.dart`'ta aktif (debug→debug, release→Play Integrity/DeviceCheck); `generateAgoraToken` `APP_CHECK_ENFORCE=true` ile App Check token'ı olmayan istekleri reddediyor (deploy edildi). **Cloud Firestore Console'dan Enforce** + debug cihaz token'ı Console'a kayıtlı. Debug build'de çağrı testi geçti (sunucu log'u `app:VALID`, status 200 → token akışı bozulmadı). **Build ayrımı:** debug build çalışır (kayıtlı debug token), **release build Play Integrity kurulumu olmadan token alamaz**. Kalan: yalnızca release için Play Integrity (**Faz 5 — yayın öncesi**: nihai paket adı + Play Console bağlama + release SHA-256 + Console'da Play Integrity sağlayıcısı). Detay: `vault/06-Security/08-Guvenlik.md`.
- **Agora token katılımcı kapısı (ÇÖZÜLDÜ kodda — 2026-06-29, K1):** `generateAgoraToken` artık token üretmeden önce `cagrilar/{channelName}` belgesini okuyup yalnızca katılımcıya (`caller_uid`/`volunteer_uid`) ve aktif çağrıya (`bekliyor|cevaplandi`) token veriyor (`functions/index.js`). Öncesinde auth+AppCheck'li herhangi biri kanal adıyla 3. taraf olarak görüşmeye girebiliyordu (mahremiyet açığı). ⚠️ **Canlıya deploy edilmeli** (`firebase deploy --only functions`). Detay: `vault/06-Security/08-Guvenlik.md`.
- **Release imzalama + paket adı (KISMİ — 2026-06-29, K2):** `android/app/build.gradle.kts` artık `key.properties` deseniyle gerçek release anahtarını okuyor; yoksa debug'a düşüyor (`signingReport` ile doğrulandı, şablon `android/key.properties.example`). **Kalan ops (yayın engelleyici):** keystore üret + 2 güvenli yere yedekle (geri alınamaz), `applicationId`'yi `com.example.*`'tan gerçek paket adına çevir + Firebase/Play Console'da yeniden kaydet (google-services.json eşleşmeli) + SHA-256'yı Play Integrity'ye ekle. Detay: `vault/05-Barindirma.md`, `vault/13-Recovery.md`.
- **POI taban katmanı — Türkiye geneli (CANLI / DEPLOY EDİLDİ — 2026-07-01, O12):** Proje tek şehir → Türkiye geneli + canlı production + kalıcı $0'a taşındı. Google Places lisans+maliyet nedeniyle elendi. Taban POI (**2.157.296**, **12.572 z12 tile**): Foursquare Open Source Places (Apache 2.0, ungated ayna `do-me/foursquare_places_100M`) → DuckDB süzme + sıralı ND-JSON + `split_tiles.mjs` (`tools/poi_pipeline/`) → **Cloudflare R2** (rclone yükleme) + Worker `/pois?bbox=` (`cloudflare/poi-worker/`, **canlı:** `asikar-poi-worker.asikar.workers.dev`) → Flutter `lib/services/fsq_poi_service.dart`, `_mergePois`'e 3. kaynak. `.env` `POI_API_BASE_URL` **dolu** (canlı URL). **D1 değil R2:** 2.16M satır D1 ücretsiz yazma kotasına (100k/gün) sığmıyor; R2 egress $0 + satır limiti yok. Tile zoom (12) Worker `Z` sabiti ile pipeline'da aynı olmalı. **Kalan (ops):** aylık tazeleme (FSQ güncellenince pipeline+rclone tekrar) — opsiyonel GitHub Actions cron. Runbook: `cloudflare/poi-worker/README.md`. Detay: `vault/03-Veritabani.md` · "POI taban katmanı".
- **iOS'ta "Sign in with Apple"** App Store şartı olabilir (Google Sign-In sunulduğu için).
- **KVKK ↔ silme yasağı çelişkisi:** "Verimi sil" talebi silme yasağıyla çatışır → anonimleştirme ile çözülmeli.

---

## Mimari Bilgi Tabanı

Her katmanın **neden** kararları, MVP kapsamı, açık sorular ve TODO'ları ayrı bir Obsidian vault'tadır (`00-Overview` + 13 katman notu). Bir mimari karar verirken/değiştirirken ilgili katman notuna bak ve gerekirse güncelle:

`01-On-Yuz · 02-API-Arka-Uc · 03-Veritabani · 04-Auth · 05-Barindirma · 06-Bulut · 07-CI-CD · 08-Guvenlik · 09-Rate-Limiting · 10-Cache-CDN · 11-Olcekleme · 12-Loglama · 13-Recovery`

---

## Dil

Uygulama arayüzü ve kullanıcıya dönük metinler **Türkçe**. Kod yorumları Türkçe/İngilizce karışık olabilir. Kullanıcı hata mesajları Türkçe ve anlaşılır olmalı (`AuthException` örneği gibi).
