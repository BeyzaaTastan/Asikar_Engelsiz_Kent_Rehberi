import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/osm_poi_model.dart';

/// Foursquare Places API v3 üzerinden POI arama servisi.
///
/// Overpass API'ye kıyasla daha güncel ve kapsamlı iş yeri verisi sağlar.
/// API key .env dosyasından FOURSQUARE_API_KEY ile okunur.
class FoursquarePlacesService {
  Timer? _debounce;
  bool _isLoading = false;

  // Cache
  String? _lastCacheKey;
  List<OsmPoi> _cachedPois = [];

  bool get isLoading => _isLoading;

  String get _apiKey => dotenv.env['FOURSQUARE_API_KEY'] ?? '';

  void dispose() {
    _debounce?.cancel();
  }

  // ── Türkçe kategori → Foursquare kategori ID'leri ─────────────────────────
  // Foursquare v3 kategori ID listesi: https://docs.foursquare.com/data-products/docs/categories
  static const Map<String, String> _categoryIds = {
    'Kafe':      '13032',  // Coffee Shop
    'Restoran':  '13065',  // Restaurant
    'Fast Food': '13145',  // Fast Food Restaurant
    'Eczane':    '17069',  // Pharmacy
    'Market':    '17069,11086', // Supermarket
    'Hastane':   '15014',  // Hospital
    'Banka':     '11086',  // Bank
    'Otel':      '19014',  // Hotel
    'Park':      '16032',  // Park
    'Müze':      '10027',  // Museum
    'Okul':      '12058',  // School
    'Cami':      '12104',  // Mosque
  };

  // ── Foursquare category ID → OSM amenity type eşleştirmesi ────────────────
  static const Map<String, String> _fsqToAmenity = {
    '13032': 'cafe',
    '13065': 'restaurant',
    '13145': 'fast_food',
    '17069': 'pharmacy',
    '11086': 'supermarket',
    '15014': 'hospital',
    '11086b': 'bank',
    '19014': 'tourism_hotel',
    '16032': 'leisure_park',
    '10027': 'tourism_museum',
    '12058': 'school',
    '12104': 'place_of_worship',
  };

  void dispose2() => dispose();

  // ── Debounce ile çevredeki POI'leri çek ───────────────────────────────────

