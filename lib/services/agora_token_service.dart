import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Agora RTC token'larını güvenli biçimde Cloud Function üzerinden alır.
///
/// App Certificate asla Flutter tarafında tutulmaz; tüm imzalama işlemi
/// sunucu tarafındaki [generateAgoraToken] Cloud Function'ı tarafından yapılır.
class AgoraTokenService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west3');

  /// Belirtilen [channelName] için sunucudan imzalı bir Agora RTC token'ı alır.
  ///
  /// [channelName] — Agora kanalının adı (genellikle çağrının UUID'si).
  /// [uid]         — Agora kullanıcı ID'si (0 = Agora otomatik atar).
  ///
  /// Hata durumunda null döner ve çağrı devam etmez.
  static Future<String?> fetchToken({
    required String channelName,
    int uid = 0,
  }) async {
    try {
      debugPrint("🔑 Agora token isteniyor... Kanal: $channelName");

      final HttpsCallable callable = _functions.httpsCallable('generateAgoraToken');
      final result = await callable.call<Map<String, dynamic>>({
        'channelName': channelName,
        'uid': uid,
      });

      final token = result.data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        debugPrint("✅ Agora token alındı.");
        return token;
      } else {
        debugPrint("❌ Agora token boş geldi.");
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Agora token Cloud Function hatası: [${e.code}] ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Agora token beklenmeyen hata: $e");
      return null;
    }
  }
}
