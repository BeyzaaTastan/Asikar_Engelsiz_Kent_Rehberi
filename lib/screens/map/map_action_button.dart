import 'package:flutter/material.dart';

/// Harita sheet'lerinde kullanılan dikey aksiyon butonu (Yol Tarifi / Ara / Web /
/// Kaydet / Paylaş). İkon + etiketten oluşur. Hem DB mekanı (venue) hem OSM POI
/// sheet'lerinde paylaşılır — eski `_buildActionButton` metodundan çıkarıldı.
class MapActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const MapActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
