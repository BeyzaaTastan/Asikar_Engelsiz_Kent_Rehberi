import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/models/venue_model.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/venue_aggregates.dart';
import 'package:asikar_engelsiz_kent_rehberi/services/accessibility_score.dart';

// Kritik akış koruması: yorum eklenince türetilmiş alanların (averageRating,
// features, accessibilityScore) doğru yeniden hesaplanması.
// Eşzamanlılık garantisi Firestore runTransaction serileştirmesinden gelir;
// bu testler serileştirilmiş (ardı ardına) uygulamanın doğru sonucunu doğrular.
// (bkz. vault/03-Data/03-Veritabani.md, vault/05-Infrastructure/07-CI-CD.md)

VenueModel _venue({
  List<CommentModel> comments = const [],
  List<String> features = const [],
  double averageRating = 0.0,
  int accessibilityScore = 0,
}) {
  return VenueModel(
    id: 'v1',
    name: 'Test Mekan',
    category: 'Park',
    address: 'Sakarya',
    latitude: 40.0,
    longitude: 30.0,
    description: 'açıklama',
    accessibilityScore: accessibilityScore,
    features: features,
    images: const [],
    comments: comments,
    addedBy: 'owner-uid',
    averageRating: averageRating,
  );
}

CommentModel _comment({
  required double rating,
  List<String> verifiedFeatures = const [],
  String id = 'c',
}) {
  return CommentModel(
    id: id,
    userId: 'u1',
    userName: 'Kullanıcı',
    userType: 'Sakin',
    rating: rating,
    content: 'yorum',
    createdAt: DateTime(2026, 1, 1),
    verifiedFeatures: verifiedFeatures,
  );
}

void main() {
  group('venueWithNewComment', () {
    test('ilk yorum (boş mekân + 4.0) → ortalama 4.0, yorum sayısı 1', () {
      final result = venueWithNewComment(_venue(), _comment(rating: 4.0));
      expect(result.averageRating, 4.0);
      expect(result.comments.length, 1);
    });

    test('ortalama doğru birikir: mevcut [5.0] + yeni 3.0 → 4.0', () {
      final venue = _venue(comments: [_comment(rating: 5.0, id: 'c0')]);
      final result = venueWithNewComment(venue, _comment(rating: 3.0, id: 'c1'));
      expect(result.averageRating, 4.0);
      expect(result.comments.length, 2);
    });

    test('iki yorum ardı ardına (transaction serileştirmesi) → ortalama 4.0, 2 yorum', () {
      var venue = _venue();
      venue = venueWithNewComment(venue, _comment(rating: 5.0, id: 'c0'));
      venue = venueWithNewComment(venue, _comment(rating: 3.0, id: 'c1'));
      expect(venue.averageRating, 4.0);
      expect(venue.comments.length, 2);
    });

    test('verifiedFeatures birleşir ve Set ile tekrarsız kalır', () {
      final venue = _venue(features: ['Rampa']);
      final result = venueWithNewComment(
        venue,
        _comment(rating: 5.0, verifiedFeatures: ['Rampa', 'Asansör']),
      );
      expect(result.features.toSet(), {'Rampa', 'Asansör'});
      expect(result.features.length, 2); // 'Rampa' tekrar etmez
    });

    test('skor yeni ortalama + özelliklere göre calculateAccessibilityScore ile tutarlı', () {
      // 4 özellik + 2.5 ortalama → (4/8)*70 + (2.5/5)*30 = 35 + 15 = 50
      final venue = _venue(features: ['Rampa', 'Asansör', 'Tuvalet']);
      final result = venueWithNewComment(
        venue,
        _comment(rating: 2.5, verifiedFeatures: ['Otopark']),
      );
      expect(result.features.length, 4);
      expect(result.averageRating, 2.5);
      expect(
        result.accessibilityScore,
        calculateAccessibilityScore(result.features, result.averageRating),
      );
      expect(result.accessibilityScore, 50);
    });

    test('saflık: orijinal venue nesnesi değişmez', () {
      final venue = _venue(comments: [_comment(rating: 5.0, id: 'c0')]);
      venueWithNewComment(venue, _comment(rating: 1.0, id: 'c1'));
      // Orijinal yorum sayısı ve ortalama korunur
      expect(venue.comments.length, 1);
      expect(venue.averageRating, 0.0);
    });
  });
}
