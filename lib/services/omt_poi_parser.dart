import 'dart:math';
import 'dart:typed_data';

import 'package:vector_tile/vector_tile.dart' as vt;

import '../models/osm_poi_model.dart';

/// OpenMapTiles vektör karo koordinatı (z/x/y).
class OmtTile {
  final int z;
  final int x;
  final int y;
  const OmtTile(this.z, this.x, this.y);
}

/// Verilen coğrafi kutuyu [z] zoom'unda kapsayan tile'ları döndürür (SAF).
/// [maxTiles] güvenlik tavanı — büyük kutularda kontrolsüz karo çekimini önler
/// (harita yalnız zoom ≥ 15'te çektiği için pratikte z14'te 1–4 tile düşer).
List<OmtTile> omtTilesForBounds({
  required double west,
  required double south,
  required double east,
  required double north,
  required int z,
  int maxTiles = 12,
}) {
  if (z < 0) return const [];
  final n = 1 << z; // 2^z
  int lonToX(double lon) => ((lon + 180.0) / 360.0 * n).floor().clamp(0, n - 1);
  int latToY(double lat) {
    // Web Mercator; kutup yakınlarında NaN olmasın diye enlemi kırp.
    final clamped = lat.clamp(-85.05112878, 85.05112878);
    final r = clamped * pi / 180.0;
    final y = ((1.0 - log(tan(r) + 1.0 / cos(r)) / pi) / 2.0 * n).floor();
    return y.clamp(0, n - 1);
  }

  final xa = lonToX(west);
  final xb = lonToX(east);
  final ya = latToY(north); // kuzey = küçük y
  final yb = latToY(south);
  final x0 = min(xa, xb), x1 = max(xa, xb);
  final y0 = min(ya, yb), y1 = max(ya, yb);

  final tiles = <OmtTile>[];
  for (var x = x0; x <= x1; x++) {
    for (var y = y0; y <= y1; y++) {
      tiles.add(OmtTile(z, x, y));
      if (tiles.length >= maxTiles) return tiles;
    }
  }
  return tiles;
}

/// OpenMapTiles `poi` katmanı `class`/`subclass` değerini bizim OsmPoi
/// rawType'ımıza ([OsmPoi.categoryToTurkish] anahtar uzayı) çevirir (SAF).
/// Bilinmeyen tür → `'other'` (kategori "Mekan"); yine gösterilir + tıklanır —
/// vektör karodaki mekanla parite korunur.
String omtRawType(String cls, String subclass) {
  final sc = subclass.trim().toLowerCase();
  final c = cls.trim().toLowerCase();

  // subclass = ham OSM değeri; categoryToTurkish anahtarlarıyla en doğrudan eşleşir.
  const amenityDirect = {
    'cafe', 'restaurant', 'fast_food', 'pharmacy', 'hospital', 'clinic',
    'bank', 'atm', 'library', 'school', 'university', 'fuel', 'parking',
    'place_of_worship', 'police', 'post_office', 'cinema', 'theatre',
    'dentist', 'doctors', 'veterinary', 'toilets', 'kindergarten',
  };
  const shopDirect = {
    'supermarket', 'convenience', 'bakery', 'butcher', 'clothes',
    'electronics', 'hairdresser', 'greengrocer', 'mall',
  };
  const tourismDirect = {
    'hotel', 'motel', 'guest_house', 'hostel', 'museum', 'attraction',
    'viewpoint',
  };
  const leisureDirect = {
    'park', 'playground', 'garden', 'sports_centre', 'swimming_pool',
    'fitness_centre',
  };

  if (amenityDirect.contains(sc)) return sc;
  if (shopDirect.contains(sc)) return 'shop_$sc';
  if (tourismDirect.contains(sc)) return 'tourism_$sc';
  if (leisureDirect.contains(sc)) return 'leisure_$sc';

  // subclass eşleşmediyse class ile en yakın kategoriye indir.
  switch (c) {
    case 'grocery':
      return 'shop_supermarket';
    case 'clothing_store':
      return 'shop_clothes';
    case 'department_store':
      return 'shop_mall';
    case 'hotel':
      return 'tourism_hotel';
    case 'park':
      return 'leisure_park';
    case 'playground':
      return 'leisure_playground';
    case 'garden':
      return 'leisure_garden';
    case 'stadium':
    case 'pitch':
    case 'sports_centre':
    case 'swimming':
    case 'golf':
      return 'leisure_sports_centre';
    case 'post':
      return 'post_office';
    case 'college':
    case 'university':
      return 'university';
    case 'museum':
    case 'art_gallery':
      return 'tourism_museum';
    case 'pharmacy':
    case 'hospital':
    case 'clinic':
    case 'restaurant':
    case 'cafe':
    case 'fast_food':
    case 'bank':
    case 'atm':
    case 'fuel':
    case 'parking':
    case 'place_of_worship':
    case 'police':
    case 'library':
    case 'school':
    case 'cinema':
    case 'theatre':
    case 'dentist':
    case 'doctors':
    case 'veterinary':
    case 'kindergarten':
      return c;
    default:
      return 'other';
  }
}

