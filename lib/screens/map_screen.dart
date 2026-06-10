import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:asikar_engelsiz_kent_rehberi/screens/route_screen.dart';
import '../services/map_search_service.dart';
import '../services/settings_service.dart';
import '../models/venue_model.dart';
import '../providers/venue_providers.dart';

// Harita türü
enum _MapType { defaultMap, satellite, terrain }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearchActive = false;
  bool _isSearchFieldEmpty = true;

  // Haritada tıklanan venue
  bool _isPlaceSelected = false;
  VenueModel? _selectedVenue;

  // Seçili olan erişilebilirlik filtresi
  String _activeFilter = 'Tekerlekli Sandalye';

  final LatLng _sakaryaCenter = const LatLng(40.7731, 29.9833);
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  bool _isLoading = false;
  final MapSearchService _searchService = MapSearchService();
  SettingsService? _settingsService;

  // Kullanıcının gerçek son aramaları — SharedPreferences'tan yüklenir
  List<Map<String, dynamic>> _recentSearches = [];

  List<Map<String, dynamic>> _nearbySuggestions = [];

  // Haritaya tıklanan nokta bilgisi
  LatLng? _tappedPoint;
  String _tappedAddress = '';
  bool _isLoadingTapInfo = false;

  // Sürüklenebilir sheet controller
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Yüklenen tüm venue'lar (yakın mekan bulmak için)
  List<VenueModel> _allVenues = [];

  _MapType _mapType = _MapType.defaultMap;
  bool _showTransit    = false;
  bool _showCycling    = false;
  bool _showHiking     = false;
  bool _showTactile    = false;
  bool _showWheelchair = false;
  bool _showElevator   = false;
  List<Polyline> _accessibilityPolylines = [];
  List<Polyline> _hikingPolylines        = [];   // Overpass yaya yolları
  List<Marker>   _accessibilityMarkers   = [];
  bool _isLoadingOverpass = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchService.dispose();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// SharedPreferences'tan son aramaları yükler.
  Future<void> _loadRecentSearches() async {
    final service = await SettingsService.create();
    if (mounted) {
      setState(() {
        _settingsService = service;
        _recentSearches = service.recentMapSearchesParsed;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _isSearchFieldEmpty = _searchController.text.isEmpty;
    });

    _searchService.debouncedSearch(
      query: _searchController.text,
      onResult: (results) {
        if (mounted) setState(() => _nearbySuggestions = results);
      },
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
    );
  }

  void _onVenueMarkerTapped(VenueModel venue) {
    setState(() {
      _isSearchActive = false;
      _isPlaceSelected = true;
      _selectedVenue = venue;
      _tappedPoint = LatLng(venue.latitude, venue.longitude);
      _tappedAddress = venue.address;
    });
    _mapController.move(LatLng(venue.latitude, venue.longitude), 16.0);
    // Sheet'i orta boy açık konuma getir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.45,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  /// Haritada boş bir yere tıklandığında
  Future<void> _onMapTapped(LatLng point, List<VenueModel> venues) async {
    // En yakın venue'yu bul (<500m)
    VenueModel? nearest;
    double minDist = double.infinity;
    for (final v in venues) {
      final d = const Distance().as(
        LengthUnit.Meter,
        point,
        LatLng(v.latitude, v.longitude),
      );
      if (d < minDist) {
        minDist = d;
        nearest = v;
      }
    }

    if (nearest != null && minDist < 500) {
      // DB mekanı: direkt göster
      _onVenueMarkerTapped(nearest);
      return;
    }

    // DB'de yoksa: koordinatı göster, Nominatim'den adres çek
    setState(() {
      _isSearchActive = false;
      _isPlaceSelected = true;
      _selectedVenue = null;
      _tappedPoint = point;
      _tappedAddress = '';
      _isLoadingTapInfo = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.35,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
        'accept-language': 'tr',
      });
      final resp = await http.get(url,
          headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (mounted) {
          setState(() {
            _tappedAddress = data['display_name'] ?? 'Adres bulunamadı';
            _isLoadingTapInfo = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingTapInfo = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTapInfo = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum servisleri kapalı. Lütfen açın.')),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni reddedildi.')),
          );
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi. Telefon ayarlarından açmalısınız.')),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      LatLng myPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = myPosition;
        _isLoadingLocation = false;
      });

      _mapController.move(myPosition, 16.0);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınırken hata oluştu: $e')),
      );
    }
  }

  /// Erişilebilirlik seviyesine göre marker rengi belirler
  Color _getMarkerColor(String accessibilityLevel) {
    switch (accessibilityLevel) {
      case 'Tam Erişilebilir':
        return AppColors.tertiary;       // Yeşil
      case 'Kısmi Erişilebilir':
        return AppColors.secondary;      // Turkuaz
      case 'Kısıtlı Erişilebilir':
        return AppColors.warning;        // Turuncu
      case 'Destek Gerekli':
        return AppColors.danger;         // Kırmızı
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firestore'daki gerçek venue verilerini Riverpod ile izle
    final venuesAsync = ref.watch(venuesStreamProvider);

    return Scaffold(
      appBar: !_isSearchActive
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              centerTitle: true,
              title: const Text('Şehir Rehberi',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primary),
                onPressed: () {},
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined,
                      color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // 1. KATMAN: OpenStreetMap Haritası
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _sakaryaCenter,
              initialZoom: 14.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                if (_isSearchActive) {
                  setState(() => _isSearchActive = false);
                  return;
                }
                _onMapTapped(point, _allVenues);
              },
            ),
            children: [
              // ── Temel harita karosu (seçili türe göre dinamik) ──
              TileLayer(
                urlTemplate: _baseTileUrl,
                subdomains: _mapType == _MapType.defaultMap
                    ? const ['a', 'b', 'c', 'd']
                    : const [],
                userAgentPackageName: 'com.example.asikar_engelsiz_kent_rehberi',
              ),
              // ── Toplu taşıma katmanı (OpenRailwayMap) ──
              if (_showTransit)
                TileLayer(
                  urlTemplate: 'https://a.tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.asikar_engelsiz_kent_rehberi',
                ),
              // ── Bisiklet yolları (Waymarked Trails) ──
              if (_showCycling)
                TileLayer(
                  urlTemplate: 'https://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.asikar_engelsiz_kent_rehberi',
                ),
              // ── Yürüyüş yolları (Overpass API: footway/pedestrian/path) ──
              if (_hikingPolylines.isNotEmpty)
                PolylineLayer(polylines: _hikingPolylines),
              // ── Erişilebilirlik polyline'ları (Overpass API) ──
              if (_accessibilityPolylines.isNotEmpty)
                PolylineLayer(polylines: _accessibilityPolylines),
              // ── Erişilebilirlik node marker'ları (Overpass API) ──
              if (_accessibilityMarkers.isNotEmpty)
                MarkerLayer(markers: _accessibilityMarkers),
              // Firestore'daki gerçek venue'lar → Dinamik Marker'lar
              venuesAsync.when(
                data: (venues) {
                  _allVenues = venues;
                  final colorFn = _getMarkerColor;
                  return MarkerLayer(
                    markers: venues.map((venue) {
                      final color = colorFn(venue.accessibilityLevel);
                      return Marker(
                        point: LatLng(venue.latitude, venue.longitude),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _onVenueMarkerTapped(venue),
                          child: Semantics(
                            label: '${venue.name}, ${venue.accessibilityLevel}',
                            button: true,
                            child: Icon(Icons.location_on, color: color, size: 44),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (e, _) => const MarkerLayer(markers: []),
              ),
              // Tıklanan nokta pin'i (DB mekanı değilse)
              if (_tappedPoint != null && _selectedVenue == null)
                MarkerLayer(markers: [
                  Marker(
                    point: _tappedPoint!,
                    width: 50, height: 60,
                    child: Column(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: const Icon(Icons.place, color: Colors.white, size: 18),
                        ),
                        Container(width: 2, height: 14, color: AppColors.secondary),
                      ],
                    ),
                  ),
                ]),
              // Kullanıcının konumu
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.2)),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border:
                                    Border.all(color: Colors.white, width: 3)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. KATMAN: Arama Barı ve Filtre Çipleri
          Positioned(
            top: _isSearchActive
                ? MediaQuery.of(context).padding.top + 16
                : 16,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              _isSearchActive
                                  ? Icons.arrow_back
                                  : Icons.search,
                              color: AppColors.outline),
                          onPressed: () {
                            setState(() => _isSearchActive = !_isSearchActive);
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            readOnly: !_isSearchActive,
                            onTap: () => setState(() {
                              _isSearchActive = true;
                              _isPlaceSelected = false;
                              _selectedVenue = null;
                            }),
                            decoration: const InputDecoration(
                              hintText: 'Nereyi arıyorsun?',
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                                color: AppColors.surface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_isSearchActive)
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.outline),
                            onPressed: () => _searchController.clear(),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  height: 24,
                                  width: 1,
                                  color: Colors.grey.shade300),
                              IconButton(
                                icon: const Icon(Icons.tune,
                                    color: AppColors.primary),
                                onPressed: () {},
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isSearchActive) const SizedBox(height: 12),
                if (_isSearchActive)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('Tekerlekli Sandalye', Icons.accessible),
                        _buildFilterChip('Hissedilebilir Yüzey', Icons.blind),
                        _buildFilterChip('Asansör', Icons.elevator),
                        _buildFilterChip('Engelli Otoparkı', Icons.local_parking),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 3. KATMAN: Arama Sonuçları
          if (_isSearchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildSmartResultsOverlay(),
            ),

          // 4. KATMAN: Konumum Butonu
          if (!_isSearchActive && !_isPlaceSelected)
            Positioned(
              bottom: 32,
              right: 16,
              child: InkWell(
                onTap: _getCurrentLocation,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location,
                              color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Konumum',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4b. KATMAN: Harita Türü / Katman Seçici Butonu
          if (!_isSearchActive)
            Positioned(
              right: 16,
              bottom: _isPlaceSelected ? 260 : 100,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black26,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _showLayerPicker,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Icon(Icons.layers_rounded, color: AppColors.primary, size: 24),
                  ),
                ),
              ),
            ),

          // 4c. Overpass yükleniyor göstergesi
          if (_isLoadingOverpass)
            Positioned(
              bottom: _isPlaceSelected ? 260 : 100,
              right: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 6),
                    Text('OSM verisi yükleniyor...', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                  ],
                ),
              ),
            ),

          // 5. KATMAN: Google Maps tarzı Sürüklenebilir Detay Sheet
          if (_isPlaceSelected)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.0,
              minChildSize: 0.0,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.35, 0.55, 0.92],
              builder: (context, scrollController) {
                return _selectedVenue != null
                    ? _buildVenueSheet(scrollController, _selectedVenue!)
                    : _buildUnknownPointSheet(scrollController);
              },
            ),
        ],
      ),
    );
  }

  // ─── Google Maps tarzı Venue sheet (DB mekanı) ───────────────────────────
  Widget _buildVenueSheet(ScrollController sc, VenueModel venue) {
    final levelColor = _getLevelColor(venue.accessibilityLevel);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: sc,
        padding: EdgeInsets.zero,
        children: [
          // Sürükleme kolu
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: isim + kapat butonu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(venue.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() {
                        _isPlaceSelected = false;
                        _selectedVenue = null;
                        _tappedPoint = null;
                      }),
                    )
                  ],
                ),

                // Kategori + Rating
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(venue.category,
                          style: TextStyle(
                              color: levelColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.star_rounded, color: Colors.amber.shade500, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      venue.averageRating > 0
                          ? venue.averageRating.toStringAsFixed(1)
                          : 'Yeni',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (venue.comments.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('(${venue.comments.length} yorum)',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Adres
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(venue.address,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                          maxLines: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Aksiyon butonları (Google Maps gibi)
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.directions,
                      label: 'Yol Tarifi',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteScreen(
                            destinationName: venue.name,
                            destinationLocation:
                                LatLng(venue.latitude, venue.longitude),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.bookmark_border_rounded,
                      label: 'Kaydet',
                      color: Colors.grey.shade700,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kaydedildi!')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Paylaş',
                      color: Colors.grey.shade700,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Erişilebilirlik skoru göstergesi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: levelColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.accessibility_new,
                          color: levelColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venue.accessibilityLevel,
                                style: TextStyle(
                                    color: levelColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('Erişilebilirlik Skoru: %${venue.accessibilityScore}',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48, height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: venue.accessibilityScore / 100,
                              color: levelColor,
                              backgroundColor:
                                  levelColor.withValues(alpha: 0.15),
                              strokeWidth: 5,
                            ),
                            Text('${venue.accessibilityScore}',
                                style: TextStyle(
                                    color: levelColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Özellikler
                if (venue.features.isNotEmpty) ...[
                  const Text('Erişilebilirlik Özellikleri',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: venue.features.map((f) {
                      return Chip(
                        label: Text(f,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        avatar: const Icon(Icons.check_circle,
                            size: 14, color: AppColors.tertiary),
                        backgroundColor: AppColors.lightSurface,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Açıklama
                if (venue.description.isNotEmpty) ...[
                  const Text('Hakkında',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Text(venue.description,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: 16),
                ],

                // Yorumlar
                if (venue.comments.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text('Yorumlar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary)),
                      const Spacer(),
                      Text('${venue.comments.length} yorum',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...venue.comments.take(3).map((c) => _buildCommentTile(c)),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bilinmeyen koordinat sheet'i ──────────────────────────────────────────
  Widget _buildUnknownPointSheet(ScrollController sc) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: sc,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _isLoadingTapInfo
                    ? const Text('Adres yükleniyor...',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey))
                    : Text(
                        _tappedAddress.isNotEmpty
                            ? _tappedAddress
                            : 'Seçilen Konum',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                        maxLines: 3,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  _isPlaceSelected = false;
                  _tappedPoint = null;
                  _tappedAddress = '';
                }),
              ),
            ],
          ),
          if (_tappedPoint != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_tappedPoint!.latitude.toStringAsFixed(5)}, '
              '${_tappedPoint!.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.directions,
                label: 'Yol Tarifi',
                color: AppColors.primary,
                onTap: _tappedPoint == null ? null : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteScreen(
                      destinationName: _tappedAddress.isNotEmpty
                          ? _tappedAddress.split(',').first
                          : 'Seçilen Konum',
                      destinationLocation: _tappedPoint!,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Aksiyon butonu (Yol Tarifi / Kaydet / Paylaş) ────────────────────────
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Yorum kutucuğu ────────────────────────────────────────────────────────
  Widget _buildCommentTile(CommentModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < c.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.content,
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.4)),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Tam Erişilebilir':
        return AppColors.tertiary;
      case 'Kısmi Erişilebilir':
        return AppColors.secondary;
      case 'Kısıtlı Erişilebilir':
        return AppColors.warning;
      case 'Destek Gerekli':
        return AppColors.danger;
      default:
        return AppColors.outline;
    }
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _activeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => setState(() {
          _activeFilter = label;
          _isSearchActive = true;
          _isPlaceSelected = false;
          _selectedVenue = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.outline),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                    color:
                        isSelected ? Colors.white : AppColors.textDark,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartResultsOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text(
                      _isSearchFieldEmpty
                          ? "Son Aramalar"
                          : "Önerilen Mekanlar",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          letterSpacing: 0.5),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _isSearchFieldEmpty && _recentSearches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Henüz arama geçmişi yok',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _isSearchFieldEmpty
                            ? _recentSearches.length
                            : _nearbySuggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 70, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final item = _isSearchFieldEmpty
                              ? _recentSearches[index]
                              : _nearbySuggestions[index];
                          return _buildSearchItem(
                            item['title'],
                            item['subtitle'],
                            _getIconForType(item['type']),
                            _isSearchFieldEmpty,
                            item['lat'],
                            item['lon'],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchItem(String title, String subtitle, IconData icon,
      bool isRecent, double? lat, double? lon) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.outline, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.surface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.outline, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: isRecent
          ? const Icon(Icons.history, color: AppColors.chipBorder, size: 20)
          : const Icon(Icons.north_west, color: AppColors.chipBorder, size: 20),
      onTap: () async {
        setState(() {
          _searchController.text = title;
          _isSearchActive = false;
        });
        if (lat != null && lon != null) {
          _mapController.move(LatLng(lat, lon), 16.0);
          // Gerçek son aramalar listesine kaydet
          final entry = {
            'title': title,
            'subtitle': subtitle,
            'lat': lat,
            'lon': lon,
            'type': 'recent',
          };
          await _settingsService?.addRecentMapSearch(entry);
          if (mounted) {
            setState(() {
              // Listeyi hemen güncelle (uygulama kapatılıp açılmadan gözükecek)
              _recentSearches.removeWhere((e) => e['title'] == title);
              _recentSearches.insert(0, {...entry, 'type': 'recent'});
              if (_recentSearches.length > 5) _recentSearches.removeRange(5, _recentSearches.length);
            });
          }
        }
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'recent':
        return Icons.history;
      case 'park':
        return Icons.park;
      case 'museum':
        return Icons.museum;
      case 'place':
        return Icons.location_on;
      default:
        return Icons.place;
    }
  }

  // ─── Temel karo URL'si (harita türüne göre) ──────────────────────────────
  String get _baseTileUrl {
    switch (_mapType) {
      case _MapType.satellite:
        // ESRI Dünya Uydu görüntüsü
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapType.terrain:
        // OpenTopoMap (OSM tabanlı arazi haritası)
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapType.defaultMap:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
    }
  }

  // ─── Overpass API: Yürüyüş / yaya yolları (footway · pedestrian · path) ──
  // highway=footway/pedestrian/path etiketleri Türkiye OSM'sinde yaygın kullanılır.
  // Waymarked Trails'ın aksine bu sorgu gerçek kaldırım ve yaya yollarını gösterir.
  Future<void> _fetchHikingLayer() async {
    if (!_showHiking) {
      setState(() => _hikingPolylines = []);
      return;
    }

    setState(() => _isLoadingOverpass = true);

    final center = _mapController.camera.center;
    final south = (center.latitude  - 0.012).toStringAsFixed(6);
    final north = (center.latitude  + 0.012).toStringAsFixed(6);
    final west  = (center.longitude - 0.016).toStringAsFixed(6);
    final east  = (center.longitude + 0.016).toStringAsFixed(6);
    final bb    = '$south,$west,$north,$east';

    // Kaldırımlar, yaya bölgeleri, parkur yolları
    final query =
        '[out:json][timeout:25];('
        'way["highway"="footway"]($bb);'
        'way["highway"="pedestrian"]($bb);'
        'way["highway"="path"]["foot"!="no"]($bb);'
        'way["highway"="steps"]($bb);'
        ');out body;>;out skel qt;';

    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
    );

    try {
      final resp = await http
          .get(url, headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi/1.0'})
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final data     = json.decode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List;

        // Node koordinat haritası
        final nodeCoords = <int, LatLng>{};
        for (final el in elements) {
          if (el['type'] == 'node') {
            nodeCoords[el['id'] as int] = LatLng(
              (el['lat'] as num).toDouble(),
              (el['lon'] as num).toDouble(),
            );
          }
        }

        // Way → Polyline
        final polylines = <Polyline>[];
        for (final el in elements) {
          if (el['type'] != 'way') continue;
          final wayNodes = el['nodes'] as List;
          final pts = wayNodes
              .map((id) => nodeCoords[id as int])
              .whereType<LatLng>()
              .toList();
          if (pts.length < 2) continue;

          final tags = ((el['tags'] as Map?)?.cast<String, String>()) ?? {};
          final isSteps = tags['highway'] == 'steps';

          polylines.add(Polyline(
            points: pts,
            // Merdiven: kırmızı  |  Yaya yolu: turuncu
            color: isSteps
                ? const Color(0xFFE53935).withValues(alpha: 0.80)
                : const Color(0xFFFF8F00).withValues(alpha: 0.75),
            strokeWidth: isSteps ? 2.5 : 3.0,
            pattern: isSteps
                ? StrokePattern.dashed(segments: const [6, 4])
                : const StrokePattern.solid(),
          ));
        }

        if (mounted) setState(() => _hikingPolylines = polylines);
      }
    } catch (e) {
      debugPrint('Hiking Overpass hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOverpass = false);
    }
  }

  // ─── Overpass API: hissedilebilir yüzey & tekerlekli sandalye yolları ─────
  Future<void> _fetchOverpassLayer() async {
    if (!_showTactile && !_showWheelchair && !_showElevator) {
      setState(() {
        _accessibilityPolylines = [];
        _accessibilityMarkers   = [];
      });
      return;
    }

    setState(() => _isLoadingOverpass = true);

    final center = _mapController.camera.center;
    final south = (center.latitude  - 0.015).toStringAsFixed(6);
    final north = (center.latitude  + 0.015).toStringAsFixed(6);
    final west  = (center.longitude - 0.020).toStringAsFixed(6);
    final east  = (center.longitude + 0.020).toStringAsFixed(6);
    final bb    = '$south,$west,$north,$east';

    final buf = StringBuffer('[out:json][timeout:30];(');
    // Way sorgusu — yollar / kaldırımlar (polyline)
    if (_showTactile) {
      buf.write('way["tactile_paving"="yes"]($bb);');
    }
    if (_showWheelchair) {
      buf.write('way["wheelchair"="yes"]($bb);');
      buf.write('way["wheelchair"="designated"]($bb);');
    }
    // Node sorgusu — tekil mekan noktaları (marker)
    if (_showWheelchair) {
      buf.write('node["wheelchair"="yes"]($bb);');
      buf.write('node["wheelchair"="designated"]($bb);');
    }
    if (_showTactile) {
      buf.write('node["tactile_paving"="yes"]($bb);');
    }
    if (_showElevator) {
      buf.write('node["highway"="elevator"]($bb);');
      buf.write('node["railway"="elevator"]($bb);');
    }
    buf.write(');out body;>;out skel qt;');

    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(buf.toString())}',
    );

    try {
      final resp = await http
          .get(url, headers: {'User-Agent': 'asikar_engelsiz_kent_rehberi/1.0'})
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final data     = json.decode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List;

        // ── 1. Node koordinat haritası (way node referansları için) ──
        final nodeCoords = <int, LatLng>{};
        for (final el in elements) {
          if (el['type'] == 'node') {
            nodeCoords[el['id'] as int] = LatLng(
              (el['lat'] as num).toDouble(),
              (el['lon'] as num).toDouble(),
            );
          }
        }

        // ── 2. Way → Polyline ──
        final polylines = <Polyline>[];
        for (final el in elements) {
          if (el['type'] != 'way') continue;
          final wayNodes = el['nodes'] as List;
          final pts = wayNodes
              .map((id) => nodeCoords[id as int])
              .whereType<LatLng>()
              .toList();
          if (pts.length < 2) continue;

          final tags        = ((el['tags'] as Map?)?.cast<String, String>()) ?? {};
          final isWheelchair = tags['wheelchair'] == 'yes' || tags['wheelchair'] == 'designated';
          final isTactile    = tags['tactile_paving'] == 'yes';

          Color color;
          if (isWheelchair && _showWheelchair) {
            color = const Color(0xFF1E88E5);  // Mavi — tekerlekli sandalye yolu
          } else if (isTactile && _showTactile) {
            color = const Color(0xFF8E24AA);  // Mor — hissedilebilir yüzey yolu
          } else {
            continue;
          }

          polylines.add(Polyline(
            points: pts,
            color: color.withValues(alpha: 0.80),
            strokeWidth: 5,
          ));
        }

        // ── 3. Node → Marker (POI noktası) ──
        final markers = <Marker>[];
        for (final el in elements) {
          if (el['type'] != 'node') continue;
          final lat = (el['lat'] as num?)?.toDouble();
          final lon = (el['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;

          final tags = ((el['tags'] as Map?)?.cast<String, String>()) ?? {};
          // Sadece gerçekten tag'li node'ları marker yap
          final isWheelchairNode = (tags['wheelchair'] == 'yes' || tags['wheelchair'] == 'designated') && _showWheelchair;
          final isTactileNode    = tags['tactile_paving'] == 'yes' && _showTactile;
          final isElevator       = (tags['highway'] == 'elevator' || tags['railway'] == 'elevator') && _showElevator;

          if (!isWheelchairNode && !isTactileNode && !isElevator) continue;

          Color markerColor;
          IconData markerIcon;
          if (isElevator) {
            markerColor = const Color(0xFF00ACC1); // Cyan — asansör
            markerIcon  = Icons.elevator;
          } else if (isWheelchairNode) {
            markerColor = const Color(0xFF1E88E5); // Mavi — tekerlekli sandalye mekanı
            markerIcon  = Icons.accessible;
          } else {
            markerColor = const Color(0xFF8E24AA); // Mor — hissedilebilir yüzey noktası
            markerIcon  = Icons.texture;
          }

          markers.add(Marker(
            point: LatLng(lat, lon),
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Icon(markerIcon, color: Colors.white, size: 16),
            ),
          ));
        }

        if (mounted) {
          setState(() {
            _accessibilityPolylines = polylines;
            _accessibilityMarkers   = markers;
          });
        }
      }
    } catch (e) {
      debugPrint('Overpass API hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOverpass = false);
    }
  }

  // ─── Harita Türü / Katman Seçici Bottom Sheet ────────────────────────────
  void _showLayerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Başlık + kapat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Harita türü',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Harita türü seçenekleri
                Row(
                  children: [
                    _buildMapTypeCard(setModalState, _MapType.defaultMap,
                        'Varsayılan', Icons.map_outlined, const Color(0xFF4DB6AC)),
                    const SizedBox(width: 10),
                    _buildMapTypeCard(setModalState, _MapType.satellite,
                        'Uydu', Icons.satellite_alt, const Color(0xFF546E7A)),
                    const SizedBox(width: 10),
                    _buildMapTypeCard(setModalState, _MapType.terrain,
                        'Arazi', Icons.terrain, const Color(0xFF8D6E63)),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Harita ayrıntıları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
                const SizedBox(height: 14),
                // Katman seçenekleri (wrap)
                Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  children: [
                    _buildOverlayChip(
                      setModalState, 'transit', 'Toplu Taşıma',
                      Icons.directions_transit_filled, const Color(0xFF00897B), _showTransit,
                    ),
                    _buildOverlayChip(
                      setModalState, 'cycling', 'Bisiklet',
                      Icons.pedal_bike, const Color(0xFF43A047), _showCycling,
                    ),
                    _buildOverlayChip(
                      setModalState, 'hiking', 'Yürüyüş Yolları',
                      Icons.directions_walk, const Color(0xFFFF8F00), _showHiking,
                    ),
                    _buildOverlayChip(
                      setModalState, 'tactile', 'Hissedilebilir\nYüzey',
                      Icons.texture, const Color(0xFF8E24AA), _showTactile,
                    ),
                    _buildOverlayChip(
                      setModalState, 'wheelchair', 'Tekerlekli\nSandalye',
                      Icons.accessible_forward, const Color(0xFF1E88E5), _showWheelchair,
                    ),
                    _buildOverlayChip(
                      setModalState, 'elevator', 'Asansör',
                      Icons.elevator, const Color(0xFF00ACC1), _showElevator,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapTypeCard(StateSetter setModalState, _MapType type,
      String label, IconData icon, Color color) {
    final selected = _mapType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mapType = type);
          setModalState(() {});
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 76,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade200,
                  width: selected ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Icon(icon,
                    color: selected ? color : Colors.grey.shade400, size: 34),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayChip(StateSetter setModalState, String key, String label,
      IconData icon, Color color, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          switch (key) {
            case 'transit':  _showTransit  = !_showTransit;  break;
            case 'cycling':  _showCycling  = !_showCycling;  break;
            case 'hiking':
              _showHiking = !_showHiking;
              if (_showHiking) {
                _fetchHikingLayer();
              } else {
                setState(() => _hikingPolylines = []);
              }
              break;
            case 'tactile':
              _showTactile = !_showTactile;
              _fetchOverpassLayer();
              break;
            case 'wheelchair':
              _showWheelchair = !_showWheelchair;
              _fetchOverpassLayer();
              break;
            case 'elevator':
              _showElevator = !_showElevator;
              _fetchOverpassLayer();
              break;
          }
        });
        setModalState(() {});
      },
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.18) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? color : Colors.grey.shade200,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Center(
                child: Icon(icon,
                    color: isActive ? color : Colors.grey.shade400, size: 28),
              ),
            ),
            const SizedBox(height: 5),
            Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : Colors.grey.shade600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

