import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccommodationDetailsScreen extends StatefulWidget {
  final Accommodation accommodation;
  const AccommodationDetailsScreen({super.key, required this.accommodation});

  @override
  State<AccommodationDetailsScreen> createState() =>
      _AccommodationDetailsScreenState();
}

class _AccommodationDetailsScreenState
    extends State<AccommodationDetailsScreen> {
  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _BookingSheetContent(accommodation: widget.accommodation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accommodation.name),
        backgroundColor: AppTheme.background,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'accommodation_image_${widget.accommodation.id}',
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 250,
                  viewportFraction: 1.0,
                  autoPlay: true,
                ),
                items: widget.accommodation.imageUrls.map((i) {
                  return Builder(
                    builder: (BuildContext context) {
                      return CachedNetworkImage(
                        imageUrl: 'https://bymapara.com/$i',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.accommodation.city}, ${widget.accommodation.country}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text('About this Stay',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    widget.accommodation.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Text('Room Types',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...widget.accommodation.roomTypes.map((room) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.king_bed_outlined,
                          color: AppTheme.primary),
                      title: Text(room.name,
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Capacity: ${room.capacity}'),
                      trailing: Text(
                          NumberFormat.currency(
                              locale: 'en_US', symbol: '\$')
                              .format(room.price),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                    ),
                  )),
                  const SizedBox(height: 24),
                  Text('Amenities',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: widget.accommodation.amenities
                        .map((amenity) => Chip(
                      avatar: Icon(
                        amenity.included
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        color: amenity.included
                            ? Colors.white
                            : AppTheme.textSecondary,
                        size: 18,
                      ),
                      label: Text(amenity.name,
                          style: TextStyle(
                              color: amenity.included
                                  ? Colors.white
                                  : AppTheme.textSecondary)),
                      backgroundColor: amenity.included
                          ? AppTheme.primary
                          : AppTheme.cardBackground,
                    ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppTheme.background,
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _showBookingCanvas,
          icon: const Icon(Icons.shopping_cart_checkout),
          label: const Text('Book Now'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

class _BookingSheetContent extends StatefulWidget {
  final Accommodation accommodation;
  const _BookingSheetContent({required this.accommodation});

  @override
  State<_BookingSheetContent> createState() => _BookingSheetContentState();
}

class _BookingSheetContentState extends State<_BookingSheetContent> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isBooking = false;
  DateTimeRange? _selectedDateRange;
  RoomType? _selectedRoom;
  int _numberOfNights = 1;
  int? _sqlId;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.accommodation.roomTypes.isNotEmpty
        ? widget.accommodation.roomTypes.first
        : null;
    _getSqlId();
  }

  Future<void> _getSqlId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final appUser = await _authService.getAppUser(user.uid);
      if (appUser != null && appUser.sqlId != null) {
        if(mounted) {
          setState(() {
            _sqlId = appUser.sqlId;
          });
        }
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _numberOfNights = picked.duration.inDays;
        if (_numberOfNights == 0) _numberOfNights = 1; // Minimum 1 night
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDateRange == null || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range and a room type.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book this accommodation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.accommodation.id,
        itemType: 'accommodation',
        numTravelers: _selectedRoom!.capacity,
        totalPrice: _selectedRoom!.price * _numberOfNights,
        startDate: _selectedDateRange!.start,
        endDate: _selectedDateRange!.end,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close the sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking Confirmed! One of our agents will contact you. Please complete your contact details in My Profile.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final totalPrice = (_selectedRoom?.price ?? 0) * _numberOfNights;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book Your Stay',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(widget.accommodation.name,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
            title: const Text('Select Dates'),
            subtitle: Text(_selectedDateRange == null
                ? 'Choose your check-in and check-out dates'
                : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)} ($_numberOfNights nights)'),
            onTap: _selectDateRange,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RoomType>(
            value: _selectedRoom,
            decoration: const InputDecoration(
              labelText: 'Select Room Type',
              prefixIcon: Icon(Icons.king_bed_outlined, color: AppTheme.primary),
            ),
            items: widget.accommodation.roomTypes
                .map((room) => DropdownMenuItem(
              value: room,
              child: Expanded( // Fix for text overflow
                child: Text(
                    '${room.name} (${currencyFormat.format(room.price)}/night)'),
              ),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoom = value;
              });
            },
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Price', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                currencyFormat.format(totalPrice),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isBooking ? null : _confirmBooking,
            child: _isBooking
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : const Text('Confirm Booking'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
          )
        ],
      ),
    );
  }
}