  void debouncedFetch({
    required double centerLat,
    required double centerLon,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
    int radiusMeters = 1000,
  }) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchNearby(
        centerLat: centerLat,
        centerLon: centerLon,
        selectedCategories: selectedCategories,
        onResult: onResult,
        onLoadingChanged: onLoadingChanged,
        radiusMeters: radiusMeters,
      );
    });
  }

  /// Belirli bir koordinat etrafındaki POI'leri Foursquare'den çeker.
  Future<void> fetchNearby({
    required double centerLat,
    required double centerLon,
    required Set<String> selectedCategories,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
    int radiusMeters = 1000,
  }) async {
    if (_apiKey.isEmpty) {
      debugPrint('Foursquare API key bulunamadı (.env dosyasını kontrol edin)');
      return;
    }

    // Cache kontrolü
    final cacheKey = '${centerLat.toStringAsFixed(3)},${centerLon.toStringAsFixed(3)},${selectedCategories.join(',')},$radiusMeters';
    if (cacheKey == _lastCacheKey && _cachedPois.isNotEmpty) {
      onResult(_cachedPois);
      return;
    }

    _isLoading = true;
    onLoadingChanged(true);

    try {
      // Seçili kategorilere göre category ID'leri topla
      final categoryIds = <String>{};
      if (selectedCategories.isEmpty) {
        // Tümünü ekle
        categoryIds.addAll(_categoryIds.values.expand((v) => v.split(',')));
      } else {
        for (final cat in selectedCategories) {
          final id = _categoryIds[cat];
          if (id != null) categoryIds.addAll(id.split(','));
        }
      }

      final params = {
        'll': '$centerLat,$centerLon',
        'radius': radiusMeters.toString(),
        'limit': '50',
        'fields': 'fsq_id,name,categories,location,geocodes,tel,website,hours,rating,price',
      };

      if (categoryIds.isNotEmpty) {
        params['categories'] = categoryIds.join(',');
      }

      final url = Uri.https(
        'api.foursquare.com',
        '/v3/places/search',
        params,
      );

      final response = await http.get(url, headers: {
        'Authorization': _apiKey,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final pois = results
            .map((r) => _fromFoursquare(r as Map<String, dynamic>))
            .where((p) => p != null)
            .cast<OsmPoi>()
            .toList();

        _lastCacheKey = cacheKey;
        _cachedPois = pois;
        onResult(pois);
      } else if (response.statusCode == 401) {
        debugPrint('Foursquare: Geçersiz API key (401)');
      } else if (response.statusCode == 429) {
        debugPrint('Foursquare: İstek limiti aşıldı (429)');
      } else {
        debugPrint('Foursquare API hatası: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('Foursquare fetch hatası: $e');
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  /// Foursquare API yanıtından [OsmPoi] oluşturur.
  OsmPoi? _fromFoursquare(Map<String, dynamic> r) {
    try {
      // Koordinat
      final geocodes = r['geocodes'] as Map<String, dynamic>?;
      final main = geocodes?['main'] as Map<String, dynamic>?;
      final lat = (main?['latitude'] as num?)?.toDouble();
      final lon = (main?['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final name = r['name'] as String? ?? '';
      if (name.isEmpty) return null;

      // Kategori
      final categories = r['categories'] as List<dynamic>? ?? [];
      String amenityType = 'other';
      String categoryName = 'Mekan';
      if (categories.isNotEmpty) {
        final firstCat = categories.first as Map<String, dynamic>;
        final catId = firstCat['id']?.toString() ?? '';
        amenityType = _fsqToAmenity[catId] ?? _amenityFromFsqName(firstCat['name']?.toString() ?? '');
        categoryName = OsmPoi.categoryToTurkish(amenityType);
        // Kategori hâlâ 'Mekan' ise Foursquare adını Türkçeleştir
        if (categoryName == 'Mekan') {
          categoryName = _turkishCategoryName(firstCat['name']?.toString() ?? '');
        }
      }

      // Adres
      final location = r['location'] as Map<String, dynamic>?;
      final addressParts = <String>[];
      final address1 = location?['address'] as String?;
      final neighborhood = location?['neighborhood'] as String?;
      final locality = location?['locality'] as String?;
      if (address1 != null) addressParts.add(address1);
      if (neighborhood != null) addressParts.add(neighborhood);
      if (locality != null) addressParts.add(locality);
      final fullAddress = addressParts.isNotEmpty ? addressParts.join(', ') : null;

      // Çalışma saatleri
      final hours = r['hours'] as Map<String, dynamic>?;
      String? openingHours;
      if (hours != null) {
        final display = hours['display'] as String?;
        openingHours = display;
      }

      // Telefon
      final tel = r['tel'] as String?;

      // Website
      final website = r['website'] as String?;

      return OsmPoi(
        osmId: r['fsq_id'].hashCode.abs(),
        osmType: 'foursquare',
        latitude: lat,
        longitude: lon,
        name: name,
        category: categoryName,
        amenityType: amenityType,
        phone: tel,
        website: website,
        openingHours: openingHours,
        address: fullAddress,
        allTags: {
          'source': 'foursquare',
          'fsq_id': r['fsq_id']?.toString() ?? '',
          if (r['rating'] != null) 'rating': r['rating'].toString(),
          if (r['price'] != null) 'price': r['price'].toString(),
        },
      );
    } catch (e) {
      debugPrint('Foursquare parse hatası: $e');
      return null;
    }
  }

  /// Foursquare İngilizce kategori adından OSM amenity tipini tahmin eder.
  String _amenityFromFsqName(String name) {
    final n = name.toLowerCase();
    if (n.contains('coffee') || n.contains('cafe')) return 'cafe';
    if (n.contains('restaurant') || n.contains('bistro')) return 'restaurant';
    if (n.contains('fast food') || n.contains('burger') || n.contains('pizza')) return 'fast_food';
    if (n.contains('pharmacy') || n.contains('drug')) return 'pharmacy';
    if (n.contains('supermarket') || n.contains('grocery') || n.contains('market')) return 'supermarket';
    if (n.contains('hospital') || n.contains('clinic') || n.contains('medical')) return 'hospital';
    if (n.contains('bank') || n.contains('atm')) return 'bank';
    if (n.contains('hotel') || n.contains('motel') || n.contains('inn')) return 'tourism_hotel';
    if (n.contains('park')) return 'leisure_park';
    if (n.contains('museum')) return 'tourism_museum';
    if (n.contains('school') || n.contains('university')) return 'school';
    if (n.contains('mosque') || n.contains('church') || n.contains('temple')) return 'place_of_worship';
    if (n.contains('bakery') || n.contains('pastry')) return 'shop_bakery';
    if (n.contains('gas') || n.contains('fuel') || n.contains('petrol')) return 'fuel';
    if (n.contains('parking')) return 'parking';
    return 'other';
  }

  /// Foursquare İngilizce kategori adını Türkçeye çevirir.
  String _turkishCategoryName(String englishName) {
    final n = englishName.toLowerCase();
    if (n.contains('coffee') || n.contains('cafe')) return 'Kafe';
    if (n.contains('restaurant') || n.contains('bistro')) return 'Restoran';
    if (n.contains('fast food')) return 'Fast Food';
    if (n.contains('pharmacy')) return 'Eczane';
    if (n.contains('supermarket') || n.contains('grocery')) return 'Market';
    if (n.contains('hospital')) return 'Hastane';
    if (n.contains('bank')) return 'Banka';
    if (n.contains('hotel')) return 'Otel';
    if (n.contains('park')) return 'Park';
    if (n.contains('museum')) return 'Müze';
    if (n.contains('school')) return 'Okul';
    if (n.contains('mosque') || n.contains('place of worship')) return 'İbadet Yeri';
    if (n.contains('bakery')) return 'Fırın';
    if (n.contains('gas station') || n.contains('fuel')) return 'Akaryakıt';
    if (n.contains('parking')) return 'Otopark';
    if (n.contains('bar') || n.contains('pub')) return 'Bar';
    if (n.contains('cinema') || n.contains('movie')) return 'Sinema';
    if (n.contains('gym') || n.contains('fitness')) return 'Spor Salonu';
    if (n.contains('spa') || n.contains('beauty')) return 'Güzellik';
    if (n.contains('clothing') || n.contains('fashion')) return 'Giyim';
    if (n.contains('electronics')) return 'Elektronik';
    return englishName; // Çeviri bulunamazsa orijinali döndür
  }

  void clearCache() {
    _lastCacheKey = null;
    _cachedPois = [];
  }
}
