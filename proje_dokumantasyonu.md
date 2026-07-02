# Aşikar Engelsiz Kent Rehberi — Proje Dokümantasyonu

> Bu doküman, projeyi hiç görmemiş bir yapay zeka asistanının ya da geliştiricinin projeyi sıfırdan anlayıp çalışabilmesi için hazırlanmıştır. Hiçbir detay atlanmamıştır.

---

## 1. Projenin Amacı

**Aşikar Engelsiz Kent Rehberi**, Sakarya iline odaklanmış, engelli bireyleri ve gönüllüleri birbirine bağlayan bir mobil erişilebilirlik uygulamasıdır.

Temel işlevler:
- **Özel Gereksinimli / Engelli bireyler** → Tek tuşla gönüllüyle görüntülü bağlanır, erişilebilir mekan bilgisi alır, haritada yol tarifi kullanır.
- **Gönüllüler** → Çağrıları FCM push bildirimi ile alır, görüntülü destek verir, mekan puanlar.
- **Turistler ve Şehir Sakinleri** → Sakarya'daki mekanları erişilebilirlik skoruna göre inceler, yorum yapar.

---

## 2. Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| Mobil Framework | Flutter (Dart), SDK ^3.9.2 |
| Backend / Auth | Firebase Authentication |
| Uygulama doğrulama | Firebase App Check (firebase_app_check: ^0.4.5) |
| Veritabanı | Cloud Firestore |
| Push Bildirim | Firebase Cloud Messaging (FCM) |
| Sunucu Fonksiyonları | Firebase Cloud Functions (Node.js) |
| Görüntülü Görüşme | Agora RTC Engine (agora_rtc_engine: ^6.5.4) |
| Gelen Çağrı UI | flutter_callkit_incoming: ^3.0.0 |
| Harita | flutter_map (OpenStreetMap tabanlı) |
| POI Servisi | Foursquare Places API v3 + OpenStreetMap Overpass API |
| Konum | geolocator: ^14.0.2 |
| State Yönetimi | flutter_riverpod: ^2.5.1 |
| Gözlemlenebilirlik | Firebase Crashlytics ^5.2.4 + Analytics ^12.4.3 |
| Yerel Depolama | shared_preferences: ^2.3.5 |
| Env Yönetimi | flutter_dotenv: ^5.2.1 |
| Google Giriş | google_sign_in: ^7.2.0 |

---

## 3. Firebase Projesi

- **Proje ID:** `asikar-engelsiz-kent-rehberi`
- **Android App ID:** `1:289977435785:android:f285be47206d9849b0e858`
- **iOS App ID:** `1:289977435785:ios:42f47e213f95309ab0e858`
- **Cloud Functions bölgesi:** `europe-west3` (Frankfurt)
- Yapılandırma dosyası: `lib/firebase_options.dart` (FlutterFire CLI tarafından oluşturulmuş)

---

## 4. Ortam Değişkenleri (.env)

Projenin kökündeki `.env` dosyası Flutter tarafından asset olarak yüklenir (`flutter_dotenv`).

```
AGORA_APP_ID=4d554a93e1d2470590e61e8dc91c0bd3
FOURSQUARE_API_KEY=1RN0DZY41NGVKI3JQJ41250CEKSEIOIB3URQ4DLI2YZROYQL
```

`functions/.env` dosyası Cloud Functions'a özeldir (sunucu tarafı):
```
AGORA_APP_ID=...
AGORA_APP_CERTIFICATE=...
APP_CHECK_ENFORCE=false   # App Check zorlaması; Console kurulumu sonrası 'true' yapılır
```

> **ÖNEMLİ:** Agora App Certificate **asla** Flutter tarafında tutulmaz. Yalnızca Cloud Functions `.env` dosyasında yer alır.

---

## 5. Klasör Yapısı

