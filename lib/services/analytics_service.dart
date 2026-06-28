import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Gözlemlenebilirlik servisi: Firebase Analytics (ürün metrikleri) +
/// Crashlytics (çökme / yakalanmış hata raporu).
///
/// **KVKK NOTU (CLAUDE.md kural #6):** Bu servise ASLA konum, engellilik
/// durumu, e-posta veya başka kişisel nitelikli veri geçirilmez. Event'ler
/// yalnızca anonim akış metrikleri taşır (çağrı durumu geçişleri gibi).
/// `setUserIdentifier` bilinçli olarak kullanılmaz.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// MaterialApp'in `navigatorObservers` listesine eklenir → ekran
  /// görüntülemeleri (screen_view) otomatik loglanır.
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Açılışta bir kez çağrılır. Toplamayı yapılandırır ve global Flutter
  /// hata yakalayıcılarını Crashlytics'e yönlendirir.
  ///
  /// Debug modda toplama KAPALI: hem geliştirme gürültüsünü panoya
  /// taşımamak hem de test cihazından kişisel veri sızdırmamak için.
  static Future<void> init() async {
    final bool collect = !kDebugMode;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(collect);
      await _analytics.setAnalyticsCollectionEnabled(collect);
    } catch (e) {
      debugPrint('Gözlemlenebilirlik toplama ayarı hatası: $e');
    }

    // Flutter framework (build/layout/paint) hatalarını Crashlytics'e yönlendir.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Flutter dışı (async / platform kanalı) yakalanmamış hataları yakala.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // --- Çağrı yaşam döngüsü (PRD başarı metriği: tamamlanan çağrı oranı) ---

  /// Engelli kullanıcı "YARDIM İSTE" ile çağrı başlattı (→ bekliyor).
  static Future<void> cagriBaslatildi() => _log('cagri_baslatildi');

  /// Bir gönüllü çağrıyı üstlendi (bekliyor → cevaplandi).
  static Future<void> cagriCevaplandi() => _log('cagri_cevaplandi');

  /// Görüşme normal şekilde tamamlandı (→ bitti).
  static Future<void> cagriTamamlandi() => _log('cagri_tamamlandi');

  /// Süre içinde gönüllü bulunamadı (→ zaman_asimi).
  static Future<void> cagriZamanAsimi() => _log('cagri_zaman_asimi');

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics event hatası ($name): $e');
    }
  }

  /// Yakalanmış (non-fatal) bir hatayı Crashlytics'e bildirir. `reason`
  /// kişisel veri İÇERMEMELİDİR (KVKK).
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason);
    } catch (_) {
      // Raporlama hatası uygulamayı etkilememeli.
    }
  }
}
