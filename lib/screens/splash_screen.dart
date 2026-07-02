import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart'; // Auth durumuna göre yönlendirme yapan bekçi

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Mimari Karar: Uygulama açıldığında 3 saniye bekleyip anket ekranına yönlendiriyoruz.
    // 6 Mayıs tesliminde buraya Firebase Auth kontrolü ekleyeceğiz (Giriş yapmış mı?).
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.mainWrapper);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Hafif dekoratif gradyan (HTML'deki subtle gradient)
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Ana İçerik (Logo ve Alt Kısım)
            Column(
              children: [
                // 1. Logo Bölümü (Ortalanmış)
                Expanded(
                  child: Center(
                    child: Semantics(
                      label: "Aşikar Engelsiz Kent Rehberi Logosu",
                      child: Image.asset(
                        'assets/images/asikar_yazili_logo.png', // Sizin belirttiğiniz logo adıyla güncellendi
                        width: 380, // Logonun boyutu artırıldı
                        height: 380,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // 2. Alt Kısım (Yükleme Barı ve Slogan)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 60.0,
                  ), // bottom-16 karşılığı
                  child: Column(
                    children: [
                      // Erişilebilir Yükleme Barı
                      SizedBox(
                        width: 180, // w-48
                        height: 6, // h-1.5
                        child: Semantics(
                          label: "Uygulama yükleniyor, lütfen bekleyin.",
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Vizyon Sloganı
                      const Text(
                        'HERKES İÇİN ERİŞİLEBİLİR ŞEHİRLER',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2.0, // tracking-widest
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // İkonlar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.accessible, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.visibility, size: 20, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
