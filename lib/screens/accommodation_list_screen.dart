import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/screens/accommodation_details_screen.dart'; // Import details screen
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/accommodation_card.dart';
import 'package:flutter/material.dart';

class AccommodationListScreen extends StatefulWidget {
  const AccommodationListScreen({super.key});

  @override
  State<AccommodationListScreen> createState() => _AccommodationListScreenState();
}

class _AccommodationListScreenState extends State<AccommodationListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Accommodation>> _accommodationsFuture;

  List<Accommodation> _allAccommodations = [];
  List<Accommodation> _filteredAccommodations = [];
  String _searchQuery = '';
  String? _selectedType;
  List<String> _types = [];

  @override
  void initState() {
    super.initState();
    _accommodationsFuture = _apiService.getAccommodations().then((accommodations) {
      if (mounted) {
        setState(() {
          _allAccommodations = accommodations;
          _filteredAccommodations = accommodations;
          _types = accommodations.map((e) => e.type).toSet().toList();
        });
      }
      return accommodations;
    });
  }

  void _filterAccommodations() {
    final filtered = _allAccommodations.where((item) {
      final nameLower = item.name.toLowerCase();
      final cityLower = item.city.toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      final typeMatches = _selectedType == null || item.type == _selectedType;
      final queryMatches = nameLower.contains(searchLower) || cityLower.contains(searchLower);
      return typeMatches && queryMatches;
    }).toList();

    setState(() {
      _filteredAccommodations = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Removed the Scaffold and AppBar to use the one from NavigationScreen
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              _searchQuery = value;
              _filterAccommodations();
            },
            decoration: const InputDecoration(
              labelText: 'Search by stay or city...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedType == null,
                onSelected: (selected) {
                  setState(() {
                    _selectedType = null;
                    _filterAccommodations();
                  });
                },
              ),
              ..._types.map((type) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FilterChip(
                  label: Text(type),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : null;
                      _filterAccommodations();
                    });
                  },
                ),
              )),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Accommodation>>(
            future: _accommodationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _allAccommodations.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && _allAccommodations.isEmpty) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (_filteredAccommodations.isEmpty) {
                return const Center(child: Text('No matching accommodations found.'));
              }

              // Display as a vertical list for better consistency
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredAccommodations.length,
                itemBuilder: (context, index) {
                  final accommodation = _filteredAccommodations[index];
                  return AccommodationCard(
                    accommodation: accommodation,
                    // FIX: Made the card clickable
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AccommodationDetailsScreen(accommodation: accommodation),
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