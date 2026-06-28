const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { RtcTokenBuilder, RtcRole } = require("agora-token");
admin.initializeApp();

// =============================================================================
// Fonksiyon 1: Çağrı Bildirimi Gönderici
// Firestore'daki 'cagrilar' koleksiyonunu dinler; durum 'bekliyor' olursa
// 'volunteers' FCM topic'ine bildirim gönderir.
// =============================================================================
exports.cagriBildirimiGonder = functions.region('europe-west3').firestore
    .document('cagrilar/{cagriId}')
    .onWrite(async (change, context) => {
        const beforeData = change.before.data();
        const afterData = change.after.data();

        // Sadece durum "bekliyor" haline YENİ geldiyse bildirim gönder (çift tetiklemeyi önler)
        const wasWaiting = beforeData && beforeData.cagri_durumu === 'bekliyor';
        const isWaiting = afterData && afterData.cagri_durumu === 'bekliyor';

        if (!isWaiting || wasWaiting) {
            console.log("Durum değişmedi veya bekliyor durumunda değil, bildirim atılmıyor.");
            return null;
        }

        // Kanal adı = Agora kanalı = çağrı belge ID'si. Yoksa gönüllü bağlanacak
        // bir görüşme bulamaz; paylaşılan bir sabite ('yardim_kanali') düşmek
        // eşzamanlı çağrılarda yanlış görüşmeye yol açar. Bu yüzden bildirim atma.
        const channelName = afterData.kanal_adi;
        if (typeof channelName !== 'string' || channelName.length === 0) {
            console.error("Çağrıda geçerli kanal_adi yok, bildirim gönderilmiyor:", context.params.cagriId);
            return null;
        }

        const message = {
            topic: "volunteers",
            data: {
                type: 'call',
                caller_name: afterData.caller_name || 'Aşikar Kullanıcısı',
                channel_name: channelName
            },
            android: {
                priority: 'high',
                ttl: 30 * 1000
            },
            apns: {
                payload: {
                    aps: { contentAvailable: true }
                },
                headers: { 'apns-priority': '10' }
            }
        };

        try {
            const response = await admin.messaging().send(message);
            console.log("Bildirim başarıyla gönderildi:", response);
            return response;
        } catch (error) {
            console.error("Bildirim gönderilirken hata oluştu:", error);
            return null;
        }
    });

// =============================================================================
// Fonksiyon 1b: Çağrı Zaman Aşımı Temizleyici (güvenlik ağı)
// Her dakika çalışır; uzun süredir 'bekliyor' durumunda kalan (arayanın uygulaması
// kapanmış olabilir) terk edilmiş çağrıları 'zaman_asimi' yapar.
//
// Birincil zaman aşımı İSTEMCİ tarafındadır (CallScreen, 45 sn) — kullanıcı anında
// "gönüllü bulunamadı" geri bildirimi alsın diye. Bu fonksiyon yalnızca arayan
// uygulaması kapandığında ortada kalan çağrıları temizler; böylece gönüllüler
// terk edilmiş çağrıları görmeye devam etmez.
//
// NOT: Bileşik index gerektirmemek için yalnızca 'bekliyor' eşitlik sorgusu yapılır,
// zaman eşiği bellek içinde filtrelenir (tek şehir → bekleyen çağrı sayısı düşük).
// =============================================================================
const CAGRI_ZAMAN_ASIMI_MS = 90 * 1000; // İstemci sayacından (45sn) uzun: terk tespiti

