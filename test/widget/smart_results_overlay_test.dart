import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/smart_results_overlay.dart';

// Widget testi: akıllı arama sonuç overlay'i (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 400, child: child)));

final _items = <Map<String, dynamic>>[
  {'title': 'Sakarya Üniversitesi', 'subtitle': 'Serdivan', 'type': 'place', 'lat': 40.7, 'lon': 30.3},
  {'title': 'Millet Bahçesi', 'subtitle': 'Adapazarı', 'type': 'place', 'lat': 40.77, 'lon': 30.39},
];

void main() {
  group('SmartResultsOverlay', () {
    testWidgets('arama boşken "Son Aramalar" başlığı', (tester) async {
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: true,
        isLoading: false,
        items: _items,
        onItemTap: (_) {},
      )));

      expect(find.text('Son Aramalar'), findsOneWidget);
      expect(find.text('Önerilen Mekanlar'), findsNothing);
    });

    testWidgets('arama doluyken "Arama Sonuçları" başlığı', (tester) async {
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: false,
        isLoading: false,
        items: _items,
        onItemTap: (_) {},
      )));

      expect(find.text('Arama Sonuçları'), findsOneWidget);
      expect(find.text('Önerilen Mekanlar'), findsNothing);
    });

    testWidgets('son aramalar doluyken "Temizle" dokununca onClearHistory çağrılır',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: true,
        isLoading: false,
        items: _items,
        onItemTap: (_) {},
        onClearHistory: () => cleared = true,
      )));

      expect(find.text('Temizle'), findsOneWidget);
      await tester.tap(find.text('Temizle'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('arama doluyken (sonuçlar) "Temizle" gösterilmez', (tester) async {
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: false,
        isLoading: false,
        items: _items,
        onItemTap: (_) {},
        onClearHistory: () {},
      )));

      expect(find.text('Temizle'), findsNothing);
    });

    testWidgets('boş geçmiş durumunda bilgilendirme gösterir', (tester) async {
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: true,
        isLoading: false,
        items: const [],
        onItemTap: (_) {},
      )));

      expect(find.text('Henüz arama geçmişi yok'), findsOneWidget);
    });

    testWidgets('öğeleri listeler ve dokununca onItemTap doğru öğeyi verir', (tester) async {
      Map<String, dynamic>? tapped;
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: false,
        isLoading: false,
        items: _items,
        onItemTap: (item) => tapped = item,
      )));

      expect(find.text('Sakarya Üniversitesi'), findsOneWidget);
      expect(find.text('Millet Bahçesi'), findsOneWidget);

      await tester.tap(find.text('Millet Bahçesi'));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!['title'], 'Millet Bahçesi');
    });

    testWidgets('isLoading true iken spinner gösterir', (tester) async {
      await tester.pumpWidget(_wrap(SmartResultsOverlay(
        isSearchFieldEmpty: false,
        isLoading: true,
        items: _items,
        onItemTap: (_) {},
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
