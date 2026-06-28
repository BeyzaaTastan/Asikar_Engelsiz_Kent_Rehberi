import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import '../models/osm_poi_model.dart';



/// Overpass API üzerinden haritanın görünür alanındaki POI'leri çeken servis.
///
/// Debounce, cache ve zoom kontrolü mekanizmalarını içerir.
/// Yalnızca zoom ≥ 15 olduğunda sorgu atar.
class OverpassPoiService {
  Timer? _debounce;
  bool _isLoading = false;

  // ── Cache ──────────────────────────────────────────────────────────────────
  // Son sorgulanan bbox ve sonuçları — aynı alan tekrar sorgulanmaz.
  String? _lastBboxKey;
  List<OsmPoi> _cachedPois = [];
  Set<String> _lastCategories = {};

  bool get isLoading => _isLoading;

  void dispose() {
    _debounce?.cancel();
  }

  // ── Türkçe kategori → OSM tag eşleştirmesi ────────────────────────────────
  /// Haritada gösterilebilecek tüm POI türleri.
  /// Key: Türkçe kategori adı, Value: Overpass sorgu parçası
  static const Map<String, String> categoryFilters = {
    'Kafe':       'nwr["amenity"="cafe"]',
    'Restoran':   'nwr["amenity"="restaurant"]',
    'Fast Food':  'nwr["amenity"="fast_food"]',
    'Eczane':     'nwr["amenity"="pharmacy"]',
    'Market':     'nwr["amenity"="supermarket"]',
    'Hastane':    'nwr["amenity"="hospital"]',
    'Banka':      'nwr["amenity"="bank"]',
    'Okul':       'nwr["amenity"="school"]',
    'Kütüphane':  'nwr["amenity"="library"]',
    'Akaryakıt':  'nwr["amenity"="fuel"]',
    'Otopark':    'nwr["amenity"="parking"]',
    'Cami':       'nwr["amenity"="place_of_worship"]',
    'Polis':      'nwr["amenity"="police"]',
    'Postane':    'nwr["amenity"="post_office"]',
    'Müze':       'nwr["tourism"="museum"]',
    'Fırın':      'nwr["shop"="bakery"]',
    'Kasap':      'nwr["shop"="butcher"]',
    'Manav':      'nwr["shop"="greengrocer"]',
    'Bakkal':     'nwr["shop"="convenience"]',
    'Kuaför':     'nwr["shop"="hairdresser"]',
    'Otel':       'nwr["tourism"="hotel"]',
    'Park':       'nwr["leisure"="park"]',
  };

  /// Sık kullanılan hızlı filtre chip'leri için alt küme.
  static const List<String> quickFilterCategories = [
    'Kafe',
    'Restoran',
    'Eczane',
    'Market',
    'Hastane',
    'Otel',
    'Park',
  ];

  // ── Debounce ile POI çekme ─────────────────────────────────────────────────