exports.cagriZamanAsimiTemizle = functions.region('europe-west3').pubsub
    .schedule('every 1 minutes')
    .onRun(async () => {
        const db = admin.firestore();
        const snap = await db.collection('cagrilar')
            .where('cagri_durumu', '==', 'bekliyor')
            .get();

        if (snap.empty) {
            console.log("Bekleyen çağrı yok, zaman aşımı kontrolü atlandı.");
            return null;
        }

        const esikMs = Date.now() - CAGRI_ZAMAN_ASIMI_MS;
        const batch = db.batch();
        let sayac = 0;
        snap.forEach((doc) => {
            const zaman = doc.get('zaman'); // Firestore Timestamp
            if (zaman && typeof zaman.toMillis === 'function' && zaman.toMillis() < esikMs) {
                batch.update(doc.ref, { cagri_durumu: 'zaman_asimi' });
                sayac++;
            }
        });

        if (sayac === 0) {
            console.log("Zaman aşımına uğrayan terk edilmiş çağrı yok.");
            return null;
        }

        await batch.commit();
        console.log(`${sayac} terk edilmiş çağrı zaman aşımına uğratıldı.`);
        return null;
    });

// =============================================================================
// Fonksiyon 2: Agora RTC Token Üreteci
// Flutter uygulaması bu fonksiyonu çağırarak güvenli bir Agora token'ı alır.
// App Certificate asla istemci tarafına gönderilmez; yalnızca bu fonksiyonda kullanılır.
//
// Ortam değişkenleri functions/.env dosyasından okunur (deploy sırasında otomatik yüklenir).
//
// Kullanım: FirebaseFunctions.httpsCallable('generateAgoraToken').call({
//   channelName: 'kanal-uuid',
//   uid: 0,
// })
// =============================================================================
// App Check zorlaması bir ortam bayrağıyla aç/kapatılır (functions/.env → APP_CHECK_ENFORCE).
// GÜVENLİ KULLANIMA ALMA: önce istemci App Check ile deploy edilir ve Console'da
// App Check metrikleri izlenir (zorlama KAPALI). Meşru trafiğin token taşıdığı
// doğrulanınca APP_CHECK_ENFORCE=true yapılır. Bayrak set edilmezse zorlama yapılmaz
// (mevcut davranış korunur, uygulama kırılmaz).
const ENFORCE_APP_CHECK = process.env.APP_CHECK_ENFORCE === 'true';

exports.generateAgoraToken = functions.region('europe-west3').https
    .onCall(async (data, context) => {
        // Yalnızca giriş yapmış kullanıcılar token alabilir
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                'Token oluşturmak için giriş yapmanız gerekiyor.'
            );
        }

        // App Check: geçerli bir uygulama attestation token'ı yoksa reddet.
        // context.app yalnızca istemci geçerli bir App Check token'ı gönderdiğinde dolar.
        if (ENFORCE_APP_CHECK && !context.app) {
            console.warn("App Check token'ı yok/geçersiz, token isteği reddedildi. UID:", context.auth.uid);
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Uygulama doğrulaması (App Check) gerekli.'
            );
        }

        const channelName = data.channelName;
        const uid = data.uid || 0;

        if (!channelName || typeof channelName !== 'string' || channelName.length === 0) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Geçerli bir channelName girilmelidir.'
            );
        }

        // .env dosyasından okunan ortam değişkenleri (process.env ile erişilir)
        const appId = process.env.AGORA_APP_ID;
        const appCertificate = process.env.AGORA_APP_CERTIFICATE;

        if (!appId || !appCertificate) {
            console.error("Agora App ID veya App Certificate eksik! .env dosyasını kontrol edin.");
            throw new functions.https.HttpsError(
                'internal',
                'Sunucu yapılandırma hatası. Lütfen daha sonra tekrar deneyin.'
            );
        }

        // Token 1 saat geçerli olacak
        const expirationTimeInSeconds = 3600;
        const currentTimestamp = Math.floor(Date.now() / 1000);
        const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

        try {
            const token = RtcTokenBuilder.buildTokenWithUid(
                appId,
                appCertificate,
                channelName,
                uid,
                RtcRole.PUBLISHER,
                privilegeExpiredTs,
                privilegeExpiredTs
            );

            console.log(`Agora token üretildi. Kanal: ${channelName}, Kullanıcı: ${context.auth.uid}`);
            return { token };
        } catch (error) {
            console.error("Agora token üretim hatası:", error);
            throw new functions.https.HttpsError(
                'internal',
                'Token oluşturulurken bir hata oluştu.'
            );
        }
    });
