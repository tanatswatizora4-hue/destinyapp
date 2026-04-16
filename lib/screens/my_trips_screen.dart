import 'package:flutter/material.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'dart:convert';

class MyTripsScreen extends StatefulWidget {
  final int userId;
  const MyTripsScreen({super.key, required this.userId});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late Future<List<Map<String, dynamic>>> _flightBookingsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchFlightBookings();
  }

  void _fetchFlightBookings() {
    _flightBookingsFuture = _apiService.getMyFlightBookings(widget.userId);
  }

  Future<void> _refreshBookings() async {
    setState(() {
      _fetchFlightBookings();
    });
  }

  void _showCancelDialog(int bookingId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Trip'),
          content: const Text('Are you sure you want to cancel this trip? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(bookingId);
              },
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelBooking(int bookingId) async {
    try {
      await _apiService.deleteFlightBooking(bookingId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip cancelled successfully!')),
      );
      _refreshBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel trip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshBookings,
        color: AppTheme.primary,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _flightBookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('Your past and upcoming journeys will appear here.'),
              );
            }

            final bookings = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return _buildBookingCard(booking);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final midPlaces = (booking['mid_places'] as String?)
        ?.split(', ')
        .where((s) => s.isNotEmpty)
        .toList() ?? [];

    final departureDate = booking['departure_date'];
    final returnDate = booking['return_date'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip ID: #${booking['id']}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${booking['origin']} to ${booking['destination']}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            if (midPlaces.isNotEmpty)
              _buildMidPlacesRow(midPlaces),
            const SizedBox(height: 8),
            if (departureDate != null && departureDate.isNotEmpty)
              _buildInfoRow(
                icon: Icons.flight_takeoff_outlined,
                label: 'Departure:',
                value: departureDate,
              ),
            if (returnDate != null && returnDate.isNotEmpty)
              _buildInfoRow(
                icon: Icons.flight_land_outlined,
                label: 'Return:',
                value: returnDate,
              ),
            _buildInfoRow(
              icon: Icons.group_outlined,
              label: 'Travelers:',
              value: '${booking['num_travelers']}',
            ),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Submitted On:',
              value: booking['created_at'],
            ),
            _buildInfoRow(
              icon: Icons.pending_actions_outlined,
              label: 'Status:',
              value: booking['status'],
            ),
            const SizedBox(height: 16),
            if (booking['status'] != 'Cancelled')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showCancelDialog(booking['id']),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Cancel Trip', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildMidPlacesRow(List<String> midPlaces) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text(
            'Stops:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: midPlaces.map((place) {
                return Chip(
                  label: Text(place),
                  backgroundColor: AppTheme.cardBackground,
                  labelStyle: const TextStyle(color: AppTheme.textPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
