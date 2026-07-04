import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/voice_search_service.dart';
import '../../services/tts_service.dart';
import '../../utils/voice_search_error.dart';

/// Google Haritalar'ın sesli arama panelinin **Aşikar'a özel** karşılığı.
///
/// Kullanıcı mikrofona dokununca alttan açılan tam panel: büyük "sizi
/// dinliyorum" başlığı, nabız atan mikrofon dalga animasyonu, canlı (kısmi)
/// tanıma metni, erişilebilirlik odaklı hızlı öneri çipleri ve iptal/tekrar
/// dene eylemleri. Amaç: kullanıcı sesli aramanın **aktifleştiğini net görsün**
/// (eski hâlde küçük "Dinleniyor…" rozeti fark edilmiyordu) — bu ürünün varlık
/// sebebi olan erişilebilirlik gereği kritik.
///
/// Mimari: [VoiceSearchSheet] **saf sunum** (widget testli), oturumu yürüten
/// `_VoiceSearchSheetHost` özeldir; [showVoiceSearchSheet] paneli açar ve tanınan
/// metni/seçilen öneriyi döndürür (iptalde `null`).
/// (bkz. vault/01-Frontend/01-On-Yuz.md · "Sesli arama".)

/// Sesli arama panelini açar; tanınan metni (veya seçilen öneriyi) döndürür,
/// kullanıcı iptal/kapatırsa `null`. Oturum (init/listen/cancel) panel içinde
/// yürütülür; çağıran yalnızca sonucu arama kutusuna yazar.
Future<String?> showVoiceSearchSheet(
  BuildContext context, {
  required VoiceSearchService service,
  required TtsService tts,
  bool speakPrompt = false,
  String localeId = 'tr_TR',
  List<String> suggestions = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoiceSearchSheetHost(
      service: service,
      tts: tts,
      speakPrompt: speakPrompt,
      localeId: localeId,
      suggestions: suggestions,
    ),
  );
}

/// Mikrofon aktifleşince sesli okunan (TTS) yönerge — panel başlığıyla aynı.
const String kVoicePrompt = 'Aramak istediğiniz yeri söyleyin';

/// Panelin dinleme durumu — sunumu (renk/animasyon/mesaj/tekrar) sürükler.
enum VoiceSheetPhase { listening, noSpeech, error, unavailable }

/// Sesli arama oturumunu yürüten özel host: initialize → listen; durum/hata/
/// kısmi sonucu [VoiceSearchSheet]'e aktarır, nihai metinde paneli sonuçla kapatır.
class _VoiceSearchSheetHost extends StatefulWidget {
  final VoiceSearchService service;
  final TtsService tts;

  /// Yönergeyi **sesli** oku mu? Yalnızca görme desteğine ihtiyacı olan
  /// kullanıcıda `true` (diğerlerinde sessiz — bkz. `visualSupportProvider`).
  final bool speakPrompt;
  final String localeId;
  final List<String> suggestions;

  const _VoiceSearchSheetHost({
    required this.service,
    required this.tts,
    required this.speakPrompt,
    required this.localeId,
    required this.suggestions,
  });

  @override
  State<_VoiceSearchSheetHost> createState() => _VoiceSearchSheetHostState();
}

class _VoiceSearchSheetHostState extends State<_VoiceSearchSheetHost> {
  VoiceSheetPhase _phase = VoiceSheetPhase.listening;
  String _partialText = '';
  String _statusText = kVoicePrompt;
  bool _submitted = false;

