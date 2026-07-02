import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import '../models/osm_poi_model.dart';

/// Türkiye geneli POI taban katmanı servisi.
///
/// Foursquare Open Source Places (Apache 2.0) verisinden üretilip Cloudflare
/// Worker + D1 üzerinden `/pois?bbox=` ucuyla sunulan **salt-okunur** mekan
/// verisini çeker. Overpass/Foursquare canlı kaynaklarına kıyasla çok daha
/// geniş kapsam sağlar; istek başına ücreti yoktur (edge cache + ücretsiz katman).
///
/// `.env` içindeki `POI_API_BASE_URL` boşsa servis **devre dışıdır** — backend
/// deploy edilene kadar uygulama davranışı değişmez (no-op).
class FsqPoiService {
  Timer? _debounce;
  bool _isLoading = false;

  // Cache — son sorgulanan bbox + kategoriler
  String? _lastKey;
  List<OsmPoi> _cached = [];
  Set<String> _lastCategories = {};

  bool get isLoading => _isLoading;

  String get _baseUrl => dotenv.env['POI_API_BASE_URL'] ?? '';

  /// Backend yapılandırılmış mı? Değilse map_screen bu kaynağı hiç tetiklemez.
  bool get isEnabled => _baseUrl.isNotEmpty;

  void dispose() {
    _debounce?.cancel();
  }

  // ── Türkçe kategori adı → pipeline slug'ı (D1 category sütunu) ─────────────
  static const Map<String, String> _turkishToSlug = {
    'Kafe': 'cafe',
    'Restoran': 'restaurant',
    'Fast Food': 'fast_food',
    'Eczane': 'pharmacy',
    'Market': 'supermarket',
    'Hastane': 'hospital',
    'Banka': 'bank',
    'Okul': 'school',
    'Kütüphane': 'library',
    'Akaryakıt': 'fuel',
    'Otopark': 'parking',
    'Cami': 'place_of_worship',
    'Polis': 'police',
    'Postane': 'post_office',
    'Müze': 'tourism_museum',
    'Fırın': 'shop_bakery',
    'Otel': 'tourism_hotel',
    'Park': 'leisure_park',
  };

  // ── Debounce ile bbox POI çekme ───────────────────────────────────────────
  void debouncedFetch({
    required LatLngBounds bounds,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) {
    if (!isEnabled) {
      onResult(const []);
      onLoadingChanged(false);
      return;
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchForBounds(
        bounds: bounds,
        selectedCategories: selectedCategories,
        onResult: onResult,
        onLoadingChanged: onLoadingChanged,
      );
    });
  }

  /// Görünür alandaki taban POI'lerini Worker'dan çeker.
  Future<void> fetchForBounds({
    required LatLngBounds bounds,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    if (!isEnabled) {
      onResult(const []);
      onLoadingChanged(false);
      return;
    }

    final s = bounds.southWest.latitude;
    final w = bounds.southWest.longitude;
    final n = bounds.northEast.latitude;
    final e = bounds.northEast.longitude;

    // Türkçe kategorileri slug'a çevir (eşleşmeyenler atlanır)
    final slugs = selectedCategories
        .map((c) => _turkishToSlug[c])
        .whereType<String>()
        .toList();

    final key = '${s.toStringAsFixed(3)},${w.toStringAsFixed(3)},'
        '${n.toStringAsFixed(3)},${e.toStringAsFixed(3)},${slugs.join(',')}';
    if (key == _lastKey &&
        _setEquals(selectedCategories, _lastCategories) &&
        _cached.isNotEmpty) {
      onResult(_cached);
      return;
    }

    _isLoading = true;
    onLoadingChanged(true);

    try {
      final params = <String, String>{'bbox': '$s,$w,$n,$e'};
      if (slugs.isNotEmpty) params['cats'] = slugs.join(',');

      final base = Uri.parse(_baseUrl);
      final url = base.replace(
        path: '${base.path}/pois'.replaceAll('//pois', '/pois'),
        queryParameters: params,
      );

      final resp = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final list = (data['pois'] as List<dynamic>? ?? [])
            .map((e) => _fromJson(e as Map<String, dynamic>))
            .whereType<OsmPoi>()
            .toList();

        _lastKey = key;
        _lastCategories = Set.from(selectedCategories);
        _cached = list;
        onResult(list);
      } else {
        debugPrint('POI API hatası: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('POI API fetch hatası: $e');
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  /// Worker JSON satırından [OsmPoi] üretir (osmType = 'fsq_os').
  OsmPoi? _fromJson(Map<String, dynamic> r) {
    try {
      final lat = (r['lat'] as num?)?.toDouble();
      final lon = (r['lon'] as num?)?.toDouble();
      final name = r['name'] as String? ?? '';
      if (lat == null || lon == null || name.isEmpty) return null;

      final slug = r['category'] as String? ?? 'other';
      return OsmPoi(
        osmId: (r['id'] as String? ?? name).hashCode.abs(),
        osmType: 'fsq_os',
        latitude: lat,
        longitude: lon,
        name: name,
        category: OsmPoi.categoryToTurkish(slug),
        amenityType: slug,
        phone: r['tel'] as String?,
        website: r['website'] as String?,
        address: r['address'] as String?,
        allTags: const {'source': 'fsq_os'},
      );
    } catch (e) {
      debugPrint('POI parse hatası: $e');
      return null;
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  void clearCache() {
    _lastKey = null;
    _cached = [];
    _lastCategories = {};
  }
}
