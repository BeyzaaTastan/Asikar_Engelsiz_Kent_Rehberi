import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/map_search_service.dart';

// Birim testi: arama sonuçlarının kullanıcı konumuna göre mesafe sıralaması
// (en yakın en üstte). Saf/testli — bkz. vault/01-Frontend/01-On-Yuz.md.
void main() {
  // Kullanıcı: Sakarya merkezi (yaklaşık).
  const userLat = 40.7731;
  const userLon = 30.4000;

  Map<String, dynamic> poi(String title, double lat, double lon) =>
      {'title': title, 'lat': lat, 'lon': lon, 'type': 'nominatim'};

  group('sortResultsByDistance', () {
    test('en yakın sonuç en üste gelir', () {
      final results = [
        poi('uzak', 41.0, 30.7), // ~40+ km
        poi('yakin', 40.7735, 30.4005), // ~60 m
        poi('orta', 40.80, 30.42), // ~4 km
      ];

      final sorted = sortResultsByDistance(results, userLat, userLon);

      expect(sorted.map((r) => r['title']).toList(),
          ['yakin', 'orta', 'uzak']);
    });

    test('her sonuca metre cinsi distanceMeters eklenir', () {
      final results = [poi('yer', 40.7735, 30.4005)];

      final sorted = sortResultsByDistance(results, userLat, userLon);

      expect(sorted.first['distanceMeters'], isA<double>());
      expect(sorted.first['distanceMeters'] as double, greaterThan(0));
    });

    test('konum null ise sıra ve içerik değişmez', () {
      final results = [
        poi('b', 41.0, 30.7),
        poi('a', 40.7735, 30.4005),
      ];

      final sorted = sortResultsByDistance(results, null, null);

      expect(sorted.map((r) => r['title']).toList(), ['b', 'a']);
      expect(sorted.first.containsKey('distanceMeters'), isFalse);
    });

    test('boş liste güvenli', () {
      expect(sortResultsByDistance([], userLat, userLon), isEmpty);
    });
  });
}
