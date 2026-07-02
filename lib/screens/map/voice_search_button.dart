import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Arama çubuğunun sağındaki sesli arama mikrofon butonu.
///
/// Boşta: `mic_none` (AppColors.primary). Dinlerken: kırmızı `mic` (AppColors.danger)
/// + nabız (scale) animasyonu. Erişilebilirlik için `Semantics(button, label)`
/// taşır — sesli arama bu üründe kritik bir erişilebilirlik özelliğidir.
/// map_screen.dart'tan çıkarıldı (saf sunum; dinleme durumu dışarıdan verilir).
class VoiceSearchButton extends StatefulWidget {
  /// Şu an dinleniyor mu (kırmızı + nabız).
  final bool isListening;

  /// Butona dokununca (başlat / durdur — mantık map_screen'de).
  final VoidCallback onTap;

  const VoiceSearchButton({
    super.key,
    required this.isListening,
    required this.onTap,
  });

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // initState'te oluştur (dispose'da tembel başlatma → deaktive context hatası olmasın).
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isListening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VoiceSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.isListening;
    return Semantics(
      button: true,
      label: listening
          ? 'Sesli arama dinleniyor, durdurmak için dokunun'
          : 'Sesli arama',
      child: IconButton(
        onPressed: widget.onTap,
        icon: listening
            ? ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.15).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: const Icon(Icons.mic, color: AppColors.danger),
              )
            : const Icon(Icons.mic_none, color: AppColors.primary),
      ),
    );
  }
}
