import 'package:shared_preferences/shared_preferences.dart';

/// Erişilebilirlik ayarlarını cihazda (SharedPreferences) saklayan servis.
class SettingsService {
  static const _keyFontScale = 'font_scale';
  static const _keyHighContrast = 'high_contrast';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyDarkMode = 'dark_mode';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  /// SharedPreferences örneği oluşturur — uygulama başlangıcında bir kez çağrılır.
  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  // --- Yazı Boyutu ---
  double get fontScale => _prefs.getDouble(_keyFontScale) ?? 1.0;
  Future<void> setFontScale(double value) => _prefs.setDouble(_keyFontScale, value);

  // --- Yüksek Kontrast ---
  bool get highContrast => _prefs.getBool(_keyHighContrast) ?? false;
  Future<void> setHighContrast(bool value) => _prefs.setBool(_keyHighContrast, value);

  // --- Ses ---
  bool get soundEnabled => _prefs.getBool(_keySoundEnabled) ?? true;
  Future<void> setSoundEnabled(bool value) => _prefs.setBool(_keySoundEnabled, value);

  // --- Karanlık Mod ---
  bool get darkMode => _prefs.getBool(_keyDarkMode) ?? false;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_keyDarkMode, value);

  // --- Favori Rotalar (Ev, İş, Park) ---
  // Konum verisini JSON string olarak saklıyoruz: {"name": "Adres", "lat": 40.1, "lng": 30.1}
  String? get routeHome => _prefs.getString('route_home');
  Future<void> setRouteHome(String jsonStr) => _prefs.setString('route_home', jsonStr);

  String? get routeWork => _prefs.getString('route_work');
  Future<void> setRouteWork(String jsonStr) => _prefs.setString('route_work', jsonStr);

  String? get routePark => _prefs.getString('route_park');
  Future<void> setRoutePark(String jsonStr) => _prefs.setString('route_park', jsonStr);

  // --- Son Harita Aramaları ---
  // Her eleman JSON string: {"title": "...", "subtitle": "...", "lat": 40.1, "lon": 30.1, "type": "recent"}
  List<String> get recentMapSearches => _prefs.getStringList('recent_map_searches') ?? [];

  Future<void> addRecentMapSearch(Map<String, dynamic> item) async {
    final list = recentMapSearches;
    // Aynı başlık daha önce eklenmiş ise önce sil (en üste taşı)
    list.removeWhere((e) {
      try {
        final decoded = _decodeJson(e);
        return decoded['title'] == item['title'];
      } catch (_) {
        return false;
      }
    });
    // En başa ekle
    list.insert(0, _encodeJson(item));
    // Maksimum 15 tane sakla — arama overlay'i kaydırılabilir olduğundan
    // (bkz. SmartResultsOverlay) klavye kapalıyken daha fazla geçmiş görünür.
    final trimmed = list.take(15).toList();
    await _prefs.setStringList('recent_map_searches', trimmed);
  }

  /// Tüm son harita aramalarını siler (kullanıcı "Temizle"ye basınca).
  Future<void> clearRecentMapSearches() async {
    await _prefs.remove('recent_map_searches');
  }

  // Yardımcı metodlar
  String _encodeJson(Map<String, dynamic> m) {
    return m.entries.map((e) => '${e.key}=${e.value}').join('||');
  }

  Map<String, dynamic> _decodeJson(String s) {
    final map = <String, dynamic>{};
    for (final part in s.split('||')) {
      final idx = part.indexOf('=');
      if (idx < 0) continue;
      final key = part.substring(0, idx);
      final val = part.substring(idx + 1);
      if (key == 'lat' || key == 'lon') {
        map[key] = double.tryParse(val);
      } else {
        map[key] = val;
      }
    }
    return map;
  }

  List<Map<String, dynamic>> get recentMapSearchesParsed {
    return recentMapSearches.map((e) {
      try {
        return _decodeJson(e);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }
}
