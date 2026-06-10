import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan merkezi renk sabitleri.
///
/// Her ekranda tekrarlanan `final Color primaryColor = const Color(0xFF1C4576)`
/// gibi tanımlar yerine `AppColors.primary` kullanılmalıdır.
class AppColors {
  // Yapıcı metot çağrılmasın — sadece static sabitleri barındıran utility sınıfı
  AppColors._();

  /// Lacivert — Ana marka rengi, başlıklar, butonlar
  static const Color primary = Color(0xFF1C4576);

  /// Turkuaz — İkincil vurgu, linkler, seçili durumlar
  static const Color secondary = Color(0xFF38A3B5);

  /// Yeşil — Üçüncül vurgu, gönüllü teması, başarı durumları
  static const Color tertiary = Color(0xFF64A744);

  /// Açık gri — Scaffold arka plan rengi
  static const Color background = Color(0xFFF4F7FA);

  /// Orta gri — İkon ve placeholder metinleri
  static const Color outline = Color(0xFF737780);

  /// Koyu gri — Gövde metinleri, açıklama satırları
  static const Color textDark = Color(0xFF43474F);

  /// Çok koyu — Büyük başlıklar, vurgulu metinler
  static const Color surface = Color(0xFF181C1E);

  /// Kırmızı — Hata, iptal ve uyarı durumları
  static const Color danger = Color(0xFFDC3545);

  /// Turuncu — Bakım, dikkat bildirimleri
  static const Color warning = Color(0xFFF39C12);

  /// Splash ekranı arka plan rengi
  static const Color splashBackground = Color(0xFFF7FAFD);

  /// Koyu turkuaz — Erişilebilirlik bilgi kutusu metin rengi
  static const Color infoDarkTeal = Color(0xFF006B79);

  /// Açık arka plan — Sonuç paneli, kutular
  static const Color lightSurface = Color(0xFFF1F4F7);

  /// İnce kenar ve ayırıcı rengi
  static const Color chipBorder = Color(0xFFC3C6D0);
}
