import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registration_complete_screen.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

/// Gönüllü olmak isteyen kullanıcıların destek olabilecekleri alanları (yetenekleri) seçtiği ekran.
class VolunteerSkillsScreen extends StatefulWidget {
  // Önceki ekranlardan toplanan veriler
  final String userType;
  final Set<String> selectedInterests;

  const VolunteerSkillsScreen({
    super.key,
    required this.userType,
    required this.selectedInterests,
  });

  @override
  State<VolunteerSkillsScreen> createState() => _VolunteerSkillsScreenState();
}

class _VolunteerSkillsScreenState extends State<VolunteerSkillsScreen> {
  // Çoklu seçim için Set kullanıyoruz
  final Set<String> _selectedSkills = {};
  bool _isLoading = false;

  /// Bir yeteneğin seçili olma durumunu değiştirir
  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  /// Tüm süreçleri bitirip final sayfasına yönlendirme işlemi
  Future<void> _finishOnboardingAndGoHome() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Firebase'e kaydediliyor...");

      // Şablonu dolduruyoruz
      final newUser = UserModel(
        uid: FirebaseAuth.instance.currentUser?.uid ?? "gecici_kullanici_id_123", // Geçerli kullanıcının ID'sini al
        userType: widget.userType,
        touristInterests: widget.selectedInterests.toList(),
        isVolunteer: true,
        volunteerSkills: _selectedSkills.toList(),
      );

      // Veritabanına yazıyoruz
      await DatabaseService().saveUserSurvey(newUser);

      // Başarılıysa yönlendir
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationCompleteScreen(isVolunteer: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kayıt sırasında bir hata oluştu: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
          // İlerleme Çubuğu (Adım 4 - %100)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Adım 4', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('4/4', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: "İlerleme durumu: Yüzde 100. Son adım.",
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0, // Tamamen dolu
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Hangi Alanlarda Destek Olabilirsin?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Birden fazla seçenek belirleyebilirsiniz.',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Çoklu Seçim Kartları
                      _buildSkillCard('İşaret Dili'),
                      _buildSkillCard('Yabancı Dil'),
                      _buildSkillCard('Fiziksel Refakat'),
                      _buildSkillCard('Yerel Bilgi'),
                    ],
                  ),
                ),

                // HTML Tasarımındaki Faint (Soluk) İkon
                Expanded(
                  child: Center(
                    child: Semantics(
                      hidden: true, // Ekran okuyucunun bu dekoratif ikonu atlaması için
                      child: Icon(
                        Icons.volunteer_activism,
                        size: 140,
                        color: AppColors.primary.withValues(alpha: 0.05), // withOpacity yerine güncel kullanım
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alt Kısım: Kaydı Tamamla Butonu
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.background,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3), // withOpacity -> withValues
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      onPressed: _isLoading || _selectedSkills.isEmpty ? null : _finishOnboardingAndGoHome,
                      child: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Kaydı Tamamla',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle, color: AppColors.tertiary), // Yeşil Tik
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kaydı tamamlayarak topluluk kurallarımızı ve veri politikamızı kabul etmiş olursunuz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Özel Tasarım Yetenek Seçim Kartı
  Widget _buildSkillCard(String title) {
    bool isSelected = _selectedSkills.contains(title);

    return Semantics(
      button: true,
      selected: isSelected,
      label: "$title. Durum: ${isSelected ? 'Seçildi' : 'Seçilmedi'}. Değiştirmek için çift dokunun.",
      child: GestureDetector(
        onTap: () => _toggleSkill(title),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent, // withOpacity -> withValues
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), // withOpacity -> withValues
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // HTML'deki input class="peer h-6 w-6 rounded-full" karşılığı
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : AppColors.primary.withValues(alpha: 0.2), // withOpacity -> withValues
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
