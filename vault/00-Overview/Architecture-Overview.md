---
katman: Genel Bakış
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[Vision]], [[PRD]]
---

# Architecture Overview

## Neden önemli
Bu not, 13 katmanın birbirine nasıl bağlandığını ve hangisinin şu an "tam" hangisinin "stub" olduğunu tek ekranda gösterir. Atlanırsa $0 maliyet disiplininde kritik olmayan bir katmana emek harcanır, kritik olan (auth/güvenlik) eksik kalır.

> **Bağlam (2026-07-01, O12):** Proje **bitirme → canlı production** ve **tek şehir → Türkiye geneli (Sakarya pilotu)** kapsamına taşındı. Aşağıdaki öncelik tablosu bu geçişe göre okunmalı; "tek şehir olduğu için stub" gerekçeleri artık **pilot sonrası tetiğe** dönüştü (bkz. [[Vision]], [[11-Olcekleme]]).

## Karar (ne + NEDEN)

### Sistem topolojisi
```
[Flutter App (Android/iOS/Web)]
        │  HTTPS / WebSocket
        ├──> Firebase Auth ........... kimlik
        ├──> Cloud Firestore ......... veri + realtime + çağrı durumu
        ├──> Cloud Functions ......... FCM tetikleyici + Agora token
        ├──> Firebase Cloud Messaging  push / çağrı bildirimi
        ├──> Agora RTC ............... görüntülü görüşme (P2P/SFU)
        ├──> Foursquare Places v3 .... POI / iş yeri (ücretsiz tier)
        ├──> OSM Overpass + tiles .... harita + POI + erişilebilirlik tag'leri (ücretsiz)
        ├──> OSRM routing ............ yaya/araç rota (routing.openstreetmap.de + project-osrm)
        └──> Nominatim ............... adres/metin arama (ücretsiz)
```

