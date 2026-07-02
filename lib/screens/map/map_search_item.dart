import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Harita arama overlay'indeki sonuç / son arama satırı. Saf sunum widget'ı:
/// `onTap` dışarıdan verilir (map_screen konum taşıma + son arama kaydını yapar).
/// map_screen.dart monolitinden çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md
/// "Birleşik arama", widget testi test/widget/map_search_item_test.dart).
class MapSearchItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isRecent;
  final VoidCallback? onTap;

  const MapSearchItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isRecent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.outline, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.surface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.outline, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: isRecent
          ? const Icon(Icons.history, color: AppColors.chipBorder, size: 20)
          : const Icon(Icons.north_west, color: AppColors.chipBorder, size: 20),
      onTap: onTap,
    );
  }
}
