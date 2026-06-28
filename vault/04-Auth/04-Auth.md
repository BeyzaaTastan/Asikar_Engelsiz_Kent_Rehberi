---
katman: Auth
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[03-Veritabani]], [[08-Guvenlik]], [[01-On-Yuz]]
---

# 04 · Auth (Kimlik Doğrulama)

## Neden önemli
Auth, hem güvenlik kurallarının hem de çağrı sahipliğinin (`caller_uid`, `volunteer_uid`) dayandığı temeldir. Atlanırsa Firestore kuralları (`isOwner`, `uidMatchesAuth`) çöker ve herkes herkesin verisine erişir.

## Karar (ne + NEDEN)
**Ne:** **Firebase Authentication** — E-posta/şifre + Google ile giriş.

**Neden Firebase Auth:**
- Firestore güvenlik kurallarıyla aynı `auth.uid` evreninde → kural yazımı sıfır ek altyapıyla çalışır.
- Ücretsiz katman cömert (aylık on binlerce aktif kullanıcı).
- Google Sign-In + e-posta hazır gelir; kendi şifre saklama/sıfırlama altyapısı kurma derdi yok (güvenlik riski de yok).

**Akış:**
- `registerWithEmail` → `createUserWithEmailAndPassword` + `updateDisplayName`
- `signInWithGoogle` → `GoogleSignIn.authenticate()` → `signInWithCredential`
- `signOut` → **önce** FCM token Firestore'dan silinir, **sonra** Google + Firebase çıkışı. **Neden bu sıra:** çıkış yapan cihaza yanlışlıkla çağrı push'u gitmesin.
- `AuthException` ile Türkçe, kullanıcı-dostu hata mesajları.

**Kullanıcı tipi yönlendirmesi (`MainWrapper`):**
1. `authStateChanges()` → giriş yoksa `LoginScreen`.
2. `users/{uid}` dinlenir → belge yoksa `UserTypeScreen` (kayıt anketi).
3. `isVolunteer:true` → `volunteers` topic'e abone + `VolunteerHomeScreen`.
4. `userType:"Özel Gereksinimli"` → `DisabledHomeScreen`, diğer → `StandardHomeScreen`.

**Kritik bağ:** Auth UID, hem `users` belge anahtarı hem çağrı sahipliği hem de FCM token'ın bağlandığı yer.

## MVP Kapsamı
**VAR:**
- E-posta + Google giriş/kayıt/çıkış
- Auth durumuna göre yönlendirme
- Türkçe hata mesajları
- Çıkışta FCM token temizliği

**YOK:**
- Telefon/SMS ile giriş (maliyet + Sakarya'da gereksiz)
- E-posta doğrulama zorunluluğu (MVP'de sürtünmeyi azaltmak için kapalı)
- Şifre sıfırlama UI'ı (Firebase mevcut ama ekran bağlanmamış olabilir — kontrol et)
- Rol/yetki sistemi (admin yok; herkes standart kullanıcı)
- Apple ile giriş (iOS App Store şartı olabilir — bkz. açık soru)

## Açık Sorular
- iOS'ta Google Sign-In sunuluyorsa App Store **"Sign in with Apple"** zorunluluğunu tetikler. iOS yayını için Apple giriş eklenmeli mi?
- E-posta doğrulaması olmadan sahte hesap riski; gönüllü kötüye kullanımına karşı yeterli mi?
- Şifre sıfırlama akışı UI'da bağlı mı? (kullanıcı şifre unutursa ne olur?)
- KVKK: kayıt anketinde toplanan veriler için açık rıza/aydınlatma metni var mı?

## TODO
- [ ] iOS yayını öncesi "Sign in with Apple" kararını netleştir
- [ ] Şifre sıfırlama ekranını doğrula/ekle
- [ ] Kayıt akışına KVKK aydınlatma + onay kutusu ekle → [[PRD]]
- [ ] E-posta doğrulamayı en azından gönüllüler için zorunlu kılmayı değerlendir

---

## İlgili Notlar
- [[Architecture-Overview]] — kimlik katmanının sistemdeki yeri
- [[PRD]] — giriş + kullanıcı tipi gereksinimi
- [[01-On-Yuz]] — login ve yönlendirme UI'ı
- [[02-API-Arka-Uc]] — token üretiminin auth kapısı
- [[03-Veritabani]] — UID sahiplik temeli
- [[06-Bulut]] — Firebase Auth servisi
- [[08-Guvenlik]] — güvenlik kurallarının ön koşulu
