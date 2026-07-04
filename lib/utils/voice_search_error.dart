/// Sesli arama (`speech_to_text`) hata kodlarını kullanıcıya dönük Türkçe mesaja
/// ve türe çeviren **saf** yardımcı. Cihaz/mikrofon/plugin gerektirmez → birim
/// testli (`test/unit/voice_search_error_test.dart`).
///
/// Neden ayrı katman: `speech_to_text`'in `onError`'ı yalnızca izin için değil,
/// izinle ilgisi OLMAYAN birçok durumda da tetiklenir (kullanıcı konuşmadı,
/// tanıyıcı meşgul, dil modeli yok, ağ hatası...). Eski kod bunların HEPSİNİ
/// "mikrofon iznini kontrol edin" diye gösteriyordu → izin verili olsa bile
/// yanıltıcı uyarı. Bu helper gerçek hatayı sınıflandırıp doğru mesajı üretir.
/// (bkz. vault/01-Frontend/01-On-Yuz.md · "Sesli arama".)
library;

/// Sesli arama hatasının kaba türü — mesaj + davranış (iyi huylu mu) ayrımı için.
enum VoiceSearchErrorKind {
  /// Gerçek izin eksikliği — kullanıcıyı ayarlara yönlendir.
  permission,

  /// Konuşma algılanamadı / zaman aşımı — iyi huylu, "tekrar deneyin".
  noSpeech,

  /// Cihazda seçili dil (tr_TR) konuşma modeli yok.
  language,

  /// Ağ tabanlı tanıma başarısız (bağlantı gerekli).
  network,

  /// Tanıyıcı meşgul / geçici istemci hatası — kısa süre sonra tekrar.
  busy,

  /// Sınıflandırılamayan diğer hatalar.
  unknown,
}

/// Sınıflandırılmış sesli arama hatası: [kind] + kullanıcıya gösterilecek
/// [message]. [isBenign] true ise kullanıcıyı korkutan bir arıza değildir
/// (yalnızca "duyamadım, tekrar deneyin").
class VoiceSearchError {
  final VoiceSearchErrorKind kind;
  final String message;

  const VoiceSearchError(this.kind, this.message);

  bool get isBenign => kind == VoiceSearchErrorKind.noSpeech;
}

/// `speech_to_text` `errorMsg`'ini (örn. `error_no_match`,
/// `error_speech_timeout`, `error_language_unavailable`, `error_network`,
/// `error_busy`, `error_client`, `error_insufficient_permissions`) doğru
/// [VoiceSearchError]'a çevirir. Bilinmeyen kod → [VoiceSearchErrorKind.unknown].
VoiceSearchError classifyVoiceSearchError(String errorMsg) {
  final e = errorMsg.toLowerCase();

  // Gerçek izin hatası — TEK bu durumda izinden bahset.
  if (e.contains('permission') || e.contains('insufficient') || e.contains('denied')) {
    return const VoiceSearchError(
      VoiceSearchErrorKind.permission,
      'Sesli arama için mikrofon izni gerekli. Uygulama ayarlarından izni açın.',
    );
  }

  // Konuşma algılanamadı / zaman aşımı — iyi huylu, izinle ilgisi yok.
  if (e.contains('no_match') ||
      e.contains('nomatch') ||
      e.contains('speech_timeout') ||
      e.contains('speechtimeout')) {
    return const VoiceSearchError(
      VoiceSearchErrorKind.noSpeech,
      'Sizi duyamadım. Lütfen tekrar deneyin.',
    );
  }

  // Cihazda Türkçe konuşma modeli yok → sesli arama değil, yazarak arama öner.
  if (e.contains('language')) {
    return const VoiceSearchError(
      VoiceSearchErrorKind.language,
      'Cihazınızda Türkçe konuşma tanıma bulunamadı. Arama kutusuna yazabilirsiniz.',
    );
  }

  // Ağ tabanlı tanıma → bağlantı gerekli.
  if (e.contains('network')) {
    return const VoiceSearchError(
      VoiceSearchErrorKind.network,
      'Sesli arama için internet bağlantısı gerekiyor. Bağlantınızı kontrol edin.',
    );
  }

  // Tanıyıcı meşgul / geçici istemci hatası (bazı Android sürümlerinde başlarken).
  if (e.contains('busy') || e.contains('client') || e.contains('recognizer')) {
    return const VoiceSearchError(
      VoiceSearchErrorKind.busy,
      'Sesli arama şu anda meşgul. Birkaç saniye sonra tekrar deneyin.',
    );
  }

  return const VoiceSearchError(
    VoiceSearchErrorKind.unknown,
    'Sesli arama başlatılamadı. Lütfen tekrar deneyin.',
  );
}
