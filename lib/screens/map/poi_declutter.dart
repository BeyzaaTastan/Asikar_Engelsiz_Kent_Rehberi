import 'dart:ui' show Offset, Rect, Size;

/// Bir POI'nin haritada nasıl çizileceği.
enum PoiRenderMode { label, dot, hidden }

/// Declutter girdisi — tek bir POI'nin ekran-uzayı bilgisi.
class DeclutterItem {
  /// map_screen'deki POI index'i (sonucu geri eşlemek için).
  final int id;

  /// POI'nin ekran piksel konumu (marker noktası / geo konumun projeksiyonu).
  final Offset anchor;

  /// [poiPriority] ağırlığı — yüksek = öncelikli (çakışmada ismini korur).
  final int priority;

  /// Bu zoom'da POI **isim** göstermeye uygun mu? (zoom ≥ poiLabelMinZoom)
  final bool canLabel;

  /// Bu zoom'da POI **nokta** göstermeye uygun mu? (zoom ≥ poiDotMinZoom)
  final bool canDot;

  /// İkon+isim etiketinin tahmini kutu boyutu (px).
  final Size labelSize;

  const DeclutterItem({
    required this.id,
    required this.anchor,
    required this.priority,
    required this.canLabel,
    required this.canDot,
    required this.labelSize,
  });
}

/// Google Haritalar tarzı açgözlü etiket yerleştirme — SAF/birim testli.
///
/// POI'ler önceliğe (yüksek→düşük) göre sıralanır; her biri için:
/// - **İsim uygunsa** ([DeclutterItem.canLabel]) ve etiket kutusu daha önce
///   yerleştirilmiş etiketlerle çakışmıyorsa → [PoiRenderMode.label].
/// - Aksi halde **nokta uygunsa** ([DeclutterItem.canDot]) ve başka bir
///   etikete/noktaya [dotSpacing]'ten yakın değilse → [PoiRenderMode.dot].
/// - Hiçbiri olmazsa → [PoiRenderMode.hidden].
/// canLabel/canDot zoom eşikleriyle (poiLabelMinZoom/poiDotMinZoom) belirlenir →
/// kademeli görünürlük: uzakta az/öncelikli isim, yaklaştıkça nokta, en yakında
/// noktalar da isme döner. [viewport] (+[margin]) dışı doğrudan gizlenir.
///
/// Deterministiktir: eşit öncelikte [DeclutterItem.id] küçük olan önce gelir →
/// aynı girdi hep aynı sonucu verir (zoom sabitken titremez).
Map<int, PoiRenderMode> declutterPois(
  List<DeclutterItem> items, {
  required Size viewport,
  double dotSpacing = 26,
  double margin = 48,
}) {
  final result = <int, PoiRenderMode>{};

  final sorted = [...items]..sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      return p != 0 ? p : a.id.compareTo(b.id);
    });

  final labelRects = <Rect>[];
  final occupied = <Offset>[]; // yerleştirilmiş etiket + nokta merkezleri

  final bounds = Rect.fromLTWH(
    -margin,
    -margin,
    viewport.width + margin * 2,
    viewport.height + margin * 2,
  );

  for (final it in sorted) {
    if (!bounds.contains(it.anchor)) {
      result[it.id] = PoiRenderMode.hidden;
      continue;
    }

    // İsim uygunsa ve etiket kutusu çakışmıyorsa → label.
    if (it.canLabel) {
      final labelRect = Rect.fromCenter(
        center: it.anchor,
        width: it.labelSize.width,
        height: it.labelSize.height,
      );
      if (!labelRects.any((r) => r.overlaps(labelRect))) {
        result[it.id] = PoiRenderMode.label;
        labelRects.add(labelRect);
        occupied.add(it.anchor);
        continue;
      }
    }

    // Nokta uygunsa ve başka noktaya/etikete çok yakın değilse → dot.
    if (it.canDot &&
        !occupied.any((c) => (c - it.anchor).distance < dotSpacing)) {
      result[it.id] = PoiRenderMode.dot;
      occupied.add(it.anchor);
      continue;
    }

    result[it.id] = PoiRenderMode.hidden;
  }

  return result;
}
