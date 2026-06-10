import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/venue_model.dart';

class VenueException implements Exception {
  final String message;
  VenueException(this.message);
  @override
  String toString() => message;
}

class VenueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Real-time stream of all venues from Firestore.
  /// If the database is empty, it triggers the initial seeding.
  Stream<List<VenueModel>> streamVenues() {
    return _db.collection('venues').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Seeding in the background
        seedInitialVenues();
      }
      return snapshot.docs.map((doc) {
        return VenueModel.fromJson(doc.data());
      }).toList();
    });
  }

  /// Adds a new venue to Firestore.
  /// Calculates initial accessibility score based on checked features.
  Future<void> addVenue(VenueModel venue) async {
    try {
      final int initialScore = _calculateScore(venue.features, venue.averageRating);
      final updatedVenue = venue.copyWith(
        id: venue.id.isEmpty ? _uuid.v4() : venue.id,
        accessibilityScore: initialScore,
      );

      await _db.collection('venues').doc(updatedVenue.id).set(updatedVenue.toJson());
      debugPrint("Venue successfully added: ${updatedVenue.name}");
    } catch (e) {
      debugPrint("Error adding venue: $e");
      throw VenueException("Yeni mekan eklenirken internet bağlantınızda veya sunucuda bir hata oluştu.");
    }
  }

  /// Adds a comment/review to a venue and updates its average rating and accessibility score.
  Future<void> addComment(String venueId, CommentModel comment) async {
    try {
      final docRef = _db.collection('venues').doc(venueId);

      await _db.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);

        if (!docSnap.exists) {
          throw VenueException("Değerlendirme yapılmak istenen mekan sistemde bulunamadı.");
        }

        final venue = VenueModel.fromJson(docSnap.data()!);
        
        // Add the new comment
        final updatedComment = comment.copyWith(id: _uuid.v4());
        final List<CommentModel> newComments = List.from(venue.comments)..add(updatedComment);

        // Recalculate average rating
        double totalRating = 0;
        for (var c in newComments) {
          totalRating += c.rating;
        }
        final double averageRating = totalRating / newComments.length;

        // Merge verified features: if a feature is verified by a user, we can ensure it is added to the venue's features
        final Set<String> updatedFeatures = Set.from(venue.features);
        updatedFeatures.addAll(comment.verifiedFeatures);

        // Recalculate accessibility score
        final int newScore = _calculateScore(updatedFeatures.toList(), averageRating);

        final updatedVenue = venue.copyWith(
          comments: newComments,
          averageRating: averageRating,
          features: updatedFeatures.toList(),
          accessibilityScore: newScore,
        );

        transaction.set(docRef, updatedVenue.toJson());
      });

      debugPrint("Comment successfully added to venue: $venueId");
    } catch (e) {
      debugPrint("Error adding comment: $e");
      if (e is VenueException) rethrow;
      throw VenueException("Yorum ve derecelendirme eklenirken internet bağlantınızda veya sunucuda bir hata oluştu.");
    }
  }

  /// Calculates the accessibility score out of 100.
  /// Base features count contributes 70 points, reviews contribute 30 points.
  int _calculateScore(List<String> features, double avgRating) {
    const int totalPossibleFeatures = 8; // Rampa, Asansör, Tuvalet, Otopark, Hissedilebilir, Kabartma, Sesli, İşaret
    final double featureRatio = features.length / totalPossibleFeatures;
    
    // Scale feature ratio to 70 points max
    final double featurePoints = featureRatio * 70;
    
    // Scale 1-5 rating to 30 points max
    final double ratingPoints = (avgRating / 5.0) * 30;

    int score = (featurePoints + ratingPoints).round();
    if (score > 100) score = 100;
    if (score < 5) score = 5; // minimum score baseline if at least something is there
    return score;
  }

  /// Seeds 7 initial high-quality venues in Sakarya.
  Future<void> seedInitialVenues() async {
    debugPrint("Seeding initial venues to Firestore...");
    try {
      final List<VenueModel> mockVenues = [
        VenueModel(
          id: 'mock_millet_bahcesi',
          name: 'Sakarya Millet Bahçesi',
          category: 'Park',
          address: 'Mithatpaşa, 54100 Adapazarı/Sakarya',
          latitude: 40.7715,
          longitude: 30.3985,
          description: 'Adapazarı merkezinde yer alan eski stadyum alanına inşa edilmiş Millet Bahçesi, geniş düz yolları, engelsiz tuvaletleri ve hissedilebilir yüzeyleri ile son derece yüksek erişilebilirliğe sahiptir.',
          accessibilityScore: 92,
          features: ['Tekerlekli Sandalye Girişi', 'Engelli Otoparkı', 'Hissedilebilir Yüzey', 'Engelli Tuvaleti'],
          images: [],
          comments: [
            CommentModel(
              id: 'c1',
              userId: 'user_millet_1',
              userName: 'Ahmet Yılmaz',
              userType: 'Engelli',
              rating: 5.0,
              content: 'Tekerlekli sandalye ile tüm parkı tek başıma gezebildim. Rampalar çok eğimli değil ve engelsiz tuvalet temizdi.',
              createdAt: DateTime.now().subtract(const Duration(days: 3)),
              verifiedFeatures: ['Tekerlekli Sandalye Girişi', 'Engelli Tuvaleti'],
            ),
            CommentModel(
              id: 'c2',
              userId: 'user_millet_2',
              userName: 'Zeynep Kaya',
              userType: 'Gönüllü',
              rating: 4.5,
              content: 'Hissedilebilir yüzeyler park genelinde iyi yerleştirilmiş, görme engelli arkadaşlarımız için de gayet elverişli.',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
              verifiedFeatures: ['Hissedilebilir Yüzey'],
            )
          ],
          addedBy: 'admin',
          averageRating: 4.75,
        ),
        VenueModel(
          id: 'mock_serdivan_avm',
          name: 'Serdivan AVM',
          category: 'Alışveriş',
          address: 'Arabacıalanı, Mehmet Akif Ersoy Cd. No:8, 54050 Serdivan/Sakarya',
          latitude: 40.7622,
          longitude: 30.3695,
          description: 'Geniş koridorlar, asansörler, engelli tuvaletleri ve özel otopark alanları ile tekerlekli sandalye kullanıcıları için tam uyumludur. Ayrıca girişlerde kabartma yönlendirme panoları mevcuttur.',
          accessibilityScore: 95,
          features: ['Tekerlekli Sandalye Girişi', 'Engelli Otoparkı', 'Asansör', 'Engelli Tuvaleti', 'Kabartma Yönlendirme'],
          images: [],
          comments: [
            CommentModel(
              id: 'c3',
              userId: 'user_serdivan_1',
              userName: 'Murat Demir',
              userType: 'Engelli',
              rating: 5.0,
              content: 'Asansörlerin genişliği ve otoparktan girişler çok rahat. Sakarya\'daki en erişilebilir alışveriş merkezi.',
              createdAt: DateTime.now().subtract(const Duration(days: 5)),
              verifiedFeatures: ['Tekerlekli Sandalye Girişi', 'Asansör', 'Engelli Otoparkı'],
            )
          ],
          addedBy: 'admin',
          averageRating: 5.0,
        ),
        VenueModel(
          id: 'mock_justinianus',
          name: 'Justinianus Köprüsü (Sangarius)',
          category: 'Tarihi Yer',
          address: 'Beşköprü, Justinianus Köprüsü, 54050 Serdivan/Sakarya',
          latitude: 40.7383,
          longitude: 30.3468,
          description: 'Tarihi Beşköprü olarak da bilinen Bizans döneminden kalma bu anıtsal köprü çevresinde engelli otoparkı mevcuttur, ancak köprü yüzeyi engebeli taşlarla kaplı olduğundan tekerlekli sandalye ile ilerlemek refakatçi eşliğinde mümkündür.',
          accessibilityScore: 55,
          features: ['Tekerlekli Sandalye Girişi', 'Engelli Otoparkı'],
          images: [],
          comments: [
            CommentModel(
              id: 'c4',
              userId: 'user_justinianus_1',
              userName: 'Canan Sert',
              userType: 'Engelli',
              rating: 3.0,
              content: 'Çevre düzenlemesi yapılmış ve düz ayak yollar var fakat köprünün üstündeki tarihi taşlar çok sarsıyor, yanınızda biri olmadan geçmek zor.',
              createdAt: DateTime.now().subtract(const Duration(days: 10)),
              verifiedFeatures: ['Tekerlekli Sandalye Girişi'],
            )
          ],
          addedBy: 'admin',
          averageRating: 3.0,
        ),
        VenueModel(
          id: 'mock_kent_park',
          name: 'Kent Park',
          category: 'Park',
          address: 'Donatım, 54100 Adapazarı/Sakarya',
          latitude: 40.7745,
          longitude: 30.3888,
          description: 'Yemyeşil doğası ve geniş yürüyüş yolları ile harika bir dinlenme alanı. Kafeterya girişleri düz ayaktır ve park içinde engelli tuvaleti bulunur. Ancak bazı yürüyüş yollarında hissedilebilir yüzey çalışmaları eksiktir.',
          accessibilityScore: 80,
          features: ['Tekerlekli Sandalye Girişi', 'Engelli Tuvaleti', 'Asansör'],
          images: [],
          comments: [
            CommentModel(
              id: 'c5',
              userId: 'user_kent_1',
              userName: 'Mustafa Öz',
              userType: 'Sakin',
              rating: 4.0,
              content: 'Tekerlekli sandalye ile gitmek için ideal. Gölet etrafındaki yürüyüş parkurları oldukça düz ve engelsiz.',
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
              verifiedFeatures: ['Tekerlekli Sandalye Girişi'],
            )
          ],
          addedBy: 'admin',
          averageRating: 4.0,
        ),
        VenueModel(
          id: 'mock_belediye',
          name: 'Adapazarı Belediyesi Hizmet Binası',
          category: 'Kamu Binası',
          address: 'Orta Mahalle, Çark Cd. No:4, 54100 Adapazarı/Sakarya',
          latitude: 40.7758,
          longitude: 30.4012,
          description: 'Kamu hizmet binası engelsiz erişim standartlarına uygun olarak tasarlanmıştır. Rampalar, asansörler, hissedilebilir yüzey yolları ve gerektiğinde işaret dili desteği sunan personel bulunmaktadır.',
          accessibilityScore: 90,
          features: ['Tekerlekli Sandalye Girişi', 'Engelli Otoparkı', 'Asansör', 'Engelli Tuvaleti', 'Hissedilebilir Yüzey', 'Kabartma Yönlendirme', 'İşaret Dili Desteği'],
          images: [],
          comments: [],
          addedBy: 'admin',
          averageRating: 0.0,
        ),
        VenueModel(
          id: 'mock_cark_caddesi',
          name: 'Çark Caddesi',
          category: 'Sosyal Alan',
          address: 'Semerciler, Çark Cd., 54100 Adapazarı/Sakarya',
          latitude: 40.7788,
          longitude: 30.3955,
          description: 'Sakarya\'nın en popüler yaya caddesidir. Cadde düz ayak olsa da, ara sokaklardaki yüksek kaldırımlar ve dükkan girişlerindeki basamaklar tekerlekli sandalye ve görme engelli bireyler için zorluk yaratmaktadır.',
          accessibilityScore: 45,
          features: ['Tekerlekli Sandalye Girişi'],
          images: [],
          comments: [
            CommentModel(
              id: 'c6',
              userId: 'user_cark_1',
              userName: 'Gizem Ak',
              userType: 'Engelli',
              rating: 2.5,
              content: 'Caddenin ortasında yürümek sorun değil ama dükkanların %90\'ına girmek imkansız, hepsi merdivenli. Engelli rampası olan çok az yer var.',
              createdAt: DateTime.now().subtract(const Duration(days: 8)),
              verifiedFeatures: ['Tekerlekli Sandalye Girişi'],
            )
          ],
          addedBy: 'admin',
          averageRating: 2.5,
        ),
        VenueModel(
          id: 'mock_poyrazlar',
          name: 'Poyrazlar Gölü Tabiat Parkı',
          category: 'Doğa',
          address: 'Poyrazlar, 54100 Adapazarı/Sakarya',
          latitude: 40.8350,
          longitude: 30.4180,
          description: 'Doğal bir göl çevresinde yer alan parkta yollar çoğunlukla toprak ve çakıldır. Tekerlekli sandalye kullanıcıları için zorlu bir parkurdur. Engelli tuvaleti mevcuttur ancak ana yola uzaktır.',
          accessibilityScore: 30,
          features: ['Engelli Otoparkı', 'Engelli Tuvaleti'],
          images: [],
          comments: [
            CommentModel(
              id: 'c7',
              userId: 'user_poyrazlar_1',
              userName: 'Bülent Bal',
              userType: 'Gönüllü',
              rating: 2.0,
              content: 'Tekerlekli sandalye kullanan bir arkadaşımla geldik, piknik alanlarında çok zorlandık. Toprak zemin ıslakken tamamen çamur oluyor.',
              createdAt: DateTime.now().subtract(const Duration(days: 12)),
              verifiedFeatures: ['Engelli Otoparkı'],
            )
          ],
          addedBy: 'admin',
          averageRating: 2.0,
        ),
      ];

      final batch = _db.batch();
      for (var venue in mockVenues) {
        batch.set(_db.collection('venues').doc(venue.id), venue.toJson());
      }
      await batch.commit();
      debugPrint("Successfully seeded 7 mock venues!");
    } catch (e) {
      debugPrint("Seeding failed: $e");
    }
  }
}
