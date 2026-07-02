import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/map_overlay_chip.dart';

// Widget testi: katman seçici harita ayrıntısı çipi (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MapOverlayChip', () {
    testWidgets('etiket ve ikonu gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const MapOverlayChip(
        label: 'Asansör',
        icon: Icons.elevator,
        color: Colors.cyan,
        isActive: false,
      )));

      expect(find.text('Asansör'), findsOneWidget);
      expect(find.byIcon(Icons.elevator), findsOneWidget);
    });

    testWidgets('aktifken ikon vurgu rengini alır, değilken gri', (tester) async {
      const accent = Colors.purple;
      await tester.pumpWidget(_wrap(const MapOverlayChip(
        label: 'Tekerlekli\nSandalye',
        icon: Icons.accessible_forward,
        color: accent,
        isActive: true,
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.accessible_forward)).color, accent);

      await tester.pumpWidget(_wrap(const MapOverlayChip(
        label: 'Tekerlekli\nSandalye',
        icon: Icons.accessible_forward,
        color: accent,
        isActive: false,
      )));
      expect(tester.widget<Icon>(find.byIcon(Icons.accessible_forward)).color, isNot(accent));
    });

    testWidgets('dokununca onTap çağrılır', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(MapOverlayChip(
        label: 'Bisiklet',
        icon: Icons.pedal_bike,
        color: Colors.green,
        isActive: false,
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(MapOverlayChip));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
