import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DestinationCategory { park, landmark, food, activities, museum, market }

class Destination {
  final String id;
  final String name;
  final String description;
  final String location;
  final LatLng? coordinates;
  final String imageUrl;
  final DestinationCategory category;
  final double rating;
  final List<String> tags;
  final BudgetInfo budget;

  Destination({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    this.coordinates,
    required this.imageUrl,
    required this.category,
    this.rating = 4.5,
    this.tags = const [],
    required this.budget,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    LatLng? coords;
    if (json['latitude'] != null && json['longitude'] != null) {
      coords = LatLng(
        json['latitude'].toDouble(),
        json['longitude'].toDouble(),
      );
    }

    return Destination(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      location: json['location'],
      coordinates: coords,
      imageUrl: json['imageUrl'],
      category: DestinationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DestinationCategory.landmark,
      ),
      rating: json['rating']?.toDouble() ?? 4.5,
      tags: List<String>.from(json['tags'] ?? []),
      budget: BudgetInfo.fromJson(json['budget']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'latitude': coordinates?.latitude,
      'longitude': coordinates?.longitude,
      'imageUrl': imageUrl,
      'category': category.name,
      'rating': rating,
      'tags': tags,
      'budget': budget.toJson(),
    };
  }
}

class BudgetInfo {
  final double minCost;
  final double maxCost;
  final String currency;

  BudgetInfo({
    required this.minCost,
    required this.maxCost,
    this.currency = '₱',
  });

  factory BudgetInfo.fromJson(Map<String, dynamic> json) {
    return BudgetInfo(
      minCost: json['minCost']?.toDouble() ?? 0.0,
      maxCost: json['maxCost']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '₱',
    );
  }

  Map<String, dynamic> toJson() {
    return {'minCost': minCost, 'maxCost': maxCost, 'currency': currency};
  }

  String get formattedRange =>
      '$currency${minCost.toStringAsFixed(0)} - $currency${maxCost.toStringAsFixed(0)}';
}
