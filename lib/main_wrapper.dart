import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/user_type_screen.dart';
import 'main_layout.dart';
import 'services/notification_service.dart';
import 'screens/call_screen.dart';
import 'main.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Uygulama yaşam döngüsü değişikliklerini (arka plan → ön plan) dinle
    WidgetsBinding.instance.addObserver(this);
    // Uygulama ilk açıldığında bekleyen çağrı var mı kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingCall());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama arka plandan öne geldiğinde (resume) çağrılır.
  /// CallKit "Cevapla" butonundan açılmış bekleyen çağrıları yakalar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingCall();
    }
  }

  /// pendingCallId varsa direkt CallScreen'e yönlendir.
  /// Bu kontrol Firestore stream'inin yeni event emit etmesini beklemez.
  void _checkPendingCall() {
    if (NotificationService.pendingCallId != null) {
      final String callId = NotificationService.pendingCallId!;
      NotificationService.pendingCallId = null;
      debugPrint("📞 MainWrapper: Bekleyen çağrı bulundu → $callId");
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            isVolunteer: true,
            callId: callId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Durum: Kullanıcı giriş yapmamışsa Login ekranına gönder
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 2. Durum: Giriş yapmışsa Firestore'dan kullanıcı tipini oku
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Veri yüklenirken hata oluştu: ${userSnapshot.error}'),
                ),
              );
            }

            // Veritabanında kullanıcı kaydı yoksa ankete (UserTypeScreen) gönder
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const UserTypeScreen();
            }

            Map<String, dynamic>? data =
                userSnapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const UserTypeScreen();

            // Kullanıcı tipine göre ilgili ana ekrana yönlendir
            bool isVolunteer = data['isVolunteer'] == true;
            String userType = data['userType'] ?? "Sakin";

            // Bildirim aboneliğini rolüne göre dinamik olarak yönet
            if (isVolunteer) {
              NotificationService.subscribeToVolunteers();
              userType = "Gönüllü";
            } else {
              NotificationService.unsubscribeFromVolunteers();
              if (userType == "Özel Gereksinimli") {
                userType = "Engelli";
              }
            }

            return MainLayout(userType: userType);
          },
        );
      },
    );
  }
}

