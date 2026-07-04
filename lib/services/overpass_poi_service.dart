import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import '../models/osm_poi_model.dart';

/// Tek kaynak — bir POI kategorisi: OSM (key/value) + Türkçe etiket + Türkçe
/// arama eşanlamlıları + haritada gösterilsin mi.
///
/// Hem harita POI katmanı ([OverpassPoiService.categoryFilters]) hem birleşik
/// aramanın kategori eşleştirmesi ([OverpassPoiService.categoriesForQuery])
/// BURADAN türetilir → OSM tag tanımı TEK yerde yaşar (ör. market
/// `shop=supermarket` bir kez; iki tabloda drift olmaz — "Market" hatası bu
/// yüzden iki yerdeydi). rawType→Türkçe etiket ters eşlemesi modeldedir
/// ([OsmPoi.categoryToTurkish]) ve bu listedeki tüm token'ları kapsar (isimsiz
/// POI'lere arama listesinde başlık vermek için).
class PoiCategory {
  final String key; // 'amenity' | 'shop' | 'tourism' | 'leisure'
  final String value; // 'cafe', 'supermarket', ...
  final String label; // Harita çipi/katman adı (Türkçe)
  final List<String> synonyms; // Türkçe arama terimleri (küçük harf)
  final bool onMap; // harita POI katman setinde yer alır mı
  const PoiCategory(this.key, this.value, this.label, this.synonyms,
      {this.onMap = true});

  /// `map_visuals` / `OsmPoi.amenityType` ile aynı token biçimi.
  String get token => key == 'amenity' ? value : '${key}_$value';

