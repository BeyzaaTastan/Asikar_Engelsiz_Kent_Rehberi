---
katman: Ölçekleme
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[03-Veritabani]], [[02-API-Arka-Uc]], [[06-Bulut]], [[12-Loglama]]
---

# 11 · Ölçekleme (Scaling)

## Neden önemli
Ölçekleme planı, "başarı gelirse sistem çöker mi" sorusunu önceden cevaplar; ama erken optimize etmek $0 maliyet hedefli bir üründe zaman/para israfıdır. Atlanırsa iki yönde de risk: ya hiç düşünülmez ve ani büyümede mimari kilitlenir, ya da gereksiz yere ölçek için fazla mühendislik yapılıp MVP gecikir.

## Karar (ne + NEDEN)
**MVP kararı: ölçekleme büyük ölçüde "ücretsiz geliyor", aktif iş yapmıyoruz.**

**Neden ölçeklemeye yatırım YOK (şimdilik):**
- Pilot sahası: Sakarya — yüzler/birkaç bin kullanıcı. Ulusal açılım aşamalı (il il), ani ülke-çapı yük beklenmiyor.
- **Firestore otomatik ölçeklenir** — provizyon yok, sharding yok; yük arttıkça Google ölçekler.
- **Cloud Functions otomatik ölçeklenir** — eşzamanlı çağrı arttıkça yeni instance açılır.
- **Agora** SFU/medya altyapısını kendi ölçekler.
Yani çekirdek bileşenler doğası gereği elastik. Bizim ek bir şey yapmamıza gerek yok → bu katman bilinçli **stub**.

> ⚠️ **Kapsam değişti (*2026-06-29*, O12):** Proje **bitirme → canlı production** ve **tek şehir (Sakarya) → Türkiye geneli**'ne taşındı. Aşağıdaki "tek şehir, ölçeklemeye yatırım yok" varsayımı **artık geçerli değil**; özellikle FCM topic broadcast (şehir segmentasyonu) ve POI taban katmanı (aşağıda #4) yakın vadede yeniden ele alınmalı. Maliyet önceliği yine **$0**.

