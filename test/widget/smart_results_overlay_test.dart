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

    testWidgets('çok sonuçta liste tavana değip kaydırılabilir', (tester) async {
      // 20 sonuç + dar availableHeight → tümü sığmaz; alttaki öğe başta görünmez
      // ama listeye kaydırılınca erişilebilir (panel kendi içinde kayar).
      final many = List.generate(
        20,
        (i) => {
          'title': 'Sonuç $i',
          'subtitle': 'Adres $i',
          'type': 'place',
          'lat': 40.0 + i,
          'lon': 30.0 + i,
        },
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SmartResultsOverlay(
            isSearchFieldEmpty: false,
            isLoading: false,
            items: many,
            onItemTap: (_) {},
            availableHeight: 400,
          ),
        ),
      ));

      // İlk öğe görünür, son öğe başta görünmez (liste tavanda kesildi).
      expect(find.text('Sonuç 0'), findsOneWidget);
      expect(find.text('Sonuç 19'), findsNothing);

      // Listeye kaydırınca son öğeye erişilir → kaydırılabilir.
      await tester.dragUntilVisible(
        find.text('Sonuç 19'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Sonuç 19'), findsOneWidget);
    });

    testWidgets('klavye kapalıyken (büyük availableHeight) panel alanı doldurur',
        (tester) async {
      // Büyük availableHeight → 8 öğe (tavana değmeyecek kadar) tümü görünür.
      final some = List.generate(
        8,
        (i) => {
          'title': 'Yer $i',
          'subtitle': 'Mah $i',
          'type': 'place',
          'lat': 40.0 + i,
          'lon': 30.0 + i,
        },
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SmartResultsOverlay(
            isSearchFieldEmpty: false,
            isLoading: false,
            items: some,
            onItemTap: (_) {},
            availableHeight: 2000,
          ),
        ),
      ));

      // Alan geniş → hepsi (ilk ve son dahil) tek seferde görünür.
      expect(find.text('Yer 0'), findsOneWidget);
      expect(find.text('Yer 7'), findsOneWidget);
    });
  });
}
