/// Overpass API'den dönen bir OpenStreetMap POI'sini temsil eder.
///
/// Kafe, restoran, eczane, market, otel, park vb. mekanların
/// harita üzerinde gösterilmesi ve detay sayfasında bilgilerinin
/// sunulması için kullanılır.
class OsmPoi {
  final int osmId;
  final String osmType; // "node", "way", "relation"
  final double latitude;
  final double longitude;
  final String name;
  final String category; // Türkçe kategori adı (ör. "Kafe", "Eczane")
  final String amenityType; // OSM ham tag değeri (ör. "cafe", "pharmacy")
  final String? phone;
  final String? website;
  final String? openingHours; // OSM ham formatı
  final String? wheelchair; // "yes", "limited", "no", null
  final String? wheelchairDescription;
  final String? address;
  final String? cuisine;
  final bool? toiletsWheelchair;
  final bool? tactilePaving;
  final Map<String, String> allTags;

  const OsmPoi({
    required this.osmId,
    required this.osmType,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.category,
    required this.amenityType,
    this.phone,
    this.website,
    this.openingHours,
    this.wheelchair,
    this.wheelchairDescription,
    this.address,
    this.cuisine,
    this.toiletsWheelchair,
    this.tactilePaving,
    this.allTags = const {},
  });

  /// Overpass API JSON yanıtındaki bir element'ten [OsmPoi] oluşturur.
  factory OsmPoi.fromOverpassElement(Map<String, dynamic> element) {
    final tags = <String, String>{};
    if (element['tags'] != null) {
      (element['tags'] as Map<String, dynamic>).forEach((k, v) {
        tags[k] = v.toString();
      });
    }

    // Koordinatları belirle — node için doğrudan, way/relation için center
    double lat;
    double lon;
    if (element['type'] == 'node') {
      lat = (element['lat'] as num).toDouble();
      lon = (element['lon'] as num).toDouble();
    } else if (element['center'] != null) {
      lat = (element['center']['lat'] as num).toDouble();
      lon = (element['center']['lon'] as num).toDouble();
    } else {
      lat = 0;
      lon = 0;
    }

    // Adres oluştur
    String? address;
    final street = tags['addr:street'];
    final houseNumber = tags['addr:housenumber'];
    final district = tags['addr:district'] ?? tags['addr:suburb'];
    final city = tags['addr:city'];
    final parts = <String>[];
    if (street != null) {
      parts.add(houseNumber != null ? '$street No:$houseNumber' : street);
    }
    if (district != null) parts.add(district);
    if (city != null) parts.add(city);
    if (parts.isNotEmpty) address = parts.join(', ');

    // amenity veya diğer tag'lerden tür belirle
    final amenity = tags['amenity'] ?? '';
    final shop = tags['shop'] ?? '';
    final tourism = tags['tourism'] ?? '';
    final leisure = tags['leisure'] ?? '';

    String rawType;
    if (amenity.isNotEmpty) {
      rawType = amenity;
    } else if (shop.isNotEmpty) {
      rawType = 'shop_$shop';
    } else if (tourism.isNotEmpty) {
      rawType = 'tourism_$tourism';
    } else if (leisure.isNotEmpty) {
      rawType = 'leisure_$leisure';
    } else {
      rawType = 'other';
    }

    return OsmPoi(
      osmId: element['id'] as int,
      osmType: element['type'] as String,
      latitude: lat,
      longitude: lon,
      name: tags['name'] ?? tags['name:tr'] ?? '',
      category: categoryToTurkish(rawType),
      amenityType: rawType,
      phone: tags['phone'] ?? tags['contact:phone'],
      website: tags['website'] ?? tags['contact:website'] ?? tags['url'],
      openingHours: tags['opening_hours'],
      wheelchair: tags['wheelchair'],
      wheelchairDescription:
          tags['wheelchair:description'] ?? tags['wheelchair:description:tr'],
      address: address,
      cuisine: _cuisineToTurkish(tags['cuisine']),
      toiletsWheelchair: tags['toilets:wheelchair'] == 'yes',
      tactilePaving: tags['tactile_paving'] == 'yes',
      allTags: tags,
    );
  }

