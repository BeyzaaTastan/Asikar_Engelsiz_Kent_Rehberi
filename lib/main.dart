import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart'; // CLI'nin bizim için oluşturduğu yapılandırma dosyası
import 'screens/splash_screen.dart';
import 'router/app_router.dart';
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

      // Merkezi route yönetimi
      onGenerateRoute: AppRouter.generateRoute,

      // Önce Splash Screen gösterilecek, ardından MainWrapper ile oturum kontrolü yapılacak
      home: const SplashScreen(),
    );
  }
}
