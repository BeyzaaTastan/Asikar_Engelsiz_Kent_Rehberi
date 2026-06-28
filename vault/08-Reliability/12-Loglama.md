---
katman: Loglama
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[02-API-Arka-Uc]], [[13-Recovery]], [[06-Bulut]], [[08-Guvenlik]], [[PRD]]
---

# 12 · Loglama (Logging & Observability)

## Neden önemli
Çağrı zinciri (Firestore → Function → FCM → CallKit → Agora) çok parçalı; bir çağrı düştüğünde log olmadan **nerede** düştüğünü bulmak imkânsız. Atlanırsa "gönüllü çağrıyı alamıyor" gibi hatalar tahminle aranır ve bitirme demosunda canlı patlar.

## Karar (ne + NEDEN)
**MVP için "ücretsiz + yüksek getirili" gözlemlenebilirlik:**

**Var olan (varsayılan):**
- **Cloud Functions logları** (`firebase functions:log`) → token üretimi + çağrı fan-out olayları otomatik loglanır.
- Flutter `debugPrint` / konsol (geliştirme sırasında).

**Eklendi (hepsi ücretsiz) — *2026-06-28*:**
1. **Firebase Crashlytics** ✅ → mobil çökme + non-fatal hata raporu. **Neden #1 öncelik:** Üretimde kullanıcının telefonunda ne çöktüğünü görmenin tek yolu; ücretsiz; kurulum dakikalar. **Gerçek cihazda (Redmi 8, release APK) test crash ile doğrulandı.**
2. **Firebase Analytics** ✅ → temel funnel (çağrı başlatma → cevaplanma → tamamlanma/zaman aşımı). **Neden:** [[PRD]] başarı metriklerini (tamamlanmış çağrı oranı) ölçmenin bedava yolu.
3. **Çağrı yaşam döngüsü olay logları** ✅ → her durum geçişine anonim Analytics event'i → çağrı düşme oranını ölçmek için.

**Neden hafif tutuyoruz:** Datadog/Sentry-pro gibi ücretli APM bu ölçekte gereksiz maliyet. Firebase'in dahili (Crashlytics + Analytics + Functions logs) üçlüsü tek şehir için fazlasıyla yeter.

**Gizlilik kuralı:** Loglara **kişisel/konum verisi yazılmaz** (KVKK — bkz. [[08-Guvenlik]]). UID yerine anonim olay; konum loglanmaz. **Uygulamada:** `AnalyticsService` event'leri yalnızca durum geçişi taşır (parametresiz); `setUserIdentifier` bilinçli kullanılmaz; **debug modda toplama tamamen kapalıdır** (`!kDebugMode`) → geliştirme cihazından veri sızmaz.

## Uygulama Durumu (nasıl kuruldu) — *2026-06-28*
- **Paketler:** `firebase_crashlytics` + `firebase_analytics` (`pubspec.yaml`).
- **Android Gradle:** `com.google.firebase.crashlytics` plugin'i + `google-services` **4.4.2**'ye yükseltildi (Crashlytics plugin v3, google-services ≥4.4.1 ister). Release derlemede `uploadCrashlyticsMappingFileRelease` çalışır → obfuscate edilmiş yığınlar Console'da çözülür.
- **Servis:** `lib/services/analytics_service.dart` → tek giriş noktası.
  - `init()`: `FlutterError.onError` + `PlatformDispatcher.instance.onError` Crashlytics'e bağlanır (Flutter içi + async/platform hataları). Toplama `!kDebugMode` ile koşullu.
  - Çağrı funnel event'leri: `cagriBaslatildi` · `cagriCevaplandi` · `cagriTamamlandi` · `cagriZamanAsimi`.
  - `observer`: ekran görüntülemeleri otomatik (`navigatorObservers`).
- **Bağlantı noktaları (kod):**
  - `main.dart` → `Firebase.initializeApp` sonrası `AnalyticsService.init()` (App Check/Settings/Notifications hataları da yakalanır).
  - `disabled_home.dart` → çağrı oluşturulunca `cagriBaslatildi` (funnel paydası).
  - `notification_service.dart` → `runTransaction` kazanılınca `cagriCevaplandi` (gönüllü, tek sefer — bkz. [[02-API-Arka-Uc]] çağrı kapma yarışı kilidi).
  - `call_screen.dart` → arayan tarafta cevaplanan çağrı bitince `cagriTamamlandi`; zaman aşımı ekranında `cagriZamanAsimi`. Her event çağrı başına tek kez (çift sayım engellenir).
