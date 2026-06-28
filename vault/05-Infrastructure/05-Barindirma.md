---
katman: Barındırma
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[06-Bulut]], [[01-On-Yuz]], [[07-CI-CD]]
---

# 05 · Barındırma (Hosting)

## Neden önemli
"Uygulama kullanıcıya nereden ulaşıyor" sorusu burada cevaplanır; mobilde bu mağaza, web'de bir sunucu/CDN demektir. Atlanırsa web sürümü yayınlanamaz ve mağaza yayın süreci (imzalama, hesaplar) son anda sürpriz olur.

## Karar (ne + NEDEN)
**Birincil dağıtım — mağaza (mobil):**
- **Android:** Google Play (App Bundle, `flutter build appbundle`). Tek seferlik 25$ geliştirici ücreti.
- **iOS:** App Store (`flutter build ios`). Apple Developer 99$/yıl — **bütçe kalemi**; yoksa iOS yayını ertelenir, TestFlight/sideload ile demo yapılır.

**İkincil — web (opsiyonel):**
- **Firebase Hosting** (`flutter build web` → `firebase deploy --only hosting`). **Neden:** Zaten Firebase ekosistemindeyiz; Hosting ücretsiz katmanı (10GB depo / 360MB gün transfer) demo için fazlasıyla yeter, üstelik global CDN + ücretsiz SSL dahil (bkz. [[10-Cache-CDN]]).

**Neden ekstra sunucu YOK:** Backend serverless ([[02-API-Arka-Uc]]), veri BaaS ([[03-Veritabani]]). Barındırılacak "kendi sunucumuz" yok → VM/konteyner maliyeti sıfır.

## MVP Kapsamı
**VAR:**
- Android App Bundle üretimi (mağaza-hazır)
- Firebase Hosting ile web demo yayını (opsiyonel ama ucuz)

**YOK:**
- iOS App Store yayını (Apple ücreti bütçeye bağlı — şimdilik **stub**)
- Özel domain + SSL (Firebase'in `*.web.app` subdomain'i yeterli)
- Çoklu ortam (staging/prod ayrı hosting siteleri)
- Play Store içi sürüm yönetimi (internal/closed testing track'leri)

## Açık Sorular
- iOS yayını bu proje kapsamında mı, yoksa Android + web demo yeterli mi? (99$/yıl kararı)
- Web "ikincil" — çağrı/harita web'de çalışıyor mu, yoksa web sadece tanıtım sayfası mı? (bkz. [[01-On-Yuz]] açık sorusu)
- Play Store yayını için gizlilik politikası URL'i gerekiyor; nerede barındırılacak? (Firebase Hosting'de statik sayfa olabilir)

## TODO
- [ ] Android imzalama anahtarı (keystore) oluştur ve güvenli sakla (kaybolursa güncelleme yapılamaz)
- [ ] Gizlilik politikası + KVKK metnini statik sayfa olarak Firebase Hosting'e koy
- [ ] iOS yayın kararını [[Architecture-Overview]] önceliğiyle netleştir
- [ ] `flutter build web` çıktısını test ortamında doğrula

---

## İlgili Notlar
- [[Architecture-Overview]] — barındırma katmanının önceliği
- [[01-On-Yuz]] — dağıtılan uygulamanın kendisi
- [[02-API-Arka-Uc]] — serverless = ek sunucu yok
- [[03-Veritabani]] — BaaS = barındırılan veri
- [[06-Bulut]] — Firebase Hosting platformu
- [[07-CI-CD]] — mağaza/web dağıtım hattı
- [[10-Cache-CDN]] — Hosting CDN/edge cache
