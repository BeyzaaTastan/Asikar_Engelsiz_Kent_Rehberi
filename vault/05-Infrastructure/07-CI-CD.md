---
katman: CI/CD
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[05-Barindirma]], [[06-Bulut]], [[08-Guvenlik]]
---

# 07 · CI/CD

## Neden önemli
CI/CD, "deploy ederken bir şeyi unutma/bozma" riskini otomatikleştirip ortadan kaldırır; özellikle Firestore kuralları yanlış deploy edilirse tüm veri açığa çıkabilir. Atlanırsa elle deploy hataları (yanlış proje, eksik kural, sızan `.env`) üretimde patlar.

## Karar (ne + NEDEN)
**MVP yaklaşımı: elle deploy + hafif otomasyon.** Tek geliştirici için tam pipeline lüks; ama sıfır otomasyon da risk. Orta yol:

**Şu an (MVP — manuel):**
- Firestore kuralları: `firebase deploy --only firestore:rules`
- Functions: `firebase deploy --only functions`
- Mobil build: `flutter build appbundle` / `flutter build apk`

**Hedef (düşük maliyetli otomasyon):**
- **GitHub Actions (ücretsiz public/2000 dk-ay private)** — push'ta `flutter analyze` + `flutter test` çalıştır. **Neden:** Bedava, repo zaten GitHub'da, en azından "derleniyor mu / lint geçiyor mu" güvencesi.
- **Codemagic (ücretsiz 500 dk-ay)** veya **Fastlane** — mobil build + mağaza yükleme için. Flutter'a özel, ücretsiz tier demo için yeter. **Neden Codemagic:** imzalama/mağaza yükleme adımlarını yönetmesi GitHub Actions'a göre Flutter'da daha az uğraştırır.

**Sır yönetimi:** `.env` ve keystore **asla repoya girmez**; CI'da GitHub Secrets / Codemagic environment olarak enjekte edilir (bkz. [[08-Guvenlik]]).

**Neden tam CI/CD MVP'de değil:** Tek kişi, düşük commit hacmi, manuel deploy 2 komut. Otomasyona harcanan saat şu an üründen çalınır; ekip büyüyünce tetiklenir.

## Test Kapsamı (kritik akış koruması)
Kritik mantık artık testle korunuyor. Kapsam üç fazda kuruluyor (*2026-06-28* başladı):

- ✅ **Faz 1 — Saf birim testleri** (cihazsız, `flutter test test/unit/`):
  - `validChannelName` (`lib/utils/channel_validator.dart`) → `test/unit/channel_validator_test.dart`: kanal adı doğrulaması, paylaşılan sabit fallback'i önleme (bkz. [[01-On-Yuz]], [[02-API-Arka-Uc]]).
  - `calculateAccessibilityScore` (`lib/services/accessibility_score.dart`) → `test/unit/accessibility_score_test.dart`: skor formülü sınır değerleri (min 5 / max 100, 70/30 ağırlık) (bkz. [[03-Veritabani]]).
  - `overpassBoundingBox` / `hikingOverpassQuery` / `accessibilityOverpassQuery` (`lib/services/overpass_query_builder.dart`) → `test/unit/overpass_query_builder_test.dart` (10 senaryo): bbox sıra/ondalık, sorgu blokları + aktif katmana göre koşullu üretim. Yanlış sorgu = bozuk erişilebilirlik katmanı (bkz. [[01-On-Yuz]], [[10-Cache-CDN]]).
  - `validateNewComment` (`lib/services/comment_validation.dart`) → `test/unit/comment_validation_test.dart` (6 senaryo, *O8*): yorum içeriği (≤1000) + yorum sayısı (≤500) üst sınırı → gömülü yorum 1MB belge sınırı tamponu (bkz. [[03-Veritabani]], [[11-Olcekleme]]).
  - `sortResultsByDistance` (`lib/services/map_search_service.dart`) → `test/unit/map_search_sort_test.dart` (4 senaryo, *2026-07-04*): arama sonuçlarının kullanıcı konumuna göre mesafe sıralaması (en yakın en üstte), `distanceMeters` eklenmesi, konum `null` iken sıranın/içeriğin korunması, boş liste güvenliği (bkz. [[01-On-Yuz]]).
  - `PoiCategory` / `categoriesForQuery` / `categoryFilters` (`lib/services/overpass_poi_service.dart`) → `test/unit/poi_category_search_test.dart` (12 senaryo, *2026-07-04*): tek kaynak kategori tablosundan arama eşleştirmesi (market→shop=supermarket+convenience, park, Türkçe ek "marketler", eşanlamlı "kahve", bilinmeyen/min-uzunluk boş), harita `onMap` türetmesi (Market=shop=supermarket, quickFilter kapsamı, onMap=false aranabilir ama katmanda yok) ve **token→Türkçe etiket invariant'ı** (isimsiz POI başlığı — bkz. [[01-On-Yuz]] · "Kategori araması genel çözüm").
  - `omtTilesForBounds` / `omtRawType` (`lib/services/omt_poi_parser.dart`) → `test/unit/omt_poi_parser_test.dart` (8 senaryo, *2026-07-05*): vektör karo (OpenMapTiles) POI ayrıştırmasının saf parçaları — kutu→tile kapsama (tek tile, zoom etkisi, maxTiles tavanı, negatif zoom), `class`/`subclass`→kategori eşlemesi (subclass doğrudan, class fallback, bilinmeyen→"other") ve **parite invariant'ı** (üretilen rawType `categoryToTurkish` ile geçerli başlık alır, bilinmeyen bile "Mekan"). MVT byte decode'u gerçek karo gerektirdiğinden ekranda kaldı (bkz. [[01-On-Yuz]] · "vektör POI etiketleri gizlendi", [[10-Cache-CDN]]).
  - *Not:* Bu saf mantıklar, test edilebilirlik için servis/ekran state'inden bağımsız saf dosyalara çıkarıldı (davranış birebir korundu). Overpass HTTP+parse→UI bilinçli ekranda kaldı.
