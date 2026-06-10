import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Nominatim OpenStreetMap API üzerinden yer arama servisi.
///
/// Arama debounce mekanizması içerir — kullanıcı yazmayı durdurduktan
/// 500ms sonra API çağrısı yapılır.
class MapSearchService {
  Timer? _debounce;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Timer'ı temizleyerek bellek sızıntısını önler.
  void dispose() {
    _debounce?.cancel();
  }

  /// Kullanıcı her harf yazdığında çağrılır.
  /// [query] boşsa mevcut sonuçları temizler.
  /// Doluysa 500ms bekleyip [_searchPlaces]'i tetikler.
  void debouncedSearch({
    required String query,
    required void Function(List<Map<String, dynamic>> results) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) {
    if (query.isEmpty) {
      onResult([]);
      return;
    }

    // Önceki zamanlayıcıyı iptal et
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchPlaces(query, onResult: onResult, onLoadingChanged: onLoadingChanged);
    });
  }

  /// Nominatim API'ye istek atarak sonuçları [onResult] callback'i ile döndürür.
  Future<void> searchPlaces(
    String query, {
    required void Function(List<Map<String, dynamic>> results) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    if (query.length < 3) return;

    _isLoading = true;
    onLoadingChanged(true);

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
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        final results = data.map((place) {
          String title = place['name'] ?? '';
          if (title.isEmpty && place['display_name'] != null) {
            title = place['display_name'].split(',')[0];
          }

          return {
            'title': title,
            'subtitle': place['display_name'] ?? 'Detaylı adres bulunamadı',
            'lat': double.parse(place['lat'].toString()),
            'lon': double.parse(place['lon'].toString()),
            'type': 'place',
          };
        }).toList();

        onResult(results);
      }
    } catch (e) {
      debugPrint("Arama Hatası: $e");
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }
}
