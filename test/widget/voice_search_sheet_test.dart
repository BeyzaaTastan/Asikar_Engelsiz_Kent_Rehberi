import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/screens/map/voice_search_sheet.dart';

// Widget testi: sesli arama paneli (saf sunum, plugin/mikrofon gerektirmez).
// Dinleme UI'ının kullanıcıya "aktif mi" olduğunu net göstermesi kritik
// (bkz. vault/01-Frontend/01-On-Yuz.md · "Sesli arama").
Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('VoiceSearchSheet', () {
    testWidgets('dinleme fazında başlık + durum gösterir', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.listening,
        statusText: 'Sizi dinliyorum…',
        partialText: '',
        soundLevel: ValueNotifier(0.0),
        suggestions: const [],
        onCancel: () {},
        onMicTap: () {},
        onSuggestionTap: (_) {},
      )));

      expect(find.text('Aramak istediğiniz yeri söyleyin'), findsOneWidget);
      expect(find.text('Sizi dinliyorum…'), findsOneWidget);
      // Dinlerken tekrar dene gösterilmez.
      expect(find.text('Tekrar dene'), findsNothing);
    });

    testWidgets('canlı tanınan metni gösterir', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.listening,
        statusText: 'Sizi dinliyorum…',
        partialText: 'sakarya üniversitesi',
        soundLevel: ValueNotifier(0.0),
        suggestions: const [],
        onCancel: () {},
        onMicTap: () {},
        onSuggestionTap: (_) {},
      )));

      expect(find.text('sakarya üniversitesi'), findsOneWidget);
    });

    testWidgets('hata/duyamadım fazında onRetry ile "Tekrar dene" gösterir',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.noSpeech,
        statusText: 'Sizi duyamadım. Tekrar deneyin.',
        partialText: '',
        soundLevel: ValueNotifier(0.0),
        suggestions: const [],
        onCancel: () {},
        onMicTap: () {},
        onRetry: () => retried = true,
        onSuggestionTap: (_) {},
      )));

      expect(find.text('Sizi duyamadım. Tekrar deneyin.'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('İptal dokununca onCancel çağrılır', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.listening,
        statusText: 'Sizi dinliyorum…',
        partialText: '',
        soundLevel: ValueNotifier(0.0),
        suggestions: const [],
        onCancel: () => cancelled = true,
        onMicTap: () {},
        onSuggestionTap: (_) {},
      )));

      await tester.tap(find.text('İptal'));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('öneri çipine dokununca onSuggestionTap doğru metni verir',
        (tester) async {
      String? picked;
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.listening,
        statusText: 'Sizi dinliyorum…',
        partialText: '',
        soundLevel: ValueNotifier(0.0),
        suggestions: const ['Eczane', 'Hastane'],
        onCancel: () {},
        onMicTap: () {},
        onSuggestionTap: (s) => picked = s,
      )));

      expect(find.text('Eczane'), findsOneWidget);
      await tester.tap(find.text('Hastane'));
      await tester.pump();
      expect(picked, 'Hastane');
    });

    testWidgets('dinlerken mikrofona dokununca onMicTap çağrılır (sonlandır)',
        (tester) async {
      var micTapped = false;
      await tester.pumpWidget(_wrap(VoiceSearchSheet(
        phase: VoiceSheetPhase.listening,
        statusText: 'Sizi dinliyorum…',
        partialText: '',
        soundLevel: ValueNotifier(0.0),
        suggestions: const [],
        onCancel: () {},
        onMicTap: () => micTapped = true,
        onSuggestionTap: (_) {},
      )));

      // Erişilebilirlik etiketiyle mikrofona dokun (sonlandır).
      await tester.tap(find.bySemanticsLabel('Dinlemeyi bitir'));
      await tester.pump();
      expect(micTapped, isTrue);
    });
  });
}
