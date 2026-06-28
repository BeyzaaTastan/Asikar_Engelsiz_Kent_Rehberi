import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/osm_poi_model.dart';
import '../services/overpass_poi_service.dart';

/// Overpass POI servis singleton'ı.
final overpassPoiServiceProvider = Provider<OverpassPoiService>((ref) {
  final service = OverpassPoiService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Haritada gösterilen aktif OSM POI listesi.
final osmPoisProvider = StateProvider<List<OsmPoi>>((ref) => []);

/// Tıklanan/seçilen OSM POI'si.
final selectedOsmPoiProvider = StateProvider<OsmPoi?>((ref) => null);

/// Seçili POI kategorileri (boş set = tümü göster).
final poiCategoryFilterProvider = StateProvider<Set<String>>((ref) => {});

/// POI yükleniyor durumu.
final poiLoadingProvider = StateProvider<bool>((ref) => false);
