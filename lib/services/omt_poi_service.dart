import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../models/osm_poi_model.dart';
import 'omt_poi_parser.dart';

/// OpenMapTiles vektör karolarındaki `poi` feature'larını uygulamanın kendi
/// **tıklanabilir** POI katmanına (OsmPoi) taşır. Böylece vektör karonun gösterip
/// de Overpass/Foursquare'in kaçırdığı mekanlar da (ör. yalnız OSM'de olan bir
/// eczane) tıklanınca detay paneli açar — kullanıcının gördüğü her mekan tıklanır.
///
/// Karoları [VectorTileProvider.provide] ile çeker → harita ile **AYNI kaynak**
/// (URL template gerekmez, sağlayıcının HTTP+retry mantığı yeniden kullanılır).
/// Ayrıştırma [compute] ile arka planda (MVT decode CPU-yoğun, frame düşürmesin).
/// Tile başına cache → aynı z14 karosu bir kez indirilir/ayrıştırılır (kota + $0).
class OmtPoiService {
  VectorTileProvider? _provider;
  int _sourceZoom = 14;
  Timer? _debounce;
  final Map<String, List<OsmPoi>> _tileCache = {};

  /// Stil yüklenip sağlayıcı verilene kadar devre dışı.
  bool get isEnabled => _provider != null;

  /// Yüklenen stilin `openmaptiles` sağlayıcısını enjekte eder (map_screen,
  /// _loadVectorStyle sonunda). poi feature'ları kaynak max zoom'da (genelde 14)
  /// en zengindir → o zoom'da karo çekilir.
  void setProvider(VectorTileProvider provider) {
    _provider = provider;
    final mz = provider.maximumZoom;
    _sourceZoom = mz < 1 ? 14 : (mz > 14 ? 14 : mz);
  }

  void debouncedFetch({
    required LatLngBounds bounds,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchForBounds(
        bounds: bounds,
        onResult: onResult,
        onLoadingChanged: onLoadingChanged,
      );
    });
  }

  Future<void> fetchForBounds({
    required LatLngBounds bounds,
    required void Function(List<OsmPoi> pois) onResult,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    final provider = _provider;
    if (provider == null) {
      onLoadingChanged(false);
      return;
    }

    final tiles = omtTilesForBounds(
      west: bounds.west,
      south: bounds.south,
      east: bounds.east,
      north: bounds.north,
      z: _sourceZoom,
    );
    if (tiles.isEmpty) {
      onLoadingChanged(false);
      onResult(const []);
      return;
    }

    onLoadingChanged(true);
    final result = <OsmPoi>[];
    final seen = <String>{};
    for (final t in tiles) {
      final key = 'z${t.z}x${t.x}y${t.y}';
      final List<OsmPoi> tilePois;
      final cached = _tileCache[key];
      if (cached != null) {
        tilePois = cached;
      } else {
        List<OsmPoi> parsed;
        try {
          final bytes = await provider.provide(TileIdentity(t.z, t.x, t.y));
          parsed =
              await compute(parseOmtTileData, OmtTileData(bytes, t.z, t.x, t.y));
        } catch (_) {
          // Karo indirilemedi/ayrıştırılamadı → boş (fail-soft, harita bozulmaz).
          parsed = const [];
        }
        _tileCache[key] = parsed;
        tilePois = parsed;
      }
      for (final p in tilePois) {
        if (seen.add(p.uniqueKey)) result.add(p);
      }
    }
    onLoadingChanged(false);
    onResult(result);
  }

  void dispose() {
    _debounce?.cancel();
  }
}
