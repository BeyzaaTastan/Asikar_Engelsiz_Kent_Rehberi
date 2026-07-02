import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../router/app_router.dart'; // Bir sonraki "İlgi Alanları" ekranımız

class UserTypeScreen extends StatefulWidget {
  const UserTypeScreen({super.key});

  @override
  State<UserTypeScreen> createState() => _UserTypeScreenState();
}

class _UserTypeScreenState extends State<UserTypeScreen> {
  // Kullanıcının hangi seçeneği seçtiğini hafızada tutuyoruz
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () async {
            // Yarıda bırakırsa veya yanlışlıkla girdiyse oturumu kapatıp Login'e dönsün
            await FirebaseAuth.instance.signOut();
          },
          tooltip: 'Çıkış Yap', // Ekran okuyucu için
        ),
        title: Text(
          'Aşikar',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // İlerleme Çubuğu (Progress Bar)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adım 1',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: "İlerleme durumu: Yüzde 20",
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.2, // İlk adım olduğu için %20 dolu
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Seni Nasıl Tanımlayalım?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seçenekler
                  _buildOptionCard(
                    title: 'Turist',
                    subtitle: "Sakarya'yı keşfetmek istiyorum",
                    icon: Icons.explore,
                    iconColor: AppColors.secondary,
                    typeValue: 'Turist',
                    imagePath: 'assets/images/turist.png',
                  ),
                  _buildOptionCard(
                    title: 'Şehir Sakini',
                    subtitle: 'Burada yaşıyorum',
                    icon: Icons
                        .home, // Eski sürümlerde hata vermemesi için home kullanıldı
                    iconColor: AppColors.secondary,
                    typeValue: 'Sakin',
                    imagePath: 'assets/images/sehir_sakini.png',
                  ),
                  _buildOptionCard(
                    title: 'Özel Gereksinimli',
                    subtitle: 'Engelsiz erişim önceliğim',
                    icon: Icons.accessible_forward,
                    iconColor: AppColors.tertiary,
                    typeValue: 'Özel Gereksinimli',
                    imagePath: 'assets/images/ozel_gereksinimli.png',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Footer: Sabit Devam Et Butonu
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Eğer seçim yapılmadıysa butonu hafif soluk yapıyoruz
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  // GÜNCELLENEN KISIM: Yönlendirme mantığı
                  onPressed: _selectedType == null
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.interests,
                            arguments: {'userType': _selectedType!},
                          );
                        },
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Devam ederek hizmet kullanım şartlarımızı kabul etmiş olursunuz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Özel Kart Tasarımımız (Temiz kod için ayırdık)
  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String typeValue,
    required String imagePath,
  }) {
    bool isSelected = _selectedType == typeValue;

    return Semantics(
      button: true,
      selected: isSelected,
      label: "$title. $subtitle. Seçmek için çift dokunun.",
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType =
                typeValue; // Seçimi günceller ve ekranı yeniden çizer
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Sol Kısım: İkon, Metinler ve Seç Butonu
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: iconColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Ufak "Seç" Butonu
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSelected ? 'Seçildi' : 'Seç',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sağ Kısım: Görsel
              Expanded(
                flex: 1,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      // Eğer görsel assets klasöründe yoksa uygulamanın çökmemesi için yedek ikon:
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
