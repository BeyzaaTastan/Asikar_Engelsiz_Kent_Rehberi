# Aşikar Engelsiz Kent Rehberi

Engelli bireyleri gönüllülerle buluşturan **Flutter + Firebase** mobil erişilebilirlik uygulaması. **Gerçek ürün / canlı production:** Sakarya'da **pilot** olarak sahaya çıkar, **Türkiye geneli** kullanıma açılır. Altyapıda kalıcı **$0/düşük katman** maliyet disiplini (bilinçli tercih).

- **Özel Gereksinimli birey** → tek tuşla gönüllüye **görüntülü** bağlanır (Agora + FCM).
- **Gönüllü** → çağrıyı push bildirimi ile alır, görüntülü destek verir.
- **Sakin / Turist** → erişilebilirlik skorlu mekânları keşfeder, yorum yapar, haritada rota kullanır.

Paket: `asikar_engelsiz_kent_rehberi` · Versiyon: `1.0.0+1` · Hedef: Android + iOS (web ikincil)

---

## Teknoloji Yığını

| Alan | Teknoloji |
|---|---|
| Mobil | Flutter (Dart ^3.9.2) |
| State | flutter_riverpod ^2.5.1 |
| Auth | Firebase Authentication (e-posta + Google) |
| Veri | Cloud Firestore (realtime) |
| Push | Firebase Cloud Messaging (FCM) |
| Backend | Firebase Cloud Functions (Node.js), bölge `europe-west3` |
| Görüntülü | agora_rtc_engine ^6.5.4 |
| Gelen çağrı UI | flutter_callkit_incoming ^3.0.0 |
| Harita | flutter_map (OpenStreetMap) |
| POI | Foursquare Places v3 + OSM Overpass (hibrit) |
| Arama / Rota | Nominatim (arama) + OSRM (yol tarifi) |
| Konum | geolocator ^14.0.2 |

---

## Kurulum

```bash
# 1. Bağımlılıklar
flutter pub get

# 2. Ortam değişkenleri — repoya DAHİL DEĞİL, elle oluştur:
#    .env            → AGORA_APP_ID, FOURSQUARE_API_KEY
#    functions/.env  → AGORA_APP_ID, AGORA_APP_CERTIFICATE  (sertifika YALNIZCA burada)

# 3. (gerekirse) Firebase yapılandırması
flutterfire configure --project=asikar-engelsiz-kent-rehberi

# 4. Çalıştır
flutter run
```

> ⚠️ Agora **App Certificate** asla Flutter tarafına konmaz; token yalnızca `generateAgoraToken` Cloud Function'ında üretilir.

---

## Komutlar

```bash
flutter analyze                 # lint — commit/PR öncesi ZORUNLU
flutter test                    # testler
flutter build appbundle         # Android yayın (Play Store)
flutter build apk               # Android APK

npx firebase-tools deploy --only firestore:rules   # kural deploy — DİKKATLİ
npx firebase-tools deploy --only functions         # Cloud Functions
npx firebase-tools functions:log                   # canlı log
```

---

## Mimari (özet)

Sunucusuz (serverless) + BaaS. Kendi sunucumuz yok; client çoğunlukla doğrudan Firestore'a yazar ve **tek güvenlik sınırı `firestore.rules`'tur.** Backend yalnızca 2 iş yapar:

1. `cagriBildirimiGonder` — Firestore trigger; `cagri_durumu == 'bekliyor'` olunca FCM `volunteers` topic'ine push.
2. `generateAgoraToken` — HTTPS Callable; `context.auth` kontrolü + 1 saatlik Agora token.

**Çağrı durum makinesi:** `bekliyor → cevaplandi → bitti` (Firestore'da, realtime dinlenir).

---

## Dokümantasyon

- **`proje_dokumantasyonu.md`** — projenin "ne ve nasıl"ı: klasör yapısı, servisler, ekranlar, veri modelleri, komutlar.
- **`vault/`** (Obsidian) — mimari "neden"i: 13 katman notu + genel bakış, `[[wikilink]]` çapraz bağlarıyla beyin haritası. Merkez: `vault/00-Overview/Architecture-Overview.md`.
- **`CLAUDE.md`** — AI asistanları için kod yazım kuralları ve konvansiyonlar.

---

## Lisans / Bağlam

Gerçek ürün / canlı production. Sakarya pilotu → Türkiye geneli. Uygulama arayüzü Türkçe.
