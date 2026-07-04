import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'overpass_poi_service.dart';

/// Nominatim + Overpass ile birleşik yer arama servisi.
///
/// - Metin araması → Nominatim API (adres bazlı)
/// - Kategori araması → Overpass API (eczane, kafe vb.)
/// - Sonuçlar birleştirilir ve duplikasyonlar temizlenir.
class MapSearchService {
  Timer? _debounce;
  bool _isLoading = false;
  final OverpassPoiService _overpassService = OverpassPoiService();

  bool get isLoading => _isLoading;

  /// Timer'ı temizleyerek bellek sızıntısını önler.
  void dispose() {
    _debounce?.cancel();
    _overpassService.dispose();
  }

  /// Kullanıcı her harf yazdığında çağrılır.
  /// [query] boşsa mevcut sonuçları temizler.
  /// Doluysa 500ms bekleyip arama yapılır.
  void debouncedSearch({
    required String query,
    required void Function(List<Map<String, dynamic>> results) onResult,
    required void Function(bool loading) onLoadingChanged,
    double? userLat,
    double? userLon,
  }) {
    if (query.isEmpty) {
      onResult([]);
      return;
    }

    // Önceki zamanlayıcıyı iptal et
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _combinedSearch(
        query,
        onResult: onResult,
        onLoadingChanged: onLoadingChanged,
        userLat: userLat,
        userLon: userLon,
      );
    });
  }

  /// Nominatim + Overpass birleşik araması.
  Future<void> _combinedSearch(
    String query, {
    required void Function(List<Map<String, dynamic>> results) onResult,
    required void Function(bool loading) onLoadingChanged,
    double? userLat,
    double? userLon,
  }) async {
    if (query.length < 2) return;

    _isLoading = true;
    onLoadingChanged(true);

    try {
      // İki aramayı paralel olarak başlat. Nominatim'e referans konum geçilir
      // → sonuçlar kullanıcının çevresine bias'lanır (viewbox), uzak şehir
      // sonuçları listeyi doldurup "en yakın" olanı gömmesin.
      final results = await Future.wait([
        _searchNominatim(query, refLat: userLat, refLon: userLon),
        _searchOverpassByCategory(
          query,
          centerLat: userLat ?? 40.7731,
          centerLon: userLon ?? 30.4000,
        ),
      ]);

      final nominatimResults = results[0];
      final overpassResults = results[1];

      // Overpass sonuçlarını önce göster (kategori eşleşmesi daha alakalı)
      final combined = <Map<String, dynamic>>[];

      // Duplikasyon kontrolü için koordinat seti
      final addedCoords = <String>{};

      for (final r in overpassResults) {
        final coordKey =
            '${(r['lat'] as double).toStringAsFixed(4)},${(r['lon'] as double).toStringAsFixed(4)}';
        if (!addedCoords.contains(coordKey)) {
          addedCoords.add(coordKey);
          combined.add(r);
        }
      }

      for (final r in nominatimResults) {
        final coordKey =
            '${(r['lat'] as double).toStringAsFixed(4)},${(r['lon'] as double).toStringAsFixed(4)}';
        if (!addedCoords.contains(coordKey)) {
          addedCoords.add(coordKey);
          combined.add(r);
        }
      }

      // Kullanıcı konumu biliniyorsa sonuçları mesafeye göre sırala
      // (en yakın en üstte). Konum yoksa mevcut (kategori-öncelikli) sıra korunur.
      onResult(sortResultsByDistance(combined, userLat, userLon));
    } catch (e) {
      debugPrint("Birleşik arama hatası: $e");
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  /// Nominatim API ile adres/yer araması.
  ///
  /// [refLat]/[refLon] verilirse sonuçlar o noktanın çevresindeki **viewbox**'a
  /// öncelikle sınırlanır (`bounded=1`) → yerel sonuçlar döner, uzak şehirdekiler
  /// listeyi doldurmaz ("en yakın en üstte" için). Yerel kutuda hiç sonuç yoksa
  /// (ör. başka şehirdeki bir yerin adı arandı) **ülke geneline düşülür** →
  /// uzak adres/yer araması yine çalışır.
  Future<List<Map<String, dynamic>>> _searchNominatim(
    String query, {
    double? refLat,
    double? refLon,
  }) async {
    if (query.length < 3) return [];

    // ~0.5° ≈ 55 km kutu — il/çevre ölçeği; uzak metropolleri dışlar.
    const double d = 0.5;
    final String? viewbox = (refLat != null && refLon != null)
        // Nominatim viewbox biçimi: lon_min,lat_min,lon_max,lat_max
        ? '${refLon - d},${refLat - d},${refLon + d},${refLat + d}'
        : null;

    // Önce yerele sınırlı ara; boşsa ülke geneli fallback (sonuç kaybolmasın).
    var results = await _nominatimRequest(query, viewbox: viewbox, bounded: true);
    if (results.isEmpty && viewbox != null) {
      results = await _nominatimRequest(query, viewbox: null, bounded: false);
    }
    return results;
  }

  /// Tek bir Nominatim HTTP isteği (viewbox/bounded opsiyonlu).
  Future<List<Map<String, dynamic>>> _nominatimRequest(
    String query, {
    String? viewbox,
    bool bounded = false,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '10',
        'countrycodes': 'tr',
        'accept-language': 'tr',
      };
      if (viewbox != null) {
        params['viewbox'] = viewbox;
        if (bounded) params['bounded'] = '1';
      }

      final url =
          Uri.https('nominatim.openstreetmap.org', '/search', params);

      final response = await http.get(url, headers: {
        'User-Agent': 'asikar_engelsiz_kent_rehberi',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        return data.map((place) {
          String title = place['name'] ?? '';
          if (title.isEmpty && place['display_name'] != null) {
            title = place['display_name'].split(',')[0];
          }

          return {
            'title': title,
            'subtitle': place['display_name'] ?? 'Detaylı adres bulunamadı',
            'lat': double.parse(place['lat'].toString()),
            'lon': double.parse(place['lon'].toString()),
            'type': 'nominatim',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Nominatim arama hatası: $e");
    }
    return [];
  }

  /// Overpass API ile Türkçe kategori bazlı POI araması.
  Future<List<Map<String, dynamic>>> _searchOverpassByCategory(
    String query, {
    required double centerLat,
    required double centerLon,
  }) async {
    try {
      final pois = await _overpassService.searchPoisByCategory(
        categoryQuery: query,
        centerLat: centerLat,
        centerLon: centerLon,
        radiusMeters: 5000,
      );

      return pois.map((poi) {
        return {
          // İsimsiz kategori POI'lerine (park/otopark/tuvalet sıklıkla isimsiz)
          // Türkçe kategori adı başlık olur → aramada "kategorisi X olan" yerler
          // de görünür.
          'title': poi.name.isNotEmpty ? poi.name : poi.category,
          'subtitle': poi.address ?? '${poi.category} • ${poi.wheelchairStatusText}',
          'lat': poi.latitude,
          'lon': poi.longitude,
          'type': 'overpass',
          'osmPoi': poi,
          'category': poi.category,
        };
      }).toList();
    } catch (e) {
      debugPrint("Overpass kategori araması hatası: $e");
    }
    return [];
  }

  /// Eski API uyumluluğu için — doğrudan Nominatim araması.
  Future<void> searchPlaces(
    String query, {
    required void Function(List<Map<String, dynamic>> results) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    _isLoading = true;
    onLoadingChanged(true);
    try {
      final results = await _searchNominatim(query);
      onResult(results);
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }
}

/// Arama sonuçlarını kullanıcı konumuna göre mesafe sırasına dizer
/// (en yakın en üstte). Saf/testli.
///
/// [userLat]/[userLon] `null` ise (konum bilinmiyor) sonuçlar **değişmeden**
/// döner — mevcut kategori-öncelikli sıra korunur. Aksi hâlde her sonuca
/// metre cinsi `distanceMeters` alanı eklenir (O(n) — kıyaslamada yeniden
/// hesaplanmaz) ve buna göre kararlı biçimde sıralanır.
List<Map<String, dynamic>> sortResultsByDistance(
  List<Map<String, dynamic>> results,
  double? userLat,
  double? userLon,
) {
  if (userLat == null || userLon == null) return results;

  final origin = LatLng(userLat, userLon);
  const distance = Distance();
  for (final r in results) {
    r['distanceMeters'] = distance.as(
      LengthUnit.Meter,
      origin,
      LatLng(r['lat'] as double, r['lon'] as double),
    );
  }
  results.sort((a, b) =>
      (a['distanceMeters'] as double).compareTo(b['distanceMeters'] as double));
  return results;
}
