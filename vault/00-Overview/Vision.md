---
katman: Genel Bakış
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[PRD]], [[Architecture-Overview]]
---

# Vision — Aşikar Engelsiz Kent Rehberi

## Neden önemli
Vizyon olmadan her teknik karar tartışmaya açık hale gelir; "neden Firebase, neden Agora, neden önce Sakarya" sorularının cevabı burada sabitlenir. Atlanırsa ekip her sprint'te aynı tartışmayı baştan yapar.

## Karar (ne + NEDEN)
**Ne:** Engelli bireyi, gönüllüyü ve şehir sakinini tek bir mobil uygulamada buluşturan, **gerçek/canlı** bir erişilebilirlik rehberi. **Sakarya'da pilot** olarak sahaya çıkar, **Türkiye geneli** kullanıma açıktır.

**Tek cümlelik vizyon:** Görme/hareket engelli bir birey, tanımadığı bir mekânda tek tuşla canlı bir gönüllüye görüntülü bağlanabilsin ve gitmeden önce o mekânın erişilebilir olup olmadığını bilsin.

> **Kapsam (2026-07-01, O12):** Bu proje artık bir bitirme çalışması değil; canlı production bir üründür. Başlangıç framing'i "tek şehir + bitirme" idi; **Sakarya artık nihai kapsam değil, ölçeklenmeden önceki pilot sahadır.** Aşağıdaki "neden bu kapsam" maddeleri bu geçiş ışığında okunmalı.

**Neden bu kapsam:**
- **Önce Sakarya pilotu, sonra Türkiye geneli:** Ürün ulusal hedefli; ancak riski düşürmek için önce tek bir sahada (Sakarya) gönüllü arz-talep dengesi ve çağrı akışı doğrulanır, sonra il il açılır. POI taban katmanı zaten **Türkiye geneli** canlıdır (2.16M POI, Cloudflare R2 — bkz. [[03-Veritabani]]); mekân/skor verisi kullanıcı üretimiyle il il büyür.
- **Kalıcı $0/düşük katman maliyet disiplini:** Artık bütçe kısıtı değil, **bilinçli mimari tercih** — kullanıcı sayısı arttıkça maliyetin doğrusal patlamaması için (serverless + BaaS + edge cache; bkz. [[06-Bulut]], [[11-Olcekleme]]).
- **Üç kullanıcı tipi:** Engelli (talep), Gönüllü (arz), Sakin/Turist (içerik üretimi/keşif). Üç taraf da aynı veriyi besler → soğuk başlangıç problemi tek koleksiyonla çözülür.
- **Mobil-öncelikli:** Hedef kitle sahada, hareket hâlinde. Görüntülü çağrı + konum + kamera → native mobil zorunlu. Web ikincil.

## MVP Kapsamı
**VAR:**
- Tek tuşla gönüllüye görüntülü bağlanma (Agora + FCM çağrı zinciri)
- Erişilebilirlik skorlu mekân listesi + yorum/puan
- Harita üzerinde POI keşfi (OSM + Foursquare)
- Üç kullanıcı tipi + kayıt anketi
- Erişilebilirlik ayarları (yazı boyutu, yüksek kontrast, karanlık mod, ses)

**YOK (bilinçli ertelendi):**
- Gönüllü puanlama/rozet/itibar sistemi
- Çağrı geçmişi & istatistik paneli
- Ödeme / bağış akışı
- Çevrimdışı harita

**Çağrı tipine göre yönlendirme (UYGULANDI 2026-07-02):** *Fiziksel yardım / yerinde şehir rehberliği* çağrıları yalnızca **aynı şehirdeki** gönüllülere düşer (`volunteers_<sehir>`); *uzaktan (görüntülü)* çağrılar **her yerdeki** gönüllülere düşer (global `volunteers`). Kullanıcı tipi çağrı ekranında seçer; şehir anlık GPS'ten çözülür. Bu, Türkiye geneli ölçek için FCM segmentasyonunu da sağlar (bkz. [[11-Olcekleme]], [[02-API-Arka-Uc]]). ⚠️ functions + rules deploy edilmeli.

**PİLOT SONRASI (Türkiye geneli açılırken gerekecek):**
- İl bazlı seed/tanıtım ve gönüllü kazanım stratejisi.
- Şehir içi hedefli gönüllü eşleştirme (fiziksel çağrı hâlâ şehir topic'ine broadcast).

## Açık Sorular
- Gönüllü arzı talebi karşılayamazsa fallback ne? (Sıra? Belediye çağrı merkezi entegrasyonu?) — pilotta ölçülecek kritik metrik.
- Erişilebilirlik skoru kullanıcı yorumuna dayanıyor — kötü niyetli/yanlış veri nasıl filtrelenecek? (moderasyon ihtiyacı; ulusal ölçekte artar)
- Sakarya pilotundan Türkiye geneline geçiş tetiği ne? (tamamlanmış çağrı sayısı / gönüllü doygunluğu eşiği belirlenmeli)

## TODO
- [ ] Pilot başarı metriğini sayısallaştır (örn. "Sakarya pilotunun ilk 3 ayında X tamamlanmış çağrı" → il açılım kararı)
- [ ] Gönüllü onboarding'inde KVKK aydınlatma metni
- [ ] Erişilebilirlik için WCAG referansı seç ve [[01-On-Yuz]]'e bağla
- [ ] Türkiye geneli açılım öncesi şehir bazlı gönüllü segmentasyonunu tasarla → [[11-Olcekleme]]

---

## İlgili Notlar
- [[Architecture-Overview]] — vizyonu mimari karara çevirir
- [[PRD]] — vizyonu somut gereksinime döker
- [[01-On-Yuz]] — mobil-öncelikli erişilebilirlik vizyonunun UI'ı
- [[06-Bulut]] — $0/düşük katman Firebase tercihinin dayanağı
- [[11-Olcekleme]] — Sakarya pilotu → Türkiye geneli ölçek sınırları
