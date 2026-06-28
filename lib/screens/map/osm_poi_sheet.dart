import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/osm_poi_model.dart';
import '../route_screen.dart';
import 'map_action_button.dart';
import 'map_visuals.dart';

/// Harita üzerinde seçilen harici POI (Overpass/Foursquare) için Google Maps tarzı
/// alt detay paneli. `map_screen.dart`'taki `_buildOsmPoiSheet` + `_buildInfoSection`
/// + `_buildInfoRow` + `_buildAccessibilitySection` kümesinden çıkarıldı.
///
/// Durumsuzdur: kapatma işlemi [onClose] ile dışarıya devredilir (panelin görünürlük
/// durumu hâlâ `MapScreen` state'inde yönetilir). Davranış birebir korunmuştur.
class OsmPoiSheet extends StatelessWidget {
  /// DraggableScrollableSheet'in verdiği scroll controller.
  final ScrollController scrollController;

  /// Gösterilecek POI.
  final OsmPoi poi;

  /// Kapat (×) butonuna basıldığında çağrılır — MapScreen seçili POI'yi temizler.
  final VoidCallback onClose;

  const OsmPoiSheet({
    super.key,
    required this.scrollController,
    required this.poi,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = MapVisuals.poiColor(poi.amenityType);
    final wheelchairColor = MapVisuals.wheelchairColor(poi.wheelchair);
    final wheelchairIcon = MapVisuals.wheelchairIcon(poi.wheelchair);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Sürükleme kolu
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: isim + kapat butonu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(poi.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onClose,
                    )
                  ],
                ),

                // Kategori badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MapVisuals.poiIcon(poi.amenityType),
                              size: 14, color: categoryColor),
                          const SizedBox(width: 4),
                          Text(poi.category,
                              style: TextStyle(
                                  color: categoryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (poi.cuisine != null) ...[
                      const SizedBox(width: 8),
                      Text('• ${poi.cuisine!}',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Erişilebilirlik durumu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: wheelchairColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: wheelchairColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.accessible, color: wheelchairColor, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(poi.wheelchairStatusText,
                                style: TextStyle(
                                    color: wheelchairColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            if (poi.wheelchairDescription != null)
                              Text(poi.wheelchairDescription!,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(wheelchairIcon, color: wheelchairColor, size: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Aksiyon butonları
                Row(
                  children: [
                    MapActionButton(
                      icon: Icons.directions,
                      label: 'Yol Tarifi',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteScreen(
                            destinationName: poi.name,
                            destinationLocation:
                                LatLng(poi.latitude, poi.longitude),
                          ),
                        ),
                      ),
                    ),
                    if (poi.phone != null) ...[
                      const SizedBox(width: 12),
                      MapActionButton(
                        icon: Icons.phone,
                        label: 'Ara',
                        color: AppColors.tertiary,
                        onTap: () => launchUrl(Uri.parse('tel:${poi.phone}')),
                      ),
                    ],
                    if (poi.website != null) ...[
                      const SizedBox(width: 12),
                      MapActionButton(
                        icon: Icons.language,
                        label: 'Web Sitesi',
                        color: AppColors.secondary,
                        onTap: () => launchUrl(
                          Uri.parse(poi.website!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Detay bilgileri
                _infoSection(poi),

                // Erişilebilirlik özellikleri
                _accessibilitySection(poi),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── OSM POI: Bilgi satırları ──────────────────────────────────────────────
  Widget _infoSection(OsmPoi poi) {
    final items = <Widget>[];

    // Adres
    if (poi.address != null && poi.address!.isNotEmpty) {
      items.add(_infoRow(
        Icons.location_on_outlined,
        poi.address!,
      ));
    }

    // Çalışma saatleri
    final hours = poi.openingHoursTurkish;
    if (hours != null) {
      items.add(_infoRow(
        Icons.access_time,
        hours,
      ));
    }

    // Telefon
    if (poi.phone != null) {
      items.add(_infoRow(
        Icons.phone_outlined,
        poi.phone!,
        isTappable: true,
        onTap: () => launchUrl(Uri.parse('tel:${poi.phone}')),
      ));
    }

    // Website
    if (poi.website != null) {
      items.add(_infoRow(
        Icons.language,
        poi.website!,
        isTappable: true,
        onTap: () => launchUrl(
          Uri.parse(poi.website!),
          mode: LaunchMode.externalApplication,
        ),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bilgiler',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary)),
        const SizedBox(height: 8),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text,
      {bool isTappable = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isTappable ? AppColors.secondary : Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.4,
                  decoration: isTappable ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── OSM POI: Erişilebilirlik özellikleri ──────────────────────────────────
  Widget _accessibilitySection(OsmPoi poi) {
    final features = <Map<String, dynamic>>[];

    if (poi.wheelchair != null) {
      features.add({
        'icon': Icons.accessible,
        'label': 'Tekerlekli Sandalye',
        'status': poi.wheelchair == 'yes' || poi.wheelchair == 'designated'
            ? 'Evet'
            : poi.wheelchair == 'limited'
                ? 'Kısmi'
                : 'Hayır',
        'color': MapVisuals.wheelchairColor(poi.wheelchair),
      });
    }

    if (poi.toiletsWheelchair == true) {
      features.add({
        'icon': Icons.wc,
        'label': 'Engelli Tuvaleti',
        'status': 'Mevcut',
        'color': AppColors.tertiary,
      });
    }

    if (poi.tactilePaving == true) {
      features.add({
        'icon': Icons.texture,
        'label': 'Hissedilebilir Yüzey',
        'status': 'Mevcut',
        'color': AppColors.poiTactile,
      });
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Erişilebilirlik',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((f) {
            final color = f['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f['icon'] as IconData, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text('${f['label']}: ${f['status']}',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
