import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'volunteer_skills_screen.dart';
import 'registration_complete_screen.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class VolunteerStatusScreen extends StatefulWidget {
  final String userType;
  final Set<String> selectedInterests;

  const VolunteerStatusScreen({
    super.key,
    required this.userType,
    required this.selectedInterests,
  });

  @override
  State<VolunteerStatusScreen> createState() => _VolunteerStatusScreenState();
}

class _VolunteerStatusScreenState extends State<VolunteerStatusScreen> {
  bool _isLoading = false;

  Future<void> _submitAndGoHome() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Firebase'e kaydediliyor (Gönüllü Değil)...");

      final newUser = UserModel(
        uid: FirebaseAuth.instance.currentUser?.uid ?? "gecici_kullanici_id_123", // Geçerli kullanıcının ID'sini al
        userType: widget.userType,
        touristInterests: widget.selectedInterests.toList(),
        isVolunteer: false,
      );

      await DatabaseService().saveUserSurvey(newUser);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationCompleteScreen(isVolunteer: false),
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
          // İlerleme Çubuğu (Adım 3)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adım 3',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: "İlerleme durumu: Yüzde 60",
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.6, // Adım 3
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hero Görseli (HTML'deki kapak fotoğrafı alanı)
          Semantics(
            image: true,
            label:
                "Aşikar Engelsiz Kent Rehberi logosunun açık olduğu bir akıllı telefon.",
            child: Container(
              width: double.infinity,
              height: 250,
              margin: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/gonullu_olmak_ister_misin.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Ana İçerik ve Butonlar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Gönüllü Olmak İster misin?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Şehrini herkes için daha erişilebilir bir şehir haline getirmek için bize katılın. Küçük bir yardım, büyük bir fark yaratır. Engelsiz yaşam için siz de bir adım atın.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(), // Butonları en alta iter
                  // "Evet, İstiyorum" Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      icon: Icon(
                        Icons.volunteer_activism,
                        color: AppColors.tertiary,
                        size: 24,
                      ),
                      label: const Text(
                        'Evet, İstiyorum',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _isLoading ? null : () {
                        debugPrint("Kullanıcı gönüllü olmak istiyor!");
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => VolunteerSkillsScreen(
                            userType: widget.userType, 
                            selectedInterests: widget.selectedInterests
                          ),
                        ));
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Şimdilik Hayır" Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitAndGoHome,
                      child: _isLoading 
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : Text(
                              'Şimdilik Hayır',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
