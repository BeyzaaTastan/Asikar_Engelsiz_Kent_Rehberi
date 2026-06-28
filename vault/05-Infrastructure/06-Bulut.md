---
katman: Bulut
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[02-API-Arka-Uc]], [[03-Veritabani]], [[04-Auth]], [[08-Guvenlik]]
---

# 06 · Bulut (Cloud Platform)

## Neden önemli
Bulut, tüm omurganın (auth, veri, fonksiyon, push) üzerinde durduğu zemindir; proje, bölge ve plan seçimi maliyeti ve gecikmeyi belirler. Atlanırsa yanlış bölge (yüksek gecikme), yanlış plan (beklenmedik fatura) veya KVKK uyumsuzluğu (yanlış kıta) sonradan düzeltilmesi pahalı kararlar olur.

## Karar (ne + NEDEN)
**Ne:** **Firebase / Google Cloud Platform** — proje `asikar-engelsiz-kent-rehberi`.

**Bölge:** **`europe-west3` (Frankfurt)** tüm Cloud Functions için.
**Neden bu bölge:**
- Türkiye'ye coğrafi yakınlık → çağrı bildirimi ve token üretiminde düşük gecikme.
- AB içinde → KVKK/GDPR açısından veri ikametgâhı savunulabilir.
- `us-central1`'e göre Türkiye trafiğinde belirgin daha düşük RTT.

**Plan:** **Blaze (kullandıkça öde)** — ama düşük kullanımda pratikte ücretsiz.
**Neden Blaze (Spark değil):** Cloud Functions **Blaze gerektirir** (Spark'ta deploy edilemez). Blaze'in ücretsiz kotaları Spark ile aynı; tek şehir trafiğinde fatura ~0 ₺.
**Düşük bütçe koruması:** GCP **bütçe alarmı** (örn. aylık 5$/10$ eşik) kurulmalı → beklenmedik kullanımda e-posta uyarısı.

**Kullanılan yönetilen servisler:**
| Servis | Rol | Maliyet profili |
|---|---|---|
| Firebase Auth | Kimlik | Ücretsiz katman bol |
| Cloud Firestore | Veri + realtime | Okuma/yazma kotası |
| Cloud Functions | Backend | Çağrı başına saniyelik |
| Cloud Messaging (FCM) | Push | Tamamen ücretsiz |
| Firebase App Check | Uygulama doğrulama | Ücretsiz |
| Firebase Crashlytics | Çökme/hata raporu | Tamamen ücretsiz |
| Firebase Analytics | Ürün funnel metrikleri | Tamamen ücretsiz |
| Firebase Hosting | Web (ops.) | Ücretsiz katman |

**3. parti (Firebase dışı, ama "bulut" bağımlılığı):** Agora RTC (aylık 10.000 ücretsiz dakika), Foursquare Places (ücretsiz tier), OSM (ücretsiz, kullanım politikasına tabi). Bunlar dış servis → tek bulut sağlayıcıya kilitli değiliz.

## MVP Kapsamı
**VAR:**
- Tek GCP/Firebase projesi (prod)
- europe-west3 fonksiyon bölgesi
- Blaze plan + (kurulması gereken) bütçe alarmı

**YOK:**
- Ayrı dev/staging/prod projeleri (tek geliştirici, tek proje — bilinçli)
- Çoklu bölge / failover
- IaC (Terraform) — yapılandırma elle/Firebase CLI ile
- VPC/özel ağ (gereksiz; serverless)

## Açık Sorular
- GCP bütçe alarmı kurulu mu? (kurulu değilse kötü niyetli kullanım/bug fatura riski yaratır)
- Tek proje hem geliştirme hem demo'ya hizmet ediyor → test verisi prod'u kirletiyor mu?
- Agora/Foursquare ücretsiz kotaları aşılırsa fatura kime kesilir, kart bağlı mı?
- Firestore verisinin fiziksel konumu europe (multi-region) mu, yoksa belirli bir yer mi? KVKK kaydı için netleşmeli.

## TODO
- [ ] GCP bütçe alarmını (5$ / 10$ eşik) kur — **bu hafta**
- [ ] Tüm 3. parti servislerin ücretsiz kota limitlerini tabloya yaz → [[09-Rate-Limiting]]
- [ ] En azından `dev` için ayrı Firebase projesi açmayı değerlendir
- [ ] Firestore veri konumunu doğrula ve KVKK notu düş

---

## İlgili Notlar
- [[Architecture-Overview]] — bulut omurgasının sistemdeki yeri
- [[Vision]] — düşük bütçe Firebase tercihinin dayanağı
- [[02-API-Arka-Uc]] — Cloud Functions'ı barındırır
- [[03-Veritabani]] — Firestore'u barındırır
- [[04-Auth]] — Firebase Auth'u barındırır
- [[05-Barindirma]] — Firebase Hosting platformu
- [[07-CI-CD]] — deploy hedef projesi
- [[08-Guvenlik]] — sır/erişim yönetimi
- [[09-Rate-Limiting]] — bütçe alarmı koruması
- [[11-Olcekleme]] — otomatik ölçek zemini
- [[12-Loglama]] — Cloud Functions logları
- [[13-Recovery]] — hesap/proje kurtarma
