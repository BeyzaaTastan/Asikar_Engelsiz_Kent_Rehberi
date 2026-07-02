/// Erişilebilirlik skorunu (0-100) saf biçimde hesaplar.
/// Özellik sayısı 70 puana, ortalama puan 30 puana kadar katkı verir; min 5 / max 100.
/// (bkz. vault/03-Data/03-Veritabani.md · "Skor formülü")
///
/// Saf, bağımlılıksız — birim testiyle korunur (test/unit/accessibility_score_test.dart).
int calculateAccessibilityScore(List<String> features, double avgRating) {
  const int totalPossibleFeatures = 8; // Rampa, Asansör, Tuvalet, Otopark, Hissedilebilir, Kabartma, Sesli, İşaret
  final double featureRatio = features.length / totalPossibleFeatures;
  final double featurePoints = featureRatio * 70; // özellikler → max 70
  final double ratingPoints = (avgRating / 5.0) * 30; // puan → max 30
  int score = (featurePoints + ratingPoints).round();
  if (score > 100) score = 100;
  if (score < 5) score = 5; // en az bir şey varsa taban skor
  return score;
}
