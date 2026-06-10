import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

// SettingsService'i async olarak başlatan provider.
// main.dart'ta override edilir: ProviderScope(overrides: [...])
final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError('settingsServiceProvider ProviderScope\'da override edilmeli');
});

/// Uygulama genelindeki erişilebilirlik ayarlarını tutan state sınıfı.
class AppSettings {
  final double fontScale;
  final bool highContrast;
  final bool soundEnabled;
  final bool darkMode;
  
  // Favori Rotalar (JSON string olarak saklanır)
  final String? routeHome;
  final String? routeWork;
  final String? routePark;

  const AppSettings({
    this.fontScale = 1.0,
    this.highContrast = false,
    this.soundEnabled = true,
    this.darkMode = false,
    this.routeHome,
    this.routeWork,
    this.routePark,
  });

  AppSettings copyWith({
    double? fontScale,
    bool? highContrast,
    bool? soundEnabled,
    bool? darkMode,
    String? routeHome,
    String? routeWork,
    String? routePark,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      highContrast: highContrast ?? this.highContrast,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      darkMode: darkMode ?? this.darkMode,
      routeHome: routeHome ?? this.routeHome,
      routeWork: routeWork ?? this.routeWork,
      routePark: routePark ?? this.routePark,
    );
  }
}

/// Tüm uygulamanın erişeceği ayar notifier'ı.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service)
      : super(AppSettings(
          fontScale: _service.fontScale,
          highContrast: _service.highContrast,
          soundEnabled: _service.soundEnabled,
          darkMode: _service.darkMode,
          routeHome: _service.routeHome,
          routeWork: _service.routeWork,
          routePark: _service.routePark,
        ));

  Future<void> setFontScale(double value) async {
    await _service.setFontScale(value);
    state = state.copyWith(fontScale: value);
  }

  Future<void> setHighContrast(bool value) async {
    await _service.setHighContrast(value);
    state = state.copyWith(highContrast: value);
  }

  Future<void> setSoundEnabled(bool value) async {
    await _service.setSoundEnabled(value);
    state = state.copyWith(soundEnabled: value);
  }

  Future<void> setDarkMode(bool value) async {
    await _service.setDarkMode(value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setRouteHome(String value) async {
    await _service.setRouteHome(value);
    state = state.copyWith(routeHome: value);
  }

  Future<void> setRouteWork(String value) async {
    await _service.setRouteWork(value);
    state = state.copyWith(routeWork: value);
  }

  Future<void> setRoutePark(String value) async {
    await _service.setRoutePark(value);
    state = state.copyWith(routePark: value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});

/// Yazı boyutu etiketlerini döndürür (Slider tick labels için).
String fontScaleLabel(double scale) {
  if (scale <= 0.85) return 'Küçük';
  if (scale <= 1.05) return 'Orta';
  if (scale <= 1.25) return 'Büyük';
  return 'Çok Büyük';
}

/// Yüksek kontrast aktifken kullanılacak renk şeması.
ColorScheme highContrastColorScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const ColorScheme.dark(
      primary: Color(0xFFFFFF00),       // Parlak sarı
      onPrimary: Colors.black,
      surface: Colors.black,
      onSurface: Color(0xFFFFFFFF),
    );
  }
  return const ColorScheme.light(
    primary: Color(0xFF000080),          // Koyu lacivert
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
  );
}
