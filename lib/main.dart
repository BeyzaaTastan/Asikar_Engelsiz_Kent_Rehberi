import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart'; // CLI'nin bizim için oluşturduğu yapılandırma dosyası
import 'screens/splash_screen.dart';
import 'router/app_router.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'providers/settings_provider.dart';
import 'constants/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutter motorunun widget ağacını çizmeden önce hazır olduğundan emin oluyoruz.
  // Asenkron (async) işlemler yapacağımız için bu satır şarttır.
  WidgetsFlutterBinding.ensureInitialized();

  // Çevre değişkenlerini .env dosyasından yüklüyoruz.
  await dotenv.load(fileName: ".env");

  // Firebase'i, uygulamanın çalıştığı platforma (Android/iOS/Web) uygun ayarlar ile başlatıyoruz.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Gözlemlenebilirlik: Crashlytics global hata yakalayıcıları + Analytics.
  // Firebase başlatıldıktan HEMEN sonra kurulur ki sonraki adımlardaki
  // (App Check, Settings, Notifications) hatalar da panoya düşsün.
  // Debug modda toplama kapalıdır (bkz. AnalyticsService.init / KVKK).
  await AnalyticsService.init();

  // Firebase App Check'i etkinleştir — sahte/script istemcilere karşı koruma.
  // Backend (generateAgoraToken) bu token'ı doğrular; böylece Agora dakikaları
  // kötüye kullanılamaz (bkz. vault/06-Security/08-Guvenlik.md, 09-Rate-Limiting.md).
  //
  // Debug modda 'debug' provider kullanılır (emülatör/geliştirme için Firebase
  // Console'a debug token eklenmelidir). Release'de Android=Play Integrity,
  // iOS=DeviceCheck gerçek cihaz attestation'ı yapar.
  // App Check başlatma açılışı kilitlememeli; hata olsa bile uygulama açılmalı.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
          kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint("App Check etkinleştirme hatası: $e");
  }

  // Erişilebilirlik ayarlarını cihazdan yükle (SharedPreferences)
  final settingsService = await SettingsService.create();

  // Bildirim Servisini (Anteni) Başlatıyoruz (Açılışı kilitlememesi için asenkron çalıştırıyoruz)
  NotificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        // SettingsService'i Riverpod'a tanıt
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const AsikarApp(),
    ),
  );
}

class AsikarApp extends ConsumerWidget {
  const AsikarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Yüksek kontrast aktifse özel renk şeması, değilse varsayılan teal
    final lightScheme = settings.highContrast
        ? highContrastColorScheme(Brightness.light)
        : ColorScheme.fromSeed(seedColor: AppColors.primary);

    final darkScheme = settings.highContrast
        ? highContrastColorScheme(Brightness.dark)
        : ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Aşikar Engelsiz Kent Rehberi',
      debugShowCheckedModeBanner: false,

      // Tema: Karanlık mod ve yüksek kontrast ayarlarına göre dinamik
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      // Yazı boyutunu sistem ayarlarından bağımsız olarak uygula
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child!,
        );
      },

      // Ekran görüntülemelerini Analytics'e otomatik raporla
      navigatorObservers: [AnalyticsService.observer],

      // Merkezi route yönetimi
      onGenerateRoute: AppRouter.generateRoute,

      // Önce Splash Screen gösterilecek, ardından MainWrapper ile oturum kontrolü yapılacak
      home: const SplashScreen(),
    );
  }
}
