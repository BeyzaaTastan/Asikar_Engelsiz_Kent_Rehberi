/// POI kategori önem/öncelik ağırlığı — SAF/birim testli.
///
/// Google Haritalar'daki gibi kademeli görünürlük için kullanılır: declutter
/// (çakışma önleme) POI'leri bu ağırlığa göre sıralar → yüksek öncelikli mekanlar
/// çakışmada ismini korur, düşük öncelikli olanlar noktaya düşer/gizlenir.
///
/// [amenityType], `OsmPoi.amenityType` ham değeridir (ör. 'cafe', 'hospital',
/// 'shop_bakery', 'tourism_hotel', 'leisure_park').
///
/// 3 = yüksek (az sayıda, yönelim için önemli/büyük mekanlar — erken görünür)
/// 2 = orta (yeme-içme, banka, eğitim)
/// 1 = düşük (küçük dükkanlar/diğer — yalnız çok yakında)
int poiPriority(String amenityType) {
  final t = amenityType.toLowerCase();

  const high = {
    'hospital',
    'pharmacy',
    'fuel',
    'police',
    'place_of_worship',
    'university',
    'museum',
    'tourism_museum',
    'tourism_hotel',
    'tourism_motel',
    'tourism_hostel',
    'tourism_guest_house',
    'tourism_attraction',
    'tourism_viewpoint',
    'supermarket',
    'shop_supermarket',
    'cinema',
    'theatre',
    'leisure_park',
    'leisure_sports_centre',
    'leisure_swimming_pool',
  };

  const medium = {
    'restaurant',
    'fast_food',
    'cafe',
    'bank',
    'clinic',
    'school',
    'library',
    'post_office',
    'parking',
    'leisure_fitness_centre',
  };

  if (high.contains(t)) return 3;
  if (medium.contains(t)) return 2;
  return 1;
}

/// Bu öncelikteki POI'nin **isim etiketiyle** görünmeye başladığı en düşük zoom.
/// Google tarzı kademeli görünürlük: yüksek öncelik erken (uzaktan) isimle,
/// düşük öncelik yalnız en yakında isimle gelir.
double poiLabelMinZoom(int priority) {
  switch (priority) {
    case 3:
      return 15; // hastane/eczane/otel/market... — uzaktan isimle
    case 2:
      return 17; // restoran/kafe/banka... — orta yakınlıkta isimle
    default:
      return 18; // küçük dükkanlar — yalnız en yakında isimle
  }
}

/// Bu öncelikteki POI'nin **nokta** (etiketsiz önizleme) olarak görünmeye
/// başladığı en düşük zoom. İsim eşiğinin ALTINDADIR (isimden önce nokta gelir).
/// Yüksek öncelikte nokta aşaması YOKTUR (doğrudan isim ya da gizli) → düşük
/// zoom'da harita nokta kalabalığıyla dolmasın (kullanıcı isteği).
double poiDotMinZoom(int priority) {
  switch (priority) {
    case 3:
      return 99; // nokta aşaması yok
    case 2:
      return 16; // 16'da nokta, 17'de isim
    default:
      return 17; // 17'de nokta, 18'de isim
  }
}