```
asikar_engelsiz_kent_rehberi/
├── lib/
│   ├── main.dart                     # Uygulama giriş noktası
│   ├── main_wrapper.dart             # Auth + kullanıcı tipi yönlendirmesi
│   ├── main_layout.dart              # Alt navigasyon çubuğu + sayfa iskeleti
│   ├── firebase_options.dart         # Firebase platform yapılandırması (CLI çıktısı)
│   │
│   ├── constants/
│   │   └── app_colors.dart           # Tüm renk sabitleri (merkezi)
│   │
│   ├── models/
│   │   ├── user_model.dart           # Kullanıcı veri modeli
│   │   ├── venue_model.dart          # Mekan + CommentModel veri modeli
│   │   └── osm_poi_model.dart        # OpenStreetMap / Foursquare POI modeli
│   │
│   ├── providers/
│   │   ├── settings_provider.dart    # Erişilebilirlik ayarları (Riverpod StateNotifier)
│   │   ├── osm_poi_providers.dart    # POI Riverpod provider
│   │   └── venue_providers.dart      # Venue Riverpod provider
│   │
│   ├── router/
│   │   └── app_router.dart           # Merkezi route yönetimi (AppRoutes + AppRouter)
│   │
│   ├── services/
│   │   ├── auth_service.dart         # E-posta + Google kimlik doğrulama
│   │   ├── database_service.dart     # Kullanıcı anket verisini Firestore'a kaydetme
│   │   ├── venue_service.dart        # Mekan CRUD + puan hesaplama
│   │   ├── notification_service.dart # FCM + CallKit push yönetimi
│   │   ├── agora_token_service.dart  # Cloud Function üzerinden güvenli Agora token alma
│   │   ├── foursquare_places_service.dart  # Foursquare Places API v3 istemcisi
│   │   ├── overpass_poi_service.dart # OpenStreetMap Overpass API istemcisi
│   │   ├── map_search_service.dart   # Birleşik arama (Nominatim + Overpass)
│   │   ├── analytics_service.dart    # Crashlytics (çökme/hata) + Analytics (çağrı funnel)
│   │   └── settings_service.dart    # SharedPreferences erişilebilirlik ayarları
│   │
│   ├── screens/
│   │   ├── splash_screen.dart        # Başlangıç ekranı
│   │   ├── login_screen.dart         # Giriş (e-posta + Google)
│   │   ├── register_screen.dart      # Kayıt ol
│   │   ├── user_type_screen.dart     # Kullanıcı tipi seçimi
│   │   ├── interests_screen.dart     # İlgi alanı seçimi
│   │   ├── accessibility_prefs_screen.dart  # Erişilebilirlik tercihleri
│   │   ├── volunteer_status_screen.dart     # Gönüllü olmak istiyor mu?
│   │   ├── volunteer_skills_screen.dart     # Gönüllü becerileri seçimi
│   │   ├── registration_complete_screen.dart # Kayıt tamamlama
│   │   ├── map_screen.dart           # Harita ekranı (~1716 satır; widget'lara bölünüyor)
│   │   ├── community_screen.dart     # Topluluk = mekan keşfi (filtreli)
│   │   ├── route_screen.dart         # Yol tarifi ekranı (OSRM)
│   │   ├── call_screen.dart          # Agora görüntülü görüşme + zaman aşımı ekranı
│   │   ├── profile_screen.dart       # Profil ekranı
│   │   ├── volunteer_tracking_screen.dart   # Gönüllü takip ekranı
│   │   │
│   │   ├── map/                      # map_screen'den çıkarılan parçalar (modülerleştirme)
│   │   │   ├── map_visuals.dart      # MapVisuals: POI ikon/renk, wheelchair, mergePois (durumsuz)
│   │   │   ├── map_action_button.dart # MapActionButton: sheet ortak aksiyon butonu
│   │   │   ├── osm_poi_sheet.dart    # OsmPoiSheet: harici POI detay paneli (onClose)
│   │   │   └── venue_sheet.dart      # VenueSheet: DB mekan detay paneli + yorum (onClose)
│   │   │
│   │   ├── home/                     # Kullanıcı tipine göre dinamik ana sayfa
│   │   │   ├── disabled_home.dart    # Engelli bireyler için ana sayfa
│   │   │   ├── volunteer_home.dart   # Gönüllüler için ana sayfa
│   │   │   └── standard_home.dart   # Turist/Sakin için ana sayfa
│   │   │
│   │   └── venue/
│   │       ├── add_venue_screen.dart     # Yeni mekan ekleme formu
│   │       └── venue_detail_screen.dart  # Mekan detay + yorum ekranı
│   │
│   └── widgets/
│       ├── accessibility_drawer.dart     # Erişilebilirlik yan menüsü (yazı boyutu, kontrast, karanlık mod)
│       ├── custom_home_widgets.dart      # Paylaşılan widget'lar (CustomAppBar vb.)
│       └── location_search_dialog.dart   # Adres arama dialog kutusu
│
├── functions/
│   ├── index.js                    # Cloud Functions (3 fonksiyon: bildirim, token, zaman aşımı)
│   ├── package.json
│   ├── .env                        # Sunucu tarafı gizli anahtarlar (Agora App Certificate)
│   └── .env.local
│
├── assets/
│   └── images/                     # Uygulama görselleri (logo, kullanıcı tipi ikonları vb.)
│
├── android/                        # Android platform kodu
├── ios/                            # iOS platform kodu
├── firestore.rules                 # Firestore güvenlik kuralları
├── firebase.json                   # Firebase CLI yapılandırması
├── pubspec.yaml                    # Flutter bağımlılıkları
└── .env                            # Flutter ortam değişkenleri
```

---

## 6. Uygulama Başlangıç Akışı (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()` → Motor hazırlığı
2. `dotenv.load(fileName: ".env")` → Env değişkenleri yüklenir
3. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` → Firebase başlatılır
4. `AnalyticsService.init()` → Crashlytics global hata yakalayıcıları (`FlutterError.onError` + `PlatformDispatcher.onError`) + Analytics. Firebase'den **hemen sonra** kurulur ki sonraki adımların hataları da raporlansın. Debug modda toplama kapalı (KVKK).
5. `FirebaseAppCheck.instance.activate(...)` → App Check (debug→debug provider, release→Play Integrity/DeviceCheck). Hata olsa bile try/catch ile açılış engellenmez.
6. `SettingsService.create()` → SharedPreferences'dan erişilebilirlik ayarları yüklenir
7. `NotificationService.initialize()` → FCM, CallKit, push izinleri asenkron başlatılır
8. `runApp(ProviderScope(...))` → Riverpod ProviderScope ile uygulama başlar
   - `settingsServiceProvider` burada override edilir (başlangıçta oluşturulan SettingsService instance verilir)
9. `AsikarApp` → `MaterialApp` oluşturulur, tema dinamik (karanlık mod + yüksek kontrast destekli)
10. İlk ekran: `SplashScreen` → ardından `MainWrapper`'a yönlendirilir

---

## 7. Kullanıcı Tipleri ve Yönlendirme Mantığı

### Kullanıcı Tipleri

| Tip | Firestore Değeri | Uygulama İçi Değer | Ana Sayfa |
|---|---|---|---|
| Turist | `"Turist"` | `"Sakin"` (varsayılan) | `StandardHomeScreen` |
| Şehir Sakini | `"Sakin"` | `"Sakin"` | `StandardHomeScreen` |
| Özel Gereksinimli | `"Özel Gereksinimli"` | `"Engelli"` | `DisabledHomeScreen` |
| Gönüllü | isVolunteer: true | `"Gönüllü"` | `VolunteerHomeScreen` |

### MainWrapper Mantığı

`MainWrapper` iki iç içe StreamBuilder kullanır:
1. `FirebaseAuth.instance.authStateChanges()` → giriş yapılmış mı?
   - Hayır → `LoginScreen`
2. Firestore'dan `users/{uid}` dinlenir:
   - Belge yok → `UserTypeScreen` (kayıt anketi)
   - `isVolunteer: true` → FCM 'volunteers' topic'ine abone ol, `VolunteerHomeScreen`
   - `userType: "Özel Gereksinimli"` → `DisabledHomeScreen`
   - Diğer → `StandardHomeScreen`

---

## 8. Routing Sistemi

**Dosya:** `lib/router/app_router.dart`

`MaterialApp.onGenerateRoute` ile merkezi route yönetimi. Named route kullanılır.

### Tüm Route'lar

| Route Sabiti | Path | Ekran | Parametre |
|---|---|---|---|
| `AppRoutes.splash` | `/` | `SplashScreen` | - |
| `AppRoutes.login` | `/login` | `LoginScreen` | - |
| `AppRoutes.register` | `/register` | `RegisterScreen` | - |
| `AppRoutes.mainWrapper` | `/main` | `MainWrapper` | - |
| `AppRoutes.profile` | `/profile` | `ProfileScreen` | - |
| `AppRoutes.userType` | `/user-type` | `UserTypeScreen` | - |
| `AppRoutes.interests` | `/interests` | `InterestsScreen` | `{userType: String}` |
| `AppRoutes.accessibilityPrefs` | `/accessibility-prefs` | `AccessibilityPrefsScreen` | `{userType, selectedInterests}` |
| `AppRoutes.volunteerStatus` | `/volunteer-status` | `VolunteerStatusScreen` | `{userType, selectedInterests}` |
| `AppRoutes.volunteerSkills` | `/volunteer-skills` | `VolunteerSkillsScreen` | `{userType, selectedInterests}` |
| `AppRoutes.registrationComplete` | `/registration-complete` | `RegistrationCompleteScreen` | `{isVolunteer: bool}` |
| `AppRoutes.routeScreen` | `/route` | `RouteScreen` | `{destinationName, destinationLocation}` |

### Kayıt Akışı

```
RegisterScreen
  → UserTypeScreen
    → InterestsScreen (Turist ise)
    → AccessibilityPrefsScreen (Özel Gereksinimli ise)
    → VolunteerStatusScreen (Sakin ise)
      → VolunteerSkillsScreen (Gönüllü olacaksa)
  → RegistrationCompleteScreen
    → MainWrapper
