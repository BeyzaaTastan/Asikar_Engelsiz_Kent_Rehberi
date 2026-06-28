---
katman: Ölçekleme
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[03-Veritabani]], [[02-API-Arka-Uc]], [[06-Bulut]], [[12-Loglama]]
---

# 11 · Ölçekleme (Scaling)

## Neden önemli
Ölçekleme planı, "başarı gelirse sistem çöker mi" sorusunu önceden cevaplar; ama erken optimize etmek düşük bütçeli bir projede zaman/para israfıdır. Atlanırsa iki yönde de risk: ya hiç düşünülmez ve ani büyümede mimari kilitlenir, ya da gereksiz yere ölçek için fazla mühendislik yapılıp MVP gecikir.

## Karar (ne + NEDEN)
**MVP kararı: ölçekleme büyük ölçüde "ücretsiz geliyor", aktif iş yapmıyoruz.**

**Neden ölçeklemeye yatırım YOK (şimdilik):**
- Hedef: tek şehir (Sakarya), bitirme projesi ölçeği — yüzler/birkaç bin kullanıcı.
- **Firestore otomatik ölçeklenir** — provizyon yok, sharding yok; yük arttıkça Google ölçekler.
- **Cloud Functions otomatik ölçeklenir** — eşzamanlı çağrı arttıkça yeni instance açılır.
- **Agora** SFU/medya altyapısını kendi ölçekler.
Yani çekirdek bileşenler doğası gereği elastik. Bizim ek bir şey yapmamıza gerek yok → bu katman bilinçli **stub**.

**Mimaride gizli ölçek sınırları (farkında olunması gereken):**
1. **FCM topic broadcast:** `volunteers` topic'ine çağrı *tüm* gönüllülere gider. 50 gönüllüde sorun yok; 5.000 gönüllüde her çağrı 5.000 push + 5.000 client'ta çağrı kapma yarışı → verimsiz. **Gerçek ölçek sınırı burada.**
2. **Gömülü yorumlar:** Çok popüler bir mekânda yorumlar 1MB belge limitine dayanır (bkz. [[03-Veritabani]]).
3. **Çağrı eşleştirme:** Topic broadcast yerine coğrafi/uygun gönüllü eşleştirme, ölçekte gerekli olacak.

**Ne zaman "tam"a geçilir (tetik koşulları):**
- Gönüllü sayısı birkaç yüzü aşarsa → topic broadcast'i hedefli eşleştirmeye çevir.
- İkinci şehir eklenirse → şehir bazlı topic/segment (`volunteers_sakarya`).

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
