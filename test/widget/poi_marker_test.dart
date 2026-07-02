import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/models/osm_poi_model.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/poi_marker.dart';

// Widget testi: isimli POI marker'ı (saf sunum, Firebase'siz).
// POI'ler yalnızca yakın zoom'da (map_screen _poiMinZoom) çizilir; o zoom'da
// az POI düştüğü için isim etiketi haritayı örtmez
// (bkz. vault/01-Frontend/01-On-Yuz.md · harita marker davranışı).
OsmPoi _poi({String name = 'Kahve Deposu', String amenity = 'cafe'}) => OsmPoi(
      osmId: 1,
      osmType: 'node',
      latitude: 40.77,
      longitude: 29.98,
      name: name,
      category: 'Kafe',
      amenityType: amenity,
    );

void main() {
  group('PoiMarker', () {
    testWidgets('kategori ikonunu VE isim etiketini gösterir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiMarker(poi: _poi())),
      ));

      expect(find.byIcon(Icons.coffee), findsOneWidget);
      expect(find.text('Kahve Deposu'), findsOneWidget);
    });

    testWidgets('isim boşsa etiketde ve Semantics\'te kategori kullanılır', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiMarker(poi: _poi(name: ''))),
      ));

      expect(find.text('Kafe'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(PoiMarker));
      expect(semantics.label, 'Kafe, Kafe');
    });

    testWidgets('erişilebilirlik: buton rolü + "isim, kategori" etiketi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiMarker(poi: _poi())),
      ));

      final semantics = tester.getSemantics(find.byType(PoiMarker));
      expect(semantics.label, 'Kahve Deposu, Kafe');
    });

    testWidgets('seçili iken ikon büyür', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiMarker(poi: _poi(), isSelected: true)),
      ));
      final selected = tester.widget<Icon>(find.byIcon(Icons.coffee)).size;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiMarker(poi: _poi())),
      ));
      final normal = tester.widget<Icon>(find.byIcon(Icons.coffee)).size;

      expect(selected, greaterThan(normal!));
    });
  });

  group('PoiDot', () {
    testWidgets('nokta çizer, isim etiketi göstermez', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiDot(poi: _poi())),
      ));

      // Etiketsiz önizleme: isim metni yok.
      expect(find.text('Kahve Deposu'), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('erişilebilirlik: buton rolü + "isim, kategori" etiketi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PoiDot(poi: _poi())),
      ));

      final semantics = tester.getSemantics(find.byType(PoiDot));
      expect(semantics.label, 'Kahve Deposu, Kafe');
    });
  });
}
