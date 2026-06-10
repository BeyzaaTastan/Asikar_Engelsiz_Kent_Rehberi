import 'package:flutter/material.dart';
import '../../widgets/custom_home_widgets.dart';
import '../../constants/app_colors.dart';

class StandardHomeScreen extends StatefulWidget {
  const StandardHomeScreen({super.key});

  @override
  State<StandardHomeScreen> createState() => _StandardHomeScreenState();
}

class _StandardHomeScreenState extends State<StandardHomeScreen> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 24.0, left: 24.0, right: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Arama Çubuğu
                        const CustomSearchBar(hintText: "Sakarya'da nereyi keşfetmek istersin?"),
                        const SizedBox(height: 24),

                        // Toplu Taşıma İkonları
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTransportIcon(icon: Icons.directions_bus, label: "Belediye\nHatları", primaryColor: AppColors.primary),
                            CustomTransportIcon(icon: Icons.bus_alert, label: "Özel Halk\nOtobüsü", primaryColor: AppColors.primary),
                            CustomTransportIcon(icon: Icons.airport_shuttle, label: "Minibüs", primaryColor: AppColors.primary),
                            CustomTransportIcon(icon: Icons.pedal_bike, label: "Bisiklet /\nYürüyüş", primaryColor: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Favori Rotalarım Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Favori Rotalarım"),
                            const SizedBox(height: 12),
                            _buildFavoriteRouteCard(icon: Icons.home, title: "Ev", subtitle: "12 km • Yaklaşık 25 dk"),
                            const SizedBox(height: 10),
                            _buildFavoriteRouteCard(icon: Icons.work, title: "İş", subtitle: "8 km • Yaklaşık 15 dk"),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Canlı Bildirimler Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Şehirden Canlı Bildirimler"),
                            const SizedBox(height: 12),
                            CustomNotificationCard(
                              icon: Icons.warning_rounded, iconColor: Colors.orange.shade600, iconBgColor: Colors.orange.shade50,
                              title: "Kent Park asansörü bakıma alındı", time: "Şimdi • Bakım Çalışması", borderColor: Colors.orange.shade500, primaryColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            CustomNotificationCard(
                              icon: Icons.construction, iconColor: Colors.blue.shade600, iconBgColor: Colors.blue.shade50,
                              title: "Çark Caddesi yol çalışması", time: "2 saat önce • Ulaşım Duyurusu", borderColor: Colors.blue.shade500, primaryColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Sadece bu sayfaya ÖZEL olan Favori Rota Kartı burada kalır
  Widget _buildFavoriteRouteCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 28),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5));
  }

}
