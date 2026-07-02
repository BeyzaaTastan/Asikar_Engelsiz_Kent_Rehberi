import 'package:flutter/material.dart';

/// Katman seçici modalindeki harita türü kartı (Varsayılan / Uydu / Arazi).
/// Saf sunum widget'ı: seçili durum (`selected`) + `onTap` dışarıdan verilir;
/// `_mapType` state'i ve `setModalState` map_screen'de tutulur. Renk parametre
/// olarak gelir (inline renk yok). map_screen.dart monolitinden çıkarıldı
/// (bkz. vault/01-Frontend/01-On-Yuz.md, widget testi
/// test/widget/map_type_card_test.dart).
class MapTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const MapTypeCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 76,
            decoration: BoxDecoration(
              color:
                  selected ? color.withValues(alpha: 0.18) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : Colors.grey.shade200,
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: Icon(icon,
                  color: selected ? color : Colors.grey.shade400, size: 34),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              )),
        ],
      ),
    );
  }
}
