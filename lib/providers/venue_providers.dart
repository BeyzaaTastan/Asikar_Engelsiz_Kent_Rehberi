import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/venue_model.dart';
import '../services/venue_service.dart';

final venueServiceProvider = Provider((ref) => VenueService());

final venuesStreamProvider = StreamProvider<List<VenueModel>>((ref) {
  return ref.watch(venueServiceProvider).streamVenues();
});

final venueSearchQueryProvider = StateProvider<String>((ref) => '');
final venueCategoryFilterProvider = StateProvider<String>((ref) => 'Tümü');
final venueAccessibilityFilterProvider = StateProvider<String>((ref) => 'Tümü');

final filteredVenuesProvider = Provider<AsyncValue<List<VenueModel>>>((ref) {
  final venuesAsync = ref.watch(venuesStreamProvider);
  final search = ref.watch(venueSearchQueryProvider);
  final cat = ref.watch(venueCategoryFilterProvider);
  final lvl = ref.watch(venueAccessibilityFilterProvider);

  return venuesAsync.whenData((venues) {
    return venues.where((venue) {
      final matchesQuery = venue.name.toLowerCase().contains(search.toLowerCase()) ||
          venue.address.toLowerCase().contains(search.toLowerCase());
      final matchesCategory = cat == 'Tümü' || venue.category == cat;
      final matchesLevel = lvl == 'Tümü' || venue.accessibilityLevel == lvl;
      return matchesQuery && matchesCategory && matchesLevel;
    }).toList();
  });
});

final venueDetailProvider = Provider.family<AsyncValue<VenueModel>, String>((ref, venueId) {
  final venuesAsync = ref.watch(venuesStreamProvider);
  return venuesAsync.whenData((venues) => venues.firstWhere((v) => v.id == venueId));
});
