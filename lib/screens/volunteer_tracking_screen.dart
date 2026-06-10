import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class VolunteerTrackingScreen extends StatefulWidget {
  const VolunteerTrackingScreen({super.key});

  @override
  State<VolunteerTrackingScreen> createState() => _VolunteerTrackingScreenState();
}

class _VolunteerTrackingScreenState extends State<VolunteerTrackingScreen> {
  final MapController _mapController = MapController();
  
  // Engelli Bireyin Beklediği Konum (Sabit)
  final LatLng _userLocation = const LatLng(40.7710, 29.9810); 
  
  // Gönüllünün Anlık Konumu (Simüle edilmiş hareketli konum)
  final LatLng _volunteerLocation = const LatLng(40.7760, 29.9860);

  // Aralarındaki rota (Polyline)
  late List<LatLng> _routePoints;

  @override
  void initState() {
    super.initState();
    // Başlangıç rotasını çiziyoruz
    _routePoints = [
      _volunteerLocation,
      const LatLng(40.7740, 29.9840),
      const LatLng(40.7725, 29.9820),
      _userLocation,
    ];
  }

  // Haritayı her iki konumu da görecek şekilde ortalama
  void _centerMap() {
    // Gerçek bir uygulamada bounds hesaplanarak iki pin de ekrana sığdırılır
    _mapController.move(const LatLng(40.7735, 29.9835), 15.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. KATMAN: OpenStreetMap Haritası
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(40.7735, 29.9835), // İki noktanın ortası
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.asikar_engelsiz_kent_rehberi',
              ),
              // Rota Çizgisi (Gönüllüden Kullanıcıya)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: AppColors.secondary.withValues(alpha: 0.8), // Turkuaz Rota
                    // Yürüyüş rotası hissiyatı için noktalı çizgi isteniyorsa pattern kullanılmalıdır
                  ),
                ],
              ),
              // Pinler (Kullanıcı ve Gönüllü)
              MarkerLayer(
                markers: [
                  // Engelli Bireyin Beklediği Konum Pini
                  Marker(
                    point: _userLocation,
                    width: 60, height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gönüllünün Hareketli Pini
                  Marker(
                    point: _volunteerLocation,
                    width: 60, height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary, // Yeşil Gönüllü Rengi
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.directions_walk, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. KATMAN: Üst Bilgi Kartı (Durum ve ETA)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  // Yanıp sönen yeşil nokta efekti
                  Container(
                    width: 12, height: 12,
                    decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gönüllü Yolda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        SizedBox(height: 2),
                        Text('Size doğru geliyor', style: TextStyle(fontSize: 13, color: AppColors.outline)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.lightSurface, borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      children: [
                        Text('5 dk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.surface)),
                        Text('450m', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. KATMAN: Harita Ortalama Butonu
          Positioned(
            right: 16,
            bottom: 240, // Alt panelin hemen üstünde
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _centerMap,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // 4. KATMAN: Gönüllü Bilgi ve Aksiyon Paneli (Bottom Sheet)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -5))],
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gönüllü Profil Bilgileri
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Örnek profil resmi
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ahmet Yılmaz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.surface)),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 18),
                                SizedBox(width: 4),
                                Text('4.9 (120 Yardım)', style: TextStyle(fontSize: 14, color: AppColors.outline)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Doğrulanmış rozeti
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.verified, color: AppColors.secondary, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Aksiyon Butonları (Ara ve Mesaj)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Telefon araması başlat
                          },
                          icon: const Icon(Icons.call, color: Colors.white),
                          label: const Text('Ara', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tertiary, // Yeşil Ara Butonu
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Mesajlaşma ekranını aç
                          },
                          icon: const Icon(Icons.message, color: AppColors.primary),
                          label: const Text('Mesaj', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // İptal Et Butonu
                  TextButton(
                    onPressed: () {
                      // TODO: Talebi iptal et
                      Navigator.pop(context);
                    },
                    child: const Text('Talebi İptal Et', style: TextStyle(color: AppColors.danger, fontSize: 16, fontWeight: FontWeight.w600)),
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
