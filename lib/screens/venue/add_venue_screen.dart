import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/venue_model.dart';
import '../../services/venue_service.dart';

class AddVenueScreen extends StatefulWidget {
  const AddVenueScreen({super.key});

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> {
  final VenueService _venueService = VenueService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  String _selectedCategory = 'Park';
  String _selectedPresetDistrict = 'Adapazarı (Merkez)';

  final List<String> _categories = [
    'Park',
    'Alışveriş',
    'Tarihi Yer',
    'Kamu Binası',
    'Sosyal Alan',
    'Doğa'
  ];

  final Map<String, Map<String, double>> _districtPresets = {
    'Adapazarı (Merkez)': {'lat': 40.7731, 'lon': 30.3985},
    'Serdivan (Mavi Durak/Kampüs)': {'lat': 40.7630, 'lon': 30.3650},
    'Erenler': {'lat': 40.7600, 'lon': 30.4150},
    'Sapanca': {'lat': 40.6900, 'lon': 30.2600},
    'Akyazı': {'lat': 40.6800, 'lon': 30.6200},
    'Hendek': {'lat': 40.7900, 'lon': 30.7500},
    'Karasu': {'lat': 41.1000, 'lon': 30.7000},
    'Özel Koordinat Gir...': {'lat': 0.0, 'lon': 0.0},
  };

  final List<String> _allFeatures = [
    'Tekerlekli Sandalye Girişi',
    'Asansör',
    'Engelli Tuvaleti',
    'Engelli Otoparkı',
    'Hissedilebilir Yüzey',
    'Kabartma Yönlendirme',
    'Sesli Yönlendirme',
    'İşaret Dili Desteği',
  ];

  final List<String> _selectedFeatures = [];
  bool _isCustomCoordinate = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_selectedPresetDistrict);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _applyPreset(String districtName) {
    if (districtName == 'Özel Koordinat Gir...') {
      setState(() {
        _isCustomCoordinate = true;
        _latController.clear();
        _lonController.clear();
      });
    } else {
      setState(() {
        _isCustomCoordinate = false;
        final coords = _districtPresets[districtName]!;
        _latController.text = coords['lat']!.toString();
        _lonController.text = coords['lon']!.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primary,
        centerTitle: true,
        title: const Text(
          'Yeni Mekan Ekle',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mekan Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Name Input
                TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen mekan adını girin.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Mekan Adı',
                    labelStyle: const TextStyle(color: AppColors.outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    labelStyle: const TextStyle(color: AppColors.outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Address Input
                TextFormField(
                  controller: _addressController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen adresi girin.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Adres',
                    labelStyle: const TextStyle(color: AppColors.outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Description Input
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen mekan açıklaması girin.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Erişilebilirlik Açıklaması',
                    labelStyle: const TextStyle(color: AppColors.outline),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Location Presets
                const Text(
                  'Konum Bilgisi (Koordinatlar)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPresetDistrict,
                  decoration: InputDecoration(
                    labelText: 'İlçe / Bölge Seçimi',
                    labelStyle: const TextStyle(color: AppColors.outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _districtPresets.keys.map((preset) {
                    return DropdownMenuItem(value: preset, child: Text(preset));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPresetDistrict = val;
                      });
                      _applyPreset(val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Lat / Lon Inputs
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        readOnly: !_isCustomCoordinate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || double.tryParse(value) == null) {
                            return 'Geçersiz enlem';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Enlem (Lat)',
                          labelStyle: const TextStyle(color: AppColors.outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: _isCustomCoordinate ? Colors.white : Colors.grey.shade100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lonController,
                        readOnly: !_isCustomCoordinate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || double.tryParse(value) == null) {
                            return 'Geçersiz boylam';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Boylam (Lon)',
                          labelStyle: const TextStyle(color: AppColors.outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: _isCustomCoordinate ? Colors.white : Colors.grey.shade100,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Features Checklist
                const Text(
                  'Mevcut Erişilebilirlik Özellikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: _allFeatures.map((feat) {
                      final isChecked = _selectedFeatures.contains(feat);
                      return CheckboxListTile(
                        title: Text(
                          feat,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        activeColor: AppColors.primary,
                        value: isChecked,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedFeatures.add(feat);
                            } else {
                              _selectedFeatures.remove(feat);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );

                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          
                          final newVenue = VenueModel(
                            id: '',
                            name: _nameController.text.trim(),
                            category: _selectedCategory,
                            address: _addressController.text.trim(),
                            latitude: double.parse(_latController.text.trim()),
                            longitude: double.parse(_lonController.text.trim()),
                            description: _descriptionController.text.trim(),
                            accessibilityScore: 0, // Computed by service
                            features: _selectedFeatures,
                            images: [],
                            comments: [],
                            addedBy: currentUser?.uid ?? 'anonymous',
                            averageRating: 0.0,
                          );

                          await _venueService.addVenue(newVenue);

                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            Navigator.pop(context); // Go back to community screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mekan başarıyla topluluğa eklendi.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Mekanı Kaydet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
