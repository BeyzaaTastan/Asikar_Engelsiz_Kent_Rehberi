import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/unknown_point_sheet.dart';

// Widget testi: bilinmeyen nokta sheet'i (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('UnknownPointSheet', () {
    testWidgets('adres yüklenmediyse ve doluysa adresi gösterir', (tester) async {
      await tester.pumpWidget(_wrap(UnknownPointSheet(
        scrollController: ScrollController(),
        isLoadingAddress: false,
        address: 'Mithatpaşa, Adapazarı',
        point: const LatLng(40.7, 30.3),
        onClose: () {},
      )));

      expect(find.text('Mithatpaşa, Adapazarı'), findsOneWidget);
      expect(find.text('Adres yükleniyor...'), findsNothing);
    });

    testWidgets('yükleniyorsa "Adres yükleniyor..." gösterir', (tester) async {
      await tester.pumpWidget(_wrap(UnknownPointSheet(
        scrollController: ScrollController(),
        isLoadingAddress: true,
        address: '',
        point: const LatLng(40.7, 30.3),
        onClose: () {},
      )));

      expect(find.text('Adres yükleniyor...'), findsOneWidget);
    });

    testWidgets('point varsa koordinatları gösterir', (tester) async {
      await tester.pumpWidget(_wrap(UnknownPointSheet(
        scrollController: ScrollController(),
        isLoadingAddress: false,
        address: 'X',
        point: const LatLng(40.7, 30.3),
        onClose: () {},
      )));

      expect(find.text('40.70000, 30.30000'), findsOneWidget);
    });

    testWidgets('kapatma butonu onClose tetikler', (tester) async {
      var closed = false;
      await tester.pumpWidget(_wrap(UnknownPointSheet(
        scrollController: ScrollController(),
        isLoadingAddress: false,
        address: 'X',
        point: const LatLng(40.7, 30.3),
        onClose: () => closed = true,
      )));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('"Yol Tarifi" aksiyonunu gösterir', (tester) async {
      await tester.pumpWidget(_wrap(UnknownPointSheet(
        scrollController: ScrollController(),
        isLoadingAddress: false,
        address: 'X',
        point: const LatLng(40.7, 30.3),
        onClose: () {},
        onDirections: () {},
      )));

      expect(find.text('Yol Tarifi'), findsOneWidget);
    });
  });
}
