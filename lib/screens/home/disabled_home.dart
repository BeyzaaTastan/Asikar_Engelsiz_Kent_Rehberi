
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/custom_home_widgets.dart';
import '../../widgets/location_search_dialog.dart';
import '../../constants/app_colors.dart';
import '../../constants/call_types.dart';
import '../../providers/settings_provider.dart';
import '../call_screen.dart';
import '../../router/app_router.dart';
import '../../services/analytics_service.dart';
import '../../services/city_lookup_service.dart';

class DisabledHomeScreen extends ConsumerStatefulWidget {
  const DisabledHomeScreen({super.key});

  @override
  ConsumerState<DisabledHomeScreen> createState() => _DisabledHomeScreenState();
}

class _DisabledHomeScreenState extends ConsumerState<DisabledHomeScreen> {
  // Renk sabitleri merkezi AppColors'tan alınıyor



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(),
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
                    padding: const EdgeInsets.only(top: 24.0, bottom: 32.0, left: 24.0, right: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Üst Bölüm: Devasa Yardım İste Butonu
                        _buildMassiveHelpButton(),
                        
                        // Orta Bölüm: Çevrimiçi Gönüllü Durumu
                        Semantics(
                          label: 'Şu an Sakarya\'da 24 Gönüllü çevrimiçi. Size yardımcı olmak için hemen bir gönüllüye bağlanabilirsiniz.',
                          container: true,
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.tertiary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.tertiary.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Şu an Sakarya'da 24 Gönüllü çevrimiçi",
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Size yardımcı olmak için\nhemen bir gönüllüye bağlanabilirsiniz.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Alt Bölüm: Favori Rotalar
                        Column(
                          children: [
                            Semantics(
                              header: true,
                              child: const Text(
                                "Favori Rotalarım",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRouteButton("Ev", Icons.home, AppColors.primary),
                                _buildRouteButton("İş", Icons.work, AppColors.secondary),
                                _buildRouteButton("Park", Icons.park, AppColors.tertiary),
                              ],
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

  // --- ÖZEL WIDGET'LAR ---

  // Devasa Yardım Butonu Tasarımı
  Widget _buildMassiveHelpButton() {
    return Semantics(
      button: true,
      label: 'Yardım İste. Görüntülü destek mi yoksa yerinde yardım mı istediğinizi seçin.', // Görme engelli biri tıkladığında cihaz bu cümleyi sesli okur
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withValues(alpha: 0.2),
            onTap: () async {
              // Kullanıcı çağrı tipini seçer: uzaktan (görüntülü) veya fiziksel (yerinde).
              // Tip, çağrının hangi gönüllülere yönlendirileceğini belirler
              // (bkz. vault/07-Performance/11-Olcekleme.md).
              final tip = await _showCallTypeSheet();
              if (tip == null || !mounted) return; // kullanıcı vazgeçti
              await _startCall(tip);
            },
            // Semantics okuduğu için içindeki metinleri tekrar okumasını engelliyoruz
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_call, size: 80, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'YARDIM İSTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GÖRÜNTÜLÜ BAĞLAN',
                    style: TextStyle(
                      color: Colors.blue.shade100.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Favori Rota Kare Butonları
  Widget _buildRouteButton(String title, IconData icon, Color color) {
    // 1. Riverpod üzerinden ayarları oku
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // 2. Bu butona ait json string'i bul
    String? jsonStr;
    if (title == "Ev") {
      jsonStr = settings.routeHome;
    } else if (title == "İş") {
      jsonStr = settings.routeWork;
    } else if (title == "Park") {
      jsonStr = settings.routePark;
    }

    bool isSet = jsonStr != null && jsonStr.isNotEmpty;
    Map<String, dynamic>? locData;
    if (isSet) {
      try {
        locData = json.decode(jsonStr); // Ünlem kaldırıldı
      } catch (e) {
        isSet = false;
      }
    }

    final String displayName = isSet && locData != null ? locData['name'] : 'Ayarla';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Semantics(
          button: true,
          label: isSet ? '$title rotasına gitmek için dokun, değiştirmek için basılı tut' : '$title rotasını ayarlamak için dokun',
          child: InkWell(
            onTap: () async {
              if (isSet && locData != null) {
                // Rotaya Git
                Navigator.pushNamed(
                  context,
                  AppRoutes.routeScreen,
                  arguments: {
                    'destinationName': locData['name'],
                    'destinationLocation': LatLng(locData['lat'], locData['lng']),
                  },
                );
              } else {
                // Ayarla
                _showLocationDialog(title, notifier);
              }
            },
            onLongPress: () {
              // Konumu Değiştir
              _showLocationDialog(title, notifier);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 36),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationDialog(String title, SettingsNotifier notifier) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LocationSearchDialog(title: title),
    );

    if (result != null) {
      final jsonStr = json.encode(result);
      if (title == "Ev") {
        await notifier.setRouteHome(jsonStr);
      } else if (title == "İş") {
        await notifier.setRouteWork(jsonStr);
      } else if (title == "Park") {
        await notifier.setRoutePark(jsonStr);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title konumu başarıyla ayarlandı!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  // --- ÇAĞRI TİPİ SEÇİMİ + BAŞLATMA ---

  /// Kullanıcıya çağrı tipini sorar (uzaktan / fiziksel). Erişilebilir, büyük
  /// dokunma hedefli iki seçenek. Kullanıcı vazgeçerse `null` döner.
  Future<String?> _showCallTypeSheet() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Nasıl yardım istersiniz?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildCallTypeOption(
                  sheetContext: sheetContext,
                  type: CagriTipi.uzaktan,
                  icon: Icons.video_call,
                  title: 'Görüntülü Destek',
                  subtitle:
                      'Uzaktan görüntülü yardım. Her yerdeki gönüllüler yanıtlayabilir.',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 14),
                _buildCallTypeOption(
                  sheetContext: sheetContext,
                  type: CagriTipi.fiziksel,
                  icon: Icons.volunteer_activism,
                  title: 'Yerinde Yardım',
                  subtitle:
                      'Bulunduğunuz yerde fiziksel yardım veya rehberlik. Yalnızca aynı şehirdeki gönüllülere ulaşır.',
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallTypeOption({
    required BuildContext sheetContext,
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(sheetContext).pop(type),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Seçilen tiple çağrı belgesini oluşturur ve CallScreen'e yönlendirir.
  ///
  /// Fiziksel çağrıda, çağrı yalnızca aynı şehirdeki gönüllülere gitmeli →
  /// arayanın ANLIK konumundan `sehir` slug'ı çözülür. Uzaktan çağrıda konum
  /// gerekmez (hızlı yol). Şehir çözülemezse `sehir` yazılmaz; Cloud Function
  /// global `volunteers`'a düşürür (çağrı kaybolmaz).
  Future<void> _startCall(String cagriTipi) async {
    final String callId = const Uuid().v4();
    final currentUser = FirebaseAuth.instance.currentUser;

    String? sehir;
    if (cagriTipi == CagriTipi.fiziksel) {
      _showResolvingDialog();
      sehir = await CityLookupService.currentCitySlug();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    // SANTRALE (FIRESTORE) SİNYALİ GÖNDER!
    // NOT: caller_uid alanı Firestore güvenlik kuralları tarafından zorunludur.
    // Kural, bu alanın giriş yapan kullanıcının UID'si ile eşleşmesini doğrular.
    final Map<String, dynamic> data = {
      'callId': callId,
      'kanal_adi': callId,
      'cagri_durumu': 'bekliyor',
      'zaman': FieldValue.serverTimestamp(),
      'caller_name': currentUser?.displayName ?? 'Aşikar Kullanıcısı',
      'caller_uid': currentUser?.uid ?? '',
      'cagri_tipi': cagriTipi,
    };
    if (sehir != null) data['sehir'] = sehir;

    await FirebaseFirestore.instance.collection('cagrilar').doc(callId).set(data);

    // Analytics: çağrı başlatıldı (PRD tamamlanan çağrı oranı paydası)
    AnalyticsService.cagriBaslatildi();

    // Kendi kameramızı açıp beklemeye başla
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          isVolunteer: false,
          callId: callId,
        ),
      ),
    );
  }

  /// Fiziksel çağrıda konum çözümlenirken gösterilen kısa yükleniyor diyaloğu.
  void _showResolvingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Semantics(
        liveRegion: true,
        label: 'Konumunuz belirleniyor, lütfen bekleyin.',
        child: AlertDialog(
          backgroundColor: AppColors.background,
          content: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Konumunuz belirleniyor...')),
            ],
          ),
        ),
      ),
    );
  }

}
