import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
      // İki aramayı paralel olarak başlat
      final results = await Future.wait([
        _searchNominatim(query),
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

      onResult(combined);
    } catch (e) {
      debugPrint("Birleşik arama hatası: $e");
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  /// Nominatim API ile adres/yer araması.
  Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
          'countrycodes': 'tr',
          'accept-language': 'tr',
        },
      );

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
          'title': poi.name,
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
