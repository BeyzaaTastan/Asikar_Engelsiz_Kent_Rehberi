import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/map_attribution.dart';

// Widget testi: harita atıf rozeti (lisans-kritik — CLAUDE.md "Foursquare
// verisi gösterilen her yüzeyde görünür atıf" + OSM/OpenMapTiles ODbL şartı).
// Atıf metinleri tek kaynaktan (map_attribution.dart sabitleri) gelmeli.
void main() {
  group('MapAttributionBadge', () {
    testWidgets('vektör taban aktifken OSM + OpenMapTiles atfı birlikte',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapAttributionBadge(
            showFoursquare: false,
            showOsm: true,
            showOpenMapTiles: true,
          ),
        ),
      ));

      expect(find.textContaining(kOsmAttribution), findsOneWidget);
      expect(find.textContaining(kOpenMapTilesAttribution), findsOneWidget);
    });

    testWidgets('OpenMapTiles varsayılan olarak gizli (raster taban)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapAttributionBadge(showFoursquare: false, showOsm: true),
        ),
      ));

      expect(find.textContaining(kOsmAttribution), findsOneWidget);
      expect(find.textContaining(kOpenMapTilesAttribution), findsNothing);
    });

    testWidgets('FSQ POI varsa Foursquare atfı da eklenir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapAttributionBadge(
            showFoursquare: true,
            showOsm: true,
            showOpenMapTiles: true,
          ),
        ),
      ));

      expect(find.textContaining(kFoursquareAttribution), findsOneWidget);
      expect(find.textContaining(kOpenMapTilesAttribution), findsOneWidget);
    });

    testWidgets('hiçbir kaynak yoksa rozet çizilmez', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapAttributionBadge(
            showFoursquare: false,
            showOsm: false,
            showOpenMapTiles: false,
          ),
        ),
      ));

      expect(find.byType(Text), findsNothing);
    });
  });
}
