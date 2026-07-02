import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/map_type_card.dart';

// Widget testi: katman seçici harita türü kartı (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Row(children: [child])));

void main() {
  group('MapTypeCard', () {
    testWidgets('etiket ve ikonu gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const Expanded(
        child: MapTypeCard(
          label: 'Uydu',
          icon: Icons.satellite_alt,
          color: Colors.blueGrey,
          selected: false,
        ),
      )));

      expect(find.text('Uydu'), findsOneWidget);
      expect(find.byIcon(Icons.satellite_alt), findsOneWidget);
    });

    testWidgets('seçili iken ikon vurgu rengini alır, değilken gri', (tester) async {
      const accent = Colors.teal;
      await tester.pumpWidget(_wrap(const Expanded(
        child: MapTypeCard(
          label: 'Varsayılan',
          icon: Icons.map_outlined,
          color: accent,
          selected: true,
        ),
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.map_outlined)).color, accent);

      await tester.pumpWidget(_wrap(const Expanded(
        child: MapTypeCard(
          label: 'Varsayılan',
          icon: Icons.map_outlined,
          color: accent,
          selected: false,
        ),
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.map_outlined)).color, isNot(accent));
    });

    testWidgets('dokununca onTap çağrılır', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(Expanded(
        child: MapTypeCard(
          label: 'Arazi',
          icon: Icons.terrain,
          color: Colors.brown,
          selected: false,
          onTap: () => tapped = true,
        ),
      )));

      await tester.tap(find.byType(MapTypeCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
