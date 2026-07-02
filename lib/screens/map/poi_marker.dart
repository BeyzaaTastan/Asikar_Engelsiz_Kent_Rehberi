import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/osm_poi_model.dart';
import 'map_visuals.dart';

/// Harita POI'si için DURUMSUZ, isimli marker.
///
/// İsim etiketi (üstte) + kategori ikon dairesi (altta). Declutter
/// (map/poi_declutter.dart) yalnızca çakışmayan/öncelikli POI'leri bu marker'la
/// çizer; sığmayanlar [PoiDot] olur → etiketler haritayı örtmez. Detay marker'a
/// dokununca OsmPoiSheet'te açılır.
///
/// Erişilebilirlik: ekran okuyucu için buton rolü + `isim, kategori` etiketi.
class PoiMarker extends StatelessWidget {
  final OsmPoi poi;
  final bool isSelected;

  const PoiMarker({super.key, required this.poi, this.isSelected = false});

  /// map_screen'deki [Marker] boyutuyla eşleşen sabitler.
  static const double width = 130;
  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final color = MapVisuals.poiColor(poi.amenityType);
    final icon = MapVisuals.poiIcon(poi.amenityType);
    final label = poi.name.isEmpty ? poi.category : poi.name;

    return Semantics(
      label: '$label, ${poi.category}',
      button: true,
      // İç metin/ikon ayrıca okunmasın (isim çift seslendirilmesin).
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İsim etiketi
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 11 : 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.surface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Kategori ikonu
          Container(
            width: isSelected ? 34 : 28,
            height: isSelected ? 34 : 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: isSelected ? 18 : 14),
          ),
        ],
      ),
    );
  }
}

/// İsmi çakışma nedeniyle gösterilemeyen POI için küçük renkli nokta önizlemesi
/// (Google Haritalar mantığı). Etiketsiz; yaklaşınca declutter onu [PoiMarker]'a
/// yükseltir. Dokununca yine detay açılır (map_screen GestureDetector'ı sarar).
class PoiDot extends StatelessWidget {
  final OsmPoi poi;
  const PoiDot({super.key, required this.poi});

  /// map_screen'deki [Marker] boyutuyla eşleşen dokunma alanı.
  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    final color = MapVisuals.poiColor(poi.amenityType);
    return Semantics(
      label: '${poi.name.isEmpty ? poi.category : poi.name}, ${poi.category}',
      button: true,
      excludeSemantics: true,
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3),
            ],
          ),
        ),
      ),
    );
  }
}
