---
katman: Genel Bakış
durum: onaylı
mvp_kritik: evet
bağımlılıklar: [[PRD]], [[Architecture-Overview]]
---

# Vision — Aşikar Engelsiz Kent Rehberi

## Neden önemli
Vizyon olmadan her teknik karar tartışmaya açık hale gelir; "neden Firebase, neden Agora, neden Sakarya" sorularının cevabı burada sabitlenir. Atlanırsa ekip her sprint'te aynı tartışmayı baştan yapar.

## Karar (ne + NEDEN)
**Ne:** Engelli bireyi, gönüllüyü ve şehir sakinini tek bir mobil uygulamada buluşturan, **Sakarya'ya odaklı** bir erişilebilirlik rehberi.

**Tek cümlelik vizyon:** Görme/hareket engelli bir birey, tanımadığı bir mekânda tek tuşla canlı bir gönüllüye görüntülü bağlanabilsin ve gitmeden önce o mekânın erişilebilir olup olmadığını bilsin.

**Neden bu kapsam:**
- **Tek şehir (Sakarya):** Bitirme projesi + düşük bütçe. Tek şehirde seed verisi (7 mekân) elle girilebilir, POI çağrıları coğrafi olarak sınırlı kalır → Foursquare/Overpass ücretsiz kotası yetiyor. Ulusal ölçek bütçeyi de kapsamı da patlatır.
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
- Çoklu şehir / il seçimi
- Gönüllü puanlama/rozet/itibar sistemi
- Çağrı geçmişi & istatistik paneli
- Ödeme / bağış akışı
- Çevrimdışı harita

## Açık Sorular
- Gönüllü arzı talebi karşılayamazsa fallback ne? (Sıra? Belediye çağrı merkezi entegrasyonu?)
- Erişilebilirlik skoru kullanıcı yorumuna dayanıyor — kötü niyetli/yanlış veri nasıl filtrelenecek? (bkz. [[06-Bulut]] içeriği değil, moderasyon ihtiyacı)
- Sakarya dışına çıkıldığında uygulama davranışı tanımsız.

## TODO
- [ ] Başarı metriğini sayısallaştır (örn. "ilk 3 ayda X tamamlanmış çağrı")
- [ ] Gönüllü onboarding'inde KVKK aydınlatma metni
- [ ] Erişilebilirlik için WCAG referansı seç ve [[01-On-Yuz]]'e bağla

---

## İlgili Notlar
- [[Architecture-Overview]] — vizyonu mimari karara çevirir
- [[PRD]] — vizyonu somut gereksinime döker
- [[01-On-Yuz]] — mobil-öncelikli erişilebilirlik vizyonunun UI'ı
- [[06-Bulut]] — düşük bütçe Firebase tercihinin dayanağı
