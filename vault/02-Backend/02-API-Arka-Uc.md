---
katman: API & Arka Uç
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[03-Veritabani]], [[04-Auth]], [[08-Guvenlik]], [[06-Bulut]]
---

# 02 · API & Arka Uç (Backend)

## Neden önemli
Backend, client'ın yapmaması gereken iki şeyi yapar: gizli sertifikayla Agora token üretmek ve çağrıyı gönüllülere fan-out etmek. Atlanırsa ya App Certificate client'a sızar (güvenlik felaketi) ya da çağrı bildirimi hiç gitmez (ürün çalışmaz).

## Karar (ne + NEDEN)
**Ne:** **Firebase Cloud Functions (Node.js)**, bölge `europe-west3`. Kendi sunucu yok. **3 fonksiyon** (2 çekirdek + 1 scheduled güvenlik ağı):

### 1. `cagriBildirimiGonder` (Firestore trigger)
- **Tetikleyici:** `cagrilar/{cagriId}` `onWrite`
- **İşlev:** `cagri_durumu == 'bekliyor'` olunca FCM topic'ine `data` mesajı yollar (`type:'call'`, `caller_name`, `channel_name`).
- **Çağrı tipine göre topic seçimi (UYGULANDI — 2026-07-02):** Çağrının `cagri_tipi` alanına göre hedef topic seçilir. **`fiziksel`** (yerinde yardım/şehir rehberliği) → yalnızca `volunteers_<sehir>` (aynı şehirdeki gönüllüler; yerinde bulunmayan gönüllüye gitmesi anlamsız). **`uzaktan`** (görüntülü destek) → global `volunteers` (konumdan bağımsız herkes). Fiziksel ama `sehir` yok/geçersizse çağrı kaybolmasın diye global'e düşülür (slug regex `^[a-z0-9_-]{1,60}$` sunucuda da doğrulanır). Şehir adı topic-güvenli slug'a çevrilir (`lib/utils/city_slug.dart`, saf/birim testli `test/unit/city_slug_test.dart`); istemcinin iki tarafı (arayan + gönüllü aboneliği) aynı slug'ı üretir. Pilotta herkes Sakarya → doğal olarak `volunteers_sakarya`/`volunteers`; ileri-uyumlu. Şehir kaynağı **anlık GPS** (reverse-geocode, `lib/services/city_lookup_service.dart`; bkz. [[11-Olcekleme]], [[03-Veritabani]]). ⚠️ **Deploy gerekli:** `firebase deploy --only functions,firestore:rules`.
- **Çift tetikleme önlemi:** `wasWaiting && isWaiting` kontrolü → aynı çağrı iki kez bildirilmez.
- **Kanal güvencesi:** `channel_name` = `kanal_adi` (= çağrı belge ID'si). `kanal_adi` yok/boşsa **bildirim gönderilmez** (eski `|| 'yardim_kanali'` sabit fallback'i kaldırıldı). **Neden:** Paylaşılan sabite düşmek, eşzamanlı çağrılarda iki ayrı çağrının aynı Agora kanalına bağlanmasına (yanlış görüşme) yol açıyordu. İstemci tarafı da aynı kuralı uygular: geçersiz kanallı çağrı gösterilmez/kabul edilmez (`validChannelName`, saf/test edilebilir → `lib/utils/channel_validator.dart`, birim testiyle korunur — bkz. [[01-On-Yuz]], [[07-CI-CD]]).
- **Push ayarı:** `android.priority:'high'`, `ttl:30000`, `apns contentAvailable:true`, `apns-priority:'10'` → kilitli ekranda bile çalsın.

### 1b. `cagriZamanAsimiTemizle` (Scheduled — pubsub `every 1 minutes`)
- **İşlev:** `cagri_durumu == 'bekliyor'` olan çağrıları çeker; `zaman`'ı **90 sn**'den eski olanları (terk edilmiş) `'zaman_asimi'` yapar (batch).
- **Neden:** Birincil zaman aşımı **istemcide** (CallScreen, 45 sn) — kullanıcı anında "gönüllü bulunamadı" görür. Bu fonksiyon yalnızca **arayan uygulaması kapandığında** ortada kalan çağrıları temizler; böylece gönüllüler terk edilmiş çağrı görmez.
- **Index notu:** Bileşik index gerektirmemek için yalnızca `bekliyor` eşitlik sorgusu yapılır, zaman eşiği bellek içinde filtrelenir (tek şehir → bekleyen çağrı az). admin SDK kuralları atlar.

### 2. `generateAgoraToken` (HTTPS Callable)
- **Güvenlik kapısı:** `context.auth` yoksa token YOK. Anonim çağrı reddedilir.
- **Katılımcı kapısı (mahremiyet — *2026-06-29*):** `channelName == cagriId`. Token üretiminden önce admin SDK ile `cagrilar/{channelName}` okunur; yalnızca `auth.uid ∈ {caller_uid, volunteer_uid}` **ve** `cagri_durumu ∈ {bekliyor, cevaplandi}` iken token verilir, aksi halde `permission-denied`. **Neden:** Aksi halde herhangi bir auth+AppCheck'li kullanıcı kanal adını okuyup (`cagrilar` okuma açık) başkasının görüntülü görüşmesine girebilirdi — özel nitelikli veri ihlali (bkz. [[08-Guvenlik]], [[03-Veritabani]] durum makinesi). **Deploy gerekli:** `firebase deploy --only functions`.
- **İşlev:** `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE` ile 1 saatlik RTC token üretir.
- **Sır yönetimi:** Sertifika **yalnızca** `functions/.env`'de; client'ta asla (bkz. [[08-Guvenlik]]).

