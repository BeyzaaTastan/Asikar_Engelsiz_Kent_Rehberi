import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/omt_poi_parser.dart';
import 'package:asikar_engelsiz_kent_rehberi/models/osm_poi_model.dart';

// Saf birim testleri: OpenMapTiles vektör karo POI ayrıştırmasının saf parçaları
// (tile kapsama + class/subclass → kategori eşlemesi). MVT byte decode'u gerçek
// karo gerektirdiği için burada test edilmez; kritik/saf mantık burada kilitli.
// Bağlam: vault/01-Frontend/01-On-Yuz.md · "vektör karo POI'leri tıklanabilir".
void main() {
  group('omtTilesForBounds', () {
    test('nokta boyutu kutu → tek tile, doğru zoom, geçerli aralık', () {
      // Arifiye civarı (~40.71, 30.36)
      final tiles = omtTilesForBounds(
        west: 30.360,
        south: 40.710,
        east: 30.361,
        north: 40.711,
        z: 14,
      );
      expect(tiles.length, 1);
      expect(tiles.first.z, 14);
      final n = 1 << 14;
      expect(tiles.first.x, inInclusiveRange(0, n - 1));
      expect(tiles.first.y, inInclusiveRange(0, n - 1));
    });

    test('daha yüksek zoom aynı kutuda ≥ tile üretir', () {
      double west = 30.30, south = 40.68, east = 30.42, north = 40.74;
      final z12 = omtTilesForBounds(
          west: west, south: south, east: east, north: north, z: 12);
      final z14 = omtTilesForBounds(
          west: west, south: south, east: east, north: north, z: 14, maxTiles: 999);
      expect(z14.length, greaterThanOrEqualTo(z12.length));
    });

    test('maxTiles güvenlik tavanına uyar (çok geniş kutu)', () {
      // Türkiye geneli — tavan olmadan yüzlerce tile olurdu.
      final tiles = omtTilesForBounds(
        west: 26.0,
        south: 36.0,
        east: 45.0,
        north: 42.0,
        z: 14,
        maxTiles: 12,
      );
      expect(tiles.length, lessThanOrEqualTo(12));
    });

    test('negatif zoom → boş', () {
      final tiles = omtTilesForBounds(
          west: 30, south: 40, east: 31, north: 41, z: -1);
      expect(tiles, isEmpty);
    });
  });

  group('omtRawType', () {
    test('subclass doğrudan OSM değerleri', () {
      expect(omtRawType('pharmacy', 'pharmacy'), 'pharmacy');
      expect(omtRawType('grocery', 'supermarket'), 'shop_supermarket');
      expect(omtRawType('convenience', 'convenience'), 'shop_convenience');
      expect(omtRawType('hotel', 'hotel'), 'tourism_hotel');
      expect(omtRawType('park', 'park'), 'leisure_park');
    });

    test('subclass yoksa class ile en yakın kategoriye iner', () {
      expect(omtRawType('grocery', ''), 'shop_supermarket');
      expect(omtRawType('clothing_store', ''), 'shop_clothes');
      expect(omtRawType('department_store', ''), 'shop_mall');
      expect(omtRawType('museum', ''), 'tourism_museum');
      expect(omtRawType('post', ''), 'post_office');
      expect(omtRawType('university', ''), 'university');
      expect(omtRawType('college', ''), 'university');
      expect(omtRawType('pharmacy', ''), 'pharmacy');
      expect(omtRawType('stadium', ''), 'leisure_sports_centre');
    });

    test('bilinmeyen tür → other (yine gösterilir, parite korunur)', () {
      expect(omtRawType('', ''), 'other');
      expect(omtRawType('unknown_class', 'weird_subclass'), 'other');
    });

    test('parite invariant: üretilen rawType kategoriye çevrilir', () {
      // Bilinen türler doğru Türkçe kategori vermeli (POI penceresi başlığı).
      expect(OsmPoi.categoryToTurkish(omtRawType('pharmacy', 'pharmacy')),
          'Eczane');
      expect(OsmPoi.categoryToTurkish(omtRawType('grocery', 'supermarket')),
          'Market');
      expect(OsmPoi.categoryToTurkish(omtRawType('hotel', 'hotel')), 'Otel');
      // Bilinmeyen bile geçerli bir etiket alır (asla boş kalmaz).
      expect(OsmPoi.categoryToTurkish(omtRawType('', '')), 'Mekan');
    });
  });
}
