/// CallKit `extra` / FCM payload'ından GEÇERLİ bir Agora kanal adını
/// (= çağrı Firestore belge ID'si) çıkarır. Geçersizse (null/boş) `null` döner.
///
/// Saf, bağımlılıksız doğrulama — birim testiyle korunur
/// (test/unit/channel_validator_test.dart). Eski kod kanal yoksa paylaşılan
/// sabite ('yardim_kanali') düşüyordu; eşzamanlı çağrılarda yanlış görüşmeye
/// yol açıyordu. Artık geçersizse çağrı kurulmaz.
String? validChannelName(Object? raw) {
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
