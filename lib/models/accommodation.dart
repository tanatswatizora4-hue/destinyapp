import 'dart:convert';
import 'package:destiny/models/tour.dart'; // Reusing Amenity model

class RoomType {
  final String name;
  final double price;
  final int capacity;

  RoomType({required this.name, required this.price, required this.capacity});

  factory RoomType.fromJson(Map<String, dynamic> json) {
    return RoomType(
      name: json['name'] ?? 'No Name',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      capacity: int.tryParse(json['capacity'].toString()) ?? 0,
    );
  }
}

class Accommodation {
  final int id;
  final String name;
  final String type;
  final String description;
  final String address;
  final String city;
  final String country;
  final bool isFeatured;
  final List<String> imageUrls;
  final List<Amenity> amenities;
  final List<RoomType> roomTypes;

  Accommodation({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.address,
    required this.city,
    required this.country,
    required this.isFeatured,
    required this.imageUrls,
    required this.amenities,
    required this.roomTypes,
  });

  String get mainImageUrl => imageUrls.isNotEmpty
      ? 'https://bymapara.com/${imageUrls.first}'
      : 'https://placehold.co/800x600/cccccc/ffffff?text=No+Image';

  factory Accommodation.fromJson(Map<String, dynamic> json) {
    return Accommodation(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'No Name',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      isFeatured: json['is_featured'].toString() == '1',
      imageUrls: List<String>.from(jsonDecode(json['image_urls_json'] ?? '[]')),
      amenities: (jsonDecode(json['amenities_json'] ?? '[]') as List)
          .map((item) => Amenity.fromJson(item))
          .toList(),
      roomTypes: (jsonDecode(json['room_types_json'] ?? '[]') as List)
          .map((item) => RoomType.fromJson(item))
          .toList(),
    );
  }
}

