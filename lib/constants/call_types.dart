/// Çağrı tipleri — çağrının hangi gönüllülere yönlendirileceğini belirler.
///
/// - [fiziksel] : Yerinde fiziksel yardım / şehir rehberliği. Gönüllünün
///   yerinde bulunması gerektiği için çağrı YALNIZCA arayanla aynı şehirdeki
///   gönüllülere düşer (FCM `volunteers_<sehir>` topic'i).
/// - [uzaktan] : Uzaktan görüntülü destek. Konum gerekmez → konumdan bağımsız
///   TÜM gönüllülere düşer (global FCM `volunteers` topic'i).
///
/// String literal kullanmak yerine bu sabitleri kullan (istemci + `functions/index.js`
/// + `firestore.rules` aynı değerlere bağlıdır). Detay: vault/07-Performance/11-Olcekleme.md.
class CagriTipi {
  const CagriTipi._();

  static const String fiziksel = 'fiziksel';
  static const String uzaktan = 'uzaktan';

  static const List<String> hepsi = [fiziksel, uzaktan];
}