```

---

## 9. Ana Navigasyon (MainLayout)

**Dosya:** `lib/main_layout.dart`

3 sekmeli alt navigasyon çubuğu (`IndexedStack` ile):

| İndeks | Sekme | Ekran |
|---|---|---|
| 0 | Topluluk | `CommunityScreen` |
| 1 | Ana Sayfa | `DisabledHomeScreen` / `VolunteerHomeScreen` / `StandardHomeScreen` |
| 2 | Harita | `MapScreen` |

Sol üstte `AccessibilityDrawer` için hamburger menü mevcuttur.

---

## 10. Veri Modelleri

### 10.1 UserModel (`lib/models/user_model.dart`)

```dart
class UserModel {
  final String uid;            // Firebase Auth UID (zorunlu)
  final String? fullName;      // Ad Soyad
  final String? email;         // E-posta
  final String userType;       // "Turist" | "Sakin" | "Özel Gereksinimli"
  final List<String>? touristInterests;    // Turist ilgi alanları
  final bool? isVolunteer;                 // Gönüllü mü?
  final List<String>? volunteerSkills;     // Gönüllü becerileri
  final List<String>? accessibilityPrefs; // Erişilebilirlik tercihleri
}
```
`toJson()`, `fromJson()`, `copyWith()` metodları mevcuttur.

### 10.2 VenueModel (`lib/models/venue_model.dart`)

```dart
class VenueModel {
  final String id;             // UUID
  final String name;           // Mekan adı
  final String category;       // "Park" | "Alışveriş" | "Tarihi Yer" | "Kamu Binası" | "Sosyal Alan" | "Doğa"
  final String address;        // Metin adres
  final double latitude;
  final double longitude;
  final String description;
  final int accessibilityScore;  // 0-100 hesaplanan skor
  final List<String> features;   // Erişilebilirlik özellikleri
  final List<String> images;     // Görsel URL'leri
  final List<CommentModel> comments;  // Gömülü yorumlar
  final String addedBy;          // Ekleyen UID
  final double averageRating;    // 0.0-5.0
}
```

**Erişilebilirlik Seviyesi Hesaplama:**
- `≥ 85` → "Tam Erişilebilir"
- `≥ 50` → "Kısmi Erişilebilir"
- `≥ 25` → "Kısıtlı Erişilebilir"
- `< 25` → "Destek Gerekli"

**Puan Hesaplama Formülü (`calculateAccessibilityScore` — saf/test edilebilir, `lib/services/accessibility_score.dart`, birim testi `test/unit/accessibility_score_test.dart`):**
- Toplam olası özellik: 8 (Rampa, Asansör, Tuvalet, Otopark, Hissedilebilir Yüzey, Kabartma, Sesli, İşaret Dili)
- `featurePoints = (features.length / 8) * 70` → Max 70 puan
- `ratingPoints = (avgRating / 5.0) * 30` → Max 30 puan
- `score = featurePoints + ratingPoints` (min 5, max 100)

### 10.3 CommentModel (`lib/models/venue_model.dart` içinde)

```dart
class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userType;
  final double rating;          // 1.0-5.0
  final String content;
  final DateTime createdAt;
  final List<String> verifiedFeatures;  // Kullanıcının doğruladığı özellikler
}
```

### 10.4 OsmPoi (`lib/models/osm_poi_model.dart`)

Haritada gösterilen POI (ilgi noktası) modeli. Hem OpenStreetMap Overpass API hem de Foursquare API'sinden gelen verilerle doldurulur.

```dart
class OsmPoi {
  final int osmId;
  final String osmType;         // "node", "way", "relation", "foursquare"
  final double latitude;
  final double longitude;
  final String name;
  final String category;        // Türkçe ("Kafe", "Eczane" vb.)
  final String amenityType;     // OSM ham tag ("cafe", "pharmacy" vb.)
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? wheelchair;     // "yes" | "limited" | "no" | null
  final String? address;
  final Map<String, String> allTags;
}
```

---

## 11. Servisler

### 11.1 AuthService (`lib/services/auth_service.dart`)

- `registerWithEmail(name, email, password)` → Firebase `createUserWithEmailAndPassword` + `updateDisplayName`
- `loginWithEmail(email, password)` → Firebase `signInWithEmailAndPassword`
- `signInWithGoogle()` → `GoogleSignIn.instance.authenticate()` → Firebase `signInWithCredential`
- `signOut()` → FCM token Firestore'dan silinir → Google oturumu kapatılır → Firebase çıkışı yapılır
- `AuthException` → Türkçe hata mesajları ile özel exception sınıfı

### 11.2 DatabaseService (`lib/services/database_service.dart`)

- `saveUserSurvey(UserModel user)` → Firestore `users/{uid}` koleksiyonuna kullanıcı anket verisi yazılır
- Firebase Auth'dan gerçek `uid`, `email`, `displayName` alınarak UserModel güncellenir

### 11.3 VenueService (`lib/services/venue_service.dart`)

- `streamVenues()` → Firestore `venues` koleksiyonunu real-time dinler. Koleksiyon boşsa `seedInitialVenues()` çağırır
- `addVenue(VenueModel venue)` → Yeni mekan ekler, UUID atar, erişilebilirlik skoru hesaplar
- `addComment(venueId, comment)` → Firestore transaction ile: yorum eklenir, ortalama puan güncellenir, verified features birleştirilir, yeni skor hesaplanır
- `seedInitialVenues()` → Sakarya'dan 7 başlangıç mekanı toplu olarak (batch) Firestore'a yazar

**Başlangıç Mekanları:**
1. Sakarya Millet Bahçesi (Skor: 92)
2. Serdivan AVM (Skor: 95)
3. Justinianus Köprüsü (Skor: 55)
4. Kent Park (Skor: 80)
5. Adapazarı Belediyesi (Skor: 90)
6. Çark Caddesi (Skor: 45)
7. Poyrazlar Gölü (Skor: 30)

### 11.4 NotificationService (`lib/services/notification_service.dart`)

FCM + CallKit entegrasyonu. **Dikkat:** `_firebaseMessagingBackgroundHandler` sınıf dışında top-level fonksiyon olarak tanımlanmıştır (FCM gereksinimi).

**Başlatma sırası (`initialize()`):**
1. `permission_handler` ile bildirim izni istenir
2. `FirebaseMessaging.requestPermission()` ile FCM izni istenir
3. `FlutterCallkitIncoming.requestNotificationPermission()` ile CallKit izni istenir
4. FCM token alınır ve Firestore `users/{uid}.fcmToken` alanına yazılır
5. `onTokenRefresh` dinlenir → token yenilenince Firestore güncellenir
6. Arka plan handler kayıt edilir
7. Uygulama açıkken gelen mesajlar (`onMessage`) dinlenir → `type: 'call'` ise CallKit incoming gösterilir
8. Aktif çağrılar kontrol edilir (CallKit'ten "Cevapla" ile açılmış olabilir)
9. CallKit event listener kurulur (tek sefer, `_listenerInitialized` flag'i ile çift kurulum önlenir)

**CallKit Akışı:**
- Gönüllü `actionCallAccept` event'i alır
- Firestore `cagrilar/{callId}.cagri_durumu` = `"cevaplandi"` yapılır, `volunteer_uid` yazılır
- `_navigateToCallScreen(callId)` → Navigator hazır değilse 300ms aralıkla 15 kez retry eder
- Tüm denemeler başarısız → `pendingCallId` static alanına yazar → `MainWrapper.didChangeAppLifecycleState` yakalar

**Topic Yönetimi:**
- `subscribeToVolunteers()` → FCM `volunteers` topic'ine abone ol
- `unsubscribeFromVolunteers()` → Topic aboneliğinden çık
- `clearFcmTokenFromFirestore()` → Çıkışta FCM token'ı Firestore'dan siler

### 11.5 AgoraTokenService (`lib/services/agora_token_service.dart`)

- `fetchToken({channelName, uid})` → `europe-west3` bölgesindeki `generateAgoraToken` Cloud Function'ını çağırır
- App Certificate **asla** client'ta bulunmaz

### 11.6 FoursquarePlacesService (`lib/services/foursquare_places_service.dart`)

- Foursquare Places API v3 kullanır
- API key: `.env` dosyasından `FOURSQUARE_API_KEY`
- `debouncedFetch()` → 800ms debounce ile API çağrısını geciktirir
- Koordinat + kategori bazlı basit cache sistemi (`_lastCacheKey`)
- Türkçe kategori → Foursquare kategori ID eşleştirmesi: 12 kategori (Kafe, Restoran, Eczane, Market, Hastane, Banka, Otel, Park, Müze, Okul, Cami, Fast Food)
- `OsmPoi` modeline dönüştürür (`_fromFoursquare()`)

### 11.7 OverpassPoiService (`lib/services/overpass_poi_service.dart`)

- OpenStreetMap **Overpass API** kullanır (ücretsiz, anahtarsız)
- `debouncedFetch()` → 800ms debounce; cache anahtarı bounding-box köşeleri (`s,w,n,e`, 3 ondalık)
- 20+ OSM amenity türü (kafe, restoran, eczane, market, turizm, leisure); `searchPoisByCategory()` metodu
- Erişilebilirlik tag'lerini (`wheelchair`, `tactile_paving`, `toilets:wheelchair`) `OsmPoi` modeline taşır
- `osmType = node | way | relation`

> **Hibrit POI:** Harita ekranı (`map_screen.dart`) Foursquare + Overpass'i **paralel** çeker; `_mergePois()` ile **Foursquare öncelikli** birleştirir, 4-ondalık koordinat + 40m isim benzerliğiyle duplikasyonu eler. Foursquare güncel iş yeri, Overpass bedava + erişilebilirlik tag'leri sağlar.

### 11.8 MapSearchService (`lib/services/map_search_service.dart`)

- **Birleşik arama:** Nominatim (adres/metin) + Overpass (kategori) **paralel** (`Future.wait`)
- 500ms debounce; sonuçları 4-ondalık koordinatla dedup eder, Overpass sonuçlarını önceler
- Metin tabanlı adres aramasında Nominatim'e fallback

### 11.9 SettingsService (`lib/services/settings_service.dart`)

`SharedPreferences` üzerinde erişilebilirlik ayarları saklar:

| Anahtar | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `font_scale` | double | 1.0 | Yazı boyutu ölçeği |
| `high_contrast` | bool | false | Yüksek kontrast modu |
| `sound_enabled` | bool | true | Ses açık mı |
| `dark_mode` | bool | false | Karanlık mod |
| `route_home` | String (JSON) | null | Ev konumu |
| `route_work` | String (JSON) | null | İş konumu |
| `route_park` | String (JSON) | null | Park konumu |
| `recent_map_searches` | List\<String\> | [] | Son 5 harita araması |

> **Not:** Favori rotalar `{"name": "...", "lat": 40.1, "lng": 30.1}` JSON formatında string olarak saklanır.

### 11.10 AnalyticsService (`lib/services/analytics_service.dart`)

Gözlemlenebilirlik servisi: Firebase **Crashlytics** (çökme/non-fatal hata) + **Analytics** (ürün metrikleri).

- `init()` → açılışta bir kez (main.dart, Firebase'den hemen sonra). `FlutterError.onError` + `PlatformDispatcher.onError` → Crashlytics; toplama `!kDebugMode` (debug'da kapalı).
- `observer` → `MaterialApp.navigatorObservers`'a eklenir → otomatik `screen_view`.
- Çağrı funnel event'leri: `cagriBaslatildi` / `cagriCevaplandi` / `cagriTamamlandi` / `cagriZamanAsimi` → çağrı durum geçişlerinde çağrılır (PRD başarı metriği).
- `recordError(error, stack, reason)` → yakalanmış hata bildirimi.
- **KVKK (kural #6):** Event'ler **parametresiz/anonim**; konum/engellilik/e-posta ASLA geçmez; `setUserIdentifier` kullanılmaz. Detay: vault `12-Loglama` + `08-Guvenlik`.

---

## 12. State Yönetimi (Riverpod)

### AppSettings

```dart
class AppSettings {
  final double fontScale;
  final bool highContrast;
  final bool soundEnabled;
  final bool darkMode;
  final String? routeHome;   // JSON string
  final String? routeWork;   // JSON string
  final String? routePark;   // JSON string
}
```

### Provider Zinciri

```
settingsServiceProvider (Provider<SettingsService>)
  → main.dart'ta ProviderScope overrides ile inject edilir
  → SettingsService başlangıçta async oluşturulur (await SettingsService.create())

