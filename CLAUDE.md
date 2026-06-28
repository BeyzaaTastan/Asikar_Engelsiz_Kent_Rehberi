# CLAUDE.md

Bu dosya, bu repoda çalışan AI asistanları (Claude Code vb.) içindir. Kod yazmadan önce buradaki kurallara uy. Mimari kararların gerekçeleri ayrı bir Obsidian vault'tadır (bkz. **Mimari Bilgi Tabanı**).

---

## Proje

**Aşikar Engelsiz Kent Rehberi** — Sakarya'ya odaklı, engelli bireyleri gönüllülerle buluşturan Flutter + Firebase mobil erişilebilirlik uygulaması. Bitirme projesi, **düşük bütçe** (ücretsiz/düşük katmanlar hedefleniyor).

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
flutter test                  # testler
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
| Harita | flutter_map (OpenStreetMap) |
| POI | Foursquare Places v3 + OSM Overpass |
| Konum | geolocator ^14.0.2 |
| Yerel depo | shared_preferences ^2.3.5 |
| Env | flutter_dotenv ^5.2.1 |

---

## ⛔ Asla Yapma (sert kurallar)

1. **Agora App Certificate'ı ASLA Flutter tarafına koyma.** Token yalnızca `generateAgoraToken` Cloud Function'ında üretilir. Sertifika sadece `functions/.env`'de yaşar.
2. **`.env`, `functions/.env`, keystore dosyalarını repoya ekleme.** `.gitignore`'da olduklarını doğrula. Sırları koda gömme.
3. **Inline `Color(0xFF...)` yazma.** Her renk `AppColors` sınıfından (`lib/constants/app_colors.dart`).
4. **String literal route yazma.** Her route `AppRoutes` sabiti üzerinden (`lib/router/app_router.dart`).
5. **`users`, `cagrilar`, `venues` için silme kodu/kuralı ekleme.** Silme bilinçli olarak her koleksiyonda yasaktır.
6. **Loglara konum/kişisel veri yazma** (KVKK). Konum + engellilik durumu özel nitelikli veridir.

---

## ✅ Zorunlu Kalıplar (konvansiyonlar)

- **FCM arka plan handler** (`_firebaseMessagingBackgroundHandler`) sınıf dışında **top-level** fonksiyon olmalı ve `@pragma('vm:entry-point')` anotasyonu taşımalı (Firebase gereği).
- **`settingsServiceProvider`** `main()` içinde `SettingsService.create()` ile async oluşturulup `ProviderScope.overrides` ile inject edilir. Provider gövdesi `throw UnimplementedError` ile korunur.
- **Oku-değiştir-yaz** gereken her yerde (örn. yorum ekleme → ortalama puan + skor güncelleme) `runTransaction()` kullan. Yarış koşulunu önler. **Çağrı üstlenme de** transaction + `cagri_durumu == 'bekliyor'` ön koşulludur (`_claimCallAndNavigate`); ayrıca `firestore.rules` `isCagriClaim` ile kilitli.
- **CallKit listener tek kez** kurulur — `_listenerInitialized` static bool flag'i ile çift kurulumu engelle.
- **Çağrı kanalı (channel_name) için sabit fallback YAZMA.** Kanal yalnızca event/payload'dan okunur (`_validChannelName`); yok/boşsa çağrı gösterilmez/kabul edilmez. `'aktif_cagri'`/`'yardim_kanali'` gibi paylaşılan sabitler eşzamanlı çağrılarda yanlış görüşmeye yol açar (hem istemci hem `functions/index.js` bu kurala uyar).
- **Navigator hazır değilken** CallScreen yönlendirmesi: 300ms aralıkla 15 deneme retry; başarısızsa `pendingCallId` static alanına yaz, `MainWrapper.didChangeAppLifecycleState` yakalar.
- **Foursquare çağrıları** 800ms debounce + koordinat/kategori cache ile yapılır. Ücretsiz kotayı korumak için bunu bozma.
- **Kritik widget'larda `Semantics(label: ...)`** zorunlu (YARDIM İSTE, rota butonları, çağrı kontrolleri). Erişilebilirlik ürünün varlık sebebi.

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
│   ├── venue_service.dart        # CRUD + transaction'lı skor
│   ├── notification_service.dart # FCM + CallKit
│   └── agora_token_service.dart  # Cloud Function üzerinden güvenli token
├── screens/map_screen.dart   # en büyük dosya (~1716 satır) — hibrit POI + arama; widget'lara bölme sürüyor
└── screens/map/              # map_screen'den çıkarılan parçalar:
    ├── map_visuals.dart      #   MapVisuals: POI ikon/renk, wheelchair, mergePois (durumsuz)
    ├── map_action_button.dart#   MapActionButton: venue + POI sheet ortak aksiyon butonu
    ├── osm_poi_sheet.dart    #   OsmPoiSheet: harici POI detay paneli (onClose callback'li)
    └── venue_sheet.dart      #   VenueSheet: DB mekan detay paneli + yorum kutucuğu (onClose)
