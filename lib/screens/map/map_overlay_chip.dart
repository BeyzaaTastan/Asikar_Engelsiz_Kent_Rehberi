import 'package:flutter/material.dart';

/// Katman seçici modalindeki harita ayrıntısı çipi (Toplu Taşıma, Bisiklet,
/// Yürüyüş Yolları, Hissedilebilir Yüzey, Tekerlekli Sandalye, Asansör).
/// Saf sunum widget'ı: aktif durum (`isActive`) + `onTap` dışarıdan verilir;
/// bayrak toggle + Overpass katman çekme (`_fetchOverpassLayer` vb.) ve
/// `setModalState` map_screen'de kalır. Renk parametre olarak gelir (inline renk
/// yok). map_screen.dart monolitinden çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md,
/// widget testi test/widget/map_overlay_chip_test.dart).
class MapOverlayChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const MapOverlayChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.18)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? color : Colors.grey.shade200,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Center(
                child: Icon(icon,
                    color: isActive ? color : Colors.grey.shade400, size: 28),
              ),
            ),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? color : Colors.grey.shade600,
                  height: 1.2,
                )),
          ],
        ),
      ),
    );
  }
}
