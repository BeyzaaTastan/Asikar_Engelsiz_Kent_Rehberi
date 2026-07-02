import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/map_action_button.dart';

// Widget testi: harita sheet aksiyon butonu (Firebase'den bağımsız, saf widget).
// Eski varsayılan `widget_test.dart` tüm uygulamayı (AsikarApp) pump ediyordu;
// AsikarApp Firebase init + settingsServiceProvider override gerektirdiği için
// birim/widget düzeyinde çalışamıyordu — o akış integration_test'e ertelendi
// (bkz. vault/05-Infrastructure/07-CI-CD.md "Test Kapsamı").
void main() {
  group('MapActionButton', () {
    testWidgets('ikon ve etiketi gösterir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapActionButton(
            icon: Icons.directions,
            label: 'Yol Tarifi',
            color: Colors.blue,
          ),
        ),
      ));

      expect(find.text('Yol Tarifi'), findsOneWidget);
      expect(find.byIcon(Icons.directions), findsOneWidget);
    });

    testWidgets('dokununca onTap çağrılır', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MapActionButton(
            icon: Icons.share,
            label: 'Paylaş',
            color: Colors.green,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(MapActionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('onTap null ise dokunmak hata vermez', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapActionButton(
            icon: Icons.web,
            label: 'Web',
            color: Colors.teal,
          ),
        ),
      ));

      await tester.tap(find.byType(MapActionButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('erişilebilirlik: buton rolü + etiket sunar', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MapActionButton(
            icon: Icons.directions,
            label: 'Yol Tarifi',
            color: Colors.blue,
          ),
        ),
      ));

      expect(
        tester.getSemantics(find.byType(MapActionButton)),
        matchesSemantics(label: 'Yol Tarifi', isButton: true),
      );

      handle.dispose();
    });
  });
}
