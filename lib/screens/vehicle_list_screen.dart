import 'package:destiny/models/vehicle.dart';
import 'package:destiny/screens/vehicle_details_screen.dart'; // Import details screen
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/vehicle_card.dart';
import 'package:flutter/material.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Vehicle>> _vehiclesFuture;
  List<Vehicle> _allVehicles = [];
  List<Vehicle> _filteredVehicles = [];

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = _apiService.getVehicles().then((vehicles) {
      if (mounted) {
        setState(() {
          _allVehicles = vehicles;
          _filteredVehicles = vehicles;
        });
      }
      return vehicles;
    });
  }

  void _filterVehicles(String query) {
    final filtered = _allVehicles.where((vehicle) {
      final modelLower = vehicle.model.toLowerCase();
      final makeLower = vehicle.make.toLowerCase();
      final searchLower = query.toLowerCase();
      return modelLower.contains(searchLower) || makeLower.contains(searchLower);
    }).toList();

    setState(() {
      _filteredVehicles = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Replaced placeholder with a full-featured list screen
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: _filterVehicles,
            decoration: const InputDecoration(
              labelText: 'Search by make or model...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Vehicle>>(
            future: _vehiclesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (_filteredVehicles.isEmpty) {
                return const Center(child: Text('No matching vehicles found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _filteredVehicles[index];
                  // FIX: Made the card clickable
                  return VehicleCard(
                    vehicle: vehicle,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}