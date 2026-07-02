import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';

class InterestsScreen extends StatefulWidget {
  final String userType;

  const InterestsScreen({super.key, required this.userType});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  // Çoklu seçim için Set kullanıyoruz
  final Set<String> _selectedInterests = {};

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri Dön',
        ),
        title: Text(
          'Aşikar',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // İlerleme Çubuğu (Adım 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adım 2',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: "İlerleme durumu: Yüzde 40",
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.4,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ana İçerik
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'İlgi Alanların Neler?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Size en uygun rotaları oluşturabilmemiz için tercihlerinizi belirleyin.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Görselli Çoklu Seçim Kartları
                  _buildImageCard(
                    title: 'Doğa ve Parklar',
                    icon: Icons.park,
                    imagePath: 'assets/images/doga_ve_parklar.png',
                  ),
                  _buildImageCard(
                    title: 'Şehir Merkezi ve Sosyal Alanlar',
                    icon: Icons.storefront,
                    imagePath: 'assets/images/sehir_merkezi_ve_sosyal_alanlar.png',
                  ),
                  _buildImageCard(
                    title: 'Tarihi Yerler',
                    icon: Icons.account_balance,
                    imagePath: 'assets/images/tarihi_yerler.png',
                  ),
                  const SizedBox(height: 80), // Footer için boşluk
                ],
              ),
            ),
          ),
        ],
      ),

      // Footer: Sabit Devam Et Butonu
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.9), // Linter uyarısı gidermek için güncellendi
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade400,
            ),
            onPressed: _selectedInterests.isEmpty
                ? null
                : () {
                    if (widget.userType == 'Özel Gereksinimli') {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.accessibilityPrefs,
                        arguments: {
                          'userType': widget.userType,
                          'selectedInterests': _selectedInterests,
                        },
                      );
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.volunteerStatus,
                        arguments: {
                          'userType': widget.userType,
                          'selectedInterests': _selectedInterests,
                        },
                      );
                    }
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Devam Et',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // HTML tasarımına sadık, arka plan resimli ve geçişli (gradient) kart
  Widget _buildImageCard({
    required String title,
    required IconData icon,
    required String imagePath,
  }) {
    bool isSelected = _selectedInterests.contains(title);

    return Semantics(
      button: true,
      selected: isSelected,
      label: "$title. Durum: ${isSelected ? 'Seçildi' : 'Seçilmedi'}. Değiştirmek için çift dokunun.",
      child: GestureDetector(
        onTap: () => _toggleInterest(title),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 130, // HTML'deki h-32 karşılığı
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.tertiary : Colors.transparent,
              width: 3, // Seçildiğinde yeşil çerçeve
            ),
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            // Alttan yukarıya doğru siyahlaştıran gradient (Yazı okunsun diye)
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9), // border'ın içinden taşmaması için 12'den küçük
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8), // Linter uyarısı gidermek için güncellendi
                  Colors.black.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.7],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(icon, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2.0,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Ortadaki boşluğu engellemek için Row ile check ikonu arası mesafe
                const SizedBox(width: 8),
                // Seçilme İkonu (Yeşil Check)
                if (isSelected)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: AppColors.tertiary, size: 28),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
