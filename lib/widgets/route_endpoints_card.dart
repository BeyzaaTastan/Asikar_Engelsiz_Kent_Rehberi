import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Başlangıç/varış giriş kartı — **DirectionsSearchScreen ile RouteScreen'de
/// AYNI görünüm** için tek ortak sarmalayıcı (iki ekranın drift etmemesi bilinçli).
///
/// Tek beyaz kart: geri oku, iki satır (başlangıç turkuaz nokta / varış kırmızı
/// pin) noktalı bağlayıcıyla, sağda yuvarlak **swap** butonu ve opsiyonel ⋮ menü.
/// Erişilebilirlik için satırlar **ferah** (min 60px) ve büyük yazı — engelli
/// kullanıcı kolay bulsun/dokunsun; `Semantics` etiketli.
///
/// Satır **içeriği** dışarıdan verilir ([originContent]/[destContent]): giriş
/// ekranında düzenlenebilir `TextField`, rota ekranında görüntü `Text`. Böylece
/// görünüm ortak, davranış her ekranda kalır. (bkz. vault/01-Frontend/01-On-Yuz.md
/// · "Rota / yol tarifi".)
class RouteEndpointsCard extends StatelessWidget {
  final VoidCallback onBack;
  final Widget originContent;
  final Widget destContent;
  final VoidCallback onSwap;

  /// Opsiyonel ⋮ menü (RouteScreen'de rota seçenekleri). Giriş ekranında null.
  final Widget? trailingMenu;

  /// Satıra dokununca (RouteScreen'de konumu düzenlemek için). Null → dokunulamaz
  /// (giriş ekranında satır zaten TextField, dokunma odakla yönetilir).
  final VoidCallback? onOriginTap;
  final VoidCallback? onDestTap;

  const RouteEndpointsCard({
    super.key,
    required this.onBack,
    required this.originContent,
    required this.destContent,
    required this.onSwap,
    this.trailingMenu,
    this.onOriginTap,
    this.onDestTap,
  });

  static const double _rowMinHeight = 50;
  static const double _dotSlot = 26;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: 'Geri',
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  originContent,
                  onOriginTap,
                ),
                _connector(),
                _row(
                  const Icon(Icons.location_on,
                      color: AppColors.danger, size: 22),
                  destContent,
                  onDestTap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingMenu != null) trailingMenu!,
              Semantics(
                button: true,
                label: 'Başlangıç ve varışı değiştir',
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.chipBorder),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSwap,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.swap_vert,
                          color: AppColors.primary, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _row(Widget dot, Widget content, [VoidCallback? onTap]) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: _dotSlot, child: Center(child: dot)),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  Widget _connector() {
    return SizedBox(
      height: 12,
      child: Row(
        children: [
          SizedBox(
            width: _dotSlot,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.chipBorder,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
