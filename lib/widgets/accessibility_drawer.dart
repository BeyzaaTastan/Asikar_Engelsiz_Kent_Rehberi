import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';

/// Sol üstteki ☰ menüye tıklandığında açılan erişilebilirlik ve geri bildirim drawer'ı.
class AccessibilityDrawer extends ConsumerWidget {
  const AccessibilityDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Başlık ──────────────────────────────────────────────────
            _DrawerHeader(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── ERİŞİLEBİLİRLİK BÖLÜMÜ ─────────────────────────
                  _SectionTitle(title: '♿  Erişilebilirlik'),

                  // Yazı Boyutu
                  _FontSizeTile(
                    currentScale: settings.fontScale,
                    onChanged: (val) => notifier.setFontScale(val),
                  ),

                  const SizedBox(height: 4),

                  // Yüksek Kontrast
                  _SwitchTile(
                    icon: Icons.contrast,
                    label: 'Yüksek Kontrast',
                    subtitle: 'Renk körülüğü desteği',
                    value: settings.highContrast,
                    onChanged: (val) => notifier.setHighContrast(val),
                  ),

                  // Karanlık Mod
                  _SwitchTile(
                    icon: Icons.dark_mode_outlined,
                    label: 'Karanlık Mod',
                    subtitle: 'Koyu tema',
                    value: settings.darkMode,
                    onChanged: (val) => notifier.setDarkMode(val),
                  ),

                  // Ses
                  _SwitchTile(
                    icon: settings.soundEnabled
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    label: 'Sesli Yönlendirme',
                    subtitle: settings.soundEnabled ? 'Açık' : 'Kapalı',
                    value: settings.soundEnabled,
                    onChanged: (val) => notifier.setSoundEnabled(val),
                  ),

                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // ── GERİ BİLDİRİM BÖLÜMÜ ───────────────────────────
                  _SectionTitle(title: '💬  Geri Bildirim'),

                  _ActionTile(
                    icon: Icons.feedback_outlined,
                    label: 'Geri Bildirim Gönder',
                    subtitle: 'Görüş ve önerileriniz',
                    onTap: () => _showFeedbackDialog(context, isBugReport: false),
                  ),

                  _ActionTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Hata Bildir',
                    subtitle: 'Teknik sorun bildirimi',
                    onTap: () => _showFeedbackDialog(context, isBugReport: true),
                  ),

                  _ActionTile(
                    icon: Icons.star_outline_rounded,
                    label: 'Uygulamayı Puanla',
                    subtitle: 'Google Play\'de değerlendirin',
                    onTap: () => _openStore(),
                  ),
                ],
              ),
            ),

            // ── Alt bilgi ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aşikar Engelsiz Kent Rehberi\nSürüm 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Geri bildirim / hata bildir formu ───────────────────────────────
  void _showFeedbackDialog(BuildContext context, {required bool isBugReport}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBugReport ? '🐛 Hata Bildir' : '💬 Geri Bildirim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBugReport
                  ? 'Karşılaştığınız sorunu kısaca açıklayın:'
                  : 'Görüş ve önerilerinizi yazın:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isBugReport
                    ? 'Sorun ne zaman ve nasıl oluştu?'
                    : 'Düşünceleriniz...',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBugReport
                        ? '🐛 Hata raporunuz iletildi, teşekkürler!'
                        : '✅ Geri bildiriminiz iletildi, teşekkürler!'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // Google Play'e yönlendirme (uygulama yayınlandığında gerçek ID girilmeli)
  Future<void> _openStore() async {
    const storeUrl =
        'https://play.google.com/store/apps/details?id=com.asikar.engelsiz';
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Alt widget'lar ─────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.accessibility_new, color: Colors.white, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Aşikar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Engelsiz Kent Rehberi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

/// Yazı boyutu ayarı — özel slider tile
class _FontSizeTile extends StatelessWidget {
  final double currentScale;
  final ValueChanged<double> onChanged;

  const _FontSizeTile({required this.currentScale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: AppColors.primary),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yazı Boyutu',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    fontScaleLabel(currentScale),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Slider(
            value: currentScale,
            min: 0.8,
            max: 1.4,
            divisions: 3,
            activeColor: AppColors.primary,
            label: fontScaleLabel(currentScale),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              Text('A', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              Text('A', style: TextStyle(fontSize: 17, color: Colors.grey.shade400)),
              Text('A', style: TextStyle(fontSize: 20, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}
