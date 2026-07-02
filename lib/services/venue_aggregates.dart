import '../models/venue_model.dart';
import 'accessibility_score.dart';

/// Bir yorum eklendiğinde mekânın türetilmiş alanlarını saf biçimde yeniden
/// hesaplar: yorumu listeye ekler, ortalama puanı, birleşik erişilebilirlik
/// özelliklerini ve erişilebilirlik skorunu günceller. Firestore/transaction'dan
/// bağımsız → birim testiyle korunur (test/unit/venue_aggregates_test.dart).
/// Eşzamanlılık garantisi Firestore transaction serileştirmesinden gelir
/// (bkz. vault/03-Data/03-Veritabani.md).
VenueModel venueWithNewComment(VenueModel venue, CommentModel newComment) {
  final List<CommentModel> newComments = [...venue.comments, newComment];

  final double totalRating =
      newComments.fold<double>(0, (sum, c) => sum + c.rating);
  final double averageRating = totalRating / newComments.length;

  final Set<String> mergedFeatures = {
    ...venue.features,
    ...newComment.verifiedFeatures,
  };

  final int newScore =
      calculateAccessibilityScore(mergedFeatures.toList(), averageRating);

  return venue.copyWith(
    comments: newComments,
    averageRating: averageRating,
    features: mergedFeatures.toList(),
    accessibilityScore: newScore,
  );
}
