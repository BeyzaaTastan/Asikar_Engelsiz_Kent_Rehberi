import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../router/app_router.dart';
import '../services/map_search_service.dart';
import '../services/settings_service.dart';
import '../services/overpass_poi_service.dart';
import '../services/foursquare_places_service.dart';
import '../services/fsq_poi_service.dart';
import '../services/overpass_query_builder.dart';
import '../services/omt_poi_service.dart';
import '../services/voice_search_service.dart';
import '../services/tts_service.dart';
import '../models/venue_model.dart';
import '../models/osm_poi_model.dart';
import '../providers/venue_providers.dart';
import '../providers/user_providers.dart';
import 'map/map_visuals.dart';
import 'map/poi_marker.dart';
import 'map/poi_priority.dart';
import 'map/poi_declutter.dart';
import 'map/osm_poi_sheet.dart';
import 'map/venue_sheet.dart';
import 'map/map_attribution.dart';
import 'map/voice_search_button.dart';
import 'map/voice_search_sheet.dart';
import 'map/unknown_point_sheet.dart';
import 'map/smart_results_overlay.dart';
import 'map/map_type_card.dart';
import 'map/map_overlay_chip.dart';


// Harita türü
enum _MapType { defaultMap, satellite, terrain }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  /// Devam eden yumuşak harita geçişi (varsa). Yeni geçiş başlarken iptal edilir.
  AnimationController? _moveAnimController;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearchActive = false;
  bool _isSearchFieldEmpty = true;

  // Haritada tıklanan venue
  bool _isPlaceSelected = false;
  VenueModel? _selectedVenue;

  final LatLng _sakaryaCenter = const LatLng(40.7731, 29.9833);
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  // Harita gövdesinin (alt navigasyon çubuğunun ÜSTÜNDEKİ) gerçek yüksekliği —
  // body Stack'i saran LayoutBuilder'dan set edilir. Arama sonuç overlay'i bunu
  // kullanarak klavye kapalıyken alttaki boşluğa kadar uzar (bkz.
  // SmartResultsOverlay._SearchResultsContainer).
  double _mapBodyHeight = 0;

  bool _isLoading = false;
  final MapSearchService _searchService = MapSearchService();
  SettingsService? _settingsService;

  // Sesli arama (cihaz OS tanıyıcısı — ücretsiz/anahtarsız). Dinleme UI'ı artık
  // VoiceSearchSheet panelinde; map_screen yalnızca sonucu arama kutusuna yazar.
  final VoiceSearchService _voiceSearch = VoiceSearchService();

  // Cihaz TTS'i — panel açılınca yönergeyi sesli okur (erişilebilirlik, $0).
  final TtsService _tts = TtsService();

  // Erişilebilirlik odaklı hızlı sesli arama önerileri (panel çipleri).
  static const List<String> _voiceSuggestions = [
    'Eczane',
    'Hastane',
    'Market',
    'Restoran',
    'Tuvalet',
    'Otobüs durağı',
  ];

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

  // ── OSM POI durumu ──────────────────────────────────────────────────────
  final OverpassPoiService _overpassPoiService = OverpassPoiService();
  final FoursquarePlacesService _foursquareService = FoursquarePlacesService();
  // Türkiye geneli taban katmanı (Cloudflare Worker + D1). POI_API_BASE_URL
  // boşsa devre dışı — backend deploy edilene kadar etki etmez.
  final FsqPoiService _fsqPoiService = FsqPoiService();
  // Vektör karodan (OpenMapTiles) çıkarılan mekanları TIKLANABILIR POI'ye çevirir
  // → haritada görünüp de diğer kaynaklarda olmayan yerler de detay paneli açar.
  final OmtPoiService _omtPoiService = OmtPoiService();
  List<OsmPoi> _osmPois = [];
  OsmPoi? _selectedOsmPoi;
  bool _isLoadingPois = false;
  // Hibrit POI yüklemesinde iki kaynak ayrı biter; gösterge ikisi de bitince kapanır.
  // (Foursquare key'i boşsa eski kod yalnızca FSQ onResult'una bağlıydı → gösterge takılırdı.)
  bool _overpassLoading = false;
  bool _fsqLoading = false;
  bool _fsqOsLoading = false;
  bool _omtLoading = false;   // OpenMapTiles vektör karo POI kaynağı
  // ignore: prefer_final_fields — set'in içeriği .add()/.remove() ile değiştiriliyor
  Set<String> _selectedPoiCategories = {};
  // POI verisi bu zoom'un altında çekilmez/gösterilmez (şehir ölçeğinde harita
  // boş kalır, kota korunur). Bu eşiğin ÜSTÜNDE hangi POI'nin isim/nokta/gizli
  // olacağına Google tarzı declutter karar verir (kademeli görünürlük).
  static const double _poiFetchMinZoom = 15.0;
  // Declutter'a girecek azami POI sayısı (öncelik sırasına göre kırpılır) —
  // çok yoğun bölgelerde relayout maliyetini sınırlar.
  static const int _poiDeclutterCap = 700;
  double _currentZoom = 15.0;
  bool _mapReady = false;


  _MapType _mapType = _MapType.defaultMap;

  // ── Vektör taban haritası (varsayılan mod) ──────────────────────────────
  // "Varsayılan" harita türü artık OpenFreeMap Liberty VEKTÖR karolarıyla
  // çizilir (Google'a yakın renk paleti; su/park/yol renkleri stil dosyasından
  // gelir, raster PNG'ye gömülü değil). Ücretsiz/anahtarsız ($0). Stil async
  // yüklenir (StyleReader); yüklenene ya da başarısız olana kadar CartoDB
  // Voyager RASTER fallback gösterilir (harita boş kalmasın). Uydu/Arazi
  // modları raster kalır (bilinçli — Google da uyduyu raster gösterir).
  static const String _libertyStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  vmt.Style? _vectorStyle;
  // Vektör karonun kendi `poi` etiket katmanı ÇIKARILMIŞ tema (Google tarzı temiz
  // taban). O mekanlar bunun yerine kendi tıklanabilir POI katmanımızda gösterilir
  // (_omtPoiService). Filtre başarısızsa null → tam stil temasına düşülür.
  vtr.Theme? _vectorTheme;

  bool _showTransit    = false;
  bool _showCycling    = false;
  bool _showHiking     = false;
  bool _showTactile    = false;
  bool _showWheelchair = false;
  bool _showElevator   = false;
  bool _showParking    = false;   // Engelli otoparkı katmanı
  List<Polyline> _accessibilityPolylines = [];
  List<Polyline> _hikingPolylines        = [];   // Overpass yaya yolları
  List<Marker>   _accessibilityMarkers   = [];
  bool _isLoadingOverpass = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
    _initLocationOnStart();
    _loadVectorStyle();
  }

  /// OpenFreeMap Liberty vektör stilini async yükler (Google'a yakın palet).
  /// Yüklenene kadar Voyager raster fallback gösterilir; hata olursa fallback'te
  /// kalır (harita asla boş kalmaz — $0/anahtarsız katman kritik olmayan görsel
  /// iyileştirme). Ağ/servis KVKK açısından konum/kişisel veri taşımaz.
  Future<void> _loadVectorStyle() async {
    try {
      final style = await vmt.StyleReader(uri: _libertyStyleUrl).read();

      // Vektör karonun kendi `poi` etiketlerini gizle: stil JSON'ından
      // source-layer=='poi' katmanlarını çıkarıp temayı yeniden kur. O mekanlar
      // yerine kendi TIKLANABILIR POI katmanımızda gösterilir (_omtPoiService).
      // Sokak/mahalle/su adları KALIR (yalnız tekil POI etiketleri çıkar).
      vtr.Theme? filteredTheme;
      try {
        final resp = await http.get(Uri.parse(_libertyStyleUrl));
        if (resp.statusCode == 200) {
          final styleJson = json.decode(resp.body) as Map<String, dynamic>;
          final layers = styleJson['layers'];
          if (layers is List) {
            layers.removeWhere(
                (l) => l is Map && l['source-layer'] == 'poi');
            filteredTheme = vtr.ThemeReader().read(styleJson);
          }
        }
      } catch (_) {
        // Filtre başarısızsa tam temayla devam (poi etiketleri görünür kalır).
      }

      // OMT POI kaynağı: openmaptiles sağlayıcısını servise ver (aynı karolar).
      final provider = style.providers.tileProviderBySource['openmaptiles'] ??
          (style.providers.tileProviderBySource.isNotEmpty
              ? style.providers.tileProviderBySource.values.first
              : null);
      if (provider != null) _omtPoiService.setProvider(provider);

      if (!mounted) return;
      setState(() {
        _vectorStyle = style;
        _vectorTheme = filteredTheme;
      });

      // Stil geldi → görünür alanı yeniden çek ki OMT POI kaynağı da katılsın
      // (ilk çekim stil yüklenmeden olduysa OMT devre dışıydı). Diğer kaynaklar
      // bbox cache'inden döner (kota etkilenmez).
      if (_mapReady && _currentZoom >= _poiFetchMinZoom) {
        _fetchPoisForVisibleArea(_mapController.camera.visibleBounds,
            immediate: true);
      }
    } catch (_) {
      // Stil yüklenemezse (OpenFreeMap erişilemez vb.) raster Voyager'da kalınır
      // (_vectorStyle null → children'da TileLayer fallback'i çizilir).
    }
  }

  @override
  void dispose() {
    _moveAnimController?.dispose();
    _voiceSearch.cancel();
    _tts.stop();
    _searchService.dispose();
    _overpassPoiService.dispose();
    _foursquareService.dispose();
    _fsqPoiService.dispose();
    _omtPoiService.dispose();
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

    // Mesafe sıralaması + Overpass kategori araması için referans konum:
    // öncelik kullanıcının GPS konumu; yoksa (izin verilmemiş/henüz
    // çözülmemiş) haritanın baktığı MERKEZ (görünen alan). Böylece sıralama
    // HER ZAMAN çalışır — "en yakın en üstte" korunur, aksi hâlde konum
    // null iken sonuçlar sırasız kalıyordu. Harita hazır değilse Sakarya
    // merkezi fallback.
    final LatLng ref = _currentLocation ??
        (_mapReady ? _mapController.camera.center : _sakaryaCenter);

    _searchService.debouncedSearch(
      query: _searchController.text,
      // Sonuçlar bu konuma göre mesafe sıralanır (en yakın en üstte);
      // Overpass kategori araması da bu merkezden yapılır.
      userLat: ref.latitude,
      userLon: ref.longitude,
      onResult: (results) {
        if (mounted) setState(() => _nearbySuggestions = results);
      },
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
    );
  }

  /// Sesli arama mikrofonuna dokununca Aşikar sesli arama panelini açar
  /// (`VoiceSearchSheet`): dinleme/hata/canlı metin oradadır. Panel tanınan metni
  /// (veya seçilen öneriyi) döndürür → arama kutusuna yazılır → mevcut arama akışı
  /// (`_onSearchChanged` → debounce'lı Nominatim/Overpass) kendiliğinden tetiklenir.
  Future<void> _onVoiceSearchPressed() async {
    // Yönerge yalnızca görme desteğine ihtiyacı olan kullanıcıya sesli okunur.
    final speakPrompt = ref.read(visualSupportProvider).valueOrNull ?? false;
    final result = await showVoiceSearchSheet(
      context,
      service: _voiceSearch,
      tts: _tts,
      speakPrompt: speakPrompt,
      suggestions: _voiceSuggestions,
    );
    if (!mounted || result == null || result.isEmpty) return;

    // Metni yaz → _onSearchChanged listener'ı aramayı tetikler.
    setState(() => _isSearchActive = true);
    _searchController.text = result;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: result.length));
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

  /// Harita ilk açıldığında konumu **izin İSTEMEDEN** yükler.
  ///
  /// Kullanıcı daha önce (bir kerelik) konum iznini verdiyse, açılışta tekrar
  /// sistem izin diyaloğu göstermeden konumuna ortalar: önce hızlı **son bilinen
  /// konum** (cache'li → anında), ardından **güncel konumla** tazeler. İzin
  /// verilmemişse hiçbir şey yapmaz — harita Sakarya merkezinde kalır (fallback).
  /// "Konumum" butonu (`_getCurrentLocation`) izin isteme akışını korur.
  Future<void> _initLocationOnStart() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      // İzin İSTEME — yalnızca mevcut durumu kontrol et.
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return;

      // Hızlı: son bilinen konum (cache'li) → anında ortala.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _applyStartLocation(LatLng(last.latitude, last.longitude));
      }

      // Kesin: güncel konumla tazele (son bilinen yoksa/eskiyse düzeltir).
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _applyStartLocation(LatLng(current.latitude, current.longitude));
      }
    } catch (_) {
      // Açılışta konum kritik değil; hata olursa Sakarya merkezi gösterilir.
    }
  }

  /// Açılış konumunu uygular: kullanıcı marker'ını günceller ve harita hazırsa
  /// oraya **yumuşak** taşır. Harita henüz hazır değilse `onMapReady` taşır.
  void _applyStartLocation(LatLng pos) {
    setState(() => _currentLocation = pos);
    if (_mapReady) {
      _animatedMapMove(pos, 16.0, onFinished: _fetchPoisAfterMove);
    }
  }

  /// Haritayı hedefe **yumuşak** taşır (ani sıçrama yerine kayan geçiş).
  /// flutter_map yerleşik animasyon sunmaz; `Tween` + `AnimationController` ile
  /// her karede `move` çağrılır. Devam eden bir geçiş varsa iptal edilir.
  /// [onFinished] yalnızca animasyon **tamamlanınca** (iptal değil) çağrılır.
  void _animatedMapMove(
    LatLng dest,
    double destZoom, {
    Duration duration = const Duration(milliseconds: 700),
    VoidCallback? onFinished,
  }) {
    // Önceki geçişi iptal et (üst üste binen animasyonlar titremesin).
    _moveAnimController?.dispose();

    final camera = _mapController.camera;
    final latTween =
        Tween<double>(begin: camera.center.latitude, end: dest.latitude);
    final lngTween =
        Tween<double>(begin: camera.center.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(duration: duration, vsync: this);
    _moveAnimController = controller;
    final anim = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
        zoomTween.evaluate(anim),
      );
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        if (identical(_moveAnimController, controller)) {
          _moveAnimController = null;
        }
        onFinished?.call();
      }
    });
    controller.forward();
  }

  /// Geçiş bittikten sonra hedef alandaki POI'leri çeker (zoom eşiği geçtiyse).
  void _fetchPoisAfterMove() {
    if (!mounted) return;
    if (_mapController.camera.zoom >= _poiFetchMinZoom) {
      _fetchPoisForVisibleArea(_mapController.camera.visibleBounds,
          immediate: true);
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

      _animatedMapMove(myPosition, 16.0);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınırken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firestore'daki gerçek venue verilerini Riverpod ile izle
    final venuesAsync = ref.watch(venuesStreamProvider);
    // Görme desteği tercihini sıcak tut (sesli arama yönergesi için) — böylece
    // mikrofona basıldığında ref.read yüklü değeri döndürür (bkz. _onVoiceSearchPressed).
    ref.watch(visualSupportProvider);

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Gövde = alt navigasyon çubuğunun ÜSTÜNDEKİ gerçek alan. Scaffold
          // klavye açılınca burayı küçülttüğü için bu yükseklik klavyeyi zaten
          // dışlar. Arama sonuç overlay'i bunu kullanıp klavye kapalıyken
          // alttaki boşluğa kadar uzar (bkz. SmartResultsOverlay).
          _mapBodyHeight = constraints.maxHeight;
          return Stack(
        children: [
          // 1. KATMAN: OpenStreetMap Haritası
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _sakaryaCenter,
              initialZoom: 15.0,
              maxZoom: 18.0,
              // Harita hazır: kamera artık projeksiyon (declutter) için kullanılabilir.
              // Zoom eşiği aşılmışsa ilk POI çekimini başlat.
              onMapReady: () {
                setState(() => _mapReady = true);
                // Açılışta konum çözüldüyse (izin önceden verilmiş) kullanıcı
                // konumuna **yumuşak** kay — harita hazır olmadan taşınamadığı
                // için burada. POI çekimi geçiş bitince (onFinished) yapılır.
                if (_currentLocation != null) {
                  _animatedMapMove(_currentLocation!, 16.0,
                      onFinished: _fetchPoisAfterMove);
                } else if (_mapController.camera.zoom >= _poiFetchMinZoom) {
                  _fetchPoisForVisibleArea(
                      _mapController.camera.visibleBounds,
                      immediate: true);
                }
              },
              onTap: (tapPosition, point) {
                if (_isSearchActive) {
                  setState(() => _isSearchActive = false);
                  return;
                }
                // OSM POI'ye tıklanıp tıklanmadığını kontrol et
                final tappedPoi = _findTappedPoi(point);
                if (tappedPoi != null) {
                  _onOsmPoiTapped(tappedPoi);
                  return;
                }
                _onMapTapped(point, _allVenues);
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  final zoom = event.camera.zoom;
                  // Hareket bitince setState → build declutter'ı yeni kamerayla
                  // yeniden hesaplar (isim/nokta yerleşimi güncellenir).
                  setState(() => _currentZoom = zoom);
                  if (zoom >= _poiFetchMinZoom) {
                    _fetchPoisForVisibleArea(event.camera.visibleBounds);
                  } else {
                    // Şehir ölçeğine inince POI'leri temizle (harita boş kalsın).
                    setState(() => _osmPois = []);
                  }
                }
              },
            ),
            children: [
              // ── Temel harita katmanı ──────────────────────────────────
              // Varsayılan mod: OpenFreeMap Liberty VEKTÖR karo (Google'a yakın
              // palet, $0/anahtarsız). Stil henüz yüklenmediyse (ya da yüklenemediyse)
              // CartoDB Voyager RASTER fallback — harita boş kalmaz. Uydu/Arazi
              // modları her zaman raster.
              if (_mapType == _MapType.defaultMap && _vectorStyle != null)
                vmt.VectorTileLayer(
                  tileProviders: _vectorStyle!.providers,
                  // poi etiketleri çıkarılmış tema (varsa); değilse tam stil.
                  theme: _vectorTheme ?? _vectorStyle!.theme,
                  sprites: _vectorStyle!.sprites,
                  // Kaynak maxzoom'u 14; harita 18'e kadar overzoom eder.
                  maximumZoom: 18,
                )
              else
                TileLayer(
                  urlTemplate: _baseTileUrl,
                  subdomains: _mapType == _MapType.defaultMap
                      ? const ['a', 'b', 'c', 'd']
                      : const [],
                  userAgentPackageName:
                      'com.example.asikar_engelsiz_kent_rehberi',
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
              // ── OSM POI Marker'ları — Google tarzı kademeli görünürlük ──
              // Declutter (map/poi_declutter.dart) her POI için isim / nokta /
              // gizli kararı verir: öncelikli (map/poi_priority.dart) mekanlar
              // ismini korur, çakışanlar noktaya düşer, sığmayan gizlenir.
              // Böylece uzakta az mekan, yaklaşınca daha fazlası isimle belirir.
              if (_osmPois.isNotEmpty && _mapReady && _currentZoom >= _poiFetchMinZoom)
                MarkerLayer(
                  markers: _buildPoiMarkers(),
                ),
              // Firestore'daki gerçek venue'lar → Dinamik Marker'lar
              venuesAsync.when(
                data: (venues) {
                  _allVenues = venues;
                  final colorFn = MapVisuals.accessibilityLevelColor;
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
                          // Alan boşken: sesli arama mikrofonu (dokununca panel
                          // açılır). Metin varken: temizle (×).
                          (_isSearchFieldEmpty
                              ? VoiceSearchButton(
                                  isListening: false,
                                  onTap: _onVoiceSearchPressed,
                                )
                              : IconButton(
                                  icon: const Icon(Icons.close,
                                      color: AppColors.outline),
                                  onPressed: () => _searchController.clear(),
                                ))
                        else
                          // Arama açılmadan önce de sesli arama mikrofonu
                          // (dokununca panel açılır — aktif haldekiyle aynı).
                          VoiceSearchButton(
                            isListening: false,
                            onTap: _onVoiceSearchPressed,
                          ),
                      ],
                    ),
                  ),
                ),
                // NOT: Sesli arama dinleme göstergesi artık VoiceSearchSheet
                // panelinde (nabız animasyonu + canlı metin + liveRegion durum).
                // NOT: Erişilebilirlik filtre çipleri (Tekerlekli Sandalye /
                // Hissedilebilir Yüzey / Asansör / Engelli Otoparkı) buradan
                // kaldırıldı — aynı katmanlar harita filtreleme modalında
                // (_showLayerPicker) yer alıyor; arama akışında tekrar
                // gösterilmiyordu (2026-07-02).
              ],
            ),
          ),

          // 2b. KATMAN: POI Kategori Filtresi (her zaman görünür — arama ve seçim modu dışında)
          if (!_isSearchActive && !_isPlaceSelected)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: OverpassPoiService.quickFilterCategories.map((cat) {
                    return _buildPoiCategoryChip(cat);
                  }).toList(),
                ),
              ),
            ),

          // 3. KATMAN: Arama Sonuçları
          // bottom VERİLMEZ: dikey kısıt gevşek kalır ki overlay içeriği kadar
          // yükselsin (yükseklik/scroll tavanı SmartResultsOverlay içinde,
          // gövde yüksekliğine göre: klavye kapalıyken alttaki boşluğa kadar
          // uzar). bottom eklemek paneli tekrar tüm ekrana yayar.
          if (_isSearchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 16,
              right: 16,
              child: _buildSmartResultsOverlay(),
            ),

          // 4. KATMAN: Konumum Butonu (yol tarifi FAB'ının üstünde)
          if (!_isSearchActive && !_isPlaceSelected)
            Positioned(
              bottom: 100,
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

          // 4a2. KATMAN: Yol Tarifi FAB (konum butonunun ALTINDA) — hedef seçme
          // ekranını (DirectionsSearchScreen) açar.
          if (!_isSearchActive && !_isPlaceSelected)
            Positioned(
              bottom: 32,
              right: 16,
              child: Semantics(
                button: true,
                label: 'Yol tarifi',
                child: Material(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 4,
                  shadowColor: Colors.black38,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.directions),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.directions, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),

          // 4b. KATMAN: Harita Türü / Katman Seçici Butonu
          if (!_isSearchActive)
            Positioned(
              right: 16,
              bottom: _isPlaceSelected ? 260 : 168,
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

          // 4c. Yükleniyor göstergesi (Overpass veya POI) — katman butonu hizasında
          if (_isLoadingOverpass || _isLoadingPois)
            Positioned(
              bottom: _isPlaceSelected ? 260 : 168,
              right: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingPois ? 'Mekanlar yükleniyor...' : 'OSM verisi yükleniyor...',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),

          // 4d. KATMAN: Veri kaynağı atıfları (Foursquare + OSM) — lisans zorunlu.
          // Bottom-left: sağdaki FAB'larla çakışmaz. Arama açıkken cam panel
          // haritayı örttüğü için gizlenir. Kaynak ekranda görünürse atıf görünür:
          //   - Foursquare: haritada FSQ kaynaklı POI varsa.
          //   - OSM: temel karo OSM türevliyse (varsayılan/arazi) VEYA OSM POI varsa;
          //     Esri uydu karolarında yalnız FSQ varsa OSM atfı gösterilmez (yanlış beyan olmasın).
          if (!_isSearchActive)
            Positioned(
              left: 8,
              bottom: 8,
              child: MapAttributionBadge(
                showFoursquare: _osmPois.any((p) => p.isFoursquare),
                showOsm: _mapType != _MapType.satellite ||
                    _osmPois.any((p) => !p.isFoursquare),
                // Varsayılan vektör taban (OpenFreeMap Liberty) aktifken
                // OpenMapTiles atfı da zorunlu.
                showOpenMapTiles:
                    _mapType == _MapType.defaultMap && _vectorStyle != null,
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
                if (_selectedVenue != null) {
                  return VenueSheet(
                    scrollController: scrollController,
                    venue: _selectedVenue!,
                    onClose: () => setState(() {
                      _isPlaceSelected = false;
                      _selectedVenue = null;
                      _tappedPoint = null;
                    }),
                  );
                } else if (_selectedOsmPoi != null) {
                  return OsmPoiSheet(
                    scrollController: scrollController,
                    poi: _selectedOsmPoi!,
                    onClose: () => setState(() {
                      _isPlaceSelected = false;
                      _selectedOsmPoi = null;
                      _tappedPoint = null;
                    }),
                  );
                } else {
                  return _buildUnknownPointSheet(scrollController);
                }
              },
            ),
        ],
          );
        },
      ),
    );
  }

  // ─── Bilinmeyen koordinat sheet'i ──────────────────────────────────────────
  // Sunum UnknownPointSheet'e taşındı (lib/screens/map/unknown_point_sheet.dart);
  // kapatma + yol tarifi (Navigator/setState) state'e bağlı olduğu için burada bağlanır.
  Widget _buildUnknownPointSheet(ScrollController sc) {
    return UnknownPointSheet(
      scrollController: sc,
      isLoadingAddress: _isLoadingTapInfo,
      address: _tappedAddress,
      point: _tappedPoint,
      onClose: () => setState(() {
        _isPlaceSelected = false;
        _tappedPoint = null;
        _tappedAddress = '';
      }),
      onDirections: _tappedPoint == null
          ? null
          : () => Navigator.pushNamed(
                context,
                AppRoutes.routeScreen,
                arguments: {
                  'destinationName': _tappedAddress.isNotEmpty
                      ? _tappedAddress.split(',').first
                      : 'Seçilen Konum',
                  'destinationLocation': _tappedPoint!,
                },
              ),
    );
  }

  // Sunum SmartResultsOverlay'e taşındı (lib/screens/map/smart_results_overlay.dart);
  // liste verisi + öğe dokunma callback'i burada bağlanır.
  Widget _buildSmartResultsOverlay() {
    return SmartResultsOverlay(
      isSearchFieldEmpty: _isSearchFieldEmpty,
      isLoading: _isLoading,
      items: _isSearchFieldEmpty ? _recentSearches : _nearbySuggestions,
      onItemTap: _onSearchItemTapped,
      onClearHistory: _clearRecentSearches,
      availableHeight: _mapBodyHeight > 0 ? _mapBodyHeight : null,
    );
  }

  /// "Temizle" — kullanıcının kayıtlı arama geçmişini siler (prefs + ekran).
  Future<void> _clearRecentSearches() async {
    await _settingsService?.clearRecentMapSearches();
    if (mounted) setState(() => _recentSearches = []);
  }

  // Arama sonucu/son arama satırına dokunulunca: konuma git + son aramayı kaydet.
  // (Eski _buildSearchItem onTap gövdesi; sunum MapSearchItem'da, mantık burada.)
  Future<void> _onSearchItemTapped(Map<String, dynamic> item) async {
    final title = item['title'] as String;
    final subtitle = item['subtitle'] as String;
    final lat = item['lat'] as double?;
    final lon = item['lon'] as double?;

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
          // Listeyi hemen güncelle (uygulama kapatılıp açılmadan gözükecek).
          // Sınır SettingsService.addRecentMapSearch ile aynı (maks. 15) —
          // overlay kaydırılabilir olduğundan klavye kapalıyken daha fazlası görünür.
          _recentSearches.removeWhere((e) => e['title'] == title);
          _recentSearches.insert(0, {...entry, 'type': 'recent'});
          if (_recentSearches.length > 15) {
            _recentSearches.removeRange(15, _recentSearches.length);
          }
        });
      }
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
        // Yalnızca FALLBACK: vektör stil (OpenFreeMap Liberty) yüklenene ya da
        // yüklenemezse gösterilir. Voyager Google'a en yakın ücretsiz raster
        // stildir → boşken bile tutarlı görünüm (bkz. _loadVectorStyle).
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
    // Saf bbox + sorgu üretimi: lib/services/overpass_query_builder.dart (birim testli)
    final bb = overpassBoundingBox(center.latitude, center.longitude,
        latDelta: 0.012, lonDelta: 0.016);
    final query = hikingOverpassQuery(bb);

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
                ? AppColors.mapSteps.withValues(alpha: 0.80)
                : AppColors.mapFootway.withValues(alpha: 0.75),
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
    if (!_showTactile && !_showWheelchair && !_showElevator && !_showParking) {
      setState(() {
        _accessibilityPolylines = [];
        _accessibilityMarkers   = [];
      });
      return;
    }

    setState(() => _isLoadingOverpass = true);

    final center = _mapController.camera.center;
    // Saf bbox + sorgu üretimi: lib/services/overpass_query_builder.dart (birim testli)
    final bb = overpassBoundingBox(center.latitude, center.longitude,
        latDelta: 0.015, lonDelta: 0.020);
    final query = accessibilityOverpassQuery(bb,
        tactile: _showTactile,
        wheelchair: _showWheelchair,
        elevator: _showElevator,
        parking: _showParking);

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
            color = AppColors.mapWheelchair;  // Mavi — tekerlekli sandalye yolu
          } else if (isTactile && _showTactile) {
            color = AppColors.poiTactile;  // Mor — hissedilebilir yüzey yolu
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
          // Sadece gerçekten tag'li node'ları marker yap.
          // Engelli otoparkı, wheelchair=yes/designated tag'li de olabilir; bu
          // yüzden parking kontrolü wheelchair'dan ÖNCE gelir (aksi hâlde
          // otopark node'u tekerlekli sandalye markerı gibi görünürdü).
          final isParkingNode    = (tags['amenity'] == 'parking' || tags['amenity'] == 'parking_space') &&
              (tags['wheelchair'] == 'yes' || tags['wheelchair'] == 'designated') && _showParking;
          final isWheelchairNode = !isParkingNode &&
              (tags['wheelchair'] == 'yes' || tags['wheelchair'] == 'designated') && _showWheelchair;
          final isTactileNode    = tags['tactile_paving'] == 'yes' && _showTactile;
          final isElevator       = (tags['highway'] == 'elevator' || tags['railway'] == 'elevator') && _showElevator;

          if (!isWheelchairNode && !isTactileNode && !isElevator && !isParkingNode) continue;

          Color markerColor;
          IconData markerIcon;
          if (isElevator) {
            markerColor = AppColors.mapElevator; // Cyan — asansör
            markerIcon  = Icons.elevator;
          } else if (isParkingNode) {
            markerColor = AppColors.mapParking; // İndigo — engelli otoparkı
            markerIcon  = Icons.local_parking;
          } else if (isWheelchairNode) {
            markerColor = AppColors.mapWheelchair; // Mavi — tekerlekli sandalye mekanı
            markerIcon  = Icons.accessible;
          } else {
            markerColor = AppColors.poiTactile; // Mor — hissedilebilir yüzey noktası
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
                        'Varsayılan', Icons.map_outlined, AppColors.mapTypeDefault),
                    const SizedBox(width: 10),
                    _buildMapTypeCard(setModalState, _MapType.satellite,
                        'Uydu', Icons.satellite_alt, AppColors.mapTypeSatellite),
                    const SizedBox(width: 10),
                    _buildMapTypeCard(setModalState, _MapType.terrain,
                        'Arazi', Icons.terrain, AppColors.mapTypeTerrain),
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
                      Icons.directions_transit_filled, AppColors.mapTransit, _showTransit,
                    ),
                    _buildOverlayChip(
                      setModalState, 'cycling', 'Bisiklet',
                      Icons.pedal_bike, AppColors.mapCycling, _showCycling,
                    ),
                    _buildOverlayChip(
                      setModalState, 'hiking', 'Yürüyüş Yolları',
                      Icons.directions_walk, AppColors.mapFootway, _showHiking,
                    ),
                    _buildOverlayChip(
                      setModalState, 'tactile', 'Hissedilebilir\nYüzey',
                      Icons.texture, AppColors.poiTactile, _showTactile,
                    ),
                    _buildOverlayChip(
                      setModalState, 'wheelchair', 'Tekerlekli\nSandalye',
                      Icons.accessible_forward, AppColors.mapWheelchair, _showWheelchair,
                    ),
                    _buildOverlayChip(
                      setModalState, 'elevator', 'Asansör',
                      Icons.elevator, AppColors.mapElevator, _showElevator,
                    ),
                    _buildOverlayChip(
                      setModalState, 'parking', 'Engelli\nOtoparkı',
                      Icons.local_parking, AppColors.mapParking, _showParking,
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

  // Sunum MapTypeCard'a taşındı (lib/screens/map/map_type_card.dart);
  // seçim (setState + setModalState) burada bağlanır. Row içinde olduğu için Expanded.
  Widget _buildMapTypeCard(StateSetter setModalState, _MapType type,
      String label, IconData icon, Color color) {
    return Expanded(
      child: MapTypeCard(
        label: label,
        icon: icon,
        color: color,
        selected: _mapType == type,
        onTap: () {
          setState(() => _mapType = type);
          setModalState(() {});
        },
      ),
    );
  }

  // Sunum MapOverlayChip'e taşındı (lib/screens/map/map_overlay_chip.dart);
  // bayrak toggle + Overpass katman çekme (yan etki) burada kalır.
  Widget _buildOverlayChip(StateSetter setModalState, String key, String label,
      IconData icon, Color color, bool isActive) {
    return MapOverlayChip(
      label: label,
      icon: icon,
      color: color,
      isActive: isActive,
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
            case 'parking':
              _showParking = !_showParking;
              _fetchOverpassLayer();
              break;
          }
        });
        setModalState(() {});
      },
    );
  }

  // ─── Overpass + Foursquare hibrit POI çekme ───────────────────────────────
  // [immediate] true ise 800ms debounce atlanır (ilk açılış / onMapReady için).
  void _fetchPoisForVisibleArea(LatLngBounds bounds, {bool immediate = false}) {
    final center = bounds.center;

    // Bounding box köşegen yarıçapını metre cinsinden hesapla (Foursquare için)
    final diagonalMeters = const Distance().as(
      LengthUnit.Meter,
      bounds.southWest,
      bounds.northEast,
    );
    final radiusMeters = (diagonalMeters / 2).round().clamp(300, 3000);

    // Filtre seçili değilse 21/12 kategorinin TAMAMI yerine sık kullanılan 7
    // kategoriyle sorgula — Overpass/Foursquare yanıtı çok daha hızlı, kota korunur.
    final effectiveCategories = _selectedPoiCategories.isEmpty
        ? OverpassPoiService.quickFilterCategories.toSet()
        : _selectedPoiCategories;

    // Dört kaynak ayrı biter; gösterge hepsi bitince kapanır. Taban katmanı
    // (fsq_os) yalnızca backend yapılandırılmışsa; OMT yalnızca vektör stil
    // yüklenip sağlayıcı hazırsa yüklenir.
    _overpassLoading = true;
    _fsqLoading = true;
    _fsqOsLoading = _fsqPoiService.isEnabled;
    _omtLoading = _omtPoiService.isEnabled;
    if (mounted) setState(() => _isLoadingPois = true);

    void syncLoading() {
      if (mounted) {
        setState(() => _isLoadingPois = _overpassLoading ||
            _fsqLoading ||
            _fsqOsLoading ||
            _omtLoading);
      }
    }

    void onOverpassResult(List<OsmPoi> overpassPois) {
      if (!mounted) return;
      _overpassLoading = false;
      // _osmPois (canlı Foursquare + taban) öncelikli; Overpass boşlukları doldurur
      final merged = MapVisuals.mergePois(_osmPois, overpassPois);
      setState(() {
        _osmPois = merged;
        _isLoadingPois =
            _overpassLoading || _fsqLoading || _fsqOsLoading || _omtLoading;
      });
    }

    void onOverpassLoading(bool loading) {
      _overpassLoading = loading;
      syncLoading();
    }

    void onFsqResult(List<OsmPoi> fsqPois) {
      if (!mounted) return;
      _fsqLoading = false;
      // Canlı Foursquare en güncel veriyi verir → en yüksek öncelik
      final merged = MapVisuals.mergePois(fsqPois, _osmPois);
      setState(() {
        _osmPois = merged;
        _isLoadingPois =
            _overpassLoading || _fsqLoading || _fsqOsLoading || _omtLoading;
      });
    }

    void onFsqLoading(bool loading) {
      _fsqLoading = loading;
      syncLoading();
    }

    void onFsqOsResult(List<OsmPoi> basePois) {
      if (!mounted) return;
      _fsqOsLoading = false;
      // Taban katmanı boşlukları doldurur → mevcut (_osmPois) öncelikli kalır
      final merged = MapVisuals.mergePois(_osmPois, basePois);
      setState(() {
        _osmPois = merged;
        _isLoadingPois =
            _overpassLoading || _fsqLoading || _fsqOsLoading || _omtLoading;
      });
    }

    void onFsqOsLoading(bool loading) {
      _fsqOsLoading = loading;
      syncLoading();
    }

    void onOmtResult(List<OsmPoi> omtPois) {
      if (!mounted) return;
      _omtLoading = false;
      // OMT (OpenMapTiles = OSM verisi) boşluk doldurucu: mevcut (_osmPois)
      // öncelikli kalır, yalnız haritada görünüp de diğer kaynaklarda OLMAYAN
      // mekanları ekler (dedup MapVisuals.mergePois — koordinat + 40m isim).
      final merged = MapVisuals.mergePois(_osmPois, omtPois);
      setState(() {
        _osmPois = merged;
        _isLoadingPois =
            _overpassLoading || _fsqLoading || _fsqOsLoading || _omtLoading;
      });
    }

    void onOmtLoading(bool loading) {
      _omtLoading = loading;
      syncLoading();
    }

    if (immediate) {
      // Debounce atla — doğrudan çek (ilk yükleme gecikmesini kaldırır)
      _overpassPoiService.fetchPoisForBounds(
        bounds: bounds,
        selectedCategories: effectiveCategories,
        onResult: onOverpassResult,
        onLoadingChanged: onOverpassLoading,
      );
      _foursquareService.fetchNearby(
        centerLat: center.latitude,
        centerLon: center.longitude,
        selectedCategories: effectiveCategories,
        radiusMeters: radiusMeters,
        onResult: onFsqResult,
        onLoadingChanged: onFsqLoading,
      );
      _fsqPoiService.fetchForBounds(
        bounds: bounds,
        selectedCategories: effectiveCategories,
        onResult: onFsqOsResult,
        onLoadingChanged: onFsqOsLoading,
      );
      _omtPoiService.fetchForBounds(
        bounds: bounds,
        onResult: onOmtResult,
        onLoadingChanged: onOmtLoading,
      );
      return;
    }

    // Overpass: debounce ile (küçük haritalar + yollar için)
    _overpassPoiService.debouncedFetch(
      bounds: bounds,
      selectedCategories: effectiveCategories,
      onResult: onOverpassResult,
      onLoadingChanged: onOverpassLoading,
    );

    // Foursquare: güncel iş yeri verisi için (debounce ayrı, paralel çalışır)
    _foursquareService.debouncedFetch(
      centerLat: center.latitude,
      centerLon: center.longitude,
      selectedCategories: effectiveCategories,
      radiusMeters: radiusMeters,
      onResult: onFsqResult,
      onLoadingChanged: onFsqLoading,
    );

    // Taban katmanı (Türkiye geneli): en geniş kapsam, istek başına ücretsiz
    _fsqPoiService.debouncedFetch(
      bounds: bounds,
      selectedCategories: effectiveCategories,
      onResult: onFsqOsResult,
      onLoadingChanged: onFsqOsLoading,
    );

    // OpenMapTiles vektör karo POI'leri: haritada görünen ama diğer kaynaklarda
    // olmayan mekanları tıklanabilir yapar (aynı karolar, ekstra servis yok).
    _omtPoiService.debouncedFetch(
      bounds: bounds,
      onResult: onOmtResult,
      onLoadingChanged: onOmtLoading,
    );
  }

  // ─── OSM POI: Google tarzı kademeli marker üretimi ──────────────────────
  // _osmPois'i ekran-uzayına projekte edip declutter'a verir; sonuca göre
  // her POI'yi isim (PoiMarker) / nokta (PoiDot) olarak çizer, gizlileri atlar.
  List<Marker> _buildPoiMarkers() {
    final camera = _mapController.camera;

    // Öncelik sırasına göre kırp (çok yoğun bölgelerde relayout'u sınırla).
    var indices = List<int>.generate(_osmPois.length, (i) => i);
    if (indices.length > _poiDeclutterCap) {
      indices.sort(
          (a, b) => poiPriority(_osmPois[b].amenityType)
              .compareTo(poiPriority(_osmPois[a].amenityType)));
      indices = indices.sublist(0, _poiDeclutterCap);
    }

    // Ekran-uzayı declutter girdileri (zoom eşikleriyle kademeli görünürlük).
    final zoom = camera.zoom;
    final items = <DeclutterItem>[];
    for (final i in indices) {
      final poi = _osmPois[i];
      final anchor = camera
          .latLngToScreenOffset(LatLng(poi.latitude, poi.longitude));
      final pr = poiPriority(poi.amenityType);
      items.add(DeclutterItem(
        id: i,
        anchor: anchor,
        priority: pr,
        canLabel: zoom >= poiLabelMinZoom(pr),
        canDot: zoom >= poiDotMinZoom(pr),
        labelSize: Size(_estimateLabelWidth(poi), PoiMarker.height),
      ));
    }

    final modes = declutterPois(items, viewport: camera.size);

    final markers = <Marker>[];
    for (final i in indices) {
      final mode = modes[i];
      if (mode == null || mode == PoiRenderMode.hidden) continue;
      final poi = _osmPois[i];
      final isSelected = _selectedOsmPoi?.uniqueKey == poi.uniqueKey;
      // Seçili POI çakışmada gizlenmiş olsa bile isim olarak gösterilsin.
      final asLabel = mode == PoiRenderMode.label || isSelected;
      markers.add(Marker(
        point: LatLng(poi.latitude, poi.longitude),
        width: asLabel ? PoiMarker.width : PoiDot.size,
        height: asLabel ? PoiMarker.height : PoiDot.size,
        child: GestureDetector(
          onTap: () => _onOsmPoiTapped(poi),
          child: asLabel
              ? PoiMarker(poi: poi, isSelected: isSelected)
              : PoiDot(poi: poi),
        ),
      ));
    }
    return markers;
  }

  // İsim etiketinin yaklaşık genişliği (px) — declutter çakışma kutusu için.
  // TextPainter yerine karakter tabanlı ucuz tahmin (her relayout'ta çalışır).
  double _estimateLabelWidth(OsmPoi poi) {
    final label = poi.name.isEmpty ? poi.category : poi.name;
    // fontSize 10, w600 ≈ 6px/karakter + ikon/padding payı; 28–140 arası kırp.
    return (label.length * 6.0 + 24).clamp(28.0, 140.0);
  }

  // ─── OSM POI: Tıklanan POI'yi bul (yakınlık kontrolü) ────────────────────
  OsmPoi? _findTappedPoi(LatLng point) {
    if (_osmPois.isEmpty) return null;
    OsmPoi? nearest;
    double minDist = double.infinity;
    for (final poi in _osmPois) {
      final d = const Distance().as(
        LengthUnit.Meter,
        point,
        LatLng(poi.latitude, poi.longitude),
      );
      if (d < minDist) {
        minDist = d;
        nearest = poi;
      }
    }
    // 50m yakınlık eşiği
    if (nearest != null && minDist < 50) return nearest;
    return null;
  }

  // ─── OSM POI: Tıklama handler ────────────────────────────────────────────
  void _onOsmPoiTapped(OsmPoi poi) {
    setState(() {
      _isSearchActive = false;
      _isPlaceSelected = true;
      _selectedVenue = null;
      _selectedOsmPoi = poi;
      _tappedPoint = LatLng(poi.latitude, poi.longitude);
      _tappedAddress = poi.address ?? '';
    });
    _mapController.move(LatLng(poi.latitude, poi.longitude), 16.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.45,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  // ─── POI Kategori Filtre Chip'i ──────────────────────────────────────────
  Widget _buildPoiCategoryChip(String category) {
    final isSelected = _selectedPoiCategories.contains(category);
    final iconData = MapVisuals.poiIcon(
      OverpassPoiService.categoryFilters.entries
          .firstWhere((e) => e.key == category,
              orElse: () => const MapEntry('Mekan', ''))
          .key
          .toLowerCase()
          .replaceAll(' ', '_'),
    );
    // Daha anlamlı ikon eşleştirmesi
    IconData chipIcon;
    switch (category) {
      case 'Kafe':       chipIcon = Icons.coffee; break;
      case 'Restoran':   chipIcon = Icons.restaurant; break;
      case 'Eczane':     chipIcon = Icons.local_pharmacy; break;
      case 'Market':     chipIcon = Icons.shopping_cart; break;
      case 'Hastane':    chipIcon = Icons.local_hospital; break;
      case 'Otel':       chipIcon = Icons.hotel; break;
      case 'Park':       chipIcon = Icons.park; break;
      default:           chipIcon = iconData;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedPoiCategories.remove(category);
            } else {
              _selectedPoiCategories.add(category);
            }
          });
          // Kategori değiştiğinde cache'i temizle ve yeniden çek
          _overpassPoiService.clearCache();
          // Zoom eşiğin altındaysa önce eşiğe yaklaştır (POI'ler görünsün), sonra çek
          if (_currentZoom < _poiFetchMinZoom) {
            _mapController.move(_mapController.camera.center, _poiFetchMinZoom);
            setState(() => _currentZoom = _poiFetchMinZoom);
          }
          final bounds = _mapController.camera.visibleBounds;
          _fetchPoisForVisibleArea(bounds);
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chipIcon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.outline),
              const SizedBox(width: 6),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
