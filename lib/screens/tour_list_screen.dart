import 'package:destiny/models/tour.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/tour_card.dart';
import 'package:flutter/material.dart';

class TourListScreen extends StatefulWidget {
  const TourListScreen({super.key});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Tour>> _toursFuture;
  List<Tour> _allTours = [];
  List<Tour> _filteredTours = [];

  @override
  void initState() {
    super.initState();
    _toursFuture = _apiService.getTours().then((tours) {
      if (mounted) {
        setState(() {
          _allTours = tours;
          _filteredTours = tours;
        });
      }
      return tours;
    });
  }

  void _filterTours(String query) {
    final filtered = _allTours.where((tour) {
      final titleLower = tour.title.toLowerCase();
      final searchLower = query.toLowerCase();
      return titleLower.contains(searchLower);
    }).toList();

    setState(() {
      _filteredTours = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Removed Scaffold and AppBar to use the main ones
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: _filterTours,
            decoration: const InputDecoration(
              labelText: 'Search tours by title...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Tour>>(
            future: _toursFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (_filteredTours.isEmpty) {
                return const Center(child: Text('No matching tours found.'));
              }

              return ListView.builder(
                itemCount: _filteredTours.length,
                itemBuilder: (context, index) {
                  // TourCard is already clickable by its own definition
                  return TourCard(tour: _filteredTours[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}