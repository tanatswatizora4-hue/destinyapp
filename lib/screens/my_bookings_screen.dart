import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/booking.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Booking>> _bookingsFuture;
  final AuthService _authService = AuthService();
  int? _sqlId;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final appUser = await _authService.getAppUser(user.uid);
      if (appUser != null && appUser.sqlId != null) {
        if(mounted) {
          setState(() {
            _sqlId = appUser.sqlId;
            _bookingsFuture = _apiService.getUserBookings(_sqlId!);
          });
        }
      }
    }
  }

  Future<void> _refreshBookings() async {
    await _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppTheme.background,
      ),
      body: _sqlId == null
          ? _buildLoginPrompt()
          : FutureBuilder<List<Booking>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('An error occurred: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final bookings = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshBookings,
            color: AppTheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return _BookingCard(
                  booking: bookings[index],
                  onDelete: (id) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: const Text('Are you sure you want to delete this booking?'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            TextButton(
                              child: const Text('Delete'),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed == true) {
                      try {
                        await _apiService.deleteBooking(int.parse(id));
                        await _refreshBookings();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking deleted successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete booking: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/plane_loader.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 24),
            Text(
              'No Adventures Yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t booked any trips. Your next journey awaits!',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login, size: 80, color: AppTheme.textSecondary),
            const SizedBox(height: 24),
            Text(
              'Please Log In',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in to see your bookings and start planning your adventures.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final Function(String) onDelete;

  const _BookingCard({required this.booking, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    String formattedDateRange;
    if (booking.itemType == 'tour' || booking.endDate == null) {
      final travelersText = booking.numberOfTravelers > 1 ? '(${booking.numberOfTravelers} travelers)' : '';
      formattedDateRange = '${DateFormat('MMMM d, yyyy').format(booking.startDate)} $travelersText';
    } else if (booking.itemType == 'accommodation') {
      final nights = booking.endDate!.difference(booking.startDate).inDays;
      formattedDateRange = '${DateFormat.yMMMd().format(booking.startDate)} - ${DateFormat.yMMMd().format(booking.endDate!)} ($nights nights)';
    } else { // vehicle
      final days = booking.endDate!.difference(booking.startDate).inDays;
      formattedDateRange = '${DateFormat.yMMMd().format(booking.startDate)} - ${DateFormat.yMMMd().format(booking.endDate!)} ($days days)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: booking.itemImageUrl,
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.itemName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${booking.itemType}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dates: $formattedDateRange',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(booking.paymentStatus),
                  backgroundColor: booking.paymentStatus == 'Confirmed'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  labelStyle: TextStyle(
                      color: booking.paymentStatus == 'Confirmed'
                          ? Colors.green[800]
                          : Colors.orange[800]),
                ),
                Text(
                  currencyFormat.format(booking.totalPrice),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => onDelete(booking.id),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
