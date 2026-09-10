import 'package:destiny/config/destiny_supabase_config.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';

/// Supabase-primary inventory with explicit legacy fallback when empty/unavailable.
class CompositeInventoryRepository implements InventoryRepository {
  CompositeInventoryRepository({
    required InventoryRepository primary,
    required InventoryRepository fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final InventoryRepository _primary;
  final InventoryRepository _fallback;

  Future<List<T>> _load<T>({
    required Future<List<T>> Function() primary,
    required Future<List<T>> Function() fallback,
  }) async {
    if (!DestinySupabaseConfig.preferSupabaseInventory) {
      return fallback();
    }
    try {
      final items = await primary();
      if (items.isNotEmpty) return items;
    } catch (_) {
      // Fall through to legacy — documented temporary bridge.
    }
    return fallback();
  }

  @override
  Future<List<Tour>> getTours() => _load(
        primary: _primary.getTours,
        fallback: _fallback.getTours,
      );

  @override
  Future<List<Accommodation>> getAccommodations() => _load(
        primary: _primary.getAccommodations,
        fallback: _fallback.getAccommodations,
      );

  @override
  Future<List<Vehicle>> getVehicles() => _load(
        primary: _primary.getVehicles,
        fallback: _fallback.getVehicles,
      );

  @override
  Future<List<Award>> getAwards() => _load(
        primary: _primary.getAwards,
        fallback: _fallback.getAwards,
      );
}
