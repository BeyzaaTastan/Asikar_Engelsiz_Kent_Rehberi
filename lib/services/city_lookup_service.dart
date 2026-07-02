import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../utils/city_slug.dart';

/// Koordinattan şehir (il) adı / slug'ı çözümler — Nominatim reverse geocode.
///
/// Çağrı yönlendirmesinde kullanılır: fiziksel yardım çağrısı yalnızca aynı
/// şehirdeki gönüllülere düşer (bkz. vault/07-Performance/11-Olcekleme.md).
/// Şehir kaynağı KARARI: arayanın/gönüllünün ANLIK GPS konumu (profil şehri değil —
/// turist bulunduğu şehrin gönüllüsünü ister).
///
/// Acil çağrı akışında gecikmeyi düşük tutmak için önce `getLastKnownPosition`
/// (anında) denenir; yoksa kısa timeout'lu `getCurrentPosition`. Herhangi bir
/// hata/gecikmede `null` döner → çağıran tarafta global `volunteers` fallback'i
/// uygulanır (çağrı hiç engellenmez).
class CityLookupService {
  /// Verilen koordinatın il adını döndürür (ör. "Sakarya"). Bulunamazsa `null`.
  static Future<String?> cityFromCoordinates(
    double lat,
    double lon, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': 'tr',
        'zoom': '10', // il/ilçe seviyesi ayrıntı yeter
      });
      final response = await http.get(url, headers: {
        'User-Agent': 'asikar_engelsiz_kent_rehberi',
      }).timeout(timeout);

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;
      // Türkiye'de il genelde 'province'; bazı sonuçlarda 'city'/'state'/'town'.
      final city = addr['province'] ?? addr['city'] ?? addr['state'] ?? addr['town'];
      if (city is String && city.trim().isNotEmpty) return city.trim();
      return null;
    } catch (e) {
      debugPrint('Şehir çözümleme (reverse geocode) hatası: $e');
      return null;
    }
  }

  /// Cihazın anlık konumundan şehir slug'ını çözer (ör. "sakarya"). Konum izni
  /// yoksa / servis kapalıysa / gecikirse `null` döner (global fallback).
  static Future<String?> currentCitySlug({
    Duration positionTimeout = const Duration(seconds: 5),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Önce son bilinen konum (anında); yoksa kısa timeout'lu anlık konum.
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(positionTimeout);

      final cityName = await cityFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return citySlug(cityName);
    } catch (e) {
      debugPrint('currentCitySlug hatası: $e');
      return null;
    }
  }
}
