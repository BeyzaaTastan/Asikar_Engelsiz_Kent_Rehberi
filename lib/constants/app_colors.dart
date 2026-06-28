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

  // ── Harita POI kategori paleti ──────────────────────────────────────────
  // OSM/Foursquare POI marker renkleri (bkz. lib/screens/map/map_visuals.dart).
  static const Color poiCafe = Color(0xFF795548);       // Kahverengi
  static const Color poiRestaurant = Color(0xFFE65100); // Turuncu
  static const Color poiPharmacy = Color(0xFF2E7D32);   // Yeşil
  static const Color poiShop = Color(0xFF1565C0);       // Mavi
  static const Color poiHealth = Color(0xFFC62828);     // Kırmızı
  static const Color poiBank = Color(0xFF283593);       // Lacivert
  static const Color poiWorship = Color(0xFF00838F);    // Turkuaz
  static const Color poiEducation = Color(0xFF6A1B9A);  // Mor
  static const Color poiHotel = Color(0xFFAD1457);      // Pembe
  static const Color poiPark = Color(0xFF388E3C);       // Koyu yeşil
  static const Color poiFuel = Color(0xFF455A64);       // Gri
  static const Color poiCulture = Color(0xFF5D4037);    // Koyu kahverengi
  static const Color poiDefault = Color(0xFF546E7A);    // Varsayılan gri
  static const Color poiTactile = Color(0xFF8E24AA);    // Mor — hissedilebilir yüzey rozeti
}
