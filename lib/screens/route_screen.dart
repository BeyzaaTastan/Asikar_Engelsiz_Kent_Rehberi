import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';

// Ulaşım modu modeli
class _TransportMode {
  final String label;
  final IconData icon;
  // OSRM birincil ve yedek URL üreticisi
  final String Function(double sLon, double sLat, double eLon, double eLat) primaryUrlBuilder;
  final String Function(double sLon, double sLat, double eLon, double eLat) secondaryUrlBuilder;
  final Color color;

  const _TransportMode({
    required this.label,
    required this.icon,
    required this.primaryUrlBuilder,
    required this.secondaryUrlBuilder,
    required this.color,
  });
}

// URL yardımcı fonksiyonları — const sınıf içinde kullanılamadığı için top-level tanımlandı
String _footPrimaryUrl(double sLon, double sLat, double eLon, double eLat) =>
    'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$sLon,$sLat;$eLon,$eLat?overview=full&geometries=geojson';

String _footSecondaryUrl(double sLon, double sLat, double eLon, double eLat) =>
    'https://router.project-osrm.org/route/v1/foot/$sLon,$sLat;$eLon,$eLat?overview=full&geometries=geojson';

String _drivingPrimaryUrl(double sLon, double sLat, double eLon, double eLat) =>
    'https://router.project-osrm.org/route/v1/driving/$sLon,$sLat;$eLon,$eLat?overview=full&geometries=geojson';

String _drivingSecondaryUrl(double sLon, double sLat, double eLon, double eLat) =>
    'https://routing.openstreetmap.de/routed-car/route/v1/driving/$sLon,$sLat;$eLon,$eLat?overview=full&geometries=geojson';

class RouteScreen extends StatefulWidget {
  final String destinationName;
  final LatLng destinationLocation;

  const RouteScreen({
    super.key,
    this.destinationName = 'Hedef',
    this.destinationLocation = const LatLng(40.7731, 29.9833),
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Ulaşım modları (OpenStreetMap verisi kullanılır)
  // NOT: router.project-osrm.org yalnızca 'driving' profilini destekler.
  // Yürüyüş ve tekerlekli sandalye için routing.openstreetmap.de/routed-foot birincil sunucu olarak kullanılır.
  static final _modes = [
    _TransportMode(
      label: 'Yürüyüş',
      icon: Icons.directions_walk,
      primaryUrlBuilder: _footPrimaryUrl,
      secondaryUrlBuilder: _footSecondaryUrl,
      color: AppColors.routeWalk,
    ),
    _TransportMode(
      label: 'Tekerlekli\nSandalye',
      icon: Icons.accessible_forward,
      primaryUrlBuilder: _footPrimaryUrl,   // Tekerlekli sandalye de yaya yollarını kullanır
      secondaryUrlBuilder: _footSecondaryUrl,
      color: AppColors.routeWheelchair,
    ),
    _TransportMode(
      label: 'Taşıt',
      icon: Icons.directions_bus,
      primaryUrlBuilder: _drivingPrimaryUrl,
      secondaryUrlBuilder: _drivingSecondaryUrl,
      color: AppColors.routeTransit,
    ),
  ];

  int _selectedModeIndex = 0;

  // Konum ve rota durumu
  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  bool _isLoadingLocation = true;
  bool _isLoadingRoute = false;
  String? _errorMsg;

  // Rota bilgileri (OSRM'den)
  double _distanceKm = 0;
  int _durationMin = 0;

  @override
  void initState() {
    super.initState();
    _initLocationAndRoute();
  }

  Future<void> _initLocationAndRoute() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMsg = null;
    });