  /// OSM amenity/shop/tourism türünü Türkçe kategori adına çevirir.
  static String categoryToTurkish(String rawType) {
    const map = {
      // amenity
      'cafe': 'Kafe',
      'restaurant': 'Restoran',
      'fast_food': 'Fast Food',
      'pharmacy': 'Eczane',
      'supermarket': 'Market',
      'hospital': 'Hastane',
      'clinic': 'Klinik',
      'bank': 'Banka',
      'atm': 'ATM',
      'library': 'Kütüphane',
      'school': 'Okul',
      'university': 'Üniversite',
      'fuel': 'Akaryakıt',
      'parking': 'Otopark',
      'place_of_worship': 'İbadet Yeri',
      'police': 'Polis',
      'post_office': 'Postane',
      'cinema': 'Sinema',
      'theatre': 'Tiyatro',
      'museum': 'Müze',
      'dentist': 'Diş Hekimi',
      'doctors': 'Doktor',
      'veterinary': 'Veteriner',
      'toilets': 'Tuvalet',
      'kindergarten': 'Kreş',
      // shop
      'shop_mall': 'AVM',
      'shop_convenience': 'Bakkal',
      'shop_bakery': 'Fırın',
      'shop_butcher': 'Kasap',
      'shop_clothes': 'Giyim',
      'shop_electronics': 'Elektronik',
      'shop_hairdresser': 'Kuaför',
      'shop_greengrocer': 'Manav',
      'shop_supermarket': 'Market',
      // tourism
      'tourism_hotel': 'Otel',
      'tourism_motel': 'Motel',
      'tourism_guest_house': 'Pansiyon',
      'tourism_hostel': 'Hostel',
      'tourism_museum': 'Müze',
      'tourism_attraction': 'Turistik Yer',
      'tourism_viewpoint': 'Manzara Noktası',
      // leisure
      'leisure_park': 'Park',
      'leisure_playground': 'Çocuk Parkı',
      'leisure_garden': 'Bahçe',
      'leisure_sports_centre': 'Spor Merkezi',
      'leisure_swimming_pool': 'Yüzme Havuzu',
      'leisure_fitness_centre': 'Spor Salonu',
    };
    return map[rawType] ?? 'Mekan';
  }

  /// Wheelchair durumunu Türkçe açıklamaya çevirir.
  String get wheelchairStatusText {
    switch (wheelchair) {
      case 'yes':
      case 'designated':
        return 'Tam Erişilebilir';
      case 'limited':
        return 'Kısmi Erişilebilir';
      case 'no':
        return 'Erişilebilir Değil';
      default:
        return 'Bilgi Yok';
    }
  }

  /// Çalışma saatlerini Türkçe okunabilir formata çevirir.
  ///
  /// Örnek: "Mo-Fr 08:00-18:00; Sa 09:00-14:00"
  ///      → "Pazartesi - Cuma: 08:00 - 18:00\nCumartesi: 09:00 - 14:00"
  String? get openingHoursTurkish {
    if (openingHours == null || openingHours!.isEmpty) return null;

    // 24/7 özel durumu
    if (openingHours!.trim().toLowerCase() == '24/7') {
      return '7/24 Açık';
    }

    try {
      final blocks = openingHours!.split(';').map((b) => b.trim()).toList();
      final lines = <String>[];

      for (final block in blocks) {
        if (block.isEmpty) continue;
        lines.add(_translateBlock(block));
      }
      return lines.join('\n');
    } catch (_) {
      // Parse edilemezse ham veriyi döndür
      return openingHours;
    }
  }

