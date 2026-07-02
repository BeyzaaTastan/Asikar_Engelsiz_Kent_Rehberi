import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'map_visuals.dart';
import 'map_search_item.dart';

/// Arama kutusunun altında açılan "Son Aramalar / Arama Sonuçları" cam panel
/// overlay'i. Saf sunum widget'ı: liste verisi (`items`) + öğe dokunma callback'i
/// (`onItemTap`) dışarıdan verilir; map_screen konum taşıma/son arama kaydını yapar.
/// Arama boşken (son aramalar) ve liste doluyken opsiyonel [onClearHistory] ile
/// "Temizle" eylemi gösterilir.
/// map_screen.dart monolitinden çıkarıldı (bkz. vault/01-Frontend/01-On-Yuz.md,
/// widget testi test/widget/smart_results_overlay_test.dart).
class SmartResultsOverlay extends StatelessWidget {
  final bool isSearchFieldEmpty;
  final bool isLoading;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onItemTap;

  /// Son aramalar (arama boşken) listelenirken "Temizle" eylemi için. Null ise
  /// buton gösterilmez.
  final VoidCallback? onClearHistory;

  const SmartResultsOverlay({
    super.key,
    required this.isSearchFieldEmpty,
    required this.isLoading,
    required this.items,
    required this.onItemTap,
    this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text(
                      isSearchFieldEmpty ? "Son Aramalar" : "Arama Sonuçları",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          letterSpacing: 0.5),
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ],
                    const Spacer(),
                    // Son aramalar doluysa "Temizle" — gerçek geçmişi sıfırlar.
                    if (isSearchFieldEmpty &&
                        items.isNotEmpty &&
                        onClearHistory != null)
                      Semantics(
                        button: true,
                        label: 'Arama geçmişini temizle',
                        child: InkWell(
                          onTap: onClearHistory,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              'Temizle',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.7)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: isSearchFieldEmpty && items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Henüz arama geçmişi yok',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(
                            height: 1, indent: 70, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return MapSearchItem(
                            title: item['title'],
                            subtitle: item['subtitle'],
                            icon: MapVisuals.searchResultTypeIcon(item['type']),
                            isRecent: isSearchFieldEmpty,
                            onTap: () => onItemTap(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
