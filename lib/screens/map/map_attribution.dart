import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Üçüncü taraf veri kaynakları için ZORUNLU atıf metinleri — TEK KAYNAK.
///
/// - Foursquare Places API v3 lisansı: Foursquare verisinin göründüğü her ekranda
///   "Powered by Foursquare" markalı atıf zorunlu (Places API License Agreement).
/// - Foursquare OS Places (Apache 2.0): telif satırı geliştirici dokümanında korunur
///   (bkz. cloudflare/poi-worker/README.md); görünür "Powered by Foursquare" bunu da kapsar.
/// - OSM/Overpass (ODbL): "© OpenStreetMap katkıda bulunanlar" AYRI zorunlu.
/// - OpenMapTiles: varsayılan haritanın vektör taban karoları (OpenFreeMap
///   Liberty) OpenMapTiles şemasıyla üretilir → "© OpenMapTiles" atfı, OSM
///   atfının YANINDA (OpenStreetMap verisi + OpenMapTiles şeması) gösterilir.
///
/// Metin değişirse YALNIZCA burayı güncelle.
const String kFoursquareAttribution = 'Powered by Foursquare';
const String kOsmAttribution = '© OpenStreetMap katkıda bulunanlar';
const String kOpenMapTilesAttribution = '© OpenMapTiles';

/// Harita köşesinde kalıcı, okunur atıf rozeti. Marker/etiket kalabalığına
/// gömülmemesi için yarı saydam zeminli; ilgili kaynak ekranda göründükçe görünür.
class MapAttributionBadge extends StatelessWidget {
  /// Foursquare atfı gösterilsin mi (haritada FSQ kaynaklı POI varsa).
  final bool showFoursquare;

  /// OSM atfı gösterilsin mi (temel harita OSM karolarını kullandığı için normalde hep true).
  final bool showOsm;

  /// OpenMapTiles atfı gösterilsin mi (varsayılan vektör taban aktifken).
  final bool showOpenMapTiles;

  const MapAttributionBadge({
    super.key,
    this.showFoursquare = true,
    this.showOsm = true,
    this.showOpenMapTiles = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (showOsm) kOsmAttribution,
      if (showOpenMapTiles) kOpenMapTilesAttribution,
      if (showFoursquare) kFoursquareAttribution,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Veri kaynakları: ${parts.join(', ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          parts.join('  ·  '),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Detay panelinde POI kaynağına göre gösterilen atıf satırı.
class SheetAttributionLine extends StatelessWidget {
  /// true → "Powered by Foursquare", false → "© OpenStreetMap katkıda bulunanlar".
  final bool isFoursquare;

  const SheetAttributionLine({super.key, required this.isFoursquare});

  @override
  Widget build(BuildContext context) {
    final text = isFoursquare ? kFoursquareAttribution : kOsmAttribution;
    return Semantics(
      label: 'Veri kaynağı: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
