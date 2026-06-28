---
katman: Genel Bakış
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[Vision]], [[Architecture-Overview]], [[03-Veritabani]], [[04-Auth]]
---

# PRD — Ürün Gereksinim Dokümanı

## Neden önemli
PRD, "ne inşa ediyoruz"u tek bir referans noktasına bağlar; aksi halde her ekran ayrı bir yorumla yapılır ve katmanlar (auth → veri → UI) birbirini tutmaz. Atlanırsa kabul kriteri olmadığı için "bitti mi" sorusunun objektif cevabı kalmaz.

## Karar (ne + NEDEN)

### Aktörler ve temel akışlar
| Aktör | Birincil ihtiyaç | Kritik akış |
|---|---|---|
| Özel Gereksinimli birey | Anlık yardım | YARDIM İSTE → gönüllüyle görüntülü görüşme |
| Gönüllü | Çağrıya ulaşmak | FCM push → CallKit → CallScreen |
| Sakin / Turist | Erişilebilir mekân keşfi | Harita/Liste → mekân detay → yorum |

### Fonksiyonel gereksinimler (MVP)
1. **Kimlik:** E-posta + Google ile giriş; kullanıcı tipi seçimi zorunlu (bkz. [[04-Auth]]).
2. **Çağrı:** Engelli kullanıcı UUID'li çağrı oluşturur → `cagrilar` koleksiyonu → Cloud Function FCM topic'e yollar (bkz. [[02-API-Arka-Uc]]).
3. **Görüntülü görüşme:** Agora kanalına her iki taraf katılır; token sunucudan alınır (bkz. [[08-Guvenlik]]). **Zaman aşımı:** 45 sn içinde gönüllü gelmezse çağrı `zaman_asimi` olur, arayana "gönüllü bulunamadı" gösterilir (bkz. [[02-API-Arka-Uc]]).
4. **Mekân & skor:** Mekân ekleme + yorum → transaction ile skor yeniden hesaplanır (bkz. [[03-Veritabani]]).
5. **POI keşfi:** Harita üzerinde Foursquare + Overpass POI'leri; kategori filtresi (bkz. [[10-Cache-CDN]]).
6. **Rota / yol tarifi:** Mekâna OSRM tabanlı yaya/araç rotası; mesafe + süre gösterimi (bkz. [[01-On-Yuz]] · `route_screen`). *Tekerlekli sandalyeye özel rota profili henüz yok — açık konu.*
7. **Erişilebilirlik:** Yazı boyutu, yüksek kontrast, karanlık mod, ses; `SharedPreferences`'ta kalıcı.

### Fonksiyonel olmayan gereksinimler
- **Erişilebilirlik:** Tüm kritik butonlarda `Semantics` etiketi; TalkBack/VoiceOver ile kullanılabilir olmalı.
- **Gecikme:** Çağrı oluşturma → gönüllü telefonunun çalması hedefi < 5 sn (FCM `priority: high`, `ttl: 30s`).
- **Maliyet:** Aylık altyapı maliyeti ~0 ₺ hedefi (ücretsiz katmanlar — bkz. [[06-Bulut]]).
- **Platform:** Android + iOS birincil, Web ikincil.

## MVP Kapsamı
**VAR:** Yukarıdaki 7 fonksiyonel gereksinimin tamamı.
**YOK:** Çağrı geçmişi, gönüllü itibar sistemi, push üzerinden mekân önerisi, admin moderasyon paneli.

## Açık Sorular
- ~~Çağrıya hiçbir gönüllü cevap vermezse zaman aşımı?~~ **ÇÖZÜLDÜ:** 45 sn (istemci) + 90 sn terk eşiği (sunucu) → `zaman_asimi`; arayana "gönüllü bulunamadı" + "Tekrar Dene". Süreler saha testiyle ayarlanacak.
- Aynı anda iki engelli kullanıcı çağrı açarsa gönüllü hangisini görür? (FCM topic herkese gider.) *Not: Aynı çağrıyı iki gönüllünün kapması artık çözüldü — `runTransaction` + `firestore.rules` `isCagriClaim` (bkz. [[03-Veritabani]], [[08-Guvenlik]]). Açık kalan: birden çok eşzamanlı **farklı** çağrının gönüllü UI'ında nasıl listeleneceği.*
- Yorum/mekân için içerik moderasyonu MVP'de yok; KVKK/içerik riski kabul mü?

## TODO
- [ ] Her akış için kabul kriteri (Given/When/Then) yaz
- [x] Çağrı zaman aşımı davranışını tanımla ve uygula (istemci 45sn + scheduled 90sn) — *2026-06-28*
- [x] "Çağrı kapma yarışı"nı transaction + güvenlik kuralıyla çöz (bkz. [[03-Veritabani]], [[08-Guvenlik]]) — *2026-06-28*

---

## İlgili Notlar
- [[Architecture-Overview]] — gereksinimlerin mimari karşılığı
- [[Vision]] — gereksinimlerin türediği vizyon
- [[01-On-Yuz]] — akışların UI/ekran karşılığı
- [[02-API-Arka-Uc]] — çağrı bildirimi + token gereksinimi
- [[03-Veritabani]] — mekân/skor/çağrı veri gereksinimi
- [[04-Auth]] — kimlik + kullanıcı tipi gereksinimi
- [[08-Guvenlik]] — Agora token güvenlik gereksinimi
- [[10-Cache-CDN]] — POI keşfi performans gereksinimi
- [[12-Loglama]] — başarı metriklerini ölçer