functions/index.js            # 3 Cloud Function (bildirim, token, zaman aşımı)
firestore.rules               # tek güvenlik sınırı
.env / functions/.env         # sırlar — repoda OLMAMALI
```

---

## Bilinen Açık Konular (kod yazarken farkında ol)

- **Çağrı kapma yarışı (ÇÖZÜLDÜ):** `volunteers` topic broadcast → birden çok gönüllü aynı çağrıyı görür. Cevaplama `NotificationService._claimCallAndNavigate` içinde `runTransaction` + `cagri_durumu == 'bekliyor'` ön koşuluyla, ayrıca `firestore.rules` `isCagriClaim` geçişiyle kilitli. **Kural değişikliği canlıya deploy edilmeli.** Kalan: emulator regresyon testi.
- **Çağrı zaman aşımı (ÇÖZÜLDÜ):** Arayan `CallScreen`'de 45sn gönüllü bulamazsa `zaman_asimi` + "gönüllü bulunamadı" ekranı; terk edilmiş çağrılar için `cagriZamanAsimiTemizle` scheduled function (90sn). Kural `isCagriTimeout` ile kilitli. **Functions + rules deploy edilmeli.**
- **App Check (ENFORCE AKTİF + DOĞRULANDI — 2026-06-28):** İstemci `main.dart`'ta aktif (debug→debug, release→Play Integrity/DeviceCheck); `generateAgoraToken` `APP_CHECK_ENFORCE=true` ile App Check token'ı olmayan istekleri reddediyor (deploy edildi). **Cloud Firestore Console'dan Enforce** + debug cihaz token'ı Console'a kayıtlı. Debug build'de çağrı testi geçti (sunucu log'u `app:VALID`, status 200 → token akışı bozulmadı). **Build ayrımı:** debug build çalışır (kayıtlı debug token), **release build Play Integrity kurulumu olmadan token alamaz**. Kalan: yalnızca release için Play Integrity (**Faz 5 — yayın öncesi**: nihai paket adı + Play Console bağlama + release SHA-256 + Console'da Play Integrity sağlayıcısı). Detay: `vault/06-Security/08-Guvenlik.md`.
- **iOS'ta "Sign in with Apple"** App Store şartı olabilir (Google Sign-In sunulduğu için).
- **KVKK ↔ silme yasağı çelişkisi:** "Verimi sil" talebi silme yasağıyla çatışır → anonimleştirme ile çözülmeli.

---

## Mimari Bilgi Tabanı

Her katmanın **neden** kararları, MVP kapsamı, açık sorular ve TODO'ları ayrı bir Obsidian vault'tadır (`00-Overview` + 13 katman notu). Bir mimari karar verirken/değiştirirken ilgili katman notuna bak ve gerekirse güncelle:

`01-On-Yuz · 02-API-Arka-Uc · 03-Veritabani · 04-Auth · 05-Barindirma · 06-Bulut · 07-CI-CD · 08-Guvenlik · 09-Rate-Limiting · 10-Cache-CDN · 11-Olcekleme · 12-Loglama · 13-Recovery`

---

## Dil

Uygulama arayüzü ve kullanıcıya dönük metinler **Türkçe**. Kod yorumları Türkçe/İngilizce karışık olabilir. Kullanıcı hata mesajları Türkçe ve anlaşılır olmalı (`AuthException` örneği gibi).
