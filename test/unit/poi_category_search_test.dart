import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/overpass_poi_service.dart';
import 'package:asikar_engelsiz_kent_rehberi/models/osm_poi_model.dart';

// Birim testi: tek kaynak POI kategori tablosu (poiCategories) → arama
// eşleştirmesi (categoriesForQuery) + harita türetmesi (categoryFilters).
// bkz. vault/01-Frontend/01-On-Yuz.md · "Kategori araması genel çözüm".

bool _hasTag(List<PoiCategory> cats, String key, String value) =>
    cats.any((c) => c.key == key && c.value == value);

void main() {
  group('categoriesForQuery', () {
    test('"market" hem shop=supermarket hem shop=convenience getirir', () {
      final r = OverpassPoiService.categoriesForQuery('market');
      expect(_hasTag(r, 'shop', 'supermarket'), isTrue);
      expect(_hasTag(r, 'shop', 'convenience'), isTrue);
    });

    test('"park" leisure=park getirir (adı değil kategorisi park)', () {
      final r = OverpassPoiService.categoriesForQuery('park');
      expect(_hasTag(r, 'leisure', 'park'), isTrue);
    });

    test('"eczane" amenity=pharmacy getirir', () {
      final r = OverpassPoiService.categoriesForQuery('eczane');
      expect(_hasTag(r, 'amenity', 'pharmacy'), isTrue);
    });

    test('"kahve" amenity=cafe getirir (eşanlamlı)', () {
      final r = OverpassPoiService.categoriesForQuery('kahve');
      expect(_hasTag(r, 'amenity', 'cafe'), isTrue);
    });

    test('Türkçe ek: "marketler" yine market kategorilerini getirir', () {
      final r = OverpassPoiService.categoriesForQuery('marketler');
      expect(_hasTag(r, 'shop', 'supermarket'), isTrue);
    });

    test('"otopark" amenity=parking getirir', () {
      final r = OverpassPoiService.categoriesForQuery('otopark');
      expect(_hasTag(r, 'amenity', 'parking'), isTrue);
    });

    test('bilinmeyen sorgu boş döner', () {
      expect(OverpassPoiService.categoriesForQuery('zxqw'), isEmpty);
    });

    test('tek harf (min uzunluk altı) boş döner', () {
      expect(OverpassPoiService.categoriesForQuery('p'), isEmpty);
    });
  });

  group('categoryFilters türetmesi (onMap)', () {
    test('Market seçicisi shop=supermarket (amenity DEĞİL)', () {
      expect(OverpassPoiService.categoryFilters['Market'],
          'nwr["shop"="supermarket"]');
    });

    test('quickFilterCategories tümü categoryFilters içinde', () {
      for (final label in OverpassPoiService.quickFilterCategories) {
        expect(OverpassPoiService.categoryFilters.containsKey(label), isTrue,
            reason: '$label harita katmanında olmalı');
      }
    });

    test('onMap=false kategoriler harita katmanında YOK ama aranabilir', () {
      // AVM aramada çıkar ama harita çipi/katmanı değil.
      expect(OverpassPoiService.categoryFilters.containsKey('AVM'), isFalse);
      expect(
          _hasTag(OverpassPoiService.categoriesForQuery('avm'), 'shop', 'mall'),
          isTrue);
    });
  });

  group('tek kaynak tutarlılığı', () {
    test('her kategori token\'ı için Türkçe etiket vardır (isimsiz POI başlığı)',
        () {
      for (final c in OverpassPoiService.poiCategories) {
        expect(OsmPoi.categoryToTurkish(c.token), isNot('Mekan'),
            reason: '${c.token} için categoryToTurkish etiketi eksik');
      }
    });
  });
}