**Neden serverless / neden bu kadar az fonksiyon:**
- $0 maliyet hedefi: çağrı başına saniyelik çalışma → Blaze planında kotada pratikte ücretsiz (ulusal ölçekte de doğrusal patlamaz).
- Minimalizm: Backend'i "yapması gerekenle" sınırlamak (token + fan-out). CRUD'u Firestore + güvenlik kuralları zaten yapıyor; ekstra API yazmak gereksiz maliyet.
- Realtime/durum yönetimi client ↔ Firestore arasında; backend olaylara tepki veren ince bir katman.

**Bilinçli olarak BACKEND'DE OLMAYAN:** Mekân/yorum CRUD'u (client doğrudan Firestore'a yazıyor, kurallar denetliyor), arama (Foursquare/Overpass'a client doğrudan gidiyor).

## MVP Kapsamı
**VAR:**
- Çağrı fan-out fonksiyonu (FCM)
- Güvenli Agora token fonksiyonu (auth korumalı)
- Çağrı zaman aşımı: istemci 45 sn sayacı + scheduled güvenlik ağı (`cagriZamanAsimiTemizle`)

**VAR (2026-07-02):**
- Çağrı tipine göre topic yönlendirme (`fiziksel`→`volunteers_<sehir>`, `uzaktan`→global `volunteers`); gönüllü her iki topic'e abone. Şehir slug'ı istemcide anlık GPS'ten (bkz. [[11-Olcekleme]]).

**YOK:**
- Tek gönüllüye yönlendirme (fiziksel çağrı şehir topic'ine broadcast; şehir içi hedefli eşleştirme yok)
- Webhook/3. parti entegrasyon, REST API yüzeyi
- Sunucu tarafı içerik moderasyonu

## Açık Sorular
- ~~Çağrıya cevap gelmezse zaman aşımı?~~ **ÇÖZÜLDÜ:** istemci 45 sn sayacı (`CallScreen`) + scheduled `cagriZamanAsimiTemizle` (90 sn terk eşiği) → `zaman_asimi`. Açık kalan: süreler saha testiyle ayarlanmalı (45/90 sn varsayım).
- `volunteers` topic broadcast → 50 gönüllü aynı çağrıyı görür. ~~"İlk kapan" mantığı client transaction'a bırakılmış.~~ **Artık `firestore.rules` `isCagriClaim` geçişiyle de (bekliyor→cevaplandi tek-kazanan) sunucu-yetki düzeyinde kilitli** (bkz. [[03-Veritabani]], [[08-Guvenlik]]) ve **emulator regresyon testiyle korunuyor** (`test/firestore-rules/cagrilar_rules.test.js` — ikinci gönüllünün kapma denemesi reddedilir; bkz. [[07-CI-CD]]). Ek bir Cloud Function'a gerek kalmadı; kural yeterli. Hedefli eşleştirme yine de broadcast verimsizliğini azaltır (bkz. [[11-Olcekleme]]).
- Token TTL 1 saat; uzun çağrılarda yenileme akışı var mı?

## TODO
- [ ] `onWrite` yerine `onUpdate`/`onCreate` ayrımıyla tetikleyiciyi sadeleştir (gereksiz invocation azalt)
- [x] Scheduled function ile çağrı zaman aşımı ekle (`cagriZamanAsimiTemizle` + istemci sayacı) — *2026-06-28*
- [ ] Zaman aşımı sürelerini (45/90 sn) saha testiyle doğrula/ayarla
- [ ] Token yenileme (renew) akışını [[01-On-Yuz]] CallScreen ile koordine et
- [ ] Cloud Functions için minimum log seviyesini [[12-Loglama]]'da tanımla

---

## İlgili Notlar
- [[Architecture-Overview]] — backend'in sistemdeki yeri
- [[PRD]] — çağrı bildirimi + token gereksinimi
- [[01-On-Yuz]] — CallScreen token tüketicisi
- [[03-Veritabani]] — çağrı trigger'ının kaynağı
- [[04-Auth]] — token üretiminin auth kapısı
- [[05-Barindirma]] — serverless = sunucusuz dağıtım
- [[06-Bulut]] — fonksiyon bölgesi ve plan
- [[08-Guvenlik]] — sertifika sır yönetimi
- [[09-Rate-Limiting]] — token çağrı limiti ihtiyacı
- [[11-Olcekleme]] — fonksiyon otomatik ölçeklemesi
- [[12-Loglama]] — fonksiyon logları
- [[13-Recovery]] — sertifika/sır yedeği
