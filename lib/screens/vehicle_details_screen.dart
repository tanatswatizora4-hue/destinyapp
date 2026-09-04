import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final Vehicle vehicle;
  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _BookingSheetContent(vehicle: widget.vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle.make} ${widget.vehicle.model}'),
        backgroundColor: AppTheme.background,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'vehicle_image_${widget.vehicle.id}',
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 250,
                  viewportFraction: 1.0,
                  autoPlay: true,
                ),
                items: widget.vehicle.resolvedImageUrls.map((imageUrl) {
                  return Builder(
                    builder: (BuildContext context) {
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.directions_car,
                            color: AppTheme.primary),
                        label: Text(widget.vehicle.type),
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                      ),
                      Text(
                        '${currencyFormat.format(widget.vehicle.pricePerDay)}/day',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Details',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text('Year: ${widget.vehicle.year}'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Pickup Location'),
                      subtitle: Text(
                          '${widget.vehicle.address}, ${widget.vehicle.city}'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Features',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: widget.vehicle.amenities
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
  final Vehicle vehicle;
  const _BookingSheetContent({required this.vehicle});

  @override
  State<_BookingSheetContent> createState() => _BookingSheetContentState();
}

class _BookingSheetContentState extends State<_BookingSheetContent> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isBooking = false;
  DateTimeRange? _selectedDateRange;
  int _numberOfDays = 1;
  int? _sqlId;

  @override
  void initState() {
    super.initState();
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
        _numberOfDays = picked.duration.inDays;
        if (_numberOfDays == 0) _numberOfDays = 1; // Minimum 1 day rental
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your rental dates.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book this vehicle.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.vehicle.id,
        itemType: 'vehicle',
        numTravelers: 1, // Typically 1 for a vehicle rental booking
        totalPrice: widget.vehicle.pricePerDay * _numberOfDays,
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
    final totalPrice = widget.vehicle.pricePerDay * _numberOfDays;

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
          Text('Book Your Ride',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${widget.vehicle.make} ${widget.vehicle.model}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
            title: const Text('Select Rental Dates'),
            subtitle: Text(_selectedDateRange == null
                ? 'Choose your pick-up and drop-off dates'
                : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)} ($_numberOfDays days)'),
            onTap: _selectDateRange,
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
