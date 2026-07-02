import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/overpass_query_builder.dart';

// Kritik akış koruması: Overpass sorgu/bbox üretimi.
// Yanlış bbox/sorgu = bozuk erişilebilirlik katmanı (yaya yolu, tekerlekli
// sandalye, hissedilebilir yüzey, asansör). (bkz. vault/07-Performance/10-Cache-CDN.md)
void main() {
  group('overpassBoundingBox', () {
    test('south,west,north,east sırasıyla ve 6 ondalıkla üretir', () {
      final bb = overpassBoundingBox(40.0, 30.0, latDelta: 0.012, lonDelta: 0.016);
      // south=40-0.012, west=30-0.016, north=40+0.012, east=30+0.016
      expect(bb, '39.988000,29.984000,40.012000,30.016000');
    });

    test('farklı delta değerlerini uygular', () {
      final bb = overpassBoundingBox(40.0, 30.0, latDelta: 0.015, lonDelta: 0.020);
      expect(bb, '39.985000,29.980000,40.015000,30.020000');
    });
  });

  group('hikingOverpassQuery', () {
    final q = hikingOverpassQuery('BB');

    test('timeout:25 sarmalayıcısıyla başlar/biter', () {
      expect(q, startsWith('[out:json][timeout:25];('));
      expect(q, endsWith(');out body;>;out skel qt;'));
    });

    test('dört yaya yolu türünü içerir', () {
      expect(q, contains('way["highway"="footway"](BB);'));
      expect(q, contains('way["highway"="pedestrian"](BB);'));
      expect(q, contains('way["highway"="path"]["foot"!="no"](BB);'));
      expect(q, contains('way["highway"="steps"](BB);'));
    });
  });

  group('accessibilityOverpassQuery', () {
    test('timeout:30 sarmalayıcısı', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: true, wheelchair: true, elevator: true);
      expect(q, startsWith('[out:json][timeout:30];('));
      expect(q, endsWith(');out body;>;out skel qt;'));
    });

    test('yalnızca tactile aktifken sadece tactile blokları', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: true, wheelchair: false, elevator: false);
      expect(q, contains('way["tactile_paving"="yes"](BB);'));
      expect(q, contains('node["tactile_paving"="yes"](BB);'));
      expect(q, isNot(contains('wheelchair')));
      expect(q, isNot(contains('elevator')));
    });

    test('yalnızca wheelchair aktifken way + node wheelchair blokları', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: true, elevator: false);
      expect(q, contains('way["wheelchair"="yes"](BB);'));
      expect(q, contains('way["wheelchair"="designated"](BB);'));
      expect(q, contains('node["wheelchair"="yes"](BB);'));
      expect(q, contains('node["wheelchair"="designated"](BB);'));
      expect(q, isNot(contains('tactile')));
      expect(q, isNot(contains('elevator')));
    });

    test('yalnızca elevator aktifken highway+railway elevator node blokları', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: false, elevator: true);
      expect(q, contains('node["highway"="elevator"](BB);'));
      expect(q, contains('node["railway"="elevator"](BB);'));
    });

    test('yalnızca parking aktifken engelli otoparkı node blokları', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: false, elevator: false, parking: true);
      expect(q, contains('node["amenity"="parking"]["wheelchair"="yes"](BB);'));
      expect(
          q, contains('node["amenity"="parking"]["wheelchair"="designated"](BB);'));
      expect(q,
          contains('node["amenity"="parking_space"]["wheelchair"="designated"](BB);'));
      expect(q, isNot(contains('tactile')));
      expect(q, isNot(contains('elevator')));
    });

    test('parking varsayılan false — belirtilmezse otopark bloğu yok', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: false, elevator: true);
      expect(q, isNot(contains('parking')));
    });

    test('way blokları node bloklarından önce gelir (orijinal sıra korunur)', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: true, elevator: false);
      expect(q.indexOf('way["wheelchair"="yes"]'),
          lessThan(q.indexOf('node["wheelchair"="yes"]')));
    });

    test('hiçbiri aktif değilken boş grup', () {
      final q = accessibilityOverpassQuery('BB',
          tactile: false, wheelchair: false, elevator: false);
      expect(q, '[out:json][timeout:30];();out body;>;out skel qt;');
    });
  });
}
