import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/repositories/customer_commerce_repository.dart';
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
  final BookingRepository _bookings = BookingRepository();
  late Future<List<CustomerBooking>> _bookingsFuture;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _signedIn = false;
          _bookingsFuture = Future.value(const []);
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _signedIn = true;
        _bookingsFuture = _bookings.listMine();
      });
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
      body: !_signedIn
          ? _buildLoginPrompt()
          : FutureBuilder<List<CustomerBooking>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Unable to load bookings: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _refreshBookings,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
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
                    padding: const EdgeInsets.all(12),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      return _CustomerBookingCard(
                        booking: bookings[index],
                        onCancel: (id) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel request'),
                              content: const Text(
                                'Cancel this booking request? Destiny will stop processing it.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Keep'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Cancel request'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          try {
                            await _bookings.cancel(bookingId: id);
                            await _refreshBookings();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Request cancelled.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to cancel: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
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
        padding: const EdgeInsets.all(32),
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
              'No requests yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tour, stay, and vehicle requests you submit will appear here for Destiny to review.',
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login, size: 80, color: AppTheme.textSecondary),
            const SizedBox(height: 24),
            Text(
              'Please sign in',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to view booking requests Destiny is reviewing for you.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBookingCard extends StatelessWidget {
  final CustomerBooking booking;
  final Future<void> Function(String id) onCancel;

  const _CustomerBookingCard({
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final amount = booking.displayAmount;
    final amountLabel = amount == null
        ? 'Estimate pending'
        : booking.hasAuthoritativeQuote
            ? 'Quoted ${currency.format(amount)}'
            : 'Estimated ${currency.format(amount)}';

    String dates = '';
    if (booking.startDate != null) {
      dates = DateFormat.yMMMd().format(booking.startDate!);
      if (booking.endDate != null) {
        dates =
            '$dates – ${DateFormat.yMMMd().format(booking.endDate!)}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: booking.mainImageUrl,
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[200]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.itemName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${booking.itemType}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      if (dates.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dates: $dates',
                          style:
                              const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
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
                  label: Text(booking.statusLabel),
                  backgroundColor: booking.status == 'confirmed'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: booking.status == 'confirmed'
                        ? Colors.green[800]
                        : Colors.orange[800],
                  ),
                ),
                Text(
                  amountLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (booking.isCancelableByCustomer) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onCancel(booking.id),
                  child: const Text('Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
