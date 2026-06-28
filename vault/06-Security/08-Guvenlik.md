---
katman: Güvenlik
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[04-Auth]], [[03-Veritabani]], [[02-API-Arka-Uc]], [[09-Rate-Limiting]]
---

# 08 · Güvenlik

## Neden önemli
Bu uygulamada güvenlik açığı = gerçek dünyada zarar: sızan Agora sertifikası ücretsiz dakikaları sömürür, gevşek Firestore kuralı engelli kullanıcının konum/kimlik verisini ifşa eder. Atlanırsa hem KVKK ihlali hem de kötüye kullanım kaçınılmaz.

## Karar (ne + NEDEN)
Güvenlik üç hatta savunulur:

### 1. Sır yönetimi (en kritik)
- **Agora App Certificate yalnızca `functions/.env`'de.** Client'a asla konmaz; token üretimi sadece `generateAgoraToken` Cloud Function'ında (bkz. [[02-API-Arka-Uc]]). **Neden:** Sertifika client'a girerse herkes sınırsız token üretip ücretsiz dakikaları tüketir.
- `AGORA_APP_ID` ve `FOURSQUARE_API_KEY` client `.env`'inde — bunlar görece düşük riskli ama yine de repoya **girmez** (`.gitignore`).
- **Açık risk:** Mobil binary tersine mühendislikle `.env` asset'leri çıkarılabilir. App ID/Foursquare key bu yüzden "yarı-gizli"; gerçek koruma sertifikanın sunucuda kalması.

### 2. Firestore Güvenlik Kuralları (yetkilendirme)
- **Kimlik doğrulanmamış erişim yok** (`isAuthenticated()` her yerde ön koşul).
- `users/{uid}`: yalnızca sahibi okur/yazar, `uid` immutable (`isOwner`, `uidNotModified`).
- `cagrilar`: oluşturan `caller_uid == auth.uid`; güncellemede **yalnızca geçerli durum makinesi geçişi** kabul edilir (bkz. [[03-Veritabani]] · "Çağrı durum makinesi"):
  - **`isCagriClaim`** (bekliyor→cevaplandi): Bir gönüllü çağrıyı üstlenir. Yalnızca durum hâlâ `'bekliyor'` iken geçer → **ikinci gönüllünün yazısı reddedilir** ("çağrı kapma yarışı"nın yetki düzeyi kilidi). `volunteer_uid == auth.uid` olmalı; arayan kendi çağrısını üstlenemez.
  - **`isCagriComplete`** ((bekliyor|cevaplandi)→bitti): Yalnızca çağrının **katılımcısı** (arayan veya üstlenen gönüllü) bitirebilir; üçüncü kullanıcı bitiremez. Geri dönüş yok.
  - **`isCagriTimeout`** (bekliyor→zaman_asimi): Yalnızca **arayan** (`caller_uid`) tetikleyebilir; gönüllü bulunamadığında. Terk edilmiş çağrılar için sunucu (scheduled function) admin SDK ile yazar — admin kuralları atlar (bkz. [[02-API-Arka-Uc]]).
- `venues`: ekleyen `addedBy == auth.uid`; çekirdek alanlar immutable.
- **Silme her koleksiyonda yasak.**
- Domain validator'lar (`isValidUserData`, `isValidNewCagri`, `isValidNewVenue` vb.) tip/boyut/aralık denetler → çöp veri DB'ye giremez.
**Neden kurallar = güvenlik sınırı:** Client doğrudan Firestore'a yazıyor; tek gerçek savunma hattı bu kurallar. Backend CRUD yok, dolayısıyla kurallar zayıfsa her şey açık.

