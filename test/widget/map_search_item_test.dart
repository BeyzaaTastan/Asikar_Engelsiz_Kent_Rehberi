import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/map_search_item.dart';

// Widget testi: harita arama sonuç/son arama satırı (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
void main() {
  group('MapSearchItem', () {
    testWidgets('başlık ve alt başlığı gösterir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapSearchItem(
            title: 'Sakarya Üniversitesi',
            subtitle: 'Serdivan/Sakarya',
            icon: Icons.location_on,
            isRecent: false,
          ),
        ),
      ));

      expect(find.text('Sakarya Üniversitesi'), findsOneWidget);
      expect(find.text('Serdivan/Sakarya'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('isRecent true → history ikonu, false → north_west', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapSearchItem(
            title: 'x', subtitle: 'y', icon: Icons.place, isRecent: true,
          ),
        ),
      ));
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.north_west), findsNothing);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapSearchItem(
            title: 'x', subtitle: 'y', icon: Icons.place, isRecent: false,
          ),
        ),
      ));
      expect(find.byIcon(Icons.north_west), findsOneWidget);
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('dokununca onTap çağrılır', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MapSearchItem(
            title: 'x', subtitle: 'y', icon: Icons.place, isRecent: false,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(MapSearchItem));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