  /// Harita her hareket ettiğinde çağrılır.
  /// 800ms bekledikten sonra Overpass sorgusunu tetikler.
  void debouncedFetch({
    required LatLngBounds bounds,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchPoisForBounds(
        bounds: bounds,
        selectedCategories: selectedCategories,
        onResult: onResult,
        onLoadingChanged: onLoadingChanged,
      );
    });
  }

  /// Belirli bir bounding box içindeki POI'leri Overpass API'den çeker.
  Future<void> fetchPoisForBounds({
    required LatLngBounds bounds,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    // Cache kontrolü — aynı alan ve kategoriler tekrar sorgulanmaz
    final bboxKey = _buildBboxKey(bounds);
    if (bboxKey == _lastBboxKey &&
        _setEquals(selectedCategories, _lastCategories) &&
        _cachedPois.isNotEmpty) {
      onResult(_cachedPois);
      return;
    }

    _isLoading = true;
    onLoadingChanged(true);

    try {
      final query = _buildOverpassQuery(bounds, selectedCategories);
      final url = Uri.parse('https://overpass-api.de/api/interpreter');

      final response = await http.post(
        url,
        body: {'data': query},
        headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi/1.0'},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>? ?? [];

        final pois = <OsmPoi>[];
        for (final element in elements) {
          final poi = OsmPoi.fromOverpassElement(element as Map<String, dynamic>);
          // İsimsiz mekanları atla
          if (poi.name.isNotEmpty && poi.latitude != 0) {
            pois.add(poi);
          }
        }

        // Cache'i güncelle
        _lastBboxKey = bboxKey;
        _lastCategories = Set.from(selectedCategories);
        _cachedPois = pois;

        onResult(pois);
      } else if (response.statusCode == 429) {
        debugPrint('Overpass API: Çok fazla istek (429). Lütfen bekleyin.');
      } else {
        debugPrint('Overpass API hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Overpass POI çekme hatası: $e');
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  /// Arama sorgusu ile POI bulan yardımcı metod.
  /// Belirli bir çevrede kategori bazlı arama yapar.
  Future<List<OsmPoi>> searchPoisByCategory({
    required String categoryQuery,
    required double centerLat,
    required double centerLon,
    int radiusMeters = 3000,
  }) async {
    // Türkçe sorguyu OSM amenity türüne çevir
    final osmTypes = _turkishQueryToOsmTypes(categoryQuery);
    if (osmTypes.isEmpty) return [];

    final typeFilter = osmTypes.map((t) {
      if (t.startsWith('shop_')) {
        return 'nwr["shop"="${t.substring(5)}"](around:$radiusMeters,$centerLat,$centerLon);';
      } else if (t.startsWith('tourism_')) {
        return 'nwr["tourism"="${t.substring(8)}"](around:$radiusMeters,$centerLat,$centerLon);';
      } else if (t.startsWith('leisure_')) {
        return 'nwr["leisure"="${t.substring(8)}"](around:$radiusMeters,$centerLat,$centerLon);';
      } else {
        return 'nwr["amenity"="$t"](around:$radiusMeters,$centerLat,$centerLon);';
      }
    }).join('\n');

    final query = '''
[out:json][timeout:20];
(
$typeFilter
);
out body center;
''';

    try {
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(
        url,
        body: {'data': query},
        headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi/1.0'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>? ?? [];
        return elements
            .map((e) => OsmPoi.fromOverpassElement(e as Map<String, dynamic>))
            .where((p) => p.name.isNotEmpty && p.latitude != 0)
            .toList();
      }
    } catch (e) {
      debugPrint('Overpass kategori araması hatası: $e');
    }
    return [];
  }

  // ── Yardımcı metodlar ──────────────────────────────────────────────────────

  /// Seçili kategorilere göre Overpass QL sorgusu oluşturur.
  String _buildOverpassQuery(LatLngBounds bounds, Set<String> categories) {
    final south = bounds.southWest.latitude;
    final west = bounds.southWest.longitude;
    final north = bounds.northEast.latitude;
    final east = bounds.northEast.longitude;
    final bbox = '($south,$west,$north,$east)';

    final categoriesToUse = categories.isEmpty
        ? categoryFilters.keys.toSet()
        : categories;

    final queryParts = <String>[];
    for (final cat in categoriesToUse) {
      final filter = categoryFilters[cat];
      if (filter != null) {
        queryParts.add('$filter$bbox;');
      }
    }

    return '''
[out:json][timeout:25];
(
${queryParts.join('\n')}
);
out body center;
''';
  }

  /// Bounding box'tan tekil bir cache anahtarı oluşturur.
  /// Küçük farklılıkları yok sayar (3 ondalık basamağa yuvarlar ~100m).
  String _buildBboxKey(LatLngBounds bounds) {
    final s = bounds.southWest.latitude.toStringAsFixed(3);
    final w = bounds.southWest.longitude.toStringAsFixed(3);
    final n = bounds.northEast.latitude.toStringAsFixed(3);
    final e = bounds.northEast.longitude.toStringAsFixed(3);
    return '$s,$w,$n,$e';
  }

  /// Türkçe arama sorgusunu OSM amenity türlerine eşleştirir.
  List<String> _turkishQueryToOsmTypes(String query) {
    final q = query.toLowerCase().trim();
    const mapping = {
      'kafe': ['cafe'],
      'kahve': ['cafe'],
      'restoran': ['restaurant'],
      'yemek': ['restaurant', 'fast_food'],
      'lokanta': ['restaurant'],
      'fast food': ['fast_food'],
      'eczane': ['pharmacy'],
      'ilaç': ['pharmacy'],
      'market': ['supermarket'],
      'süpermarket': ['supermarket'],
      'bakkal': ['shop_convenience'],
      'hastane': ['hospital'],
      'sağlık': ['hospital', 'clinic'],
      'klinik': ['clinic'],
      'doktor': ['doctors'],
      'banka': ['bank'],
      'atm': ['atm'],
      'okul': ['school'],
      'üniversite': ['university'],
      'kütüphane': ['library'],
      'benzin': ['fuel'],
      'akaryakıt': ['fuel'],
      'otopark': ['parking'],
      'cami': ['place_of_worship'],
      'polis': ['police'],
      'postane': ['post_office'],
      'müze': ['tourism_museum'],
      'sinema': ['cinema'],
      'tiyatro': ['theatre'],
      'fırın': ['shop_bakery'],
      'ekmek': ['shop_bakery'],
      'kasap': ['shop_butcher'],
      'manav': ['shop_greengrocer'],
      'kuaför': ['shop_hairdresser'],
      'berber': ['shop_hairdresser'],
      'otel': ['tourism_hotel'],
      'konaklama': ['tourism_hotel', 'tourism_motel', 'tourism_guest_house'],
      'park': ['leisure_park'],
    };

    final results = <String>[];
    for (final entry in mapping.entries) {
      if (q.contains(entry.key)) {
        results.addAll(entry.value);
      }
    }
    return results.toSet().toList();
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Cache'i temizler — kategori değişikliğinde kullanılır.
  void clearCache() {
    _lastBboxKey = null;
    _cachedPois = [];
    _lastCategories = {};
  }
}