  /// Overpass seçici (bbox/around eki çağıran tarafından eklenir).
  String get selector => 'nwr["$key"="$value"]';
}

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

  // ── Tek kaynak: Türkçe kategori ↔ OSM tag ↔ arama eşanlamlıları ────────────
  /// Tüm POI kategorileri (bkz. [PoiCategory]). `onMap=true` olanlar harita
  /// katmanında; TÜMÜ aramada kullanılır. Yeni kategori/eşanlamlı eklemek TEK
  /// satır — hem harita hem arama otomatik alır.
  static const List<PoiCategory> poiCategories = [
    // ── amenity ──
    PoiCategory('amenity', 'cafe', 'Kafe', ['kafe', 'kahve']),
    PoiCategory('amenity', 'restaurant', 'Restoran', ['restoran', 'lokanta', 'yemek']),
    PoiCategory('amenity', 'fast_food', 'Fast Food', ['fast food', 'fastfood', 'yemek']),
    PoiCategory('amenity', 'pharmacy', 'Eczane', ['eczane', 'ilaç', 'nöbetçi']),
    PoiCategory('amenity', 'hospital', 'Hastane', ['hastane', 'sağlık']),
    PoiCategory('amenity', 'clinic', 'Klinik', ['klinik', 'sağlık'], onMap: false),
    PoiCategory('amenity', 'doctors', 'Doktor', ['doktor'], onMap: false),
    PoiCategory('amenity', 'dentist', 'Diş Hekimi', ['dişçi', 'diş hekimi'], onMap: false),
    PoiCategory('amenity', 'veterinary', 'Veteriner', ['veteriner'], onMap: false),
    PoiCategory('amenity', 'bank', 'Banka', ['banka']),
    PoiCategory('amenity', 'atm', 'ATM', ['atm', 'bankamatik'], onMap: false),
    PoiCategory('amenity', 'school', 'Okul', ['okul']),
    PoiCategory('amenity', 'university', 'Üniversite', ['üniversite', 'fakülte'], onMap: false),
    PoiCategory('amenity', 'library', 'Kütüphane', ['kütüphane']),
    PoiCategory('amenity', 'fuel', 'Akaryakıt', ['benzin', 'akaryakıt', 'benzinlik', 'petrol']),
    PoiCategory('amenity', 'parking', 'Otopark', ['otopark']),
    PoiCategory('amenity', 'place_of_worship', 'Cami', ['cami', 'camii', 'ibadet', 'mescit', 'kilise']),
    PoiCategory('amenity', 'police', 'Polis', ['polis', 'karakol']),
    PoiCategory('amenity', 'post_office', 'Postane', ['postane', 'ptt']),
    PoiCategory('amenity', 'cinema', 'Sinema', ['sinema'], onMap: false),
    PoiCategory('amenity', 'theatre', 'Tiyatro', ['tiyatro'], onMap: false),
    PoiCategory('amenity', 'toilets', 'Tuvalet', ['tuvalet', 'lavabo', 'umumi'], onMap: false),
    PoiCategory('amenity', 'kindergarten', 'Kreş', ['kreş', 'anaokulu'], onMap: false),
    // ── shop ──
    PoiCategory('shop', 'supermarket', 'Market', ['market', 'süpermarket']),
    PoiCategory('shop', 'convenience', 'Bakkal', ['bakkal', 'market']),
    PoiCategory('shop', 'bakery', 'Fırın', ['fırın', 'ekmek', 'pastane']),
    PoiCategory('shop', 'butcher', 'Kasap', ['kasap']),
    PoiCategory('shop', 'greengrocer', 'Manav', ['manav']),
    PoiCategory('shop', 'hairdresser', 'Kuaför', ['kuaför', 'berber']),
    PoiCategory('shop', 'mall', 'AVM', ['avm', 'alışveriş merkezi', 'alışveriş'], onMap: false),
    // ── tourism ──
    PoiCategory('tourism', 'hotel', 'Otel', ['otel', 'konaklama']),
    PoiCategory('tourism', 'motel', 'Motel', ['motel', 'konaklama'], onMap: false),
    PoiCategory('tourism', 'guest_house', 'Pansiyon', ['pansiyon', 'konaklama'], onMap: false),
    PoiCategory('tourism', 'museum', 'Müze', ['müze']),
    // ── leisure ──
    PoiCategory('leisure', 'park', 'Park', ['park']),
    PoiCategory('leisure', 'playground', 'Çocuk Parkı', ['çocuk parkı', 'oyun alanı'], onMap: false),
    PoiCategory('leisure', 'sports_centre', 'Spor Merkezi', ['spor merkezi'], onMap: false),
    PoiCategory('leisure', 'fitness_centre', 'Spor Salonu', ['spor salonu', 'fitness', 'gym'], onMap: false),
  ];

  /// Haritada gösterilecek kategoriler (Türkçe etiket → Overpass seçici).
  /// [poiCategories] içinden `onMap=true` olanlardan türetilir → tag TEK yerde.
  static final Map<String, String> categoryFilters = {
    for (final c in poiCategories)
      if (c.onMap) c.label: c.selector,
  };

  /// Türkçe arama sorgusuna uyan kategoriler ([poiCategories] eşanlamlıları ile).
  /// Overpass kategori araması bunların [PoiCategory.selector]'larını kullanır.
  /// Eşleşme substring bazlı (Türkçe ekleri yakalar: "marketler", "parklar").
  static List<PoiCategory> categoriesForQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.length < 2) return const [];
    return [
      for (final c in poiCategories)
        if (c.synonyms.any((s) => q.contains(s))) c,
    ];
  }

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
    // Türkçe sorguyu kategori(ler)e çevir (tek kaynak: poiCategories).
    final matched = categoriesForQuery(categoryQuery);
    if (matched.isEmpty) return [];

    final typeFilter = matched
        .map((c) => '${c.selector}(around:$radiusMeters,$centerLat,$centerLon);')
        .join('\n');

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
            // İsim filtresi YOK (harita katmanından farklı): kategori aramasında
            // isimsiz POI'ler de döner (park/otopark/tuvalet sıklıkla isimsiz);
            // başlık map_search_service'te poi.category ile doldurulur. Yalnız
            // geçersiz koordinat elenir.
            .where((p) => p.latitude != 0)
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