### 3. Sunucu tarafı kimlik + uygulama kapısı
- `generateAgoraToken`: `context.auth` yoksa reddeder → anonim kullanıcı görüntülü görüşmeye giremez.
- **App Check:** İstemci `main.dart`'ta `FirebaseAppCheck.instance.activate` ile etkinleşir (debug→debug provider, release→Android Play Integrity / iOS DeviceCheck). `generateAgoraToken`, `APP_CHECK_ENFORCE=true` iken `context.app` yoksa reddeder → **yalnızca gerçek uygulama** token alabilir, sahte/script istemci Agora dakikalarını yakamaz (bkz. [[09-Rate-Limiting]]).
  - **Güvenli kullanıma alma:** Bayrak önce `false` (Console'da metrik izle) → meşru trafik token taşıyınca `true`. Bayrak yokken zorlama yapılmaz (uygulama kırılmaz).
  - **ENFORCE AKTİF — *2026-06-28*:** `APP_CHECK_ENFORCE=true` yapıldı + functions deploy edildi. `generateAgoraToken` artık App Check token'ı olmayan istekleri reddediyor. Debug cihaz token'ı (`6d5dd0ce-…`) Console'a kayıtlı → debug build çalışır.
  - **Build ayrımı (kritik):** **Debug build** = debug provider → kayıtlı debug token → çalışır. **Release build** = Play Integrity → Play Console/Play Integrity kurulumu gerekir (henüz YOK) → enforce altında token alamaz. Yayın öncesi Play Integrity kurulmalı (aşağıdaki TODO, Faz 5).
  - **Firestore ENFORCE — AKTİF (*2026-06-28*):** Console'dan Cloud Firestore zorlaması açıldı (App Check → APIs → Cloud Firestore → Enforce) + debug token kayıtlı. **Doğrulama testi (debug build):** çağrı oluşturuldu → istemci `✅ Agora token alındı`, sunucu log'u `{"verifications":{"app":"VALID","auth":"VALID"}}` + `status 200` → **Firestore enforce + Agora token akışı bozulmadı.** Hiç `failed-precondition`/ret uyarısı yok. Debug token kayıtlı olduğu sürece debug build güvenli.

## MVP Kapsamı
**VAR:**
- Sertifika sunucu-tarafı izolasyonu
- Kapsamlı Firestore kuralları + domain validator'lar
- **Çağrı durum makinesi yetki kilidi** (`isCagriClaim`/`isCagriComplete`) — çağrı kapma yarışı + geri dönüş + üçüncü taraf müdahalesi engellenir
- Token fonksiyonunda auth kapısı
- HTTPS (Firebase/Agora varsayılan, taşımada şifreleme)

> ⚠️ **Deploy gerekli:** Bu kural değişikliği canlıya `npx firebase-tools deploy --only firestore:rules` ile çıkmadan etkili olmaz. Deploy öncesi emulator ile doğrula (bkz. [[07-CI-CD]]).

**VAR (madde 3'e ek):**
- **Firebase App Check — ENFORCE AKTİF** (*2026-06-28*): istemci aktif + sunucu `generateAgoraToken` zorlaması açık (`APP_CHECK_ENFORCE=true`, deploy edildi) + **Cloud Firestore Console'dan Enforce** + debug token Console'da kayıtlı (bkz. [[09-Rate-Limiting]]). Debug build'de doğrulandı (çağrı token akışı `app:VALID`, status 200). Kalan: yalnızca release için Play Integrity (Faz 5).

**YOK:**
- E-posta doğrulama zorunluluğu (sahte hesap riski)
- İçerik moderasyonu (yorum/mekânda kötü/yasa dışı içerik)
- Penetrasyon testi / güvenlik denetimi
- Çağrı kötüye kullanım tespiti (spam çağrı engeli)

## Açık Sorular
- ~~**App Check** olmadan biri token fonksiyonunu otomatik çağırıp dakika tüketebilir.~~ **ÇÖZÜLDÜ — ENFORCE AKTİF + DOĞRULANDI** (*2026-06-28*): istemci + sunucu zorlaması (`APP_CHECK_ENFORCE=true`, deploy) + Firestore Console Enforce + debug token kayıtlı; debug build çağrı testi geçti (`app:VALID`). Açık kalan: yalnızca release için Play Integrity kurulumu (Faz 5).
- KVKK: konum + engellilik durumu **özel nitelikli kişisel veri**. Açık rıza, saklama süresi, silme talebi akışı var mı? (silme yasak ile çelişiyor!)
- KVKK ↔ gözlemlenebilirlik: Crashlytics + Analytics eklendi (*2026-06-28*, bkz. [[12-Loglama]]). Teknik tarafta veri **anonim** (parametresiz event, `setUserIdentifier` yok, debug'da toplama kapalı) ama **aydınlatma/rıza metninde bu veri toplama bildirilmeli.**
- Yorumlarda hakaret/yanlış erişilebilirlik bilgisi → moderasyon yokken sorumluluk kimde?
- `.env` mobil binary'den çıkarılabilir; Foursquare key sızarsa kota riski.

## TODO
- [x] **Firebase App Check** entegre et (istemci `activate` + `generateAgoraToken` env-bayraklı zorlama) — *2026-06-28*
- [x] App Check'i Console'da kaydet + debug token ekle + `APP_CHECK_ENFORCE=true` + functions deploy — *2026-06-28*
- [x] Firestore App Check enforce'u Console'dan aç (App Check → APIs → Cloud Firestore → Enforce) — *2026-06-28*; debug build çağrı testiyle doğrulandı (`app:VALID`, status 200)
- [ ] **🚀 FAZ 5 — Yayın öncesi yapılacaklar (Play Integrity, release build için ZORUNLU):** Şu an uygulanmadı; release build enforce altında token alamaz. Yayından önce:
  - [ ] Gerçek paket adını belirle (`com.example.asikar_engelsiz_kent_rehberi` → nihai uygulama kimliği) ve `android/app/build.gradle.kts` `applicationId` + Firebase Console Android app kaydını buna göre güncelle
  - [ ] Uygulamayı Google Play Console'a kaydet ve Firebase projesini Play Console'a bağla (App Check Play Integrity sağlayıcısı bunu gerektirir)
  - [ ] Release imzalama anahtarının **SHA-256** parmak izini al (`keytool -list -v -keystore <release.keystore>`) ve Firebase Console → Project Settings → Android app'e ekle
  - [ ] Firebase Console → App Check → Android app → **Play Integrity** sağlayıcısını etkinleştir
  - [ ] Bir internal/closed test track'i ile release build'de `generateAgoraToken` token akışını doğrula (debug'daki `app:VALID` doğrulamasının release karşılığı)
- [ ] Node.js 20 runtime → daha yeni sürüme yükselt (2026-10-30'da decommission, bkz. [[02-API-Arka-Uc]])
- [ ] KVKK: aydınlatma metni + rıza + "verimi sil" talebi süreci (silme yasağıyla uyumlu çözüm: anonimleştirme) — aydınlatma metni **Crashlytics + Analytics** veri toplamayı da kapsamalı (bkz. [[12-Loglama]])
- [ ] Firestore kurallarını emulator ile test et → [[07-CI-CD]]
- [ ] Yorum için basit moderasyon (küfür filtresi / şikayet butonu) değerlendir
- [ ] `.gitignore` sır kapsamını doğrula

---

## İlgili Notlar
- [[Architecture-Overview]] — güvenlik sınırının sistemdeki yeri
- [[PRD]] — token güvenlik gereksinimi
- [[02-API-Arka-Uc]] — sertifika sunucu-tarafı izolasyonu
- [[03-Veritabani]] — Firestore kuralları = güvenlik sınırı
- [[04-Auth]] — kuralların kimlik ön koşulu
- [[06-Bulut]] — sır/erişim yönetimi
- [[07-CI-CD]] — sır/kural deploy güvenliği
- [[09-Rate-Limiting]] — App Check ortak koruması
- [[12-Loglama]] — KVKK log gizliliği
- [[13-Recovery]] — sır/keystore yedeği