  // Mikrofon ses seviyesi (0..1, yumuşatılmış) — dalga animasyonunu besler.
  // ValueNotifier ile yalnızca mikrofon repaint olur, tüm panel değil.
  final ValueNotifier<double> _level = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _promptThenStart();
  }

  @override
  void dispose() {
    // Panel (swipe ile de) kapanırsa tanıyıcıyı + seslendirmeyi serbest bırak.
    widget.service.cancel();
    widget.tts.stop();
    _level.dispose();
    super.dispose();
  }

  /// Görme desteğine ihtiyacı olan kullanıcıda önce yönergeyi **sesli** oku
  /// ("Aramak istediğiniz yeri söyleyin"), bitince dinlemeye başla — tanıyıcı
  /// kendi promptunu duymasın (erişilebilirlik). Diğer kullanıcılarda seslendirme
  /// yok, doğrudan dinlemeye geçilir.
  Future<void> _promptThenStart() async {
    if (widget.speakPrompt) {
      setState(() {
        _phase = VoiceSheetPhase.listening;
        _statusText = kVoicePrompt;
      });
      await widget.tts.speak(kVoicePrompt);
      if (!mounted || _submitted) return;
    }
    await _start();
  }

  Future<void> _start() async {
    setState(() {
      _phase = VoiceSheetPhase.listening;
      _partialText = '';
      _statusText = 'Sizi dinliyorum…';
    });

    final available = await widget.service.initialize(
      onStatus: (status) {
        if (!mounted || _submitted) return;
        // 'done'/'notListening' → OS dinlemeyi bitirdi.
        if (status == 'done' || status == 'notListening') {
          if (_partialText.trim().isNotEmpty) {
            _submit(_partialText);
          } else if (_phase == VoiceSheetPhase.listening) {
            setState(() {
              _phase = VoiceSheetPhase.noSpeech;
              _statusText = 'Sizi duyamadım. Tekrar deneyin.';
            });
          }
        }
      },
      onError: (errorMsg) {
        if (!mounted || _submitted) return;
        final error = classifyVoiceSearchError(errorMsg);
        setState(() {
          _phase = VoiceSheetPhase.error;
          _statusText = error.message;
        });
      },
    );

    if (!mounted || _submitted) return;

    if (!available) {
      setState(() {
        _phase = VoiceSheetPhase.unavailable;
        _statusText = 'Cihazınızda sesli arama kullanılamıyor.';
      });
      return;
    }

    await widget.service.listen(
      localeId: widget.localeId,
      onSoundLevelChange: (raw) {
        if (!mounted) return;
        // Cihaz ses seviyesini (Android'de ~ -2..10 dB) 0..1'e normalize et,
        // sonra yumuşat (jitter azalsın) → dalgalar sese göre canlanır.
        const minLevel = -2.0, maxLevel = 10.0;
        final norm =
            ((raw - minLevel) / (maxLevel - minLevel)).clamp(0.0, 1.0);
        _level.value = _level.value * 0.7 + norm * 0.3;
      },
      onResult: (text, isFinal) {
        if (!mounted || _submitted) return;
        setState(() => _partialText = text);
        if (isFinal && text.trim().isNotEmpty) _submit(text);
      },
    );
  }

  void _submit(String text) {
    if (_submitted || !mounted) return;
    _submitted = true;
    Navigator.of(context).pop(text.trim());
  }

  void _cancel() {
    widget.service.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  /// Mikrofona dokunuş: dinliyorsa **sonlandır** (o ana dek tanınanı finalize
  /// et — `stop` son sonucu korur → onStatus 'done' handler'ı arar; boşsa
  /// "duyamadım"a düşer). Dinlemiyorsa yeniden başlat.
  void _onMicTap() {
    if (_phase == VoiceSheetPhase.listening) {
      widget.service.stop();
    } else {
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VoiceSearchSheet(
      phase: _phase,
      statusText: _statusText,
      partialText: _partialText,
      soundLevel: _level,
      suggestions: widget.suggestions,
      onCancel: _cancel,
      onMicTap: _onMicTap,
      onRetry: _phase == VoiceSheetPhase.listening ? null : _start,
      onSuggestionTap: _submit,
    );
  }
}

/// Sesli arama panelinin **saf sunum** katmanı (durum dışarıdan verilir → widget
/// testli). Yalnızca nabız animasyonu için içsel durum tutar (VoiceSearchButton
/// ile aynı desen).
class VoiceSearchSheet extends StatefulWidget {
  /// Dinleme/duyamadım/hata/kullanılamıyor durumu.
  final VoiceSheetPhase phase;

  /// Başlık altındaki durum satırı (ekran okuyucuya `liveRegion` ile duyurulur).
  final String statusText;

  /// Canlı (kısmi) tanınan metin — boşsa gösterilmez.
  final String partialText;

  /// Mikrofon ses seviyesi (0..1) — dalga animasyonunu besler. Yalnızca mikrofon
  /// bu değere abone olur (tüm panel değil).
  final ValueListenable<double> soundLevel;

  /// Erişilebilirlik odaklı hızlı arama önerileri (çip). Boşsa gösterilmez.
  final List<String> suggestions;

  /// İptal (paneli kapat).
  final VoidCallback onCancel;

  /// Mikrofona dokununca: dinlerken **sonlandırır**, değilse yeniden dinler.
  final VoidCallback onMicTap;

  /// Yeniden dinle — yalnızca dinleme dışı fazlarda gösterilir (null ise gizli).
  final VoidCallback? onRetry;

  /// Öneri çipine dokununca (metinle ara).
  final void Function(String suggestion) onSuggestionTap;

  const VoiceSearchSheet({
    super.key,
    required this.phase,
    required this.statusText,
    required this.partialText,
    required this.soundLevel,
    required this.suggestions,
    required this.onCancel,
    required this.onMicTap,
    required this.onSuggestionTap,
    this.onRetry,
  });

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.phase == VoiceSheetPhase.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listening = widget.phase == VoiceSheetPhase.listening;
    if (listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!listening && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.phase == VoiceSheetPhase.listening;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tutamaç
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.chipBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Büyük yönlendirme başlığı
            const Text(
              'Aramak istediğiniz yeri söyleyin',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.surface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // Durum satırı — ekran okuyucu için canlı bölge
            Semantics(
              liveRegion: true,
              child: Text(
                widget.statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.phase == VoiceSheetPhase.error ||
                          widget.phase == VoiceSheetPhase.unavailable
                      ? AppColors.danger
                      : AppColors.textDark,
                ),
              ),
            ),
            // Canlı tanınan metin
            if (widget.partialText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                widget.partialText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 28),
            // Nabız atan mikrofon — dokununca dinlerken sonlandırır.
            Center(
              child: Semantics(
                button: true,
                label: listening
                    ? 'Dinlemeyi bitir'
                    : 'Yeniden dinlemek için dokunun',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onMicTap,
                  child: _PulsingMic(
                    controller: _pulse,
                    listening: listening,
                    soundLevel: widget.soundLevel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Hızlı öneri çipleri (erişilebilirlik odaklı)
            if (widget.suggestions.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in widget.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          label: '$s ara',
                          child: ActionChip(
                            label: Text(s),
                            labelStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.lightSurface,
                            side: const BorderSide(color: AppColors.chipBorder),
                            onPressed: () => widget.onSuggestionTap(s),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Eylemler: İptal + (gerekliyse) Tekrar dene
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Sesli aramayı iptal et',
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: AppColors.chipBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Yeniden dinle',
                      child: FilledButton.icon(
                        onPressed: widget.onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.mic, size: 20),
                        label: const Text('Tekrar dene'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ortada mikrofon + dinlerken dışa doğru açılan halkalar. Halkaların genliği
/// **mikrofon ses seviyesine** ([soundLevel] 0..1) göre büyür/küçülür → sese
/// tepki verir. [controller] halkaların sürekli dışa akışını (faz), [soundLevel]
/// ise genliği/parlaklığı sürükler. Durunca sabit (soluk) mikrofon.
class _PulsingMic extends StatelessWidget {
  final AnimationController controller;
  final bool listening;
  final ValueListenable<double> soundLevel;

  const _PulsingMic({
    required this.controller,
    required this.listening,
    required this.soundLevel,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 132;
    return SizedBox(
      width: size,
      height: size,
      // Hem faz (controller) hem ses seviyesi (soundLevel) değişince yeniden çiz.
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, soundLevel]),
        builder: (context, _) {
          final level = listening ? soundLevel.value.clamp(0.0, 1.0) : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (listening)
                for (final phase in const [0.0, 0.33, 0.66])
                  _ring(size, (controller.value + phase) % 1.0, level),
              // Merkez mikrofon — sesle hafifçe büyür (canlılık hissi).
              Transform.scale(
                scale: 1 + level * 0.18,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: listening ? AppColors.primary : AppColors.outline,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 36),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double maxSize, double t, double level) {
    // t: 0→1 dışa açılım fazı; genlik (ne kadar açıldığı) ve parlaklık ses
    // seviyesiyle artar → sessizde küçük/soluk, konuşurken büyük/belirgin.
    final amplitude = 0.35 + 0.65 * level;
    final dim = 72 + (maxSize - 72) * t * amplitude;
    return Opacity(
      opacity: (1 - t) * 0.35 * (0.4 + 0.6 * level),
      child: Container(
        width: dim,
        height: dim,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}
