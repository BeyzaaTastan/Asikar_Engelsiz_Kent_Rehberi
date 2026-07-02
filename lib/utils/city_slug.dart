/// Şehir (il) adını FCM topic-güvenli bir slug'a çevirir. SAF / test edilebilir.
///
/// Neden: Fiziksel yardım çağrıları şehir bazlı FCM topic'ine (`volunteers_<sehir>`)
/// gönderilir (bkz. vault/07-Performance/11-Olcekleme.md). FCM topic adı yalnızca
/// `[a-zA-Z0-9-_.~%]+` içerebilir; ürettiğimiz slug yalnızca `[a-z0-9]` içerir → güvenli.
/// İstemci ([lib/screens/home/disabled_home.dart] arayan tarafı ve
/// [lib/services/notification_service.dart] gönüllü aboneliği) AYNI slug'ı üretmeli ki
/// iki taraf aynı topic'te buluşsun.
///
/// - Türkçe karakterler ASCII'ye foldlanır (ç→c, ğ→g, ı/İ→i, ö→o, ş→s, ü→u).
/// - Küçük harfe indirilir; harf/rakam dışı her karakter (boşluk, tire, nokta) atılır.
/// - Boş/anlamsız girdide `null` döner → çağrı global `volunteers`'a düşer (fallback).
String? citySlug(String? cityName) {
  if (cityName == null) return null;
  final trimmed = cityName.trim();
  if (trimmed.isEmpty) return null;

  const foldMap = <String, String>{
    'ç': 'c', 'Ç': 'c',
    'ğ': 'g', 'Ğ': 'g',
    'ı': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o',
    'ş': 's', 'Ş': 's',
    'ü': 'u', 'Ü': 'u',
  };

  final buffer = StringBuffer();
  for (final rune in trimmed.runes) {
    var ch = String.fromCharCode(rune);
    ch = foldMap[ch] ?? ch.toLowerCase();
    if (ch.length != 1) continue; // beklenmeyen çok-kod-birimli sonuç → atla
    final code = ch.codeUnitAt(0);
    final isLower = code >= 0x61 && code <= 0x7A; // a-z
    final isDigit = code >= 0x30 && code <= 0x39; // 0-9
    if (isLower || isDigit) buffer.write(ch);
  }

  final slug = buffer.toString();
  return slug.isEmpty ? null : slug;
}
