---
katman: Recovery
durum: taslak
mvp_kritik: hayır
bağımlılıklar: [[03-Veritabani]], [[06-Bulut]], [[07-CI-CD]], [[12-Loglama]]
---

# 13 · Recovery (Yedekleme & Felaket Kurtarma)

## Neden önemli
Bu projede "geri alınamayan" iki şey var: **silinemeyen** Firestore verisi ve **kaybolursa güncelleme yapılamayan** Android imzalama anahtarı. Atlanırsa tek bir yanlış işlem (yanlış kural deploy'u, yanlışlıkla koleksiyon temizleme, keystore kaybı) projeyi kurtarılamaz hale getirir.

## Karar (ne + NEDEN)
Recovery iki ayrı varlık sınıfında düşünülür:

### 1. Veri kurtarma (Firestore)
- **Risk:** Silme kural seviyesinde yasak → kullanıcı verisi "yanlışlıkla silinmeye" karşı zaten korumalı. **Ama** geliştirici elle/konsoldan veya yanlış kuralla veriyi bozabilir.
- **Düşük maliyetli plan:** **`gcloud firestore export`** ile **periyodik manuel/zamanlanmış yedek** bir Cloud Storage bucket'a. **Neden:** Firestore yönetilen yedeği (scheduled backups) ücretli olabilir; `export` ile depolama maliyeti cent'ler düzeyinde kalır.
- **PITR (Point-in-time recovery):** Firestore PITR mevcut ama ek maliyet; MVP'de **stub**, kritik veri büyüyünce açılır.

### 2. Yapılandırma / sır kurtarma (en sinsi risk)
- **Android keystore:** Kaybolursa Play Store'da **güncelleme imkânsız** — uygulama ölür. **Plan:** Keystore + şifresi şifreli ve **en az 2 ayrı güvenli yerde** (örn. şifre yöneticisi + çevrimdışı kopya). Repoda **asla** (bkz. [[07-CI-CD]], [[08-Guvenlik]]).
- **`.env` sırları** (Agora App Certificate, App ID, Foursquare key): güvenli kasada yedek. Sertifika kaybolursa Agora konsolundan yenilenir ama bilinmesi gerek.
- **Firebase/Google hesabı erişimi:** Tek geliştirici hesabına bağlıysa, hesap kaybı = proje kaybı. **Plan:** En az bir yedek "owner" hesabı veya kurtarma e-postası.

### 3. Servis kesintisi (üçüncü parti)
- Firebase/Agora/Foursquare düşerse uygulama kısmen çalışmaz. Tek bölge, tek sağlayıcı → **failover yok** (bilinçli; çoklu bölge bütçe dışı). Kabul edilen risk: nadir kesintilerde geçici bozulma.

**Neden tam DR yok:** Çoklu bölge replikasyon, sıcak yedek, otomatik failover bu ölçekte aşırı pahalı ve gereksiz. Asıl tehdit "felaket" değil "insan hatası + anahtar kaybı" → ucuz yedekleme bunu karşılar.

## MVP Kapsamı
**VAR:**
- Silme yasağı (veri için pasif koruma)
- (Yapılması gereken) keystore + sır yedeği

**YOK:**
- Otomatik zamanlanmış Firestore export
- PITR
- Çoklu bölge / failover
- Belgelenmiş RTO/RPO hedefleri
- Düzenli "yedekten geri yükleme" tatbikatı

## Açık Sorular
- Android keystore **şu anda** repo dışında, güvenli ve yedekli mi? (En kritik tek soru — kaybı geri alınamaz)
- KVKK "verimi sil" talebi ile "silme yasak" kuralı çelişiyor → anonimleştirme akışı recovery'yi etkiler mi?
- Tek geliştirici hesabı dışında projeye erişimi olan ikinci kişi/yedek owner var mı?
- Yedekten geri yükleme hiç denendi mi? (denenmemiş yedek = yedek değil)

## TODO
- [ ] **Keystore + şifresini 2 güvenli yere yedekle** — geri alınamaz risk, en yüksek öncelik
- [ ] `.env` / Agora sertifikası yedeğini güvenli kasaya al
- [ ] Haftalık `gcloud firestore export` (manuel veya scheduled function) kur
- [ ] Yedek owner / kurtarma e-postası tanımla
- [ ] Bir kez "export → boş projeye import" tatbikatı yap (yedeğin geçerliliğini kanıtla)

---

## İlgili Notlar
- [[Architecture-Overview]] — kurtarma katmanı (stub)
- [[03-Veritabani]] — Firestore export yedeği
- [[06-Bulut]] — proje/hesap kurtarma
- [[07-CI-CD]] — keystore/sır yedeği
- [[08-Guvenlik]] — sır/sertifika yedeği
- [[12-Loglama]] — yedek doğrulama/izleme
