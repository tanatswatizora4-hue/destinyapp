import 'dart:convert';

class Amenity {
  final String name;
  final bool included;

  Amenity({required this.name, required this.included});

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      name: json['name'],
      included: json['included'] ?? false,
    );
  }
}

class Itinerary {
  final String date;
  final String location;
  final String activity;
  final String description;

  Itinerary({
    required this.date,
    required this.location,
    required this.activity,
    required this.description,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      date: json['date'] ?? '',
      location: json['location'] ?? '',
      activity: json['activity'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class Tour {
  final int id;
  final String title;
  final String description;
  final double price;
  final String duration;
  final bool isFeatured;
  final List<String> imageUrls;
  final List<Amenity> amenities;
  final List<Itinerary> itinerary;

  Tour({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.duration,
    required this.isFeatured,
    required this.imageUrls,
    required this.amenities,
    required this.itinerary,
  });

  String get mainImageUrl => imageUrls.isNotEmpty
      ? 'https://bymapara.com/${imageUrls.first}'
      : 'https://placehold.co/800x600/cccccc/ffffff?text=No+Image';

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      duration: json['duration'] ?? '',
      isFeatured: json['is_featured'].toString() == '1',
      imageUrls: List<String>.from(jsonDecode(json['image_urls_json'] ?? '[]')),
      amenities: (jsonDecode(json['amenities_json'] ?? '[]') as List)
          .map((item) => Amenity.fromJson(item))
          .toList(),
      itinerary: (jsonDecode(json['itinerary_json'] ?? '[]') as List)
          .map((item) => Itinerary.fromJson(item))
          .toList(),
    );
  }
}

