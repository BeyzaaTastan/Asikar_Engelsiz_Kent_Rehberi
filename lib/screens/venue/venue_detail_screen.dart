import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../models/venue_model.dart';
import '../../services/venue_service.dart';
import '../../providers/venue_providers.dart';
import '../route_screen.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  final VenueService _venueService = VenueService();
  final _commentController = TextEditingController();
  double _userRating = 5.0;
  final List<String> _userVerifiedFeatures = [];

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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  Color _getUserTypeColor(String type) {
    switch (type) {
      case 'Engelli':
        return Colors.orange.shade700;
      case 'Gönüllü':
        return AppColors.tertiary;
      default:
        return AppColors.primary;
    }
  }

  void _showAddReviewBottomSheet(VenueModel venue) {
    _commentController.clear();
    _userRating = 5.0;
    _userVerifiedFeatures.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Değerlendir ve Yorum Yap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Star Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1.0;
                        return IconButton(
                          icon: Icon(
                            _userRating >= starValue ? Icons.star : Icons.star_border,
                            color: Colors.amber.shade600,
                            size: 36,
                          ),
                          onPressed: () {
                            setModalState(() {
                              _userRating = starValue;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    // Comment TextField
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Mekanın erişilebilirlik durumu hakkında yorum yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Verified Features Header
                    const Text(
                      'Ziyaretinizde Hangi Özellikleri Gördünüz?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Feature checkboxes
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allFeatures.map((feat) {
                        final isChecked = _userVerifiedFeatures.contains(feat);
                        return FilterChip(
                          label: Text(
                            feat,
                            style: TextStyle(
                              color: isChecked ? Colors.white : AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isChecked,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                _userVerifiedFeatures.add(feat);
                              } else {
                                _userVerifiedFeatures.remove(feat);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_commentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen yorum alanını doldurun.')),
                            );
                            return;
                          }

                          Navigator.pop(context); // Close bottom sheet
                          
                          // Show loading overlay
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );

                          try {
                            final currentUser = FirebaseAuth.instance.currentUser;
                            String userName = 'İsimsiz Kullanıcı';
                            String userType = 'Sakin';

                            if (currentUser != null) {
                              // Fetch user profile from Firestore
                              final userDoc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .get();
                              if (userDoc.exists && userDoc.data() != null) {
                                userName = userDoc.data()?['fullName'] ?? currentUser.displayName ?? 'Anonim';
                                userType = userDoc.data()?['userType'] ?? 'Sakin';
                              }
                            }

                            final newComment = CommentModel(
                              id: '',
                              userId: currentUser?.uid ?? 'anonymous',
                              userName: userName,
                              userType: userType,
                              rating: _userRating,
                              content: _commentController.text.trim(),
                              createdAt: DateTime.now(),
                              verifiedFeatures: _userVerifiedFeatures,
                            );

                            await _venueService.addComment(venue.id, newComment);

                            if (context.mounted) {
                              Navigator.pop(context); // Close loading overlay
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Yorumunuz başarıyla eklendi.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Close loading overlay
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Yorumu Gönder',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueDetailAsync = ref.watch(venueDetailProvider(widget.venueId));

    return venueDetailAsync.when(
      data: (venue) {
        final levelColor = _getLevelColor(venue.accessibilityLevel);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Beautiful Custom Header Banner
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [levelColor.withValues(alpha: 0.9), AppColors.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -30,
                          bottom: -30,
                          child: Icon(
                            Icons.location_on,
                            size: 180,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  venue.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                venue.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Accessibility Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Big Score Circle
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '%${venue.accessibilityScore}',
                                  style: TextStyle(
                                    color: levelColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Level details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venue.accessibilityLevel,
                                    style: TextStyle(
                                      color: levelColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Topluluk raporları ve fiziksel donanımlara göre hesaplanan puan.',
                                    style: TextStyle(
                                      color: AppColors.outline,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'Mekan Hakkında',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        venue.description,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Accessibility Checklist
                      const Text(
                        'Erişilebilirlik Kontrol Listesi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _allFeatures.length,
                          itemBuilder: (context, index) {
                            final feat = _allFeatures[index];
                            final isAvailable = venue.features.contains(feat);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? AppColors.tertiary.withValues(alpha: 0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAvailable
                                      ? AppColors.tertiary.withValues(alpha: 0.2)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isAvailable ? Icons.check_circle : Icons.cancel,
                                    color: isAvailable ? AppColors.tertiary : Colors.grey.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feat,
                                      style: TextStyle(
                                        color: isAvailable ? AppColors.primary : Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation Action Panel
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RouteScreen(
                                  destinationName: venue.name,
                                  destinationLocation: LatLng(venue.latitude, venue.longitude),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: const Text(
                            'Yol Tarifi Al',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Reviews Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yorumlar ve Deneyimler',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    venue.averageRating == 0
                                        ? 'Yazılmamış'
                                        : venue.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${venue.comments.length} Değerlendirme)',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          OutlinedButton(
                            onPressed: () => _showAddReviewBottomSheet(venue),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Değerlendir'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Comments List
                      if (venue.comments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'Henüz yorum yapılmamış. İlk yorumu siz yapın!',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: venue.comments.length,
                          itemBuilder: (context, index) {
                            final comment = venue.comments[index];
                            final typeColor = _getUserTypeColor(comment.userType);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: typeColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              comment.userType,
                                              style: TextStyle(
                                                color: typeColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: List.generate(5, (starIdx) {
                                          return Icon(
                                            starIdx < comment.rating ? Icons.star : Icons.star_border,
                                            color: Colors.amber.shade600,
                                            size: 14,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment.content,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                  // Verified features in comments
                                  if (comment.verifiedFeatures.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: comment.verifiedFeatures.map((f) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightSurface,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '✓ $f',
                                            style: const TextStyle(
                                              color: AppColors.outline,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => const Scaffold(
        body: Center(child: Text("Bir hata oluştu.")),
      ),
    );
  }
}
