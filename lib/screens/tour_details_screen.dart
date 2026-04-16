import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TourDetailsScreen extends StatefulWidget {
  final Tour tour;
  const TourDetailsScreen({super.key, required this.tour});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _BookingSheetContent(tour: widget.tour),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tour.title),
        backgroundColor: AppTheme.background,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'tour_image_${widget.tour.id}',
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 250,
                  viewportFraction: 1.0,
                  autoPlay: true,
                ),
                items: widget.tour.imageUrls.map((i) {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.timer_outlined,
                            color: AppTheme.primary),
                        label: Text(widget.tour.duration),
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                      ),
                      Text(
                        currencyFormat.format(widget.tour.price),
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
                  Text('About this Tour',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    widget.tour.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Text('Itinerary',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...widget.tour.itinerary.map((item) => Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.1),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today_outlined,
                          color: AppTheme.primary),
                      title: Text(item.activity,
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.date}\n${item.location}'),
                    ),
                  )),
                  const SizedBox(height: 24),
                  Text('Amenities',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: widget.tour.amenities
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
  final Tour tour;
  const _BookingSheetContent({required this.tour});

  @override
  State<_BookingSheetContent> createState() => _BookingSheetContentState();
}

class _BookingSheetContentState extends State<_BookingSheetContent> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isBooking = false;
  int _travelerCount = 1;
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

  void _incrementTravelers() => setState(() => _travelerCount++);
  void _decrementTravelers() =>
      setState(() {
        if (_travelerCount > 1) _travelerCount--;
      });

  Future<void> _confirmBooking() async {
    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book this tour.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.tour.id,
        itemType: 'tour',
        numTravelers: _travelerCount,
        totalPrice: widget.tour.price * _travelerCount,
        startDate: DateTime.now(), // Placeholder date
        endDate: DateTime.now(), // Placeholder date
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
    final totalPrice = widget.tour.price * _travelerCount;

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
          Text('Book Your Trip',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(widget.tour.title,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Number of Travelers',
                  style: Theme.of(context).textTheme.bodyLarge),
              Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _decrementTravelers),
                  Text('$_travelerCount',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _incrementTravelers),
                ],
              ),
            ],
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
