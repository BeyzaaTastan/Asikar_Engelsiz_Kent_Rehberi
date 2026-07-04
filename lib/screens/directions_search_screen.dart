import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';
import '../services/map_search_service.dart';
import '../services/settings_service.dart';
import 'map/map_search_item.dart';
import 'map/map_visuals.dart';
import '../widgets/route_endpoints_card.dart';

/// Google Haritalar tarzı **yön tarifi / başlangıç-varış seçme** ekranı (Aşikar'a
/// özel).
///
/// Haritadaki yol tarifi FAB'ından açılır. **Hem başlangıç hem varış**
/// düzenlenebilir arama alanıdır: başlangıç varsayılan "Konumunuz" (GPS), üstüne
/// dokununca "Başlangıç noktası seçin" olarak aranabilir; varış "Varış noktası
/// seçin". Sağdaki **↑↓ butonu** ikisini yer değiştirir. Ulaşım modu (Yürüyüş /
/// Tekerlekli Sandalye / Taşıt) seçilir; iki uç da belirlenince `RouteScreen`'e
/// geçilir ve rota çizilir.
///
/// Arama/son-arama map_screen ile aynı servisleri yeniden kullanır — çatallamaz.
/// (bkz. vault/01-Frontend/01-On-Yuz.md · "Rota / yol tarifi".)
class DirectionsSearchScreen extends StatefulWidget {
  /// Mevcut bir rotayı düzenlemek için başlangıç değerleri (RouteScreen'de
  /// konuma dokununca gelir). `*Location` null + isim "Konumunuz" → anlık konum.
  final String? initialOriginName;
  final LatLng? initialOriginLocation;
  final String? initialDestName;
  final LatLng? initialDestLocation;

  /// Açılışta odaklanacak alan ('origin' / 'destination'). Varsayılan varış.
  final String? focusField;
  final int initialModeIndex;

  const DirectionsSearchScreen({
    super.key,
    this.initialOriginName,
    this.initialOriginLocation,
    this.initialDestName,
    this.initialDestLocation,
    this.focusField,
    this.initialModeIndex = 0,
  });

  @override
  State<DirectionsSearchScreen> createState() => _DirectionsSearchScreenState();
}

enum _Field { origin, destination }

// Ulaşım modu — RouteScreen'deki _modes sırasıyla AYNI index (0/1/2).
class _Mode {
  final String label;
  final IconData icon;
  const _Mode(this.label, this.icon);
}

const List<_Mode> _kModes = [
  _Mode('Yürüyüş', Icons.directions_walk),
  _Mode('Tekerlekli Sandalye', Icons.accessible_forward),
  _Mode('Taşıt', Icons.directions_bus),
];

const String _kCurrentLabel = 'Konumunuz';

class _DirectionsSearchScreenState extends State<DirectionsSearchScreen> {
  final TextEditingController _originCtrl =
      TextEditingController(text: _kCurrentLabel);
  final TextEditingController _destCtrl = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  final MapSearchService _searchService = MapSearchService();
  SettingsService? _settings;

  // Uç noktalar: "current" (Konumunuz/GPS) veya çözülmüş koordinat.
  bool _originIsCurrent = true;
  LatLng? _originLoc;
  bool _destIsCurrent = false;
  LatLng? _destLoc;

  _Field _active = _Field.destination;
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  int _modeIndex = 0;

  // Programatik metin değişiminde dinleyicinin arama tetiklemesini engeller.
  bool _suppressSearch = false;

  bool get _originReady => _originIsCurrent || _originLoc != null;
  bool get _destReady => _destIsCurrent || _destLoc != null;

  /// Aktif alanın arama sorgusu ("current" uç → boş → son aramalar gösterilir).
  String get _activeQuery {
    if (_active == _Field.origin) {
      return _originIsCurrent ? '' : _originCtrl.text.trim();
    }
    return _destIsCurrent ? '' : _destCtrl.text.trim();
  }

  @override
  void initState() {
    super.initState();
    _modeIndex = widget.initialModeIndex.clamp(0, _kModes.length - 1);
    _applySeed(); // dinleyicilerden ÖNCE (metin ataması arama tetiklemesin)
    _active =
        widget.focusField == 'origin' ? _Field.origin : _Field.destination;
    _loadRecent();
    _originCtrl.addListener(_onOriginChanged);
    _destCtrl.addListener(_onDestChanged);
    _originFocus.addListener(_onOriginFocus);
    _destFocus.addListener(_onDestFocus);
  }