  static String _translateBlock(String block) {
    // "Mo-Fr 08:00-18:00" veya "Sa 09:00-14:00" formatı
    // Kısa gün isimlerini Türkçeye çevir
    var result = block;
    const dayMap = {
      'Mo': 'Pzt',
      'Tu': 'Sal',
      'We': 'Çar',
      'Th': 'Per',
      'Fr': 'Cum',
      'Sa': 'Cmt',
      'Su': 'Paz',
      'PH': 'Tatil',
    };

    const dayMapFull = {
      'Mo': 'Pazartesi',
      'Tu': 'Salı',
      'We': 'Çarşamba',
      'Th': 'Perşembe',
      'Fr': 'Cuma',
      'Sa': 'Cumartesi',
      'Su': 'Pazar',
    };

    // Tek gün ise tam adını kullan, aralık ise kısa kullan
    // Önce aralıkları çevir (ör. Mo-Fr)
    final rangeRegex = RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su)-(Mo|Tu|We|Th|Fr|Sa|Su)\b');
    result = result.replaceAllMapped(rangeRegex, (m) {
      final from = dayMapFull[m.group(1)] ?? m.group(1)!;
      final to = dayMapFull[m.group(2)] ?? m.group(2)!;
      return '$from - $to';
    });

    // Sonra tekli günleri çevir
    final singleDayRegex = RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su|PH)\b');
    result = result.replaceAllMapped(singleDayRegex, (m) {
      return dayMapFull[m.group(1)] ?? dayMap[m.group(1)] ?? m.group(1)!;
    });

    // "off" → "Kapalı"
    result = result.replaceAll(RegExp(r'\boff\b', caseSensitive: false), 'Kapalı');

    // Boşlukla ayrılan saat kısmının önüne ": " ekle
    // "Pazartesi - Cuma 08:00-18:00" → "Pazartesi - Cuma: 08:00 - 18:00"
    result = result.replaceAllMapped(
      RegExp(r'([a-zA-ZçğıöşüÇĞİÖŞÜ\s-]+)\s+(\d{1,2}:\d{2})'),
      (m) => '${m.group(1)!.trim()}: ${m.group(2)}',
    );

    // Saat aralığındaki tire etrafına boşluk
    result = result.replaceAllMapped(
      RegExp(r'(\d{2}:\d{2})-(\d{2}:\d{2})'),
      (m) => '${m.group(1)} - ${m.group(2)}',
    );

    // Virgülle ayrılan günleri işle (ör. Mo,We,Fr → Pazartesi, Çarşamba, Cuma)
    result = result.replaceAll(',', ', ');

    return result;
  }

  /// Mutfak türünü Türkçeye çevirir.
  static String? _cuisineToTurkish(String? cuisine) {
    if (cuisine == null) return null;
    const map = {
      'turkish': 'Türk Mutfağı',
      'kebab': 'Kebap',
      'pizza': 'Pizza',
      'burger': 'Hamburger',
      'coffee_shop': 'Kahveci',
      'tea': 'Çay',
      'ice_cream': 'Dondurma',
      'seafood': 'Deniz Ürünleri',
      'italian': 'İtalyan Mutfağı',
      'chinese': 'Çin Mutfağı',
      'japanese': 'Japon Mutfağı',
      'international': 'Dünya Mutfağı',
      'regional': 'Yöresel',
      'chicken': 'Tavuk',
      'fish': 'Balık',
      'sandwich': 'Sandviç',
      'pastry': 'Pastane',
      'breakfast': 'Kahvaltı',
    };
    // Birden fazla cuisine varsa (";"-ile ayrılmış)
    final items = cuisine.split(';').map((c) => c.trim()).toList();
    final translated = items.map((c) => map[c.toLowerCase()] ?? c).toList();
    return translated.join(', ');
  }

  /// Benzersiz anahtar — haritadaki marker cache için.
  String get uniqueKey => '${osmType}_$osmId';

  /// POI'nin Foursquare kaynaklı olup olmadığı (canlı API v3 veya OS Places).
  /// Atıf seçimi tek yerden: [SheetAttributionLine] / [MapAttributionBadge].
  bool get isFoursquare => osmType == 'foursquare' || osmType == 'fsq_os';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsmPoi &&
          runtimeType == other.runtimeType &&
          osmId == other.osmId &&
          osmType == other.osmType;

  @override
  int get hashCode => osmId.hashCode ^ osmType.hashCode;
}
