import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../models/osm_poi_model.dart';

/// Harita ekranının DURUMSUZ görsel eşleyicileri ve POI yardımcıları.
///
/// Bu metotlar yalnızca parametrelerine bağlıdır (state/`this` kullanmaz),
/// bu yüzden `map_screen.dart`'tan ayrılarak hem dosya boyutu küçültülür hem de
/// test edilebilir saf birimler elde edilir. Davranış birebir korunmuştur.
class MapVisuals {
  MapVisuals._();

  // ─── Erişilebilirlik seviyesi → Renk (DB mekanı marker'ı) ────────────────
  // Not: Eski `_getMarkerColor` ve `_getLevelColor` birebir aynıydı; burada
  // tek metotta birleştirildi.
  static Color accessibilityLevelColor(String level) {
    switch (level) {
      case 'Tam Erişilebilir':
        return AppColors.tertiary; // Yeşil
      case 'Kısmi Erişilebilir':
        return AppColors.secondary; // Turkuaz
      case 'Kısıtlı Erişilebilir':
        return AppColors.warning; // Turuncu
      case 'Destek Gerekli':
        return AppColors.danger; // Kırmızı
      default:
        return AppColors.outline;
    }
  }

  // ─── OSM POI: Kategori → İkon ──────────────────────────────────────────────
  static IconData poiIcon(String amenityType) {
    const map = {
      'cafe': Icons.coffee,
      'restaurant': Icons.restaurant,
      'fast_food': Icons.fastfood,
      'pharmacy': Icons.local_pharmacy,
      'supermarket': Icons.shopping_cart,
      'hospital': Icons.local_hospital,
      'clinic': Icons.medical_services,
      'bank': Icons.account_balance,
      'atm': Icons.atm,
      'library': Icons.local_library,
      'school': Icons.school,
      'university': Icons.account_balance,
      'fuel': Icons.local_gas_station,
      'parking': Icons.local_parking,
      'place_of_worship': Icons.mosque,
      'police': Icons.local_police,
      'post_office': Icons.local_post_office,
      'cinema': Icons.movie,
      'theatre': Icons.theater_comedy,
      'museum': Icons.museum,
      'dentist': Icons.medical_services,
      'doctors': Icons.medical_services,
      'veterinary': Icons.pets,
      // shop
      'shop_convenience': Icons.store,
      'shop_bakery': Icons.bakery_dining,
      'shop_butcher': Icons.restaurant,
      'shop_clothes': Icons.checkroom,
      'shop_electronics': Icons.devices,
      'shop_hairdresser': Icons.content_cut,
      'shop_greengrocer': Icons.eco,
      'shop_supermarket': Icons.shopping_cart,
      // tourism
      'tourism_hotel': Icons.hotel,
      'tourism_motel': Icons.hotel,
      'tourism_guest_house': Icons.house,
      'tourism_hostel': Icons.night_shelter,
      'tourism_museum': Icons.museum,
      'tourism_attraction': Icons.attractions,
      'tourism_viewpoint': Icons.panorama,
      // leisure
      'leisure_park': Icons.park,
      'leisure_playground': Icons.toys,
      'leisure_garden': Icons.yard,
      'leisure_sports_centre': Icons.sports,
      'leisure_swimming_pool': Icons.pool,
      'leisure_fitness_centre': Icons.fitness_center,
    };
    return map[amenityType] ?? Icons.place;
  }

  // ─── OSM POI: Kategori → Renk ──────────────────────────────────────────────
  static Color poiColor(String amenityType) {
    if (amenityType.contains('cafe') || amenityType.contains('coffee')) {
      return AppColors.poiCafe;
    } else if (amenityType.contains('restaurant') || amenityType.contains('fast_food')) {
      return AppColors.poiRestaurant;
    } else if (amenityType.contains('pharmacy')) {
      return AppColors.poiPharmacy;
    } else if (amenityType.contains('supermarket') || amenityType.contains('shop_')) {
      return AppColors.poiShop;
    } else if (amenityType.contains('hospital') || amenityType.contains('clinic') ||
        amenityType.contains('doctor') || amenityType.contains('dentist')) {
      return AppColors.poiHealth;
    } else if (amenityType.contains('bank') || amenityType.contains('atm')) {
      return AppColors.poiBank;
    } else if (amenityType.contains('worship')) {
      return AppColors.poiWorship;
    } else if (amenityType.contains('school') || amenityType.contains('university') || amenityType.contains('library')) {
      return AppColors.poiEducation;
    } else if (amenityType.contains('tourism_hotel') || amenityType.contains('tourism_motel') || amenityType.contains('tourism_guest')) {
      return AppColors.poiHotel;
    } else if (amenityType.contains('leisure_park') || amenityType.contains('leisure_garden')) {
      return AppColors.poiPark;
    } else if (amenityType.contains('fuel')) {
      return AppColors.poiFuel;
    } else if (amenityType.contains('museum') || amenityType.contains('theatre') || amenityType.contains('cinema')) {
      return AppColors.poiCulture;
    }
    return AppColors.poiDefault;
  }

  // ─── OSM POI: Wheelchair durumu → Renk ─────────────────────────────────────
  static Color wheelchairColor(String? wheelchair) {
    switch (wheelchair) {
      case 'yes':
      case 'designated':
        return AppColors.tertiary;
      case 'limited':
        return AppColors.warning;
      case 'no':
        return AppColors.danger;
      default:
        return AppColors.outline;
    }
  }

  // ─── OSM POI: Wheelchair durumu → İkon ─────────────────────────────────────
  static IconData wheelchairIcon(String? wheelchair) {
    switch (wheelchair) {
      case 'yes':
      case 'designated':
        return Icons.check_circle;
      case 'limited':
        return Icons.warning_amber_rounded;
      case 'no':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // ─── Arama sonucu tipi → İkon ──────────────────────────────────────────────
  static IconData searchResultTypeIcon(String type) {
    switch (type) {
      case 'recent':
        return Icons.history;
      case 'park':
        return Icons.park;
      case 'museum':
        return Icons.museum;
      case 'nominatim':
      case 'place':
        return Icons.location_on;
      case 'overpass':
        return Icons.storefront;
      default:
        return Icons.place;
    }
  }

  /// İki POI listesini birleştirir, 40m içindeki duplikasyonları atar.
  /// [priority] listesi önde tutulur, [secondary] eklenirken duplik kontrol yapılır.
  /// (Foursquare-öncelikli hibrit POI birleştirme — bkz. vault/07-Performance/10-Cache-CDN.md)
  static List<OsmPoi> mergePois(List<OsmPoi> priority, List<OsmPoi> secondary) {
    final result = List<OsmPoi>.from(priority);
    final addedCoords = priority
        .map((p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}')
        .toSet();

    for (final poi in secondary) {
      // 40m yakınlık kontrolü — aynı mekanın iki kaynaktan gelmesini engeller
      final coordKey = '${poi.latitude.toStringAsFixed(4)},${poi.longitude.toStringAsFixed(4)}';
      if (!addedCoords.contains(coordKey)) {
        // İsim benzerliği de kontrol et (farklı koordinat ama aynı isim)
        final isDuplicate = result.any((existing) {
          if (existing.name.toLowerCase() != poi.name.toLowerCase()) return false;
          final dist = const Distance().as(
            LengthUnit.Meter,
            LatLng(existing.latitude, existing.longitude),
            LatLng(poi.latitude, poi.longitude),
          );
          return dist < 40;
        });
        if (!isDuplicate) {
          addedCoords.add(coordKey);
          result.add(poi);
        }
      }
    }
    return result;
  }
}
