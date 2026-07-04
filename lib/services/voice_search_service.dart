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

  // Durum/hata dinleyicileri her oturumda TAZE tutulur. speech_to_text bu
  // handler'ları yalnızca ilk initialize'da kaydeder; bu alanlar sayesinde
  // panel her açıldığında güncel callback'lere yönlendiririz (yoksa ikinci
  // açılışta ilk oturumun -artık unmount olmuş- callback'ine düşerdi).
  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  /// Tanıyıcı şu an aktif dinliyor mu?
  bool get isListening => _speech.isListening;

  /// Tanıyıcıyı (mikrofon izni dahil) hazırlar. İlk çağrıda izin diyaloğu çıkar;
  /// sonraki çağrılar ucuzdur. Kullanılamıyorsa `false` döner. Her çağrıda
  /// [onStatus]/[onError] **güncellenir** (tekrar açılışta bayat callback olmaz).
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: (s) => _onStatus?.call(s),
      onError: (e) => _onError?.call(e.errorMsg),
    );
    return _available;
  }

  /// Dinlemeye başlar. [onResult] her (kısmi/nihai) tanımada çağrılır: tanınan
  /// metin + `isFinal` bayrağı. Türkçe (`tr_TR`); cihazda yoksa OS varsayılanı.
  ///
  /// Süreler bilinçli **uzun** tutulur (panel açık dururken kullanıcı düşünebilsin
  /// / erişilebilirlik gereği ağır konuşan kullanıcı yetişebilsin): tek oturum
  /// en çok [listenFor], konuşma arasında [pauseFor] sessizlik toleransı.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevelChange,
    String localeId = 'tr_TR',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 5),
  }) async {
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );
  }

  /// Dinlemeyi durdurur (son sonucu korur).
  Future<void> stop() => _speech.stop();

  /// Dinlemeyi iptal eder (sonucu atar).
  Future<void> cancel() => _speech.cancel();
}
