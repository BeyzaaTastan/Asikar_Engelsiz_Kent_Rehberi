import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userType;
  final double rating;
  final String content;
  final DateTime createdAt;
  final List<String> verifiedFeatures;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.rating,
    required this.content,
    required this.createdAt,
    required this.verifiedFeatures,
  });

  CommentModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userType,
    double? rating,
    String? content,
    DateTime? createdAt,
    List<String>? verifiedFeatures,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userType: userType ?? this.userType,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      verifiedFeatures: verifiedFeatures ?? this.verifiedFeatures,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userType': userType,
      'rating': rating,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedFeatures': verifiedFeatures,
    };
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['createdAt'] is Timestamp) {
      parsedDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      parsedDate = DateTime.parse(json['createdAt']);
    } else {
      parsedDate = DateTime.now();
    }

    return CommentModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'İsimsiz Kullanıcı',
      userType: json['userType'] ?? 'Sakin',
      rating: (json['rating'] ?? 0.0).toDouble(),
      content: json['content'] ?? '',
      createdAt: parsedDate,
      verifiedFeatures: json['verifiedFeatures'] != null
          ? List<String>.from(json['verifiedFeatures'])
          : [],
    );
  }
}

class VenueModel {
  final String id;
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String description;
  final int accessibilityScore;
  final List<String> features;
  final List<String> images;
  final List<CommentModel> comments;
  final String addedBy;
  final double averageRating;

  VenueModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.accessibilityScore,
    required this.features,
    required this.images,
    required this.comments,
    required this.addedBy,
    required this.averageRating,
  });

  String get accessibilityLevel {
    if (accessibilityScore >= 85) {
      return "Tam Erişilebilir";
    } else if (accessibilityScore >= 50) {
      return "Kısmi Erişilebilir";
    } else if (accessibilityScore >= 25) {
      return "Kısıtlı Erişilebilir";
    } else {
      return "Destek Gerekli";
    }
  }

  VenueModel copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    int? accessibilityScore,
    List<String>? features,
    List<String>? images,
    List<CommentModel>? comments,
    String? addedBy,
    double? averageRating,
  }) {
    return VenueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      accessibilityScore: accessibilityScore ?? this.accessibilityScore,
      features: features ?? this.features,
      images: images ?? this.images,
      comments: comments ?? this.comments,
      addedBy: addedBy ?? this.addedBy,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'accessibilityScore': accessibilityScore,
      'features': features,
      'images': images,
      'comments': comments.map((c) => c.toJson()).toList(),
      'addedBy': addedBy,
      'averageRating': averageRating,
    };
  }

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    var rawComments = json['comments'] as List? ?? [];
    List<CommentModel> parsedComments = rawComments
        .map((c) => CommentModel.fromJson(Map<String, dynamic>.from(c)))
        .toList();

    return VenueModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      accessibilityScore: json['accessibilityScore'] ?? 0,
      features: json['features'] != null ? List<String>.from(json['features']) : [],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      comments: parsedComments,
      addedBy: json['addedBy'] ?? '',
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
    );
  }
}
