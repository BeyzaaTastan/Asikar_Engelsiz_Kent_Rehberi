import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../router/app_router.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

/// Özel gereksinimli kullanıcıların erişilebilirlik tercihlerini seçtiği ekran.
class AccessibilityPrefsScreen extends StatefulWidget {
  // Önceki ekranlardan gelen kullanıcı verileri
  final String userType;
  final Set<String> selectedInterests;

  const AccessibilityPrefsScreen({
    super.key,
    required this.userType,
    required this.selectedInterests,
  });

  @override
  State<AccessibilityPrefsScreen> createState() => _AccessibilityPrefsScreenState();
}

class _AccessibilityPrefsScreenState extends State<AccessibilityPrefsScreen> {
  // Kullanıcının birden fazla ihtiyacı olabileceği için Set kullanıyoruz (Kapsayıcı Tasarım)
  final Set<String> _selectedPrefs = {};
  bool _isLoading = false;

  // Uygulamanın genel renk paleti
  /// Verilen bir tercihin seçim durumunu tersine çevirir (varsa çıkarır, yoksa ekler).
  void _togglePref(String pref) {
    setState(() {
      if (_selectedPrefs.contains(pref)) {
        _selectedPrefs.remove(pref);
      } else {
        _selectedPrefs.add(pref);
      }
    });
  }

  /// Tüm seçimleri Firebase'e kaydeder ve Home Screen'e yönlendirir.
  Future<void> _saveToFirebaseAndGoHome() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Firebase'e kaydediliyor...");

      final newUser = UserModel(
        uid: FirebaseAuth.instance.currentUser?.uid ?? "gecici_kullanici_id_123", // Geçerli kullanıcının ID'sini al
        userType: widget.userType,
        touristInterests: widget.selectedInterests.toList(),
        isVolunteer: false, // Özel Gereksinimli
        accessibilityPrefs: _selectedPrefs.toList(),
      );

      // Veritabanına yazıyoruz
      await DatabaseService().saveUserSurvey(newUser);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.registrationComplete,
          (route) => false,
          arguments: {'isVolunteer': false},
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
      // AppBar tasarımı (Geri ok ve sayfa başlığı içeriyor)
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
          // İlerleme Çubuğu (Adım 3 - %75)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adım 3',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                // Ekran okuyucu cihazlar için anlamsal (semantics) açıklamalar ekliyoruz
                Semantics(
                  label: "İlerleme durumu: Yüzde 75",
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.75,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ana İçerik bölümü (Listelenebilir/kaydırılabilir yapı)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                children: [
                  // Sayfa Ana Başlığı
                  Semantics(
                    header: true,
                    child: Text(
                      'Erişilebilirlik Tercihlerin Nelerdir?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sayfa Açıklama Metni
                  Text(
                    'Size en uygun rotayı ve deneyimi sunabilmemiz için ihtiyacınızı seçin.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Seçenek Kartları (Tasarımına birebir uygun)
                  _buildPrefCard(
                    title: 'Görme Desteği',
                    subtitle: 'Yüksek kontrast ve sesli geribildirim odaklı',
                    icon: Icons.visibility,
                    iconColor: AppColors.secondary,
                  ),
                  _buildPrefCard(
                    title: 'İşitme/Konuşma Desteği',
                    subtitle: 'Görsel ipuçları ve metin odaklı bildirimler',
                    icon: Icons.hearing,
                    iconColor: AppColors.tertiary,
                  ),
                  _buildPrefCard(
                    title: 'Hareket Desteği',
                    subtitle: 'Rampa ve asansör içeren uygun rotalar',
                    icon: Icons.accessible,
                    iconColor: AppColors.secondary, 
                  ),
                  const SizedBox(height: 80), // Footer için boşluk, son kartın altta kalmasını önler
                ],
              ),
            ),
          ),
        ],
      ),

      // Alt Kısım: Sabit Buton ve Bilgi Metni
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.95), // Geleceğe uyumlu renk ayarlaması
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Sadece içerik alanını kapla
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              // Eğer seçim yapılmadıysa `onPressed` null atanır ve buton otomatik inaktif (gri) görünür
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.25),
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                onPressed: _isLoading || _selectedPrefs.isEmpty ? null : _saveToFirebaseAndGoHome,
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Devam Et',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Onboarding sürecinin sadece başlangıç olmadığı ve ayarların değişebileceği vurgusu
            Text(
              'Tercihlerinizi istediğiniz zaman ayarlardan değiştirebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Özel Tasarımlı Seçenek Kartı Oluşturan Yardımcı Method
  /// İkonlara özel renk ve metinler girilerek esnek bir kullanım sunar
  Widget _buildPrefCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    // Kartın seçili olup olmadığını küme(Set) içinden buluruz
    bool isSelected = _selectedPrefs.contains(title);

    return Semantics(
      button: true, // Ekran okuyucu bunu bir buton olarak algılayacak
      selected: isSelected, // Seçim durumunu belirtecek
      label: "$title. $subtitle. Durum: ${isSelected ? 'Seçildi' : 'Seçilmedi'}. Değiştirmek için çift dokunun.",
      child: GestureDetector(
        onTap: () => _togglePref(title), // Tıklama işlemi (aç/kapa)
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? iconColor.withValues(alpha: 0.5) : iconColor.withValues(alpha: 0.1),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Sol İkon Kutusu
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              // Orta Metinler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.3, // Satır yüksekliği ideal okuma oranı
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Sağ Seçim Çemberi (Radio Button Görünümü, fakat çoklu seçime imkan tanıyan opsiyon listesi)
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
