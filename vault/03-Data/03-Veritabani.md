---
katman: Veritabanı
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[04-Auth]], [[08-Guvenlik]], [[02-API-Arka-Uc]], [[13-Recovery]], [[10-Cache-CDN]], [[01-On-Yuz]]
---

# 03 · Veritabanı (Data)

## Neden önemli
Tüm uygulama durumu (kullanıcı, çağrı, mekân) burada yaşar ve çağrı akışı Firestore'un realtime dinlemesine bağlıdır. Atlanırsa/yanlış modellenirse ya çağrı durumu iki taraf arasında senkronize olmaz ya da yarış koşulları (aynı çağrıyı iki gönüllü cevaplar) ürünü bozar.

## Karar (ne + NEDEN)
**Ne:** **Cloud Firestore** (NoSQL, belge tabanlı, realtime).

**Neden Firestore:**
- **Realtime listener** dahili: çağrı durumu (`bekliyor → cevaplandi → bitti`) her iki tarafta `snapshots()` ile anında yansır. Ayrı bir WebSocket altyapısı kurmaya gerek yok.
- Auth + güvenlik kuralları aynı ekosistemde → kimlik bazlı erişim kuralları DB'nin içinde (bkz. [[08-Guvenlik]]).
- Ücretsiz/düşük katman: tek şehir trafiğinde okuma/yazma kotası bol bol yeter.

### Koleksiyon modeli
| Koleksiyon | Anahtar | Rol | Özellik |
|---|---|---|---|
| `users/{uid}` | Auth UID | Profil + anket + fcmToken | Sadece sahibi okur/yazar |
| `cagrilar/{callId}` | UUID | Çağrı durum makinesi | `kanal_adi = callId` (Agora channel) |
| `venues/{venueId}` | UUID | Mekân + **gömülü** yorumlar | Skor yorumla yeniden hesaplanır |

**Tasarım kararları:**
- **Yorumlar mekâna gömülü (embedded):** Ayrı `comments` alt-koleksiyonu yerine `venues` belgesinde liste. **Neden:** Mekân detayında tek okumada her şey gelir → okuma sayısı (maliyet) düşer. Tek mekân yorum hacmi sınırlı olduğu için belge boyutu limiti (1MB) sorun değil.
- **Transaction ile skor:** `addComment` `runTransaction()` ile yapılır — yorum eklenir, `averageRating` ve `accessibilityScore` atomik güncellenir. **Neden:** Oku-değiştir-yaz döngüsünde iki kullanıcı aynı anda yorum yaparsa puan bozulmasın.
- **Silme yok:** `users`, `cagrilar`, `venues` hiçbir koşulda silinemez (kural seviyesinde). **Neden:** Veri bütünlüğü + denetlenebilirlik + yanlışlıkla/kötü niyetli silmeye karşı koruma.
- **Skor formülü:** `featurePoints = (features/8)*70` + `ratingPoints = (avgRating/5)*30`, min 5 / max 100.

### Çağrı durum makinesi
```
bekliyor ──(gönüllü üstlenir)──────> cevaplandi ──(görüşme biter)──> bitti
   ├──────(arayan iptal eder)──────────────────────────────────────> bitti
   └──(45sn gönüllü yok / terk edildi)──> zaman_asimi   [TERMİNAL]
```
**Geri dönüş YOK.** `bitti` ve `zaman_asimi` terminal durumlardır. Geçişler hem istemcide hem güvenlik kuralında kilitlidir:

- **İstemci (UX kilidi):** Gönüllü kabulü `notification_service.dart` → `_claimCallAndNavigate` içinde `runTransaction` ile yapılır. Transaction çağrının güncel durumunu okur, **yalnızca hâlâ `'bekliyor'` ise** `'cevaplandi'` + `volunteer_uid` yazar. Aksi halde yarış kaybedilir, ekrana yönlendirilmez.
- **Zaman aşımı (UX):** Arayan `CallScreen`'de 45 sn gönüllü bulamazsa, transaction ile (yalnızca hâlâ `'bekliyor'` ise) `'zaman_asimi'` yazar ve "gönüllü bulunamadı" ekranı gösterir. Tam o anda gönüllü üstlenirse dokunmaz (bkz. [[01-On-Yuz]], [[02-API-Arka-Uc]]).
- **Güvenlik (yetki kilidi):** `firestore.rules` `isCagriClaim` (bekliyor→cevaplandi) + `isCagriComplete` ((bekliyor|cevaplandi)→bitti, yalnızca katılımcı) + `isCagriTimeout` (bekliyor→zaman_asimi, yalnızca arayan) ile (bkz. [[08-Guvenlik]]). İstemci atlatılsa bile geçersiz/geri geçiş reddedilir → **"çağrı kapma yarışı" çözülmüştür.**
- **Sunucu güvenlik ağı:** Arayanın uygulaması kapanıp çağrı `'bekliyor'`da kalırsa, `cagriZamanAsimiTemizle` scheduled function (her dk, 90 sn eşik) terk edilmiş çağrıyı `'zaman_asimi'` yapar (bkz. [[02-API-Arka-Uc]]).

> `volunteer_uid` alanı yalnızca üstlenme anında (bekliyor→cevaplandi) tek seferlik yazılır; sonradan değiştirilemez.

