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

## MVP Kapsamı
**VAR:**
- Manuel deploy komutları (dokümante — bkz. proje README)
- (Önerilen) GitHub Actions ile lint + test on push

**YOK:**
- Otomatik mağaza yükleme (elle yapılır)
- Otomatik Firestore rules/functions deploy (elle, dikkatle)
- Çoklu ortam promosyonu (dev→staging→prod)
- Release versiyonlama otomasyonu / changelog
- E2E test pipeline'ı

## Açık Sorular
- Firestore kuralları için **emulator + test** CI'a eklenmeli mi? (yanlış kural = veri sızıntısı; en yüksek getirili otomasyon bu olabilir)
- Keystore kaybı = Android güncellemesi imkânsız; CI dışında nerede yedekleniyor? → [[13-Recovery]]
- Tek geliştirici hastalanırsa/ayrılırsa deploy bilgisi (hesaplar, sırlar) nasıl devredilir?

## TODO
- [ ] GitHub Actions: `flutter analyze` + `flutter test` workflow ekle (en ucuz kazanç)
- [ ] Firestore rules için emulator testi yaz ve CI'a bağla
- [ ] `.gitignore`'da `.env`, `*.keystore`, `functions/.env` olduğunu doğrula → [[08-Guvenlik]]
- [ ] Keystore ve sırların güvenli yedeğini al → [[13-Recovery]]

---

## İlgili Notlar
- [[Architecture-Overview]] — CI/CD katmanının önceliği (stub)
- [[05-Barindirma]] — mağaza/web dağıtım hedefi
- [[06-Bulut]] — deploy edilen proje
- [[08-Guvenlik]] — sır/kural deploy güvenliği
- [[13-Recovery]] — keystore/sır yedeği