**İstemci render ölçeği (*2026-07-01*, O13):** Türkiye geneli taban katmanı (#4) yoğun bölgelerde viewport'a yüzlerce POI düşürebilir. Hepsi aynı anda ikon+isimle çizilince harita hem okunamıyor hem jank yapıyordu. Çözüm: **zoom kapısı + Google tarzı declutter**. `_poiFetchMinZoom = 15` altında hiç çizilmez/çekilmez. Üstünde `declutterPois` (öncelik `poiPriority`) ekranda yalnızca çakışmayan öncelikli POI'lere isim verir, bir kısmını noktaya düşürür, gerisini gizler; `_poiDeclutterCap = 700` ile relayout girdisi kırpılır. Böylece çizilen etiket/widget sayısı zoom ve yoğunluktan bağımsız sınırlı kalır. Bu bir **çizim** ölçek sınırıydı; eşik veri çekimini de kapıladığı için kota tarafına da olumlu (bkz. [[10-Cache-CDN]], [[01-On-Yuz]]). Marker kümeleme (`flutter_map_marker_cluster`) denendi, elendi. Daha da yoğunlaşırsa sıradaki adım vektör-tile (PMTiles) POI katmanı (#4).

**Mimaride gizli ölçek sınırları (farkında olunması gereken):**
1. **FCM topic broadcast:** `volunteers` topic'ine çağrı *tüm* gönüllülere gider. 50 gönüllüde sorun yok; 5.000 gönüllüde her çağrı 5.000 push + 5.000 client'ta çağrı kapma yarışı → verimsiz. **Gerçek ölçek sınırı burada.** Türkiye geneli artık gündemde → şehir bazlı topic (`volunteers_<sehir>`) öncelik kazandı.
   - **Çözüm — çağrı tipine göre yönlendirme (UYGULANDI 2026-07-02):** Çağrı `cagri_tipi ∈ {fiziksel, uzaktan}` taşır. **Fiziksel yardım / yerinde şehir rehberliği** → yalnızca `volunteers_<sehir>` topic'ine gönderilir (yerinde bulunmayan gönüllüye gitmesi anlamsız). **Uzaktan (görüntülü) destek** → global `volunteers` topic'inde kalır (konumdan bağımsız herkes cevaplayabilir). Her gönüllü **iki** topic'e abone olur: global `volunteers` + `volunteers_<kendi_sehri>` (`notification_service.dart` `subscribeToVolunteers`; şehir çözümü oturumda bir kez). Böylece hem doğru eşleştirme, hem de fiziksel çağrılarda push fan-out'u şehir başına düşer → ulusal ölçekte broadcast maliyeti kırılır. Şehir → topic-güvenli slug: `lib/utils/city_slug.dart` (saf/birim testli `test/unit/city_slug_test.dart`; Türkçe ASCII-fold — proje konvansiyonu, bkz. `channel_validator`/`poi_priority`); istemcinin iki tarafı aynı slug'ı üretir, `functions/index.js` + `firestore.rules` aynı regex ile doğrular. **Şehir kaynağı: arayanın/gönüllünün anlık GPS konumu** (reverse-geocode via Nominatim, `lib/services/city_lookup_service.dart`), profil şehri değil — turist/seyahat senaryosunda kullanıcı bulunduğu şehrin gönüllüsüne ihtiyaç duyar. Acil akışta gecikmeye karşı: `getLastKnownPosition` (anında) → kısa timeout'lu `getCurrentPosition` fallback; çözülemezse `sehir` yazılmaz ve çağrı global `volunteers`'a düşer (hiç engellenmez). Kullanıcı çağrı tipini `disabled_home` bottom-sheet'inden seçer (erişilebilir, Semantics'li). ⚠️ **Deploy gerekli:** `firebase deploy --only functions,firestore:rules`.
2. **Gömülü yorumlar:** Çok popüler bir mekânda yorumlar 1MB belge limitine dayanır (bkz. [[03-Veritabani]]). *Kısmi azaltım (*2026-06-29*, O8):* içerik uzunluğu (≤1000) + yorum sayısı (≤500) üst sınırı (`comment_validation.dart`, test edilebilir — bkz. [[07-CI-CD]]); asıl çözüm alt-koleksiyon, ölçekte gerekli.
3. **Çağrı eşleştirme:** Topic broadcast yerine coğrafi/uygun gönüllü eşleştirme, ölçekte gerekli olacak.
4. **POI taban katmanı (Cloudflare R2 + tile JSON):** Türkiye geneli **2.16M POI** Foursquare Open Source Places'ten süzülüp z12 tile JSON'larına bölünür, R2'ye yüklenir, Worker `/pois?bbox=` ile sunulur (bkz. [[03-Veritabani]], [[06-Bulut]]). **D1 elendi:** 2.16M satır, D1 ücretsiz **100k yazma/gün** kotasına sığmıyor (~22 gün). R2'de **satır limiti yok + egress $0 + 10M okuma/ay** → kullanıcı sayısı maliyeti etkilemez. Daha da büyürse aynı R2 üzerinde **PMTiles** (vektör tile) alternatifi; o aşamada Flutter POI katmanı vektör-tile'a taşınır.

**Ne zaman "tam"a geçilir (tetik koşulları):**
- Gönüllü sayısı birkaç yüzü aşarsa → topic broadcast'i hedefli eşleştirmeye çevir.
- **Sakarya pilotu 2. ile açılırsa (planlı, opsiyonel değil)** → şehir bazlı topic/segment (`volunteers_<sehir>`) zorunlu; aksi halde bir ildeki çağrı tüm ülkedeki gönüllülere gider. Bu, Türkiye geneli açılımının **ön koşuludur**.

## MVP Kapsamı
**VAR:**
- Yönetilen servislerin otomatik ölçeklemesi (sıfır yapılandırma)

**YOK:**
- Hedefli çağrı eşleştirme (topic broadcast yeterli)
- Şehir/bölge segmentasyonu (tek şehir)
- Firestore sharding / yük dağıtımı (gereksiz)
- Yük testi / kapasite planlaması
- Cloud Functions min-instance (cold start kabul ediliyor)

## Açık Sorular
- Cold start: `generateAgoraToken` ilk çağrıda gecikirse, kullanıcı çağrı beklerken fazladan saniyeler ekler mi? Acil yardım senaryosunda kritik olabilir — min-instance (1) maliyeti değer mi?
- FCM topic broadcast hangi gönüllü sayısında pratikte sorun olmaya başlar?
- İkinci şehir gerçekten gündeme gelecek mi? (gelecekse segmentasyonu şimdiden veri modeline koymak ucuz)

## TODO
- [ ] Çağrı akışında cold start gecikmesini ölç → gerekirse min-instance:1 değerlendir
- [ ] Veri modeline `sehir` alanı ekleyip topic'i şehir bazlı tasarlamayı düşün (gelecek-uyumlu, ucuz)
- [ ] "Hedefli gönüllü eşleştirme" tasarımını backlog'a not düş → [[02-API-Arka-Uc]]

---

## İlgili Notlar
- [[Architecture-Overview]] — ölçekleme katmanı (MVP dışı)
- [[02-API-Arka-Uc]] — topic broadcast ölçek sınırı
- [[03-Veritabani]] — gömülü yorum ölçek sınırı
- [[06-Bulut]] — otomatik ölçek zemini
- [[12-Loglama]] — cold start ölçümü