    try {
      // Konum izni
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _userLocation = const LatLng(40.7731, 29.9833);
      } else {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          _userLocation = const LatLng(40.7731, 29.9833);
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high),
          );
          _userLocation = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      _userLocation = const LatLng(40.7731, 29.9833);
    }

    setState(() => _isLoadingLocation = false);
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_userLocation == null) return;

    setState(() {
      _isLoadingRoute = true;
      _errorMsg = null;
      _routePoints = [];
    });

    final mode = _modes[_selectedModeIndex];
    final start = _userLocation!;
    final end = widget.destinationLocation;

    // Her mod için doğru OSRM sunucu URL'leri moda göre üretilir
    final primaryUrl   = Uri.parse(mode.primaryUrlBuilder(start.longitude, start.latitude, end.longitude, end.latitude));
    final secondaryUrl = Uri.parse(mode.secondaryUrlBuilder(start.longitude, start.latitude, end.longitude, end.latitude));

    // Birincil sunucuyu dene
    bool success = await _tryFetchRouteFromUrl(primaryUrl, isFallbackServer: false);

    // Başarısız olursa yedek sunucuyu dene
    if (!success) {
      debugPrint('Primary OSRM server failed or unreachable. Trying secondary OSRM server...');
      success = await _tryFetchRouteFromUrl(secondaryUrl, isFallbackServer: true);
    }

    // Her ikisi de başarısız olursa düz çizgi fallback uygula
    if (!success) {
      _setFallbackRoute(start, end);
    }
  }

  Future<bool> _tryFetchRouteFromUrl(Uri url, {required bool isFallbackServer}) async {
    try {
      final resp = await http
          .get(url, headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi/1.0'})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final coords = route['geometry']['coordinates'] as List;

          final legs = (route['legs'] as List);
          double totalDist = 0;
          double totalDur = 0;
          for (final leg in legs) {
            totalDist += (leg['distance'] as num).toDouble();
            totalDur += (leg['duration'] as num).toDouble();
          }

          final points = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          setState(() {
            _routePoints = points;
            _distanceKm = totalDist / 1000;
            _durationMin = (totalDur / 60).round();
            _isLoadingRoute = false;
            if (isFallbackServer) {
              _errorMsg = 'Yedek rota sunucusu kullanılıyor.';
            } else {
              _errorMsg = null;
            }
          });

          // Haritayı rotayı kapsayacak şekilde ayarla
          if (points.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(points);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.fromLTRB(48, 120, 48, 280),
                ),
              );
            });
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error fetching route from $url: $e');
    }
    return false;
  }

  void _setFallbackRoute(LatLng start, LatLng end) {
    // API başarısız olursa düz çizgi göster
    final mid = LatLng(
      (start.latitude + end.latitude) / 2,
      (start.longitude + end.longitude) / 2,
    );

    final dist = const Distance().as(LengthUnit.Kilometer, start, end);
    setState(() {
      _routePoints = [start, mid, end];
      _distanceKm = dist;
      // Yürüyüş/tekerlekli sandalye: ~4 km/s, araç: ~50 km/s
      final isDriving = _selectedModeIndex == 2;
      _durationMin = isDriving
          ? (dist / 50 * 60).round()
          : (dist / 4 * 60).round();
      _isLoadingRoute = false;
      _errorMsg = 'OpenStreetMap rota servisi yanıt vermedi, yaklaşık mesafe gösteriliyor.';
    });
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(int min) {
    if (min < 60) return '$min dk';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}s' : '${h}s ${m}dk';
  }

  Color get _modeColor => _modes[_selectedModeIndex].color;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── KATMAN 1: Gerçek OpenStreetMap ──────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.destinationLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.asikar_engelsiz_kent_rehberi',
              ),

              // Rota polyline (OpenStreetMap verisine dayalı)
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 10,
                      color: _modeColor.withValues(alpha: 0.25),
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: _modeColor,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: _modeColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _modeColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: _modeColor,
                          size: 22,
                        ),
                      ),
                    ),
                  Marker(
                    point: widget.destinationLocation,
                    width: 44,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _modeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _modeColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 12,
                          color: _modeColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── KATMAN 2: Üst Yüzen Kart (Google Maps Tarzı) ─────────────────
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Geri butonu
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Konum satırları
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Başlangıç konumu
                        _buildLocationBox(
                          _isLoadingLocation ? 'Konum alınıyor...' : 'Mevcut Konumunuz',
                          Icons.radio_button_checked,
                          _modeColor,
                        ),
                        // Noktalı ayraç
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Row(
                            children: List.generate(
                              4,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bitiş konumu
                        _buildLocationBox(
                          widget.destinationName,
                          Icons.location_on,
                          AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                  // Sağ aksiyon sütunu
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⋮ Seçenekler menüsü
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.primary, size: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(value)),
                          );
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'Rota Seçenekleri', child: Text('Rota Seçenekleri')),
                          PopupMenuItem(value: 'Ara Nokta Ekle', child: Text('Ara Nokta Ekle')),
                          PopupMenuItem(value: 'Rotayı Paylaş', child: Text('Rotayı Paylaş')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // ↑↓ Başlangıç-bitiş yer değiştirme butonu
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rota ters çevrildi.')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.swap_vert, color: AppColors.primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // ── KATMAN 3: Rota yüklenme göstergesi ──────────────────────────
          if (_isLoadingRoute || _isLoadingLocation)
            Positioned(
              top: topPad + 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _modeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isLoadingLocation
                            ? 'Konum alınıyor...'
                            : 'OSM Rotası Hesaplanıyor...',
                        style: TextStyle(
                          color: _modeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── KATMAN 4: Alt Detay Paneli ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBox(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Ulaşım Modu Seçicisi
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: List.generate(_modes.length, (i) {
                  final mode = _modes[i];
                  final selected = _selectedModeIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (_selectedModeIndex == i) return;
                        setState(() => _selectedModeIndex = i);
                        await _fetchRoute();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? mode.color.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? mode.color
                                : Colors.grey.shade200,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mode.icon,
                              size: 26,
                              color: selected
                                  ? mode.color
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? mode.color
                                    : Colors.grey.shade500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),

            // Süre & Mesafe
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLoadingRoute
                  ? Row(
                      children: [
                        Container(
                          width: 80,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 120,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Süre — taşma önlemek için Flexible kullan
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _formatDuration(_durationMin),
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: _modeColor,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Mesafe + kaynak etiketi
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDistance(_distanceKm),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'OSM · ${_modes[_selectedModeIndex].label.replaceAll('\n', ' ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 12, color: Colors.orange.shade400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // Başlat Butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingRoute || _routePoints.isEmpty
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Navigasyon başlatıldı! (Demo)'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 20),
                  label: const Text(
                    'Başlat',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modeColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
