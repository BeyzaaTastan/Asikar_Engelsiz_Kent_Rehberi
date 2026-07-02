import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/voice_search_button.dart';

// Widget testi: sesli arama mikrofon butonu (saf sunum, Firebase'siz).
// map_screen.dart'tan çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md).
Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('VoiceSearchButton', () {
    testWidgets('boşta mic_none ikonu + "Sesli arama" etiketi', (tester) async {
      await tester.pumpWidget(_wrap(
        VoiceSearchButton(isListening: false, onTap: () {}),
      ));

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(
        find.bySemanticsLabel('Sesli arama'),
        findsOneWidget,
      );
    });

    testWidgets('dinlerken mic ikonu + dinleme etiketi', (tester) async {
      await tester.pumpWidget(_wrap(
        VoiceSearchButton(isListening: true, onTap: () {}),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(
        find.bySemanticsLabel('Sesli arama dinleniyor, durdurmak için dokunun'),
        findsOneWidget,
      );
    });

    testWidgets('dokununca onTap çağrılır', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        VoiceSearchButton(isListening: false, onTap: () => tapped = true),
      ));

      await tester.tap(find.byType(VoiceSearchButton));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
