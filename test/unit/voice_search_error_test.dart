import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/utils/voice_search_error.dart';

// Regresyon koruması: sesli arama hata mesajı doğru sınıflandırılmalı.
// Eski hata: HER speech_to_text hatası "mikrofon iznini kontrol edin" gösteriyordu
// → izin verili olsa bile yanıltıcı uyarı. "izin" mesajı YALNIZCA gerçek izin
// hatasında çıkmalı. (bkz. vault/01-Frontend/01-On-Yuz.md "Sesli arama")
void main() {
  group('classifyVoiceSearchError', () {
    // "mikrofon" ayırt edici: yalnızca gerçek izin mesajı bu kelimeyi taşır;
    // diğer hatalar kullanıcıyı izne yönlendirmemeli.
    test('gerçek izin hatası → permission türü + mikrofon izni mesajı', () {
      final e = classifyVoiceSearchError('error_insufficient_permissions');
      expect(e.kind, VoiceSearchErrorKind.permission);
      expect(e.message.toLowerCase(), contains('mikrofon'));
      expect(e.isBenign, isFalse);
    });

    test('konuşma algılanamadı → noSpeech (iyi huylu, izinden bahsetmez)', () {
      final e = classifyVoiceSearchError('error_no_match');
      expect(e.kind, VoiceSearchErrorKind.noSpeech);
      expect(e.isBenign, isTrue);
      expect(e.message.toLowerCase(), isNot(contains('mikrofon')));
    });

    test('konuşma zaman aşımı → noSpeech', () {
      expect(classifyVoiceSearchError('error_speech_timeout').kind,
          VoiceSearchErrorKind.noSpeech);
    });

    test('dil modeli yok → language (izinden bahsetmez)', () {
      final e = classifyVoiceSearchError('error_language_unavailable');
      expect(e.kind, VoiceSearchErrorKind.language);
      expect(e.message.toLowerCase(), isNot(contains('mikrofon')));
    });

    test('dil desteklenmiyor → language', () {
      expect(classifyVoiceSearchError('error_language_not_supported').kind,
          VoiceSearchErrorKind.language);
    });

    test('ağ hatası → network', () {
      expect(classifyVoiceSearchError('error_network_timeout').kind,
          VoiceSearchErrorKind.network);
    });

    test('tanıyıcı meşgul / istemci hatası → busy', () {
      expect(classifyVoiceSearchError('error_busy').kind,
          VoiceSearchErrorKind.busy);
      expect(classifyVoiceSearchError('error_client').kind,
          VoiceSearchErrorKind.busy);
    });

    test('bilinmeyen kod → unknown, izinden bahsetmez', () {
      final e = classifyVoiceSearchError('error_something_new');
      expect(e.kind, VoiceSearchErrorKind.unknown);
      expect(e.message.toLowerCase(), isNot(contains('mikrofon')));
    });

    test('büyük/karışık harf duyarsız', () {
      expect(classifyVoiceSearchError('ERROR_NO_MATCH').kind,
          VoiceSearchErrorKind.noSpeech);
    });
  });
}