settingsProvider (StateNotifierProvider<SettingsNotifier, AppSettings>)
  → settingsServiceProvider'a bağlıdır
  → setFontScale(), setHighContrast(), setDarkMode() vb. metodlar ile state güncellenir
```

**Kullanım örneği:**
```dart
// Okuma
final settings = ref.watch(settingsProvider);
double scale = settings.fontScale;

// Yazma
ref.read(settingsProvider.notifier).setDarkMode(true);
```

---

## 13. Erişilebilirlik Sistemi

### AccessibilityDrawer (`lib/widgets/accessibility_drawer.dart`)

Tüm ekranlarda sol üst hamburger menüsünden açılan çekmece. İçerir:
- **Yazı Boyutu Slider** (0.8x – 1.4x, 4 kademe: Küçük/Orta/Büyük/Çok Büyük)
- **Yüksek Kontrast Toggle** (açıkken MaterialApp teması değişir: sarı üzerine siyah metin)
- **Ses Toggle**
- **Karanlık Mod Toggle**

### Tema Dinamizmi (`main.dart`)

```dart
// Yüksek kontrast + karanlık mod → 4 farklı tema kombinasyonu
final lightScheme = settings.highContrast
    ? highContrastColorScheme(Brightness.light)
    : ColorScheme.fromSeed(seedColor: AppColors.primary);
