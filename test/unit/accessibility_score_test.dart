import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/accessibility_score.dart';

// Kritik akış koruması: erişilebilirlik skoru formülü.
// Formül: (özellik/8)*70 + (avgRating/5)*30, min 5 / max 100.
// (bkz. vault/03-Data/03-Veritabani.md "Skor formülü")
void main() {
  group('calculateAccessibilityScore', () {
    test('hiç özellik + 0 puan → taban skor 5 (min clamp)', () {
      expect(calculateAccessibilityScore([], 0.0), 5);
    });

    test('8 özellik + 5.0 puan → 100 (tam puan)', () {
      final f = List.generate(8, (i) => 'f$i');
      expect(calculateAccessibilityScore(f, 5.0), 100);
    });

    test('8+ özellik + 5.0 puan → 100 (üst clamp)', () {
      final f = List.generate(12, (i) => 'f$i');
      expect(calculateAccessibilityScore(f, 5.0), 100);
    });

    test('yalnızca 8 özellik (0 puan) → 70 (özellik ağırlığı)', () {
      final f = List.generate(8, (i) => 'f$i');
      expect(calculateAccessibilityScore(f, 0.0), 70);
    });

    test('yalnızca 5.0 puan (0 özellik) → 30 (puan ağırlığı)', () {
      expect(calculateAccessibilityScore([], 5.0), 30);
    });

    test('4 özellik + 2.5 puan → 50 (35 + 15)', () {
      final f = List.generate(4, (i) => 'f$i'); // (4/8)*70 = 35
      expect(calculateAccessibilityScore(f, 2.5), 50); // + (2.5/5)*30 = 15
    });

    test('1 özellik + 0 puan → round(8.75) = 9', () {
      expect(calculateAccessibilityScore(['rampa'], 0.0), 9); // (1/8)*70 = 8.75
    });
  });
}