### Harici POI modeli (`OsmPoi` — Firestore DIŞI, salt-okunur)
Firestore'daki kullanıcı katkılı `venues`'dan **ayrı** olarak, harita ekranı **harici, geçici (persist edilmeyen)** POI verisi gösterir. Model: `lib/models/osm_poi_model.dart` (`OsmPoi`).

- **Kaynaklar:** Overpass (`osmType = node|way|relation`) + Foursquare (`osmType = foursquare`) — paralel çekilip `_mergePois` ile birleştirilir (bkz. [[10-Cache-CDN]], [[01-On-Yuz]]).
- **Erişilebilirlik tag'leri (OSM):** `wheelchair` (`yes`/`limited`/`no`), `wheelchairDescription`, `toiletsWheelchair`, `tactilePaving` (hissedilebilir yüzey) + tüm ham etiketler `allTags` map'inde. **Neden önemli:** Ürünün erişilebilirlik vaadinin haritadaki karşılığı bu tag'lerdir; engelli birey mekâna gitmeden tekerlekli sandalye uygunluğunu görür.
- **Yardımcılar:** `categoryToTurkish()` (40+ tür → Türkçe), `wheelchairStatusText` getter, `openingHoursTurkish` ayrıştırıcı, `fromOverpassElement()` factory.
- **Neden Firestore'a yazılmıyor:** Harici/canlı veri; depolamak hem güncelliği bozar hem maliyet/kota yaratır. Kullanıcı katkısı (`venues`) kalıcı, harici POI (`OsmPoi`) salt-okunur ve cache'lenir (bkz. [[10-Cache-CDN]]).

> **Ayrım netliği:** `venues` = kalıcı, kullanıcı-üretimi, skorlu (Firestore). `OsmPoi` = geçici, harici-kaynak, erişilebilirlik tag'li (Overpass/Foursquare). İkisi haritada birlikte görünür ama farklı yaşam döngüsüne sahiptir.

## MVP Kapsamı
**VAR:**
- 3 koleksiyon + güvenlik kuralları + transaction'lı yorum
- Seed: koleksiyon boşsa `seedInitialVenues()` 7 Sakarya mekânını batch yazar
- Realtime listener'lar (çağrı + mekân listesi)
- **Mekân keşfi client-side filtreli:** Topluluk sekmesi tüm `venues`'u `venuesStreamProvider` ile çeker, arama/kategori/erişilebilirlik filtrelerini **cihazda** uygular (`filteredVenuesProvider`). **Neden:** Tek şehir, az mekân → sunucu sorgusu/composite index gereksiz; realtime tazelik korunur (bkz. [[01-On-Yuz]] · "Topluluk sekmesi").

**YOK:**
- Otomatik yedekleme/PITR (bkz. [[13-Recovery]] — bilinçli stub)
- Composite index optimizasyonu (sorgular basit, gerek yok)
- Soft-delete / arşivleme (silme zaten yasak)
- Çağrı geçmişi raporlama koleksiyonu

## Açık Sorular
- ~~"Çağrı kapma yarışı": iki gönüllü aynı anda `cevaplandi` yazarsa?~~ **ÇÖZÜLDÜ:** istemci `runTransaction` + `cagri_durumu == 'bekliyor'` ön koşulu **ve** `firestore.rules` `isCagriClaim` geçiş kilidi. Kalan iş: emulator ile regresyon testi (bkz. [[07-CI-CD]]).
- `cagrilar` sonsuza dek birikiyor (silme yok). 1 yıl sonra koleksiyon şişer; arşiv stratejisi gerekecek mi?
- Gömülü yorumlar 1MB belge limitine yaklaşırsa popüler mekânlarda ne olur?

## TODO
- [x] Çağrı kapma yarışını transaction ön koşuluyla kilitle (istemci `_claimCallAndNavigate` + kural `isCagriClaim`) — *2026-06-28*
- [ ] Çağrı kapma yarışı için emulator regresyon testi yaz → [[07-CI-CD]]
- [ ] `cagrilar` için TTL/arşiv politikası tasarla → [[13-Recovery]] ile bağla
- [ ] Firestore günlük yedeği (gcloud export) planını [[13-Recovery]]'ye taşı
- [ ] Belge boyutu izleme metriği ekle → [[12-Loglama]]

---

## İlgili Notlar
- [[Architecture-Overview]] — veri katmanının sistemdeki yeri
- [[PRD]] — mekân/skor/çağrı veri gereksinimi
- [[01-On-Yuz]] — realtime stream tüketicisi
- [[02-API-Arka-Uc]] — çağrı trigger'ının kaynağı
- [[04-Auth]] — UID belge anahtarı/sahiplik
- [[05-Barindirma]] — BaaS = barındırılan veri
- [[06-Bulut]] — Firestore'u barındıran bulut
- [[08-Guvenlik]] — kurallar veri erişim sınırı
- [[10-Cache-CDN]] — POI/okuma önbelleği
- [[11-Olcekleme]] — gömülü yorum ölçek sınırı
- [[12-Loglama]] — belge boyutu metriği
- [[13-Recovery]] — Firestore export yedeği
