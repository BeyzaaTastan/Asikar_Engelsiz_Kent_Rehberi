import 'package:flutter/material.dart';
import '../services/map_search_service.dart';
import '../constants/app_colors.dart';

class LocationSearchDialog extends StatefulWidget {
  final String title;

  const LocationSearchDialog({super.key, required this.title});

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final MapSearchService _searchService = MapSearchService();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchService.debouncedSearch(
      query: _searchController.text,
      onResult: (results) {
        if (mounted) setState(() => _results = results);
      },
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Başlık
            Text(
              "${widget.title} Konumunu Ayarla",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Arama Kutusu
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Adres, mekan, cadde arayın...",
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results.clear());
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Sonuç Listesi veya Yükleniyor Göstergesi
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? "Konum aramak için yazmaya başlayın"
                                : "Sonuç bulunamadı",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final place = _results[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: AppColors.tertiary),
                              title: Text(place['title']),
                              subtitle: Text(
                                place['subtitle'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                // Seçilen adresi geri döndür
                                Navigator.of(context).pop({
                                  'name': place['title'],
                                  'lat': place['lat'],
                                  'lng': place['lon'],
                                });
                              },
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
            
            // İptal Butonu
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("İptal"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
