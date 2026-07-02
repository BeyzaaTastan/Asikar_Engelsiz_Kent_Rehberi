---
katman: Rate Limiting
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[08-Guvenlik]], [[02-API-Arka-Uc]], [[10-Cache-CDN]], [[06-Bulut]]
---

# 09 · Rate Limiting

## Neden önemli
Ücretsiz kotalara dayanan bir projede rate limiting = maliyet kontrolü; kontrolsüz çağrı, Foursquare/Agora/Functions kotasını tüketip ya faturayı patlatır ya da servisi durdurur. Atlanırsa tek bir bug (sonsuz döngü) veya kötü niyetli kullanıcı tüm ücretsiz bütçeyi bir günde bitirir.

## Karar (ne + NEDEN)
**MVP'de var olan koruma — client tarafı (kısmi):**
- **Foursquare debounce 800ms** + koordinat/kategori bazlı cache → kullanıcı haritayı kaydırdıkça yağmur gibi istek gitmez (bkz. [[10-Cache-CDN]]). **Neden client'ta:** İstek hiç doğmadan engellenir → en ucuz katman.
- **Overpass:** OSM kullanım politikasına saygı; kategori/alan bazlı sınırlı sorgu.

**Eksik olan — sunucu tarafı (bilinçli stub):**
- Cloud Functions'ta **per-user çağrı limiti yok.** Geçerli auth'lı bir kullanıcı `generateAgoraToken`'ı döngüde çağırabilir.
- `cagrilar` oluşturmada spam koruması yok (bir kullanıcı saniyede yüzlerce çağrı açabilir → FCM topic'i bombalar).

**Savunma durumu:**
1. ✅ **Firebase App Check** → sahte/script client'ları en baştan eler (bkz. [[08-Guvenlik]]). **ENFORCE AKTİF + DOĞRULANDI (*2026-06-28*):** istemci aktif + `generateAgoraToken` zorlaması açık (`APP_CHECK_ENFORCE=true`, deploy) + **Cloud Firestore Console Enforce** + debug token kayıtlı; debug build çağrı testi geçti (sunucu `app:VALID`, status 200). Kalan: yalnızca release Play Integrity (Faz 5). Tek en yüksek getirili adım, ücretsiz.
2. ⬜ **Firestore kuralında throttle:** Çağrı oluştururken son çağrı zaman damgasını kontrol (örn. "30 sn içinde 2. çağrı yasak"). Sunucu kodu gerektirmez.
3. ⬜ **Functions içi basit sayaç:** Token isteklerini `users/{uid}` altında dakikalık sayaçla sınırla (gerekirse).

**Neden tam rate limiting MVP'de değil:** Tek şehir, az kullanıcı, düşük doğal trafik. Asıl risk kötü niyet/bug → onu App Check + bütçe alarmı ([[06-Bulut]]) yeterince azaltıyor. Tam API gateway/quota sistemi şu an aşırı mühendislik.

## MVP Kapsamı
**VAR:**
- Foursquare 800ms debounce + cache
- OSM/Overpass kullanım politikasına uyumlu sorgu
- **App Check ENFORCE AKTİF + DOĞRULANDI** (istemci + token fonksiyonu zorlaması + Firestore Console Enforce + debug token kayıtlı; debug çağrı testi `app:VALID`) — *2026-06-28*
- **Foursquare atıf/lisans uyumu:** "Powered by Foursquare" görünür atıf eklendi (Places API lisans şartı: veri göründüğü her ekranda markalı atıf) — *2026-07-02* → [[10-Cache-CDN]], [[08-Guvenlik]]
- **Sesli arama = cihaz OS tanıyıcısı** (`speech_to_text` → `VoiceSearchService`): API anahtarı/kota yok, **$0** — ücretsiz kota ilkesine uygun (bkz. [[01-On-Yuz]] · "Sesli arama") — *2026-07-02*

**YOK:**
- Cloud Functions per-user rate limit (token sayacı)
- Çağrı oluşturma spam koruması (throttle)
- IP/cihaz bazlı global limit
- 429 geri-basınç (backpressure) yönetimi

## Açık Sorular
- `generateAgoraToken` döngüde çağrılırsa Agora dakika kotası ne kadar sürede biter? (limit testi yapılmadı)
- FCM topic broadcast spam'i: bir kullanıcı 100 çağrı açarsa tüm gönüllülere 100 push gider → kullanıcı deneyimi + kota sorunu.
- OSM Overpass'ın adil kullanım eşiği nedir, ona yaklaşıyor muyuz?

## TODO
- [x] App Check'i ekle (istemci + token fonksiyonu env-bayraklı zorlama) → [[08-Guvenlik]] ortak TODO — *2026-06-28*
- [x] App Check Console kaydı + debug token + `APP_CHECK_ENFORCE=true` + deploy — *2026-06-28* → [[08-Guvenlik]]
- [x] Firestore App Check enforce (Console) — *2026-06-28*, debug çağrı testiyle doğrulandı → [[08-Guvenlik]]
- [ ] Release için Play Integrity (Faz 5 — yayın öncesi) → [[08-Guvenlik]]
- [ ] Firestore kuralına çağrı oluşturma throttle'ı (zaman damgası kontrolü) ekle
- [ ] Tüm 3. parti ücretsiz kota limitlerini tabloya çıkar → [[06-Bulut]]
- [ ] Bir "limit aşıldı" kullanıcı mesajı tasarla (sessiz hata yerine)

---

## İlgili Notlar
- [[Architecture-Overview]] — kota koruması katmanı (stub)
- [[02-API-Arka-Uc]] — token çağrı limiti ihtiyacı
- [[06-Bulut]] — bütçe alarmı + kota
- [[08-Guvenlik]] — App Check ortak koruması
- [[10-Cache-CDN]] — debounce/cache ile istek azaltma