  /// RouteScreen'den düzenleme için gelen başlangıç/varış değerlerini uygular.
  void _applySeed() {
    if (widget.initialOriginName != null) {
      _originIsCurrent = widget.initialOriginLocation == null;
      _originLoc = widget.initialOriginLocation;
      _originCtrl.text =
          _originIsCurrent ? _kCurrentLabel : widget.initialOriginName!;
    }
    if (widget.initialDestName != null) {
      _destIsCurrent = widget.initialDestLocation == null;
      _destLoc = widget.initialDestLocation;
      _destCtrl.text =
          _destIsCurrent ? _kCurrentLabel : widget.initialDestName!;
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    _searchService.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final service = await SettingsService.create();
    if (mounted) {
      setState(() {
        _settings = service;
        _recent = service.recentMapSearchesParsed;
      });
    }
  }

  void _onOriginFocus() {
    if (_originFocus.hasFocus) {
      // "Konumunuz" alanına dokununca metni temizle (kullanıcı yeni yer yazsın);
      // _originIsCurrent korunur → boş bırakılırsa geri döner. Gerçek bir yer
      // varsa hepsini seç (kolay değiştirilsin).
      if (_originIsCurrent) {
        _setText(_originCtrl, '');
      } else if (_originCtrl.text.isNotEmpty) {
        _originCtrl.selection = TextSelection(
            baseOffset: 0, extentOffset: _originCtrl.text.length);
      }
      _activateField(_Field.origin);
    } else if (_originCtrl.text.trim().isEmpty) {
      // Odak kaybı + boş → varsayılan "Konumunuz"a dön (her zaman geçerli başlangıç).
      _suppressSearch = true;
      _originCtrl.text = _kCurrentLabel;
      _suppressSearch = false;
      setState(() {
        _originIsCurrent = true;
        _originLoc = null;
      });
    }
  }

  void _onDestFocus() {
    if (_destFocus.hasFocus) {
      // Swap sonrası varış "Konumunuz" olabilir → dokununca temizle. Gerçek bir
      // yer varsa hepsini seç (kolay değiştirilsin).
      if (_destIsCurrent) {
        _setText(_destCtrl, '');
      } else if (_destCtrl.text.isNotEmpty) {
        _destCtrl.selection = TextSelection(
            baseOffset: 0, extentOffset: _destCtrl.text.length);
      }
      _activateField(_Field.destination);
    }
  }

  void _activateField(_Field field) {
    setState(() {
      _active = field;
      _results = []; // diğer alanın sonuçları taşınmasın
    });
    if (_activeQuery.isNotEmpty) _runSearch();
  }

  void _onOriginChanged() {
    if (_suppressSearch) return;
    if (_originIsCurrent && _originCtrl.text != _kCurrentLabel) {
      _originIsCurrent = false;
    }
    if (_active == _Field.origin) _runSearch();
    setState(() {});
  }

  void _onDestChanged() {
    if (_suppressSearch) return;
    if (_destIsCurrent && _destCtrl.text != _kCurrentLabel) {
      _destIsCurrent = false;
    }
    if (_active == _Field.destination) _runSearch();
    setState(() {});
  }

  void _runSearch() {
    final query = _activeQuery;
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    _searchService.debouncedSearch(
      query: query,
      onResult: (results) {
        if (mounted) setState(() => _results = results);
      },
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
    );
  }

  /// Programatik metin yaz (dinleyici arama tetiklemesin).
  void _setText(TextEditingController ctrl, String text) {
    _suppressSearch = true;
    ctrl.text = text;
    _suppressSearch = false;
  }

  /// Listeden bir yer seçilince aktif alanı doldur; iki uç hazırsa rotaya geç,
  /// değilse eksik alana odaklan.
  Future<void> _onSelected(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? '';
    final lat = item['lat'] as double?;
    final lon = item['lon'] as double?;
    if (lat == null || lon == null) return;

    await _settings?.addRecentMapSearch({
      'title': title,
      'subtitle': item['subtitle'] ?? '',
      'lat': lat,
      'lon': lon,
      'type': 'recent',
    });
    if (!mounted) return;

    setState(() {
      if (_active == _Field.origin) {
        _setText(_originCtrl, title);
        _originIsCurrent = false;
        _originLoc = LatLng(lat, lon);
      } else {
        _setText(_destCtrl, title);
        _destIsCurrent = false;
        _destLoc = LatLng(lat, lon);
      }
      _results = [];
    });

    if (_originReady && _destReady) {
      _navigateToRoute();
    } else if (_active == _Field.origin) {
      _destFocus.requestFocus();
    } else {
      _originFocus.requestFocus();
    }
  }

  void _navigateToRoute() {
    FocusScope.of(context).unfocus();
    // pushReplacement → düzenleme döngüsü (route↔directions) düz kalır, yığılmaz.
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.routeScreen,
      arguments: {
        'destinationName': _destIsCurrent ? _kCurrentLabel : _destCtrl.text.trim(),
        'destinationLocation': _destIsCurrent ? null : _destLoc,
        'startName': _originIsCurrent ? _kCurrentLabel : _originCtrl.text.trim(),
        'startLocation': _originIsCurrent ? null : _originLoc,
        'initialModeIndex': _modeIndex,
      },
    );
  }