```

### Yazı Boyutu Ölçekleme

```dart
// Sistem yazı boyutundan bağımsız, uygulama kendi kontrolünü sağlar
builder: (context, child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(settings.fontScale),
    ),
    child: child!,
  );
},
```

### Semantics Kullanımı

Görme engelli kullanıcılar için kritik widget'larda `Semantics` kullanılmıştır:
- Yardım İste butonu: `label: 'Acil Yardım İste. Görüntülü bir gönüllüye bağlan.'`
- Rota butonları: `label: 'Ev rotasına gitmek için dokun, değiştirmek için basılı tut'`
- CallScreen butonları: `label: 'Aramayı Sonlandır'`

---

## 14. Görüntülü Görüşme Sistemi

### Akış (Engelli → Gönüllü)

```
1. DisabledHomeScreen: "YARDIM İSTE" butonuna bas
2. UUID oluştur → Firestore 'cagrilar/{callId}' belgesi oluştur
   {callId, kanal_adi, cagri_durumu: 'bekliyor', zaman, caller_name, caller_uid}
3. Cloud Function (cagriBildirimiGonder) tetiklenir
   → FCM 'volunteers' topic'ine data mesajı gönderilir
   {type: 'call', caller_name, channel_name}
4. Gönüllü telefonu çalar (CallKit incoming)
5. Gönüllü "Cevapla" basar
   → CallKit actionCallAccept event
   → Firestore güncellenir: {cagri_durumu: 'cevaplandi', volunteer_uid}
   → CallScreen açılır (isVolunteer: true)