> POI katmanı **hibrit**: Foursquare (güncel iş yeri) + Overpass (bedava + erişilebilirlik tag'leri) paralel çekilir, Foursquare-öncelikli birleştirilir. Detay: [[10-Cache-CDN]], [[01-On-Yuz]], [[03-Veritabani]].

**Mimari tarz:** Sunucusuz (serverless) + BaaS. Kendi sunucumuz yok; Firebase yönetilen servisleri kullanılır. **Neden:** Kalıcı $0/düşük katman maliyet disiplini + küçük ekip. Sunucu işletmek (VM, ölçekleme, yama) hem para hem zaman ister; BaaS bunları devralır ve ulusal ölçeğe otomatik ölçeklenir → Türkiye geneli hedefiyle uyumlu.

**Bölge:** `europe-west3` (Frankfurt) — Türkiye'ye en yakın düşük gecikmeli Google Cloud bölgesi, KVKK açısından AB içinde.

### Katman → klasör eşlemesi
- [[01-On-Yuz]] (Frontend)
- [[02-API-Arka-Uc]] (Backend)
- [[03-Veritabani]] (Data)
- [[04-Auth]] (Auth)
- [[05-Barindirma]], [[06-Bulut]], [[07-CI-CD]] (Infrastructure)
- [[08-Guvenlik]], [[09-Rate-Limiting]] (Security)
- [[10-Cache-CDN]], [[11-Olcekleme]] (Performance)
- [[12-Loglama]], [[13-Recovery]] (Reliability)

## ÖNCELİK TABLOSU (13 katman)

| # | Katman | MVP'de mi? | Gerekçe | tam / stub |
|---|---|---|---|---|
| 1 | Ön Yüz ([[01-On-Yuz]]) | ✅ Evet | Ürünün kendisi; kullanıcı buradan her şeyi yapıyor | **tam** |
| 2 | API & Arka Uç ([[02-API-Arka-Uc]]) | ✅ Evet | Çağrı bildirimi + Agora token + zaman aşımı sunucu tarafı zorunlu | **tam** (3 fonksiyon) |
| 3 | Veritabanı ([[03-Veritabani]]) | ✅ Evet | Tüm durum (kullanıcı, çağrı, mekân) Firestore'da | **tam** |
| 4 | Auth ([[04-Auth]]) | ✅ Evet | Kimlik olmadan çağrı/güvenlik kuralı çalışmaz | **tam** |
| 5 | Barındırma ([[05-Barindirma]]) | 🟡 Kısmi | Mobil = mağaza; web ikincil. Hosting opsiyonel | **stub** (web için) |
| 6 | Bulut ([[06-Bulut]]) | ✅ Evet | Firebase/GCP projesi = tüm omurga | **tam** |
| 7 | CI/CD ([[07-CI-CD]]) | 🟡 Kısmi | Tek geliştirici elle deploy edebilir; otomasyon lüks | **stub** |
| 8 | Güvenlik ([[08-Guvenlik]]) | ✅ Evet | Firestore rules + sır yönetimi MVP'de pazarlık dışı | **tam** |
| 9 | Rate Limiting ([[09-Rate-Limiting]]) | 🟡 Kısmi | Foursquare debounce var; sunucu tarafı koruma eksik | **stub** |
| 10 | Cache/CDN ([[10-Cache-CDN]]) | 🟡 Kısmi | POI cache + OSM tile cache var; bilinçli minimal | **stub** |
| 11 | Ölçekleme ([[11-Olcekleme]]) | 🟡 Kısmi | Firestore/Functions/Agora otomatik ölçekler; POI taban katmanı Türkiye geneli canlı. **Açık sınır:** FCM topic broadcast → Türkiye geneli açılırken şehir bazlı segmentasyon şart | **stub → pilot sonrası tam** |
| 12 | Loglama ([[12-Loglama]]) | ✅ Evet | Crashlytics + Analytics funnel eklendi (*2026-06-28*); çağrı yaşam döngüsü ölçülüyor | **tam** (çekirdek gözlemlenebilirlik) |
| 13 | Recovery ([[13-Recovery]]) | 🟡 Kısmi | Veri kaybı = itibar kaybı; ama tam DR pahalı | **stub** |

**Özet:** **Tam** olanlar 1-2-3-4-6-8 (çekirdek) + 12 (gözlemlenebilirlik, *2026-06-28*). Geri kalanı bilinçli **stub** — Sakarya pilotu için "yeterince iyi"; Türkiye geneli açılımında özellikle 11 (ölçekleme/segmentasyon) tam'a taşınır.

## MVP Kapsamı
**VAR:** Çekirdek 6 katman tam, diğer 7 katman çalışır-stub.
**YOK:** Mikroservis ayrımı, çoklu bölge, dedike CDN, otomatik DR.

## Açık Sorular
- Web platformu gerçekten gerekli mi, yoksa sadece demo için mi? (Hosting kararını belirler)
- ~~Crashlytics MVP'ye sığar mı yoksa launch sonrası mı?~~ **Eklendi** (*2026-06-28*, ücretsiz — bkz. [[12-Loglama]]).

## TODO
- [ ] Her stub katman için "ne zaman tam'a geçilir" tetik koşulu yaz
- [ ] Topoloji diyagramını görsel hale getir (Excalidraw/Mermaid)

---

## İlgili Notlar
- [[Vision]] — ürün vizyonu, mimarinin çıkış noktası
- [[PRD]] — gereksinimler, katman önceliklerini belirler
- [[01-On-Yuz]] — Frontend katmanı (çekirdek/tam)
- [[02-API-Arka-Uc]] — Backend katmanı (çekirdek/tam)
- [[03-Veritabani]] — veri katmanı (çekirdek/tam)
- [[04-Auth]] — kimlik katmanı (çekirdek/tam)
- [[05-Barindirma]] — barındırma katmanı (kısmi/stub)
- [[06-Bulut]] — bulut omurgası (çekirdek/tam)
- [[07-CI-CD]] — dağıtım otomasyonu (stub)
- [[08-Guvenlik]] — tek güvenlik sınırı (çekirdek/tam)
- [[09-Rate-Limiting]] — kota koruması (stub)
- [[10-Cache-CDN]] — önbellek katmanı (stub)
- [[11-Olcekleme]] — ölçekleme katmanı (stub)
- [[12-Loglama]] — gözlemlenebilirlik (tam, *2026-06-28*)
- [[13-Recovery]] — yedekleme/kurtarma (stub)
