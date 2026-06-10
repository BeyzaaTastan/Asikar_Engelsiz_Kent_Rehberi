import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../screens/call_screen.dart';

// 🛑 ÇOK ÖNEMLİ: Bu fonksiyon sınıfın DIŞINDA olmak zorunda.
// Çünkü uygulama kapalıyken bile çalışıp mesajları yakalaması gerekiyor.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Arka planda (uygulama kapalıyken) sinyal geldi: ${message.notification?.title}");
  
  // Bildirimde çağrı varsa telefonu çaldır
  if (message.data['type'] == 'call') {
    _showCallkitIncoming(message.data['caller_name'], message.data['channel_name']);
  }
}

void _showCallkitIncoming(String? callerName, String? channelName) async {
  final callId = const Uuid().v4();
  CallKitParams callKitParams = CallKitParams(
    id: callId,
    nameCaller: callerName ?? 'Aşikar Çağrı Merkezi',
    appName: 'Aşikar',
    avatar: 'https://i.pravatar.cc/100',
    handle: 'Acil Yardım Çağrısı',
    type: 0,
    duration: 30000,
    textAccept: 'Cevapla',
    textDecline: 'Reddet',
    missedCallNotification: const NotificationParams(
      showNotification: true,
      isShowCallback: false,
      subtitle: 'Cevapsız Çağrı',
      callbackText: 'Geri Ara',
    ),
    extra: <String, dynamic>{'channel_name': channelName ?? 'yardim_kanali'},
    headers: <String, dynamic>{'apiKey': 'v1.0', 'platform': 'flutter'},
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0955fa',
      actionColor: '#4CAF50',
    ),
    ios: const IOSParams(
      iconName: 'CallKitLogo',
      handleType: '',
      supportsVideo: true,
      maximumCallGroups: 2,
      maximumCallsPerCallGroup: 1,
      audioSessionMode: 'default',
      audioSessionActive: true,
      audioSessionPreferredSampleRate: 44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF: true,
      supportsHolding: true,
      supportsGrouping: false,
      supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? pendingCallId;
  // Listener'ın birden fazla kez kurulmasını önler
  static bool _listenerInitialized = false;

  /// CallScreen'e yönlendirmeyi dener. Navigator henüz hazır değilse
  /// 300ms aralıklarla [maxRetries] kez tekrar dener.
  static void _navigateToCallScreen(String callId, {int retryCount = 0, int maxRetries = 15}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      debugPrint("🚀 CallScreen'e yönlendiriliyor (deneme: ${retryCount + 1}): $callId");
      navigator.push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            isVolunteer: true,
            callId: callId,
          ),
        ),
      );
    } else if (retryCount < maxRetries) {
      debugPrint("⏳ Navigator henüz hazır değil, ${300}ms sonra tekrar deneniyor... ($retryCount/$maxRetries)");
      Future.delayed(const Duration(milliseconds: 300), () {
        _navigateToCallScreen(callId, retryCount: retryCount + 1, maxRetries: maxRetries);
      });
    } else {
      // Tüm denemeler başarısız oldu — MainWrapper devralacak
      debugPrint("⚠️ Navigator $maxRetries denemede hazır olmadı, pendingCallId olarak işaretlendi.");
      pendingCallId = callId;
    }
  }

  static Future<void> subscribeToVolunteers() async {
    try {
      await _messaging.subscribeToTopic('volunteers');
      debugPrint("Gönüllüler kanalına abone olundu.");
    } catch (e) {
      debugPrint("Kanal aboneliği başarısız: $e");
    }
  }

  static Future<void> unsubscribeFromVolunteers() async {
    try {
      await _messaging.unsubscribeFromTopic('volunteers');
      debugPrint("Gönüllüler kanalından çıkıldı.");
    } catch (e) {
      debugPrint("Kanal aboneliğinden çıkış başarısız: $e");
    }
  }

  /// FCM token'ı Firestore'daki kullanıcı belgesine kaydeder.
  /// Yalnızca giriş yapmış kullanıcı için çalışır.
  static Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint("FCM token kaydedilemedi: kullanıcı oturum açmamış.");
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
      debugPrint("✅ FCM token Firestore'a kaydedildi.");
    } catch (e) {
      // Kullanıcı belgesi henüz oluşturulmamış olabilir (kayıt akışı devam ediyor).
      // Bu durumda sessizce geç — MainWrapper'da profil kaydedilince token da yazılır.
      debugPrint("FCM token Firestore kaydı başarısız (belge henüz yok olabilir): $e");
    }
  }

  /// Kullanıcı çıkış yaptığında FCM token'ı Firestore'dan temizler.
  /// Böylece çıkış yapan kullanıcıya artık bildirim gönderilmez.
  static Future<void> clearFcmTokenFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
      debugPrint("FCM token Firestore'dan temizlendi.");
    } catch (e) {
      debugPrint("FCM token temizleme hatası: $e");
    }
  }

  static Future<void> initialize() async {
    // 1. Kullanıcıdan bildirim izni iste
    await Permission.notification.request();

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Kullanıcı bildirimlere izin verdi!');
    }

    // CallKit için ekstra sistem izinleri
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        "rationaleMessagePermission": "Aramaları ekranda görebilmek için bildirim ve diğer uygulamaların üzerinde gösterme izni gereklidir.",
        "postNotificationMessageRequired": "İzin vermeniz zorunludur."
      });
    } catch (e) {
      debugPrint("CallKit izin hatası: $e");
    }

    // 2. Bu cihazın FCM token'ını al ve Firestore'a kaydet
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint("📢 FCM Token alındı, Firestore'a kaydediliyor...");
        await _saveFcmTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint("Token alınırken hata oluştu: $e");
    }

    // 3. Token yenilenince Firestore'u otomatik güncelle
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint("🔄 FCM Token yenilendi, Firestore güncelleniyor...");
      await _saveFcmTokenToFirestore(newToken);
    });

    // 4. Arka plan sinyallerini dinlemeye başla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Uygulama açıkken sinyal gelirse
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Uygulama açıkken sinyal geldi!');
      if (message.data['type'] == 'call') {
        _showCallkitIncoming(message.data['caller_name'], message.data['channel_name']);
      }
    });

    // 6. Uygulama arka plandayken kullanıcı "Cevapla"ya bastıysa ve
    //    uygulama yeniden açıldıysa, aktif çağrıları kontrol et.
    //    Bu, çift instance sorununu önleyen singleTask ile birlikte çalışır.
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls != null && activeCalls is List && activeCalls.isNotEmpty) {
        final activeCall = activeCalls.first as Map<dynamic, dynamic>?;
        final status = activeCall?['callStatus'];
        // Eğer çağrı "accepted" durumundaysa (kullanıcı dışarıdan cevapladı)
        if (status == 'accepted' || status == 'ACCEPTED') {
          final channelName = activeCall?['extra']?['channel_name'] as String?;
          final callId = channelName ?? 'aktif_cagri';
          debugPrint("📞 Arka planda kabul edilmiş çağrı bulundu: $callId");
          pendingCallId = callId;
        }
      }
    } catch (e) {
      debugPrint("Aktif çağrı kontrolünde hata: $e");
    }

    // 7. CallKit'ten gelen "Cevapla" / "Reddet" aksiyonlarını dinle
    //    Listener yalnızca bir kez kurulur (çift kayıt önlenir).
    if (!_listenerInitialized) {
      _listenerInitialized = true;
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        switch (event.event) {
          case Event.actionCallAccept:
            debugPrint("Çağrı CallKit üzerinden KABUL edildi!");

            final String callId = (event.body != null && event.body['extra'] != null)
                ? (event.body['extra']['channel_name'] ?? 'aktif_cagri')
                : 'aktif_cagri';

            // Santrale "Çağrıyı ben aldım" sinyali gönder
            final uid = FirebaseAuth.instance.currentUser?.uid;
            FirebaseFirestore.instance.collection('cagrilar').doc(callId).update({
              'cagri_durumu': 'cevaplandi',
              'volunteer_uid': uid ?? '',
            }).catchError((e) => debugPrint("Firestore güncelleme hatası: $e"));

            // Görüntülü konuşma ekranına git — navigator hazır olmasa bile retry ile dener
            _navigateToCallScreen(callId);
            break;
          case Event.actionCallDecline:
            debugPrint("Çağrı CallKit üzerinden REDDEDİLDİ!");
            break;
          default:
            break;
        }
      });
    }
  }
}
