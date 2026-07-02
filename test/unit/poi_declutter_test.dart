import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/poi_declutter.dart';

// Birim testi: Google tarzı açgözlü etiket yerleştirme (saf/deterministik).
// bkz. vault/01-Frontend/01-On-Yuz.md · harita kademeli görünürlük.
void main() {
  const viewport = Size(400, 800);
  const label = Size(100, 44);

  DeclutterItem item(int id, Offset at, int priority,
          {bool canLabel = true, bool canDot = true}) =>
      DeclutterItem(
        id: id,
        anchor: at,
        priority: priority,
        canLabel: canLabel,
        canDot: canDot,
        labelSize: label,
      );

  group('declutterPois', () {
    test('tek POI viewport içinde → label', () {
      final r = declutterPois([item(0, const Offset(200, 400), 2)],
          viewport: viewport);
      expect(r[0], PoiRenderMode.label);
    });

    test('viewport dışındaki POI → hidden', () {
      final r = declutterPois([item(0, const Offset(-200, 400), 3)],
          viewport: viewport);
      expect(r[0], PoiRenderMode.hidden);
    });

    test('uzak iki POI → ikisi de label', () {
      final r = declutterPois([
        item(0, const Offset(100, 100), 2),
        item(1, const Offset(300, 600), 2),
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.label);
      expect(r[1], PoiRenderMode.label);
    });

    test('yüksek öncelikli etiketi kazanır; üstüne binen düşük öncelikli → hidden',
        () {
      // Aynı noktada iki POI: yüksek öncelikli label; düşük olanın hem etiketi
      // hem noktası çakışır (mesafe 0) → hidden.
      final r = declutterPois([
        item(0, const Offset(200, 400), 1), // düşük
        item(1, const Offset(200, 400), 3), // yüksek
      ], viewport: viewport);
      expect(r[1], PoiRenderMode.label);
      expect(r[0], PoiRenderMode.hidden);
    });

    test('etiket çakışan ama yeterince uzak POI → dot', () {
      // A(100,100) label. B(150,100): etiket A ile çakışır (100px genişlik)
      // ama anchor mesafesi 50 ≥ dotSpacing(26) → dot.
      final r = declutterPois([
        item(0, const Offset(100, 100), 3),
        item(1, const Offset(150, 100), 2),
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.label);
      expect(r[1], PoiRenderMode.dot);
    });

    test('çok yakın (nokta bile sığmayan) → hidden', () {
      final r = declutterPois([
        item(0, const Offset(100, 100), 3),
        item(1, const Offset(110, 100), 2), // mesafe 10 < 26
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.label);
      expect(r[1], PoiRenderMode.hidden);
    });

    test('deterministik: eşit öncelikte küçük id kazanır', () {
      final r = declutterPois([
        item(5, const Offset(200, 400), 2),
        item(2, const Offset(230, 400), 2), // etiket çakışır
      ], viewport: viewport);
      expect(r[2], PoiRenderMode.label); // küçük id önce yerleşir
    });

    test('isim uygun değil ama nokta uygun → dot (kademeli görünürlük)', () {
      final r = declutterPois([
        item(0, const Offset(200, 400), 2, canLabel: false, canDot: true),
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.dot);
    });

    test('ne isim ne nokta uygun → hidden (düşük zoom)', () {
      final r = declutterPois([
        item(0, const Offset(200, 400), 2, canLabel: false, canDot: false),
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.hidden);
    });

    test('isim uygun+boşta → nokta uygunluğuna bakılmadan label', () {
      final r = declutterPois([
        item(0, const Offset(200, 400), 3, canLabel: true, canDot: false),
      ], viewport: viewport);
      expect(r[0], PoiRenderMode.label);
    });
  });
}
