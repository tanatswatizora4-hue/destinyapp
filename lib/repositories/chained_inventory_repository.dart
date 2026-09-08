import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';

/// Tries inventory sources in order; first non-empty success wins.
///
/// Does not merge lists from multiple sources (avoids duplicates).
class ChainedInventoryRepository implements InventoryRepository {
  ChainedInventoryRepository(this.sources);

  final List<InventoryRepository> sources;

  Future<List<T>> _firstNonEmpty<T>(
    Future<List<T>> Function(InventoryRepository repo) load,
  ) async {
    Object? lastError;
    for (final source in sources) {
      try {
        final items = await load(source);
        if (items.isNotEmpty) return items;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) {
      throw Exception('All inventory sources failed: $lastError');
    }
    return const [];
  }

  @override
  Future<List<Tour>> getTours() => _firstNonEmpty((r) => r.getTours());

  @override
  Future<List<Accommodation>> getAccommodations() =>
      _firstNonEmpty((r) => r.getAccommodations());

  @override
  Future<List<Vehicle>> getVehicles() => _firstNonEmpty((r) => r.getVehicles());

  @override
  Future<List<Award>> getAwards() => _firstNonEmpty((r) => r.getAwards());
}