  /// Başlangıç ↔ varış yer değiştir.
  void _swap() {
    setState(() {
      final oText = _originCtrl.text;
      final oCur = _originIsCurrent;
      final oLoc = _originLoc;

      _setText(_originCtrl, _destCtrl.text);
      _originIsCurrent = _destIsCurrent;
      _originLoc = _destLoc;

      _setText(_destCtrl, oText);
      _destIsCurrent = oCur;
      _destLoc = oLoc;

      _results = [];
    });
    if (_activeQuery.isNotEmpty) _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final showRecent = _activeQuery.isEmpty;
    final items = showRecent ? _recent : _results;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildModeTabs(),
          SizedBox(
            height: 2,
            child: _isLoading
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.secondary,
                    backgroundColor: AppColors.divider,
                  )
                : const ColoredBox(color: AppColors.divider),
          ),
          Expanded(child: _buildList(items, showRecent)),
        ],
      ),
    );
  }

  // ─── Üst alan: ortak RouteEndpointsCard (RouteScreen ile aynı görünüm) ────
  Widget _buildHeader() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        bottom: false,
        child: RouteEndpointsCard(
          onBack: () => Navigator.pop(context),
          onSwap: _swap,
          originContent: _buildEndpointField(
            controller: _originCtrl,
            focusNode: _originFocus,
            hint: 'Başlangıç noktası seçin',
            highlight: _originIsCurrent,
            autofocus: widget.focusField == 'origin',
          ),
          destContent: _buildEndpointField(
            controller: _destCtrl,
            focusNode: _destFocus,
            hint: 'Varış noktası seçin',
            autofocus: widget.focusField != 'origin',
          ),
        ),
      ),
    );
  }

  /// Kart içindeki düzenlenebilir uç alanı (kenarlık kartta; burada border yok).
  /// Dikey ortalama: SİMETRİK dikey contentPadding (isDense/isCollapsed KULLANMA
  /// — textAlignVertical'ı bozup metni üste yaslıyor).
  Widget _buildEndpointField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool highlight = false,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        color: highlight ? AppColors.secondary : AppColors.surface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 16),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        suffixIcon: controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: () => controller.clear(),
                child: const Icon(Icons.close,
                    color: AppColors.outline, size: 22),
              ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 34, minHeight: 34),
      ),
    );
  }

  // ─── Ulaşım modu sekmeleri ───────────────────────────────────────────────
  Widget _buildModeTabs() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (int i = 0; i < _kModes.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _kModes.length - 1 ? 8 : 0),
                child: _buildModeTab(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeTab(int index) {
    final mode = _kModes[index];
    final selected = _modeIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} modu',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _modeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            mode.icon,
            color: selected ? Colors.white : AppColors.outline,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ─── Son aramalar / canlı sonuçlar listesi ───────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> items, bool showRecent) {
    if (showRecent && items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Yer yazın veya son aramalardan seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.outline, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 70, color: Colors.black12),
      itemBuilder: (context, index) {
        final item = items[index];
        return MapSearchItem(
          title: item['title'] ?? '',
          subtitle: item['subtitle'] ?? '',
          icon: MapVisuals.searchResultTypeIcon(item['type'] ?? ''),
          isRecent: showRecent,
          onTap: () => _onSelected(item),
        );
      },
    );
  }
}
