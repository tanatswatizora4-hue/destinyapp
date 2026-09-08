import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/award.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';

/// Inventory reads used by discovery / details / Home.
abstract class InventoryRepository {
  Future<List<Tour>> getTours();
  Future<List<Accommodation>> getAccommodations();
  Future<List<Vehicle>> getVehicles();
  Future<List<Award>> getAwards();
}
