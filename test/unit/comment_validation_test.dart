import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/comment_validation.dart';

// Kritik akış koruması: gömülü yorum 1MB belge sınırına dayanmasın diye
// içerik uzunluğu + mekan başına yorum sayısı üst sınırı.
// (bkz. vault/03-Data/03-Veritabani.md, vault/07-Performance/11-Olcekleme.md)
void main() {
  group('validateNewComment', () {
    test('sınır altındaki normal yorum geçerli (null)', () {
      expect(validateNewComment(content: 'Harika bir yer', existingCommentCount: 3), isNull);
    });

    test('boş içerik reddedilmez (mevcut davranış korunur)', () {
      expect(validateNewComment(content: '', existingCommentCount: 0), isNull);
    });

    test('tam sınırdaki içerik (1000) geçerli', () {
      final content = 'a' * kMaxCommentContentLength;
      expect(validateNewComment(content: content, existingCommentCount: 0), isNull);
    });

    test('sınırı aşan içerik (1001) reddedilir', () {
      final content = 'a' * (kMaxCommentContentLength + 1);
      expect(validateNewComment(content: content, existingCommentCount: 0), isNotNull);
    });

    test('yorum sayısı sınıra ulaşınca reddedilir', () {
      expect(validateNewComment(content: 'x', existingCommentCount: kMaxCommentsPerVenue), isNotNull);
    });

    test('yorum sayısı sınırın hemen altında geçerli', () {
      expect(validateNewComment(content: 'x', existingCommentCount: kMaxCommentsPerVenue - 1), isNull);
    });
  });
}
