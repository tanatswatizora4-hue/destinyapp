import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/repositories/inventory_repository.dart';
import 'package:destiny/services/api_service.dart';

/// Legacy bymapara inventory reads via [ApiService] HTTP endpoints.
class LegacyInventoryRepository implements InventoryRepository {
  LegacyInventoryRepository({ApiService? apiService})
      : _api = apiService ?? ApiService();

  final ApiService _api;

  @override
  Future<List<Tour>> getTours() => _api.fetchToursLegacy();

  @override
  Future<List<Accommodation>> getAccommodations() =>
      _api.fetchAccommodationsLegacy();

  @override
  Future<List<Vehicle>> getVehicles() => _api.fetchVehiclesLegacy();

  @override
  Future<List<Award>> getAwards() => _api.fetchAwardsLegacy();
}
