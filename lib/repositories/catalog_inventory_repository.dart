import 'dart:convert';

import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Parses Destiny-owned inventory catalog JSON (asset or Supabase Storage).
class CatalogInventoryMappers {
  static List<Tour> tours(Map<String, dynamic> catalog) {
    final rows = catalog['tours'];
    if (rows is! List) return const [];
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return Tour(
        id: int.tryParse('${row['id']}') ?? 0,
        title: row['title']?.toString() ?? 'No Title',
        description: row['description']?.toString() ?? '',
        price: double.tryParse('${row['price']}') ?? 0,
        duration: row['duration']?.toString() ?? '',
        isFeatured: row['is_featured'] == true,
        imageUrls: _stringList(row['image_urls']),
        amenities: _amenities(row['amenities']),
        itinerary: _itinerary(row['itinerary']),
      );
    }).toList(growable: false);
  }

  static List<Accommodation> stays(Map<String, dynamic> catalog) {
    final rows = catalog['stays'];
    if (rows is! List) return const [];
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return Accommodation(
        id: int.tryParse('${row['id']}') ?? 0,
        name: row['name']?.toString() ?? 'No Name',
        type: row['type']?.toString() ?? '',
        description: row['description']?.toString() ?? '',
        address: row['address']?.toString() ?? '',
        city: row['city']?.toString() ?? '',
        country: row['country']?.toString() ?? '',
        isFeatured: row['is_featured'] == true,
        imageUrls: _stringList(row['image_urls']),
        amenities: _amenities(row['amenities']),
        roomTypes: (row['room_types'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => RoomType.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }).toList(growable: false);
  }

  static List<Vehicle> vehicles(Map<String, dynamic> catalog) {
    final rows = catalog['vehicles'];
    if (rows is! List) return const [];
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return Vehicle(
        id: int.tryParse('${row['id']}') ?? 0,
        make: row['make']?.toString() ?? '',
        model: row['model']?.toString() ?? '',
        year: int.tryParse('${row['year']}') ?? 0,
        type: row['type']?.toString() ?? '',
        pricePerDay: double.tryParse('${row['price_per_day']}') ?? 0,
        address: row['address']?.toString() ?? '',
        city: row['city']?.toString() ?? '',
        country: row['country']?.toString() ?? '',
        isFeatured: row['is_featured'] == true,
        imageUrls: _stringList(row['image_urls']),
        amenities: _amenities(row['amenities']),
      );
    }).toList(growable: false);
  }

  static List<Award> awards(Map<String, dynamic> catalog) {
    final rows = catalog['awards'];
    if (rows is! List) return const [];
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return Award(
        id: int.tryParse('${row['id']}') ?? 0,
        name: row['name']?.toString() ?? 'No Name',
        description: row['description']?.toString() ?? '',
        year: int.tryParse('${row['year']}') ?? 0,
        imageUrls: _stringList(row['image_urls']),
      );
    }).toList(growable: false);
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  static List<Amenity> _amenities(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Amenity.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<Itinerary> _itinerary(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Itinerary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

/// Bundled Destiny inventory snapshot (not live bymapara).
class AssetCatalogInventoryRepository implements InventoryRepository {
  AssetCatalogInventoryRepository({
    this.assetPath = 'assets/data/destiny_inventory_catalog.json',
  });

  final String assetPath;
  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _catalog() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid Destiny inventory catalog asset');
    }
    _cache = decoded;
    return decoded;
  }

  @override
  Future<List<Tour>> getTours() async =>
      CatalogInventoryMappers.tours(await _catalog());

  @override
  Future<List<Accommodation>> getAccommodations() async =>
      CatalogInventoryMappers.stays(await _catalog());

  @override
  Future<List<Vehicle>> getVehicles() async =>
      CatalogInventoryMappers.vehicles(await _catalog());

  @override
  Future<List<Award>> getAwards() async =>
      CatalogInventoryMappers.awards(await _catalog());
}

/// Public Supabase Storage catalog (`destiny-media/inventory/catalog.json`).
class StorageCatalogInventoryRepository implements InventoryRepository {
  StorageCatalogInventoryRepository({
    http.Client? client,
    this.catalogUrl =
        'https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/inventory/catalog.json',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String catalogUrl;
  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _catalog() async {
    final cached = _cache;
    if (cached != null) return cached;
    final response = await _client.get(Uri.parse(catalogUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Storage catalog failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid Destiny inventory catalog from Storage');
    }
    _cache = decoded;
    return decoded;
  }

  @override
  Future<List<Tour>> getTours() async =>
      CatalogInventoryMappers.tours(await _catalog());

  @override
  Future<List<Accommodation>> getAccommodations() async =>
      CatalogInventoryMappers.stays(await _catalog());

  @override
  Future<List<Vehicle>> getVehicles() async =>
      CatalogInventoryMappers.vehicles(await _catalog());

  @override
  Future<List<Award>> getAwards() async =>
      CatalogInventoryMappers.awards(await _catalog());
}