/// MVT tile byte'larındaki `poi` katmanından [OsmPoi] listesi üretir (isimli
/// olanlar). `osmType='omt'` (OpenMapTiles kaynağı → `isFoursquare=false` →
/// OSM atfı). MVT decode CPU-yoğun olduğundan [compute] ile arka planda
/// çağrılabilsin diye TOP-LEVEL (bkz. [parseOmtTileData]).
List<OsmPoi> omtPoisFromTileBytes(Uint8List bytes, int z, int x, int y) {
  final vt.VectorTile tile;
  try {
    tile = vt.VectorTile.fromBytes(bytes: bytes);
  } catch (_) {
    return const [];
  }
  final pois = <OsmPoi>[];
  for (final layer in tile.layers) {
    if (layer.name != 'poi') continue;
    for (final feature in layer.features) {
      try {
        final props = feature.decodeProperties();
        final name = (props['name']?.dartStringValue ??
                props['name:latin']?.dartStringValue ??
                '')
            .trim();
        if (name.isEmpty) continue; // isimsizleri atla (kaldırım mobilyası gürültüsü)

        final gj = feature.toGeoJson<vt.GeoJsonPoint>(x: x, y: y, z: z);
        final coords = gj?.geometry?.coordinates;
        if (coords == null || coords.length < 2) continue;
        final lon = coords[0];
        final lat = coords[1];

        final cls = props['class']?.dartStringValue ?? '';
        final subclass = props['subclass']?.dartStringValue ?? '';
        final rawType = omtRawType(cls, subclass);
        final fid = feature.id.toInt();

        pois.add(OsmPoi(
          osmId: fid != 0 ? fid : _synthId(name, lat, lon),
          osmType: 'omt',
          latitude: lat,
          longitude: lon,
          name: name,
          category: OsmPoi.categoryToTurkish(rawType),
          amenityType: rawType,
        ));
      } catch (_) {
        continue;
      }
    }
  }
  return pois;
}

/// feature.id 0 olan karolarda kararlı bir kimlik üret (declutter/dedup için).
int _synthId(String name, double lat, double lon) {
  final key = '$name:${lat.toStringAsFixed(5)}:${lon.toStringAsFixed(5)}';
  return key.hashCode & 0x7fffffff;
}

/// [compute] için tek mesaj argümanı (sendable: Uint8List + int'ler).
class OmtTileData {
  final Uint8List bytes;
  final int z;
  final int x;
  final int y;
  const OmtTileData(this.bytes, this.z, this.x, this.y);
}

/// [compute] giriş noktası (TOP-LEVEL) — [omtPoisFromTileBytes] sarmalayıcısı.
List<OsmPoi> parseOmtTileData(OmtTileData d) =>
    omtPoisFromTileBytes(d.bytes, d.z, d.x, d.y);
