import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isGoogleInitialized = false;

  Future<void> _initGoogle() async {
    if (!_isGoogleInitialized) {
      try {
        await GoogleSignIn.instance.initialize();
        _isGoogleInitialized = true;
      } catch (e) {
        debugPrint("GoogleSignIn initialize error: $e");
      }
    }
  }

  // 1. Kullanıcının anlık durumunu dinleyen stream (Giriş yapmış mı?)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 2. E-posta, Şifre ve İSİM ile Kayıt Olma
  Future<User?> registerWithEmail(String name, String email, String password) async {
    try {
      // Firebase'de kullanıcıyı oluştur
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      User? user = result.user;

      // Kullanıcının "Ad Soyad" bilgisini Firebase profiline ekle
      if (user != null) {
        await user.updateDisplayName(name.trim());
        await user.reload(); // Değişikliklerin anında yansıması için
        user = _auth.currentUser;
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Kayıt Hatası: ${e.code}");
      String message = "Kayıt işlemi sırasında bir hata oluştu.";
      if (e.code == 'email-already-in-use') {
        message = "Bu e-posta adresi zaten kullanımda.";
      } else if (e.code == 'weak-password') {
        message = "Belirlediğiniz şifre çok zayıf (En az 6 karakter olmalıdır).";
      } else if (e.code == 'invalid-email') {
        message = "Geçersiz bir e-posta adresi girdiniz.";
      }
      throw AuthException(message);
    } catch (e) {
      debugPrint("Sistemsel Kayıt Hatası: $e");
      throw AuthException("Sistem hatası. Lütfen daha sonra tekrar deneyin.");
    }
  }

  // 3. E-posta ve Şifre ile Giriş Yapma
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Giriş Hatası: ${e.code}");
      String message = "Giriş başarısız.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "E-posta adresi veya şifre hatalı.";
      } else if (e.code == 'invalid-email') {
        message = "Geçersiz e-posta formatı.";
      } else if (e.code == 'user-disabled') {
        message = "Bu kullanıcı hesabı askıya alınmış.";
      }
      throw AuthException(message);
    } catch (e) {
      debugPrint("Sistemsel Giriş Hatası: $e");
      throw AuthException("Sistem hatası. Lütfen daha sonra tekrar deneyin.");
    }
  }

  // 4. Google ile Tek Tıkla Giriş Yapma / Kayıt Olma
  Future<User?> signInWithGoogle() async {
    try {
      await _initGoogle();

      // 1. Google Giriş ekranını tetikle
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } catch (e) {
        debugPrint("Google SignIn error: $e");
        return null;
      }

      // 2. Google'dan kimlik doğrulama bilgilerini al (idToken)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // 3. Bu bilgilerle Firebase için yepyeni bir kimlik oluştur
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e bu kimlikle giriş yap (hesap yoksa otomatik açar)
      UserCredential result = await _auth.signInWithCredential(credential);
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Google Giriş Firebase Hatası: ${e.code}");
      throw AuthException("Google ile Firebase kaydı başarısız oldu: ${e.message}");
    } catch (e) {
      debugPrint("Google Giriş Hatası: $e");
      throw AuthException("Google ile giriş yapılırken beklenmeyen bir hata oluştu.");
    }
  }

  // 5. Çıkış Yapma
  Future<void> signOut() async {
    try {
      // Çıkış öncesinde cihazın FCM token'ını Firestore'dan sil
      await NotificationService.clearFcmTokenFromFirestore();
      // Çıkış yaparken bildirim aboneliğini temizle
      await NotificationService.unsubscribeFromVolunteers();
      await _initGoogle();
      // Hem Firebase'den hem de cihazdaki Google oturumundan çıkış yap
      await GoogleSignIn.instance.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Çıkış Hatası: $e");
      throw AuthException("Oturum kapatılırken bir hata oluştu.");
    }
  }
}
