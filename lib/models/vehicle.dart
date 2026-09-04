import 'dart:convert';

import 'package:destiny/models/tour.dart'; // Reusing Amenity model
import 'package:destiny/utils/destiny_media_url.dart';

class Vehicle {
  final int id;
  final String make;
  final String model;
  final int year;
  final String type;
  final double pricePerDay;
  final String address;
  final String city;
  final String country;
  final bool isFeatured;
  final List<String> imageUrls;
  final List<Amenity> amenities;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.type,
    required this.pricePerDay,
    required this.address,
    required this.city,
    required this.country,
    required this.isFeatured,
    required this.imageUrls,
    required this.amenities,
  });

  String get mainImageUrl => DestinyMediaUrl.resolve(
        imageUrls.isNotEmpty ? imageUrls.first : null,
      );

  /// Fully resolved, safely encoded URLs for every gallery image.
  List<String> get resolvedImageUrls =>
      imageUrls.map(DestinyMediaUrl.resolve).toList(growable: false);

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: int.tryParse(json['id'].toString()) ?? 0,
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: int.tryParse(json['year'].toString()) ?? DateTime.now().year,
      type: json['type'] ?? '',
      pricePerDay: double.tryParse(json['price_per_day'].toString()) ?? 0.0,
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      isFeatured: json['is_featured'].toString() == '1',
      imageUrls: List<String>.from(jsonDecode(json['image_urls_json'] ?? '[]')),
      amenities: (jsonDecode(json['amenities_json'] ?? '[]') as List)
          .map((item) => Amenity.fromJson(item))
          .toList(),
    );
  }
}

