import 'dart:convert';

import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:destiny/repositories/supabase_inventory_mappers.dart';
import 'package:http/http.dart' as http;

/// PostgREST inventory reads against Destiny Supabase (anon key only).
class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [String query = '']) {
    final q = query.isEmpty ? '' : '?$query';
    return Uri.parse('${DestinySupabaseConfig.url}/rest/v1/$path$q');
  }

  Map<String, String> get _headers => {
        'apikey': DestinySupabaseConfig.anonKey,
        'Authorization': 'Bearer ${DestinySupabaseConfig.anonKey}',
        'Accept': 'application/json',
      };

  Future<List<dynamic>> _get(String path, String query) async {
    if (!DestinySupabaseConfig.isConfigured) {
      throw StateError('DESTINY_SUPABASE_ANON_KEY is not configured');
    }
    final response = await _client.get(_uri(path, query), headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Supabase $path failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception('Supabase $path returned unexpected payload');
    }
    return decoded;
  }

  @override
  Future<List<Tour>> getTours() async {
    final rows = await _get(
      'tours',
      'select=*,tour_images(*),tour_amenities(*),tour_itinerary_items(*)'
          '&is_published=eq.true&order=legacy_id.desc',
    );
    return rows
        .map((raw) => SupabaseInventoryMappers.tourFromRow(
              raw as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<Accommodation>> getAccommodations() async {
    final rows = await _get(
      'stays',
      'select=*,stay_images(*),stay_rooms(*),stay_amenities(*)'
          '&is_published=eq.true&order=legacy_id.desc',
    );
    return rows
        .map((raw) => SupabaseInventoryMappers.stayFromRow(
              raw as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    final rows = await _get(
      'vehicles',
      'select=*,vehicle_images(*),vehicle_features(*)'
          '&is_published=eq.true&order=legacy_id.desc',
    );
    return rows
        .map((raw) => SupabaseInventoryMappers.vehicleFromRow(
              raw as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<Award>> getAwards() async {
    final rows = await _get(
      'awards',
      'select=*,award_images(*)&is_published=eq.true&order=year.desc',
    );
    return rows
        .map((raw) => SupabaseInventoryMappers.awardFromRow(
              raw as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }
}
