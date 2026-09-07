import 'dart:convert';

import 'package:destiny/utils/destiny_media_url.dart';

class Award {
  final int id;
  final String name;
  final String description;
  final int year;
  final List<String> imageUrls;

  Award({
    required this.id,
    required this.name,
    required this.description,
    required this.year,
    required this.imageUrls,
  });

  String get mainImageUrl => imageUrls.isNotEmpty
      ? DestinyMediaUrl.resolve(imageUrls.first)
      : 'https://placehold.co/100x100/D4AF37/ffffff?text=AWARD';

  factory Award.fromJson(Map<String, dynamic> json) {
    return Award(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '',
      year: int.tryParse(json['year'].toString()) ?? 0,
      imageUrls: List<String>.from(jsonDecode(json['image_url_json'] ?? '[]')),
    );
  }
}
