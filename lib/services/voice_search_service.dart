import 'package:speech_to_text/speech_to_text.dart';

/// Cihazın yerleşik (OS) konuşma tanıyıcısını kullanan **ücretsiz / anahtarsız**
/// sesli arama sarmalayıcısı.
///
/// `speech_to_text` paketi Android `SpeechRecognizer` / iOS `Speech` framework'ünü
/// kullanır → projeye **maliyet yok**, API anahtarı gerekmez (bkz.
/// vault/06-Security/09-Rate-Limiting.md · "Sesli arama"). Kısa komut/ifade için
/// tasarlanmıştır; harita yer araması bu kullanıma uygundur.
///
/// map_screen yalnızca UI durumunu (dinleniyor mu) tutar; init/listen/stop burada
/// izole edilir (mantık ile ekran ayrımı — proje konvansiyonu).
class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  /// Tanıyıcı şu an aktif dinliyor mu?
  bool get isListening => _speech.isListening;

  /// Tanıyıcıyı (mikrofon izni dahil) hazırlar. İlk çağrıda izin diyaloğu çıkar;
  /// sonraki çağrılar ucuzdur. Kullanılamıyorsa `false` döner.
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: (s) => onStatus?.call(s),
      onError: (e) => onError?.call(e.errorMsg),
    );
    return _available;
  }

  /// Dinlemeye başlar. [onResult] her (kısmi/nihai) tanımada çağrılır: tanınan
  /// metin + `isFinal` bayrağı. Türkçe (`tr_TR`); cihazda yoksa OS varsayılanı.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'tr_TR',
  }) async {
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
        localeId: localeId,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Dinlemeyi durdurur (son sonucu korur).
  Future<void> stop() => _speech.stop();

  /// Dinlemeyi iptal eder (sonucu atar).
  Future<void> cancel() => _speech.cancel();
}
