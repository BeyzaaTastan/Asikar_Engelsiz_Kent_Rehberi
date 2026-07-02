/// Yorum girdisi doğrulaması (saf, test edilebilir).
/// Gömülü yorum modelinde mekan belgesi 1MB Firestore sınırına dayanmasın diye
/// içerik uzunluğu ve mekan başına yorum sayısı üst sınırlanır.
/// (bkz. vault/03-Data/03-Veritabani.md gömülü yorum,
///  vault/07-Performance/11-Olcekleme.md gömülü yorum 1MB ölçek sınırı)
library;

/// Tek yorum içeriği üst sınırı (karakter).
const int kMaxCommentContentLength = 1000;

/// Mekan başına gömülü yorum sayısı üst sınırı (1MB belge limitine pay bırakır).
const int kMaxCommentsPerVenue = 500;

/// Yeni yorumu doğrular. Geçersizse Türkçe hata mesajı, geçerliyse null döner.
/// Yalnızca ÜST sınır koyar (boş/kısa içeriği reddetmez → mevcut davranış korunur);
/// amaç kötüye kullanım/şişme ile belgenin 1MB'a dayanmasını engellemek.
String? validateNewComment({
  required String content,
  required int existingCommentCount,
}) {
  if (content.length > kMaxCommentContentLength) {
    return 'Yorum en fazla $kMaxCommentContentLength karakter olabilir.';
  }
  if (existingCommentCount >= kMaxCommentsPerVenue) {
    return 'Bu mekan için yorum sınırına ulaşıldı.';
  }
  return null;
}
