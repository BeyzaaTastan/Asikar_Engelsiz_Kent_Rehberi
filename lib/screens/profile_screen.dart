import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Renk sabitleri merkezi AppColors'tan alınıyor
  static const Color errorColor = Color(0xFFBA1A1A);

  // O an giriş yapmış olan Firebase kullanıcısını alıyoruz
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Profil Fotoğrafı ve Bilgiler
              _buildProfileHeader(),
              const SizedBox(height: 32),

              // 2. Menü Öğeleri
              _buildMenuItem(
                icon: Icons.person,
                title: "Profili Düzenle",
                onTap: () {
                  // TODO: Profili Düzenle sayfasına git
                },
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.security,
                title: "Hesap Güvenliği",
                onTap: () {
                  // TODO: Hesap Güvenliği sayfasına git
                },
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.notifications,
                title: "Bildirim Ayarları",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.help,
                title: "Yardım Merkezi",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.person_add,
                title: "Arkadaşlarını Davet Et",
                onTap: () {},
              ),
              const SizedBox(height: 32),

              // 3. Çıkış Yap Butonu
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- ÖZEL WIDGET'LAR ---

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.person, size: 64, color: AppColors.primary),
            ),
            // Kamera İkonu (Accent Color)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 3),
              ),
              child: const Icon(Icons.photo_camera, size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Firebase'den Gelen İsim (Yoksa varsayılan)
        Text(
          currentUser?.displayName ?? "İsimsiz Kullanıcı",
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // Firebase'den Gelen E-posta
        Text(
          currentUser?.email ?? "E-posta bulunamadı",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () async {
        // Çıkış yaparken kullanıcıya küçük bir yükleniyor diyaloğu gösterebiliriz
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // 1. Firebase ve Google'dan Çıkış Yap
        await AuthService().signOut();

        // 2. Yükleniyor diyaloğunu kapat ve kullanıcıyı ana kapıya (MainWrapper/Login) fırlat
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: errorColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Çıkış Yap",
                style: TextStyle(
                  color: errorColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: errorColor, size: 24),
          ],
        ),
      ),
    );
  }
}