- ✅ **Faz 2 — Emulator: `firestore.rules` testleri** (*2026-06-28*): `test/firestore-rules/cagrilar_rules.test.js` — 10 senaryo: `isCagriClaim` (ikinci gönüllü reddi = çağrı kapma yarışı), `isCagriTimeout` (yalnızca arayan), geri-geçiş + `delete` guard'ları → "çağrı kapma yarışı regresyon testi" açık maddesini kapatır (bkz. [[03-Veritabani]], [[08-Guvenlik]]). **Çalıştırma:** `bash tool/run_rules_tests.sh` (tek komut; `@firebase/rules-unit-testing` + mocha, demo proje). **JDK:** java PATH'te yoksa Android Studio JBR otomatik kullanılır.
- ✅ **Faz 3 — `addComment` skor/ortalama saf birim testi** (*2026-06-28*): `venueWithNewComment` (`lib/services/venue_aggregates.dart`) → `test/unit/venue_aggregates_test.dart` (6 senaryo): yorum eklenince `averageRating` + birleşik `features` + `accessibilityScore` doğru güncellenir; ardı ardına yorumlarda puan bozulmaz (transaction serileştirmesi); saflık (orijinal nesne değişmez). Mantık `addComment` transaction'ından bağımsız saf fonksiyona çıkarıldı (bkz. [[03-Veritabani]]).
- ✅ **Widget testleri** (cihazsız, `flutter test test/widget/`): `lib/screens/map/`'ten çıkarılan saf sunum widget'ları (monolit bölme — bkz. [[01-On-Yuz]]):
  - `MapActionButton` → `map_action_button_test.dart` (4 senaryo): ikon/etiket render, `onTap`, `onTap == null` güvenliği, **erişilebilirlik buton rolü + etiket (O10)**.
  - ~~`MapFilterChip` → `map_filter_chip_test.dart`~~ *(2026-07-02'de widget + testi kaldırıldı — arama çubuğu erişilebilirlik çipleri harita filtreleme modalıyla tekrar ediyordu; bkz. [[01-On-Yuz]])*.
  - `MapSearchItem` → `map_search_item_test.dart` (4 senaryo): başlık/alt başlık render, `isRecent` ikon farkı (history↔north_west), `onTap`.
  - `UnknownPointSheet` → `unknown_point_sheet_test.dart` (5 senaryo): adres/yükleniyor durumu, koordinat (point!=null), `onClose`, "Yol Tarifi".
  - `SmartResultsOverlay` → `smart_results_overlay_test.dart` (9 senaryo): başlık (Son Aramalar↔Arama Sonuçları), "Temizle" görünürlüğü + `onClearHistory`, boş geçmiş durumu, öğe listesi + `onItemTap`, yükleniyor spinner, **çok sonuçta tavana değip kaydırılabilirlik** ve **büyük `availableHeight`'te alanı doldurma** (*2026-07-04* gövde-yüksekliği tabanlı overlay — bkz. [[01-On-Yuz]]).
  - `MapTypeCard` → `map_type_card_test.dart` (3 senaryo): render, `selected` ikon rengi, `onTap`.
  - `MapOverlayChip` → `map_overlay_chip_test.dart` (3 senaryo): render, `isActive` ikon rengi, `onTap`.
  - `MapAttributionBadge` → `map_attribution_test.dart` (4 senaryo, *2026-07-04*): vektör taban aktifken OSM + **OpenMapTiles** atfı birlikte, OpenMapTiles varsayılan gizli (raster taban), Foursquare atfı eklenmesi, hiçbir kaynak yoksa rozet çizilmez. Lisans-kritik (OpenFreeMap Liberty vektör taban — bkz. [[01-On-Yuz]] · "Google tarzı görünüm", [[10-Cache-CDN]]).
  - *Not:* Varsayılan `widget_test.dart` tüm uygulamayı (`AsikarApp`) pump ediyordu; `AsikarApp` Firebase init + `settingsServiceProvider` override gerektirdiğinden birim/widget düzeyinde çalışamıyor ve **tüm `flutter test` suite'ini kırıyordu** → kaldırıldı, yerine Firebase'siz gerçek widget testi kondu. Tüm uygulama smoke/akış testi `integration_test/`'e ertelendi (aşağıda YOK).

> Tek komutla çalışır: `flutter test` (141 senaryo — birim + widget; 2026-07-02: −3 `MapFilterChip` widget testi, +2 `accessibilityOverpassQuery` parking birim testi; 2026-07-04: +4 `sortResultsByDistance`, +2 `SmartResultsOverlay` kaydırma/alan, +12 `poi_category_search`, +4 `MapAttributionBadge` OpenMapTiles atfı; 2026-07-05: +8 `omt_poi_parser` vektör karo POI ayrıştırma) ve `bash tool/run_rules_tests.sh` (10 senaryo — rules emulator) → sonradan CI'a sorunsuz bağlanır.

## MVP Kapsamı
**VAR:**
- Manuel deploy komutları (dokümante — bkz. proje README)
- **Saf birim + widget testleri** (`test/unit/` + `test/widget/`, 62 senaryo) — `flutter test` ile **tüm suite yeşil** (bkz. yukarıdaki Test Kapsamı)
- **Faz 2 Firestore rules emulator testleri** (`test/firestore-rules/`, 10 senaryo) — `bash tool/run_rules_tests.sh` ile çalışır
- (Önerilen) GitHub Actions ile lint + test on push

**YOK:**
- Otomatik mağaza yükleme (elle yapılır)
- Otomatik Firestore rules/functions deploy (elle, dikkatle)
- Çoklu ortam promosyonu (dev→staging→prod)
- Release versiyonlama otomasyonu / changelog
- **Tüm uygulama smoke/akış testi** (`integration_test/`, cihaz/emülatör + Firebase mock gerektirir) — ertelendi
- E2E test pipeline'ı

## Açık Sorular
- ~~Firestore kuralları için **emulator + test** CI'a eklenmeli mi?~~ **Test yazıldı** (`test/firestore-rules/`, Faz 2 ✅). Kalan: bu testi GitHub Actions'a bağlamak (emulator job) — CI maddesiyle birlikte ele alınacak.
- Keystore kaybı = Android güncellemesi imkânsız; CI dışında nerede yedekleniyor? → [[13-Recovery]]
- Tek geliştirici hastalanırsa/ayrılırsa deploy bilgisi (hesaplar, sırlar) nasıl devredilir?

## TODO
- [x] **Faz 1 — saf birim testleri** (`validChannelName`, `calculateAccessibilityScore`) — *2026-06-28* (bkz. Test Kapsamı)
- [ ] GitHub Actions: `flutter analyze` + `flutter test` workflow ekle (en ucuz kazanç)
- [x] **Faz 2** — Firestore rules için emulator testi yaz (10 senaryo, `bash tool/run_rules_tests.sh`) — *2026-06-28*; CI'a bağlama ayrı madde → [[03-Veritabani]], [[08-Guvenlik]]
- [x] **Faz 3** — `addComment` skor/ortalama saf birim testi (`venueWithNewComment`, 6 senaryo) — *2026-06-28* → [[03-Veritabani]]
- [ ] `.gitignore`'da `.env`, `*.keystore`, `functions/.env` olduğunu doğrula → [[08-Guvenlik]]
- [ ] Keystore ve sırların güvenli yedeğini al → [[13-Recovery]]

---

## İlgili Notlar
- [[Architecture-Overview]] — CI/CD katmanının önceliği (stub)
- [[01-On-Yuz]] — `validChannelName` testi (çağrı kabulü)
- [[02-API-Arka-Uc]] — çağrı/kanal akışı regresyon testi
- [[03-Veritabani]] — skor formülü + `isCagriClaim`/`isCagriTimeout` rules testi
- [[05-Barindirma]] — mağaza/web dağıtım hedefi
- [[06-Bulut]] — deploy edilen proje
- [[08-Guvenlik]] — sır/kural deploy güvenliği + rules emulator testi
- [[13-Recovery]] — keystore/sır yedeği
