import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import 'map_action_button.dart';

/// Haritada bilinmeyen bir noktaya dokunulduğunda açılan detay sheet'i
/// (adres + koordinat + "Yol Tarifi"). Saf sunum widget'ı: adres/yükleniyor
/// durumu/nokta dışarıdan verilir; kapatma ve yol tarifi `onClose`/`onDirections`
/// callback'leri map_screen'de bağlanır (Navigator + setState orada kalır).
/// map_screen.dart monolitinden çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md,
/// widget testi test/widget/unknown_point_sheet_test.dart).
class UnknownPointSheet extends StatelessWidget {
  final ScrollController scrollController;
  final bool isLoadingAddress;
  final String address;
  final LatLng? point;
  final VoidCallback onClose;
  final VoidCallback? onDirections;

  const UnknownPointSheet({
    super.key,
    required this.scrollController,
    required this.isLoadingAddress,
    required this.address,
    required this.point,
    required this.onClose,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: isLoadingAddress
                    ? const Text('Adres yükleniyor...',
                        style: TextStyle(fontSize: 15, color: Colors.grey))
                    : Text(
                        address.isNotEmpty ? address : 'Seçilen Konum',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                        maxLines: 3,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          if (point != null) ...[
            const SizedBox(height: 4),
            Text(
              '${point!.latitude.toStringAsFixed(5)}, '
              '${point!.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              MapActionButton(
                icon: Icons.directions,
                label: 'Yol Tarifi',
                color: AppColors.primary,
                onTap: onDirections,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
