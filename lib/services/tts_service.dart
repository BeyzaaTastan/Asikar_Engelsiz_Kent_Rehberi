import 'package:flutter_tts/flutter_tts.dart';

/// Cihazın yerleşik metin-okuma (TTS) motorunu kullanan **ücretsiz / anahtarsız**
/// seslendirme sarmalayıcısı. Sesli arama panelinde "Aramak istediğiniz yeri
/// söyleyin" yönergesini görme engelli/okuma güçlüğü olan kullanıcıya sesli
/// duyurmak için kullanılır (erişilebilirlik — ürünün varlık sebebi).
///
/// `flutter_tts` Android `TextToSpeech` / iOS `AVSpeechSynthesizer`'ı kullanır →
/// projeye **maliyet yok**, API anahtarı gerekmez (bkz.
/// vault/06-Security/09-Rate-Limiting.md). Türkçe (`tr-TR`); cihazda yoksa OS
/// varsayılanı. `speak()` seslendirme bitene kadar bekler (awaitSpeakCompletion)
/// → çağıran, prompt bittikten SONRA dinlemeyi başlatabilir (tanıyıcı kendi
/// promptunu duymasın).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5); // OS varsayılanı çoğu cihazda hızlı — yavaşlat
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  /// [text]'i seslendirir; seslendirme bitene kadar bekler. Herhangi bir hatada
  /// sessizce yutulur (TTS erişilebilirlik ek konforudur, akışı bloklamaz).
  Future<void> speak(String text) async {
    try {
      await _ensureConfigured();
      await _tts.speak(text);
    } catch (_) {
      // TTS motoru yok/başarısız → sessiz geç (dinleme yine başlar).
    }
  }

  /// Süren seslendirmeyi durdurur.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
