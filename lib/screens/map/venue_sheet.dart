import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../models/venue_model.dart';
import '../route_screen.dart';
import 'map_action_button.dart';
import 'map_visuals.dart';

/// Harita üzerinde seçilen kullanıcı katkılı `venues` mekanı için Google Maps tarzı
/// alt detay paneli. `map_screen.dart`'taki `_buildVenueSheet` + `_buildCommentTile`
/// kümesinden çıkarıldı.
///
/// Durumsuzdur: kapatma işlemi [onClose] ile dışarıya devredilir (panelin görünürlük
/// durumu hâlâ `MapScreen` state'inde yönetilir). Davranış birebir korunmuştur.
class VenueSheet extends StatelessWidget {
  /// DraggableScrollableSheet'in verdiği scroll controller.
  final ScrollController scrollController;

  /// Gösterilecek mekan.
  final VenueModel venue;

  /// Kapat (×) butonuna basıldığında çağrılır — MapScreen seçili mekanı temizler.
  final VoidCallback onClose;

  const VenueSheet({
    super.key,
    required this.scrollController,
    required this.venue,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = MapVisuals.accessibilityLevelColor(venue.accessibilityLevel);
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
                      child: Text(venue.name,
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

                // Kategori + Rating
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(venue.category,
                          style: TextStyle(
                              color: levelColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.star_rounded, color: Colors.amber.shade500, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      venue.averageRating > 0
                          ? venue.averageRating.toStringAsFixed(1)
                          : 'Yeni',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (venue.comments.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('(${venue.comments.length} yorum)',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Adres
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(venue.address,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                          maxLines: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Aksiyon butonları (Google Maps gibi)
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
                            destinationName: venue.name,
                            destinationLocation:
                                LatLng(venue.latitude, venue.longitude),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    MapActionButton(
                      icon: Icons.bookmark_border_rounded,
                      label: 'Kaydet',
                      color: Colors.grey.shade700,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kaydedildi!')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    MapActionButton(
                      icon: Icons.share_outlined,
                      label: 'Paylaş',
                      color: Colors.grey.shade700,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Erişilebilirlik skoru göstergesi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: levelColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.accessibility_new,
                          color: levelColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venue.accessibilityLevel,
                                style: TextStyle(
                                    color: levelColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('Erişilebilirlik Skoru: %${venue.accessibilityScore}',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48, height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: venue.accessibilityScore / 100,
                              color: levelColor,
                              backgroundColor:
                                  levelColor.withValues(alpha: 0.15),
                              strokeWidth: 5,
                            ),
                            Text('${venue.accessibilityScore}',
                                style: TextStyle(
                                    color: levelColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Özellikler
                if (venue.features.isNotEmpty) ...[
                  const Text('Erişilebilirlik Özellikleri',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: venue.features.map((f) {
                      return Chip(
                        label: Text(f,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        avatar: const Icon(Icons.check_circle,
                            size: 14, color: AppColors.tertiary),
                        backgroundColor: AppColors.lightSurface,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Açıklama
                if (venue.description.isNotEmpty) ...[
                  const Text('Hakkında',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Text(venue.description,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: 16),
                ],

                // Yorumlar
                if (venue.comments.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text('Yorumlar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary)),
                      const Spacer(),
                      Text('${venue.comments.length} yorum',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...venue.comments.take(3).map((c) => _commentTile(c)),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Yorum kutucuğu ──────────────────────────────────────────────────────
  Widget _commentTile(CommentModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < c.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.content,
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.4)),
        ],
      ),
    );
  }
}
