import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';

/// Pure PostgREST → domain model mappers (unit-testable, no I/O).
class SupabaseInventoryMappers {
  static List<String> imagePaths(List<dynamic>? rows, {String? primary}) {
    final sorted = [...?rows]..sort((a, b) {
        final ao = int.tryParse('${a['sort_order']}') ?? 0;
        final bo = int.tryParse('${b['sort_order']}') ?? 0;
        return ao.compareTo(bo);
      });
    final fromRows = sorted
        .map((row) {
          final path = '${row['storage_path'] ?? ''}'.trim();
          if (path.isNotEmpty) return path;
          return '${row['legacy_url'] ?? ''}'.trim();
        })
        .where((p) => p.isNotEmpty)
        .toList();
    final primaryPath = (primary ?? '').trim();
    if (primaryPath.isEmpty) return List.unmodifiable(fromRows);
    return List.unmodifiable([
      primaryPath,
      ...fromRows.where((p) => p != primaryPath),
    ]);
  }

  static Tour tourFromRow(Map<String, dynamic> row) {
    final imageUrls = imagePaths(
      row['tour_images'] as List?,
      primary: row['primary_image_path']?.toString(),
    );
    return Tour(
      id: int.tryParse('${row['legacy_id']}') ?? 0,
      title: row['title']?.toString() ?? 'No Title',
      description: row['description']?.toString() ?? '',
      price: double.tryParse('${row['price']}') ?? 0,
      duration: row['duration']?.toString() ?? '',
      isFeatured: row['is_featured'] == true,
      imageUrls: imageUrls,
      amenities: (row['tour_amenities'] as List? ?? const [])
          .map((item) => Amenity.fromJson({
                'name': item['name'],
                'included': item['included'] ?? true,
              }))
          .toList(),
      itinerary: (row['tour_itinerary_items'] as List? ?? const [])
          .map((item) => Itinerary.fromJson({
                'date': item['date_label'] ?? '',
                'location': item['location'] ?? '',
                'activity': item['activity'] ?? '',
                'description': item['description'] ?? '',
              }))
          .toList(),
    );
  }

  static Accommodation stayFromRow(Map<String, dynamic> row) {
    final imageUrls = imagePaths(
      row['stay_images'] as List?,
      primary: row['primary_image_path']?.toString(),
    );
    return Accommodation(
      id: int.tryParse('${row['legacy_id']}') ?? 0,
      name: row['name']?.toString() ?? 'No Name',
      type: row['type']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      country: row['country']?.toString() ?? '',
      isFeatured: row['is_featured'] == true,
      imageUrls: imageUrls,
      amenities: (row['stay_amenities'] as List? ?? const [])
          .map((item) => Amenity.fromJson({
                'name': item['name'],
                'included': item['included'] ?? true,
              }))
          .toList(),
      roomTypes: (row['stay_rooms'] as List? ?? const [])
          .map((item) => RoomType.fromJson({
                'name': item['name'],
                'price': item['price'],
                'capacity': item['capacity'],
              }))
          .toList(),
    );
  }

  static Vehicle vehicleFromRow(Map<String, dynamic> row) {
    final imageUrls = imagePaths(
      row['vehicle_images'] as List?,
      primary: row['primary_image_path']?.toString(),
    );
    return Vehicle(
      id: int.tryParse('${row['legacy_id']}') ?? 0,
      make: row['make']?.toString() ?? '',
      model: row['model']?.toString() ?? '',
      year: int.tryParse('${row['year']}') ?? 0,
      type: row['type']?.toString() ?? '',
      pricePerDay: double.tryParse('${row['price_per_day']}') ?? 0,
      address: row['address']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      country: row['country']?.toString() ?? '',
      isFeatured: row['is_featured'] == true,
      imageUrls: imageUrls,
      amenities: (row['vehicle_features'] as List? ?? const [])
          .map((item) => Amenity.fromJson({
                'name': item['name'],
                'included': item['included'] ?? true,
              }))
          .toList(),
    );
  }

  static Award awardFromRow(Map<String, dynamic> row) {
    final imageUrls = imagePaths(
      row['award_images'] as List?,
      primary: row['primary_image_path']?.toString(),
    );
    return Award(
      id: int.tryParse('${row['legacy_id']}') ?? 0,
      name: row['name']?.toString() ?? 'No Name',
      description: row['description']?.toString() ?? '',
      year: int.tryParse('${row['year']}') ?? 0,
      imageUrls: imageUrls,
    );
  }
}
