import 'dart:async'; // Radar (Stream) için gerekli
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/custom_home_widgets.dart';
import '../../constants/app_colors.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  StreamSubscription<QuerySnapshot>? _cagriRadari;

  @override
  void initState() {
    super.initState();
    _radariCalistir();
  }

  // 📡 RADAR SİSTEMİ
  // Firestore'daki aktif çağrının durumunu izler. Eğer çağrı iptal edildiyse veya
  // başka biri tarafından cevaplandıysa çalmakta olan CallKit arama ekranını kapatır.
  void _radariCalistir() {
    _cagriRadari = FirebaseFirestore.instance
        .collection('cagrilar')
        .where('cagri_durumu', isEqualTo: 'bekliyor')
        .snapshots() // Bu komut veritabanını canlı olarak dinler
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isEmpty) {
        // Bekleyen çağrı kalmadıysa CallKit ekranını ve sesini otomatik olarak kapat
        FlutterCallkitIncoming.endAllCalls();
      }
    });
  }

  @override
  void dispose() {
    _cagriRadari?.cancel(); // Sayfa kapanırsa radarı durdur (Batarya tasarrufu)
    super.dispose();
  }

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
                        const CustomSearchBar(hintText: 'Nereye gitmek istersiniz?'),
                        const SizedBox(height: 24),

                        // Rotalar Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Toplu Taşıma ve Rotalar",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTransportIcon(icon: Icons.directions_bus, label: "Belediye\nHatları", primaryColor: AppColors.primary),
                                CustomTransportIcon(icon: Icons.airport_shuttle, label: "Özel Halk\nOtobüsü", primaryColor: AppColors.primary),
                                CustomTransportIcon(icon: Icons.airport_shuttle, label: "Minibüs", primaryColor: AppColors.primary),
                                CustomTransportIcon(icon: Icons.pedal_bike, label: "Bisiklet /\nYürüyüş", primaryColor: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Senin Etkin Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Senin Etkin"),
                            const SizedBox(height: 12),
                            _buildVolunteerStats(),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Şehirden Canlı Bildirimler Bölümü
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

  // Sadece bu sayfaya ÖZEL olan Motivasyon Kartı burada kalır
  Widget _buildVolunteerStats() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // Bu ayın başlangıç tarihi
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cagrilar')
          .where('volunteer_uid', isEqualTo: currentUser.uid)
          .where('zaman', isGreaterThanOrEqualTo: startOfMonth)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism, color: AppColors.tertiary, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bu ay $count kişiye rehberlik ettin.",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0 ? "Rehberlik etmeye başla!" : "Harikasın!",
                      style: const TextStyle(
                        color: AppColors.tertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5));
  }

}
