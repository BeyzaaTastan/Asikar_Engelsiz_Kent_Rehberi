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

  /// Harita gövdesinin (alt navigasyon çubuğunun ÜSTÜNDEKİ) gerçek yüksekliği —
  /// map_screen'deki `LayoutBuilder`'dan gelir. Panel bu alan içinde, klavye
  /// kapalıyken alttaki boşluğa kadar uzayabilir. Null ise (test/fallback)
  /// `MediaQuery` kullanılır (bkz. [_SearchResultsContainer]).
  final double? availableHeight;

  const SmartResultsOverlay({
    super.key,
    required this.isSearchFieldEmpty,
    required this.isLoading,
    required this.items,
    required this.onItemTap,
    this.onClearHistory,
    this.availableHeight,
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
          // Hem "Son Aramalar" hem canlı "Arama Sonuçları" AYNI sarmalayıcıdan
          // geçer: yükseklik = içerik kadar, ekranın %40'ında tavanlanır ve
          // taşarsa kendi içinde kayar (bkz. _SearchResultsContainer).
          child: _SearchResultsContainer(
            availableHeight: availableHeight,
            header: _buildHeader(),
            body: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
          if (isSearchFieldEmpty && items.isNotEmpty && onClearHistory != null)
            Semantics(
              button: true,
              label: 'Arama geçmişini temizle',
              child: InkWell(
                onTap: onClearHistory,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Boş geçmiş: sabit yükseklikli bilgilendirme (ekranı kaplamasın).
    if (isSearchFieldEmpty && items.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Henüz arama geçmişi yok',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // shrinkWrap: liste yüksekliği öğe sayısı kadar; _SearchResultsContainer'ın
    // maxHeight tavanına ulaşırsa kendi içinde kayar (dıştaki harita kaymaz).
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 70, color: Colors.black12),
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
    );
  }
}

/// Arama overlay'inin yükseklik davranışını TEK yerde toplayan ortak
/// sarmalayıcı: hem "Son Aramalar" hem canlı "Arama Sonuçları" bununla sarılır,
/// böylece biri düzeltilip diğeri unutulmaz.
///
/// Davranış: `mainAxisSize.min` ile yükseklik = başlık + içerik kadar; az öğede
/// boş alanda uzamaz. Tavan (`maxHeight`) harita gövdesinin gerçek yüksekliğine
/// göre hesaplanır: [availableHeight] = alt navigasyon çubuğunun ÜSTÜNDEKİ alan
/// (map_screen `LayoutBuilder`'ından; Scaffold klavye açılınca burayı küçülttüğü
/// için klavye ZATEN dışlanır). Panel top'u ([topReserve]) ve küçük bir alt
/// boşluk düşülür → **klavye kapalıyken panel alttaki boşluğa (nav çubuğunun
/// hemen üstüne) kadar uzar**, klavye açılınca klavyenin üstünde kalır. Tavana
/// değen liste gövde İÇİNDE kayar (dıştaki harita kaymaz). [availableHeight] yok
/// ise (test/fallback) `MediaQuery` (ekran − klavye) kullanılır.
class _SearchResultsContainer extends StatelessWidget {
  final Widget header;
  final Widget body;

  /// Harita gövde yüksekliği (nav çubuğunun üstü, klavye dışlanmış). Bkz.
  /// [SmartResultsOverlay.availableHeight].
  final double? availableHeight;

  const _SearchResultsContainer({
    required this.header,
    required this.body,
    this.availableHeight,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Panel arama çubuğunun altında (~padding.top + 96) başlar.
    final topReserve = mq.padding.top + 96;
    // Kullanılabilir gövde yüksekliği: LayoutBuilder değeri (klavyeyi zaten
    // dışlar) yoksa MediaQuery (ekran − klavye).
    final bodyHeight = availableHeight ?? (mq.size.height - mq.viewInsets.bottom);
    // Panel top'undan gövdenin altına kadar − 12px alt boşluk. Klavye kapalıyken
    // bodyHeight büyüktür → panel alttaki boşluğa kadar uzar; açıkken küçüktür →
    // klavyenin üstünde kalır. Çok öğede tavana değip kendi içinde kayar.
    final minHeight = bodyHeight < 200.0 ? bodyHeight : 200.0;
    final maxHeight =
        (bodyHeight - topReserve - 12).clamp(minHeight, bodyHeight);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          // Flexible: gövde kalan alanı öğe sayısı kadar kaplar, tavana
          // ulaşınca sınırlanır (shrinkWrap'li ListView içeride kayar).
          Flexible(child: body),
        ],
      ),
    );
  }
}