6. Engelli kullanıcı da CallScreen'e geçmiştir (isVolunteer: false)
7. Agora token Cloud Function'dan alınır (generateAgoraToken)
8. Her iki taraf aynı channel'a katılır (channelId = callId)
9. Çağrı biter: Firestore {cagri_durumu: 'bitti'} → her iki taraf ekrandan çıkar
```

### CallScreen Detayları

- **Engelli kullanıcı:** Arka kamera açık başlar (`switchCamera()`), gönüllüye çevresini gösterir
- **Gönüllü:** Kamera kapalı başlar (`muteLocalVideoStream(true)`), ihtiyaç halinde açabilir
- Firestore `cagrilar/{callId}` real-time dinlenir → `'bitti'` olunca otomatik çıkış
- Token alınamazsa hata ekranı gösterilir (bağlantı yok)

---

## 15. Firestore Yapısı

### Koleksiyonlar

#### `users/{uid}`
```
uid:               string (required, immutable)
fullName:          string (optional, max 100)
email:             string (optional, max 254)
userType:          string ("Turist" | "Sakin" | "Özel Gereksinimli")
isVolunteer:       bool
touristInterests:  list (optional, max 20)
volunteerSkills:   list (optional, max 20)
accessibilityPrefs: list (optional, max 20)
fcmToken:          string (optional, max 200)
```

#### `cagrilar/{callId}`
```
callId:        string (immutable)
kanal_adi:     string (immutable) — Agora channel adı = callId
cagri_durumu:  string ("bekliyor" | "cevaplandi" | "bitti")
zaman:         timestamp (immutable)
caller_name:   string (immutable, max 100)
caller_uid:    string (immutable)
volunteer_uid: string (güncelleme ile eklenir)
```

#### `venues/{venueId}`
```
id:                string (immutable)
name:              string (immutable, max 200)
category:          string (immutable) — "Park" | "Alışveriş" | "Tarihi Yer" | "Kamu Binası" | "Sosyal Alan" | "Doğa"
address:           string (immutable, max 500)
latitude:          number (immutable)
longitude:         number (immutable)
description:       string (immutable, max 2000)
accessibilityScore: number (0-100, yorumla güncellenir)
features:          list (max 20, yorumla genişler)
images:            list (max 10)
comments:          list (embedded CommentModel'ler)
addedBy:           string (immutable)
averageRating:     number (0.0-5.0)
```

---

## 16. Firestore Güvenlik Kuralları

Dosya: `firestore.rules`

### Genel Prensipler

- Kimlik doğrulanmamış hiçbir erişime izin verilmez
- Her kullanıcı yalnızca kendi `users` belgesini okuyup yazabilir
- `users`, `cagrilar` ve `venues` belgeleri **asla silinemez**

### Kural Özeti

| Koleksiyon | Okuma | Oluşturma | Güncelleme | Silme |
|---|---|---|---|---|
| `users/{uid}` | Sadece belge sahibi | Sadece kendisi (UID eşleşmeli) | Sadece kendisi (UID değişmez) | ❌ Asla |
| `cagrilar/{cagriId}` | Giriş yapmış herkes | Giriş yapmış, caller_uid kendi | Giriş yapmış, yalnızca `cagri_durumu` değişebilir | ❌ Asla |
| `venues/{venueId}` | Giriş yapmış herkes | Giriş yapmış, addedBy kendi UID | Giriş yapmış, çekirdek alanlar değişmez | ❌ Asla |

### Yardımcı Fonksiyonlar

```javascript
function isAuthenticated()       // request.auth != null
function isOwner(userId)         // auth.uid == userId
function uidMatchesAuth()        // request.resource.data.uid == auth.uid
function uidNotModified()        // uid alanı değiştirilmemiş mi?
function hasRequiredFields(fields)     // Zorunlu alanlar mevcut mu?
function hasOnlyAllowedFields(fields)  // Yalnızca izinli alanlar var mı?
function areImmutableFieldsUnchanged(fields) // Değişmez alanlar korunmuş mu?
```

### Domain Validator Fonksiyonları

- `isValidUserData()` → İzinli alan listesi + tip ve boyut kontrolleri
- `isValidNewCagri()` → Zorunlu alanlar + `cagri_durumu == 'bekliyor'` + `caller_uid == auth.uid`
- **Çağrı durum makinesi geçişleri** (eski tekil `isValidCagriStatusUpdate` yerine):
  - `isCagriClaim()` → `bekliyor → cevaplandi`; yalnızca durum `bekliyor` iken; `volunteer_uid == auth.uid`; arayan kendi çağrısını üstlenemez. **Çağrı kapma yarışı kilidi.**
  - `isCagriComplete()` → `(bekliyor|cevaplandi) → bitti`; yalnızca katılımcı (arayan/üstlenen gönüllü).
  - `isCagriTimeout()` → `bekliyor → zaman_asimi`; yalnızca arayan.
  - Geri dönüş / üçüncü taraf / başkası adına üstlenme reddedilir.
- `isValidNewVenue()` → Tüm alanlar + kategori listesi + koordinat aralıkları + `addedBy == auth.uid`
- `isValidVenueUpdate()` → İmmutable alanlar korunmuş + puan aralıkları + liste boyutları

---

## 17. Firebase Cloud Functions

Dosya: `functions/index.js`

### Fonksiyon 1: `cagriBildirimiGonder`

- **Tetikleyici:** `cagrilar/{cagriId}` Firestore document `onWrite`
- **Bölge:** `europe-west3`
- **İşlev:** `cagri_durumu` yeni `'bekliyor'` olduğunda FCM `volunteers` topic'ine data mesajı gönderir
- **Çift tetikleme önlemi:** `wasWaiting && isWaiting` kontrolü

```javascript
// Gönderilen mesaj yapısı
{
  topic: "volunteers",
  data: {
    type: 'call',
    caller_name: '...',
    channel_name: '...'  // Agora channel = callId
  },
  android: { priority: 'high', ttl: 30000 },
  apns: { payload: { aps: { contentAvailable: true } }, headers: { 'apns-priority': '10' } }
}
```

### Fonksiyon 1b: `cagriZamanAsimiTemizle`

- **Tetikleyici:** Scheduled (pubsub) — `every 1 minutes`
- **Bölge:** `europe-west3`
- **İşlev:** `cagri_durumu == 'bekliyor'` çağrıları çeker; `zaman`'ı 90 sn'den eski (terk edilmiş) olanları `'zaman_asimi'` yapar (batch).
- **Neden:** Birincil zaman aşımı istemcide (`CallScreen`, 45 sn). Bu fonksiyon yalnızca arayan uygulaması kapanınca ortada kalan çağrıları temizler → gönüllüler terk edilmiş çağrı görmez.
- **Index notu:** Bileşik index'ten kaçınmak için yalnızca `bekliyor` eşitlik sorgusu; zaman eşiği bellek içinde filtrelenir.

### Fonksiyon 2: `generateAgoraToken`

- **Tetikleyici:** HTTPS Callable
- **Bölge:** `europe-west3`
- **İşlev:** Agora RTC token üretir (1 saatlik geçerlilik)
- **Güvenlik:** `context.auth` kontrolü → giriş yapmamış kullanıcı token alamaz
- **App Check:** `APP_CHECK_ENFORCE=true` iken `context.app` yoksa reddeder (yalnızca gerçek uygulama token alır). Bayrak `false`/yok iken zorlama yapılmaz (güvenli kullanıma alma için).
- **Env değişkenleri:** `process.env.AGORA_APP_ID`, `process.env.AGORA_APP_CERTIFICATE`, `process.env.APP_CHECK_ENFORCE`

**Çağrı örneği (Flutter):**
```dart
final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
    .httpsCallable('generateAgoraToken')
    .call({'channelName': callId, 'uid': 0});
final token = result.data['token'];
```

---

## 18. Renk Paleti (`lib/constants/app_colors.dart`)

```dart
AppColors.primary          = Color(0xFF1C4576)  // Lacivert — marka rengi
AppColors.secondary        = Color(0xFF38A3B5)  // Turkuaz — vurgu
AppColors.tertiary         = Color(0xFF64A744)  // Yeşil — gönüllü teması
AppColors.background       = Color(0xFFF4F7FA)  // Açık gri — scaffold arka plan
AppColors.outline          = Color(0xFF737780)  // Orta gri — ikon ve placeholder
AppColors.textDark         = Color(0xFF43474F)  // Koyu gri — gövde metni
AppColors.surface          = Color(0xFF181C1E)  // Çok koyu — vurgulu başlık
AppColors.danger           = Color(0xFFDC3545)  // Kırmızı — hata/iptal
AppColors.warning          = Color(0xFFF39C12)  // Turuncu — uyarı
AppColors.splashBackground = Color(0xFFF7FAFD)  // Splash arka plan
AppColors.infoDarkTeal     = Color(0xFF006B79)  // Koyu turkuaz — bilgi kutusu
AppColors.lightSurface     = Color(0xFFF1F4F7)  // Açık yüzey — panel kutuları
AppColors.chipBorder       = Color(0xFFC3C6D0)  // Ince kenar ve ayırıcı
```

### Yüksek Kontrast Şeması

- **Açık mod:** `primary: Color(0xFF000080)` (koyu lacivert), `onPrimary: white`
- **Karanlık mod:** `primary: Color(0xFFFFFF00)` (parlak sarı), `onPrimary: black`

---

## 19. Ana Ekranlar

### DisabledHomeScreen

- Merkeze yerleştirilmiş devasa "YARDIM İSTE" butonu (280x280 daire)
- Gönüllü bağlantı sayısı ve açıklama metni
- 3 favori rota butonu (Ev / İş / Park) — `SharedPreferences`'dan okunur, `SettingsNotifier` ile güncellenir
- Rota ayarlanmamışsa "Ayarla", ayarlanmışsa adres gösterilir
- Rota butonuna uzun basınca konum değiştirilir
- Tüm butonlarda `Semantics` etiketleri mevcuttur

### VolunteerHomeScreen

- Gönüllü çağrı bekler
- Aktif çağrıları Firestore `cagrilar` koleksiyonundan real-time dinler
- Gelen çağrı → CallScreen'e yönlendirilir

### StandardHomeScreen

- Turist ve şehir sakinleri için ana ekran

### CommunityScreen (Topluluk sekmesi)

- Kullanıcı katkılı `venues` mekânlarının keşfi
- Realtime `venuesStreamProvider` + **client-side** arama, kategori ve **erişilebilirlik seviyesi** filtresi (`filteredVenuesProvider`)
- Mekana tıklanınca `VenueDetailScreen`

### MapScreen

- flutter_map + OpenStreetMap tile kullanır
- **Hibrit POI:** Foursquare + Overpass **paralel** çekilir, `_mergePois()` ile Foursquare-öncelikli birleştirilir (4-ondalık koordinat + 40m isim dedup)
- Erişilebilirlik katmanları: footway/yaya yolları, tekerlekli sandalye yolları, hissedilebilir yüzey node'ları (Overpass)
- Kategori filtreleme
- Mekan markerlarına tıklanınca `VenueDetailScreen`'e gidilir
- `LocationSearchDialog` + `MapSearchService` (Nominatim + Overpass birleşik arama)

### RouteScreen (Rota / yol tarifi)

- **OSRM** tabanlı yaya/araç rotası (birincil `routing.openstreetmap.de`, yedek `router.project-osrm.org`)
- GeoJSON geometri; API yanıt vermezse düz-çizgi yaklaşık mesafe fallback
- Mesafe + süre gösterimi, rota ters çevirme/paylaşma
- **Not:** Tekerlekli sandalyeye özel routing profili henüz yok

### CallScreen

- Agora RTC Engine kullanan görüntülü görüşme ekranı
- Kamera döndür / kapat, arama sonlandır butonları
- Firestore'dan çağrı durumunu dinler (`cevaplandi` → sayacı iptal, `bitti`/`zaman_asimi` → kapat)
- Gönüllü kamera kapalı, engelli arka kamera açık başlar
- **Zaman aşımı (yalnızca arayan):** 45 sn gönüllü bulunamazsa transaction ile `zaman_asimi` (yalnızca hâlâ `bekliyor` ise) + "Şu anda uygun bir gönüllü bulunamadı" / "Tekrar Dene" ekranı. Gönüllü tam zamanında üstlenirse görüşme normal devam eder.

---

## 20. Geliştirme Komutları

### Flutter

```powershell
# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır (debug)
flutter run

# Belirli cihazda çalıştır
flutter run -d <device_id>

# Bağlı cihazları listele
flutter devices

# Analiz
flutter analyze

# Test
flutter test

# Build (Android APK)
flutter build apk

# Build (Android App Bundle)
flutter build appbundle

# Build (iOS)
flutter build ios
```

### Firebase CLI

```powershell
# Firebase CLI versiyonunu kontrol et
npx -y firebase-tools@latest --version

# Firebase'e giriş yap
npx firebase-tools login

# Aktif projeyi ayarla
npx firebase-tools use asikar-engelsiz-kent-rehberi

# Firestore kurallarını deploy et
npx firebase-tools deploy --only firestore:rules

# Cloud Functions'ı deploy et
npx firebase-tools deploy --only functions

# Her ikisini birden deploy et
npx firebase-tools deploy --only firestore:rules,functions

# Cloud Functions loglarını görüntüle
npx firebase-tools functions:log
```

### Firebase FlutterFire CLI

```powershell
# firebase_options.dart'ı yeniden oluştur (gerekirse)
dart pub global activate flutterfire_cli
flutterfire configure --project=asikar-engelsiz-kent-rehberi
```

---

## 21. Önemli Mimari Kararlar ve Kurallar

1. **Renk sabitleri her zaman `AppColors` sınıfından kullanılır.** Inline `Color(0xFF...)` yazılmaz.

2. **Route isimleri her zaman `AppRoutes` sabitleri üzerinden kullanılır.** String literal yazılmaz.

3. **Agora App Certificate asla Flutter tarafında bulunmaz.** Token üretimi yalnızca `generateAgoraToken` Cloud Function'ında yapılır.

4. **FCM arka plan handler (`_firebaseMessagingBackgroundHandler`) sınıf dışında top-level fonksiyon olarak tanımlanmak zorundadır** — Firebase gereksinimi. `@pragma('vm:entry-point')` anotasyonu zorunludur.

5. **`settingsServiceProvider` `ProviderScope.overrides` listesinde override edilir** — `main()` içinde `SettingsService.create()` async oluşturulur ve inject edilir. Provider kendi içinde `throw UnimplementedError` ile korunur.

6. **Firestore transaction kullanımı:** Yorum ekleme gibi okuma-değiştirme-yazma döngüsü gerektiren işlemlerde `runTransaction()` kullanılır (yarış koşullarını önler).

7. **Görüntülü görüşmede gönüllü birden fazla çağrıyı cevaplamaması için** Firestore'dan durum güncellenir ve diğer gönüllüler bu çağrıyı cevaplamamış sayılır.

8. **CallKit listener tek kez kurulur** — `_listenerInitialized` static bool flag'i ile çift kurulum önlenir.

9. **Navigator henüz hazır değilken CallScreen yönlendirmesi** → 300ms aralıklı 15 deneme retry mekanizması, başarısız olursa `pendingCallId` static alanına yazılır, `MainWrapper.didChangeAppLifecycleState` ile yakalanır.

10. **Mekan silme yok:** Firestore kurallarında `venues`, `cagrilar` ve `users` koleksiyonlarında silme asla izin verilmez.

11. **Foursquare servisinde debounce:** API aşırı yüklenmesini önlemek için 800ms debounce ve basit koordinat+kategori bazlı cache kullanılır.

12. **Çağrı tipine göre FCM yönlendirmesi (2026-07-02):** Çağrı `cagri_tipi` taşır (`CagriTipi.fiziksel`/`uzaktan` — `lib/constants/call_types.dart`). **Fiziksel** (yerinde yardım/şehir rehberliği) yalnızca aynı şehirdeki gönüllülere (`volunteers_<sehir>`), **uzaktan** (görüntülü) tüm gönüllülere (global `volunteers`) gider. Kullanıcı tipi çağrı ekranındaki bottom-sheet'ten seçer. `sehir` arayanın anlık GPS konumundan reverse-geocode ile çözülür (`city_lookup_service.dart`) ve topic-güvenli slug'a çevrilir (`city_slug.dart`, saf/testli). Gönüllü hem global hem kendi şehir topic'ine abone olur. `functions/index.js` + `firestore.rules` aynı slug regex'iyle doğrular. **Deploy gerekli:** functions + rules.

---

## 22. Proje Bağlamı

- **Amaç:** Gerçek ürün / canlı production — engelli bireyler için erişilebilirlik + gönüllü destek platformu
- **Yayılım:** Sakarya'da **pilot** → **Türkiye geneli** kullanıma açık
- **Maliyet duruşu:** Altyapıda kalıcı **$0/düşük katman** hedefi (bilinçli tercih)
- **Dil:** Uygulama arayüzü Türkçe, kod yorumları Türkçe/İngilizce karışık
- **Hedef platformlar:** Android ve iOS (birincil), Web (ikincil)
- **Uygulama adı:** Aşikar Engelsiz Kent Rehberi
- **Paket adı:** `asikar_engelsiz_kent_rehberi`
- **Versiyon:** `1.0.0+1`

---

## 23. Mimari Bilgi Tabanı (Obsidian Vault)

Her katmanın **neden** kararları, MVP kapsamı, açık sorular ve TODO'ları `vault/` klasöründeki Obsidian not ağındadır. Notlar `[[wikilink]]` ile çapraz bağlıdır → Obsidian graf görünümü projenin beyin haritasını verir.

- **Merkez (MOC):** `vault/00-Overview/Architecture-Overview.md` — 13 katmanı tek ekranda bağlar
- **Genel bakış:** `Vision`, `PRD`, `Architecture-Overview`
- **13 katman:** `01-On-Yuz` · `02-API-Arka-Uc` · `03-Veritabani` · `04-Auth` · `05-Barindirma` · `06-Bulut` · `07-CI-CD` · `08-Guvenlik` · `09-Rate-Limiting` · `10-Cache-CDN` · `11-Olcekleme` · `12-Loglama` · `13-Recovery`

> Bu doküman "ne ve nasıl"ı (mevcut durum), vault ise "neden"i (mimari gerekçe) anlatır. Bir mimari kararı değiştirirken ilgili katman notunu da güncelle.
