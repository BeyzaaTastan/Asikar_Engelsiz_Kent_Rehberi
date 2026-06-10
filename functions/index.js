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

        const message = {
            topic: "volunteers",
            data: {
                type: 'call',
                caller_name: afterData.caller_name || 'Aşikar Kullanıcısı',
                channel_name: afterData.kanal_adi || 'yardim_kanali'
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
exports.generateAgoraToken = functions.region('europe-west3').https
    .onCall(async (data, context) => {
        // Yalnızca giriş yapmış kullanıcılar token alabilir
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                'Token oluşturmak için giriş yapmanız gerekiyor.'
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