- **Funnel metriği:** `tamamlanan çağrı oranı = cagri_tamamlandi ÷ cagri_baslatildi` → [[PRD]] başarı metriği.
- **Doğrulama:** Release APK → Profil ekranına geçici test-crash butonu → çökme Console'da göründü → test kodu temizlendi.
- **Notlar (yayın öncesi):** `--obfuscate --split-debug-info` ile çıkan sembol klasörü saklanmalı; release toplama açık (debug kapalı), DebugView ile anlık event izlenebilir.

## MVP Kapsamı
**VAR:**
- Cloud Functions otomatik logları
- **Firebase Crashlytics** (çökme + global Flutter/async hata yakalama) — *2026-06-28*
- **Firebase Analytics funnel** (çağrı yaşam döngüsü event'leri + ekran görüntüleme) — *2026-06-28*
- **Yapılandırılmış çağrı yaşam döngüsü logu** (durum geçişi başına anonim event) — *2026-06-28*

**YOK:**
- Merkezî log toplama / alerting / dashboard
- Performans izleme (Firebase Performance Monitoring)
- Uptime/healthcheck alarmı

## Açık Sorular
- ~~Çağrı düşme oranını ölçmeden "ürün çalışıyor" denebilir mi?~~ Artık ölçülebilir (funnel kuruldu); kalan: yeterli veri biriktikten sonra oranı yorumla.
- **Crashlytics + Analytics KVKK açısından açık rıza gerektiriyor mu?** (kullanıcıya aydınlatma metninde bildirilmeli — bkz. [[08-Guvenlik]] KVKK TODO). Teknik tarafta veri anonim ve debug'da kapalı, ama **rıza/aydınlatma metni hâlâ açık.**
- Cloud Functions log retention ne kadar; demo/jüri öncesi yeterli geçmiş tutuluyor mu?
- Çağrı tamamlanma event'i yalnızca arayan tarafta sayılıyor (çift sayım önlemek için); ağ kesintisinde event kaybı olursa funnel az sayar — kabul edilebilir mi?

## TODO
- [x] **Crashlytics ekle** — en yüksek getirili, ücretsiz, ilk iş — *2026-06-28*
- [x] Analytics ile çağrı funnel'ı kur → [[PRD]] metriklerine bağla — *2026-06-28*
- [x] Çağrı durum geçişlerine yapılandırılmış (anonim) event ekle (düşme analizi) — *2026-06-28*
- [x] Log'lara konum/kişisel veri sızmadığını denetle (event'ler parametresiz, `setUserIdentifier` yok, debug'da kapalı) → [[08-Guvenlik]] — *2026-06-28*
- [ ] KVKK aydınlatma/rıza metnine Crashlytics + Analytics kullanımını ekle → [[08-Guvenlik]]
- [ ] Release pipeline'da `--obfuscate` sembol klasörünü arşivle (deobfuscation için) → [[07-CI-CD]]
- [ ] Birkaç gün veri sonrası `tamamlanan çağrı oranı`nı [[PRD]] hedefiyle karşılaştır

---

## İlgili Notlar
- [[Architecture-Overview]] — gözlemlenebilirlik katmanı (tam, *2026-06-28*)
- [[PRD]] — başarı metriklerini ölçer
- [[02-API-Arka-Uc]] — Cloud Functions logları
- [[03-Veritabani]] — belge boyutu metriği
- [[06-Bulut]] — Firebase log servisleri (Crashlytics + Analytics barındırma)
- [[07-CI-CD]] — release sembol (`--split-debug-info`) arşivi + obfuscate
- [[08-Guvenlik]] — KVKK log gizliliği (anonim event, debug'da kapalı)
- [[10-Cache-CDN]] — cache hit/miss metriği
- [[11-Olcekleme]] — cold start ölçümü
- [[13-Recovery]] — yedek doğrulama/izleme
