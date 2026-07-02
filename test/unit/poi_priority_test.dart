import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/poi_priority.dart';

// Birim testi: POI kategori önceliği (saf). Google tarzı kademeli görünürlükte
// declutter sıralamasını belirler (bkz. vault/01-Frontend/01-On-Yuz.md).
void main() {
  group('poiPriority', () {
    test('yüksek öncelikli kategoriler 3 döner', () {
      for (final t in ['hospital', 'pharmacy', 'fuel', 'tourism_hotel',
          'supermarket', 'place_of_worship', 'leisure_park', 'museum']) {
        expect(poiPriority(t), 3, reason: t);
      }
    });

    test('orta öncelikli kategoriler 2 döner', () {
      for (final t in ['restaurant', 'cafe', 'fast_food', 'bank', 'school']) {
        expect(poiPriority(t), 2, reason: t);
      }
    });

    test('küçük dükkan / bilinmeyen kategoriler 1 döner', () {
      for (final t in ['shop_bakery', 'shop_hairdresser', 'atm', 'other', '']) {
        expect(poiPriority(t), 1, reason: t);
      }
    });

    test('büyük/küçük harf duyarsız', () {
      expect(poiPriority('HOSPITAL'), 3);
      expect(poiPriority('Cafe'), 2);
    });

    test('sıralama tutarlı: yüksek > orta > düşük', () {
      expect(poiPriority('hospital'), greaterThan(poiPriority('restaurant')));
      expect(poiPriority('restaurant'), greaterThan(poiPriority('shop_bakery')));
    });
  });

  group('zoom eşikleri (kademeli görünürlük)', () {
    test('isim eşiği: yüksek öncelik uzakta, düşük öncelik yakında', () {
      expect(poiLabelMinZoom(3), lessThan(poiLabelMinZoom(2)));
      expect(poiLabelMinZoom(2), lessThan(poiLabelMinZoom(1)));
    });

    test('nokta eşiği isim eşiğinin altındadır (orta/düşük öncelik)', () {
      expect(poiDotMinZoom(2), lessThan(poiLabelMinZoom(2)));
      expect(poiDotMinZoom(1), lessThan(poiLabelMinZoom(1)));
    });

    test('yüksek öncelikte nokta aşaması yok (erişilemez zoom)', () {
      // Harita maxZoom 18; 99 => yüksek öncelik hiçbir zaman nokta olmaz.
      expect(poiDotMinZoom(3), greaterThan(18));
    });
  });
}
