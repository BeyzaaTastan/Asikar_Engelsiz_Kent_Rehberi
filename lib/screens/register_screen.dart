import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../router/app_router.dart';
import '../constants/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Veritabanı işlemleri için servis objesi
  final AuthService _authService = AuthService();
  
  // Form verilerini tutmak için controller'lar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Yükleme animasyonu için state

  // Renk Paleti merkezi AppColors'tan alınıyor

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Kayıt ol butonuna basıldığında tetiklenecek asenkron fonksiyon
  Future<void> _handleRegister() async {
    // 1. Boş Alan Kontrolü
    if (_nameController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    // 2. Yükleniyor durumuna alıp butonu kilitliyoruz
    setState(() => _isLoading = true);

    // async gap öncesi context bağımlı referansları saklıyoruz
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 3. auth_service kütüphanemiz ile Firebase'e kayıt işlemi
      final user = await _authService.registerWithEmail(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        // Kayıt başarılıysa kullanıcının ankete başlaması için UserTypeScreen'e yönlendiriyoruz
        messenger.showSnackBar(
          const SnackBar(content: Text('Kayıt Başarılı! Aşikar\'a hoş geldiniz.')),
        );
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.mainWrapper,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    // async gap öncesi context bağımlı referansları saklıyoruz
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final user = await _authService.signInWithGoogle();
      
      if (!mounted) return;
      
      if (user != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Google ile Giriş Başarılı!')),
        );
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.mainWrapper,
          (route) => false,
        );
      } else {
        // returned null (user canceled signIn window)
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Üst Bar
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        title: Text(
          'Aramıza Katılın',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Üst Bölüm: Logo ve Başlıklar
                        Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Semantics(
                                label: "Aşikar Logosu",
                                child: Image.asset(
                                  'assets/images/asikar_yazisiz_logo.png', 
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),
                            Text(
                              'Aşikar',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Şehri herkes için erişilebilir kılmak adına\nilk adımınızı atın.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                        
                        // Orta Bölüm: Form Alanları
                        Column(
                          children: [
                            _buildTextField(
                              label: 'Ad Soyad',
                              hint: 'Adınız ve soyadınız',
                              icon: Icons.person,
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              label: 'E-posta Adresiniz',
                              hint: 'ornek@mail.com',
                              icon: Icons.mail,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 10),
                            _buildPasswordField(),
                            const SizedBox(height: 12),
                            
                            // Erişilebilirlik Bilgi Kutusu
                            Semantics(
                              label: "Bilgi: Engelsiz şehir rehberi için tüm alanlar erişilebilirlik standartlarına uygundur.",
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.accessibility_new, color: AppColors.secondary, size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Engelsiz şehir rehberi için tüm alanlar erişilebilirlik standartlarına uygundur.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.infoDarkTeal,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Alt Bölüm: Kayıt ve Google Butonları + Yönlendirme
                        Column(
                          children: [
                            // Kayıt Ol Butonu
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _isLoading ? null : _handleRegister,
                                child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            'Kayıt Ol',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.chevron_right),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Ayırıcı
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'veya',
                                    style: TextStyle(color: AppColors.outline, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Google ile Giriş
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.g_mobiledata, color: Colors.blue, size: 28), 
                                    SizedBox(width: 8),
                                    Text(
                                      'Google ile Devam Et',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Giriş Yap Yönlendirmesi
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Zaten hesabınız var mı? ',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                    children: [
                                      TextSpan(
                                        text: 'Giriş Yap',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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

  // Özel Tasarım Text Field
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.outline.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: AppColors.outline),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // Şifre alanına özel (Göz ikonlu) tasarım
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Şifre',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
          ),
        ),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: AppColors.outline.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.lock, color: AppColors.outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.outline,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              tooltip: _isPasswordVisible ? 'Şifreyi Gizle' : 'Şifreyi Göster',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
