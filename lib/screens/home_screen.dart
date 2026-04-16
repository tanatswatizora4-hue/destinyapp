// Added for the min() function to simplify list limiting
import 'dart:math';

import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/resources/app_strings.dart';
import 'package:destiny/screens/accommodation_details_screen.dart';
import 'package:destiny/screens/accommodation_list_screen.dart';
import 'package:destiny/screens/vehicle_details_screen.dart';
import 'package:destiny/screens/vehicle_list_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/accommodation_card.dart';
import 'package:destiny/widgets/award_card.dart';
import 'package:destiny/widgets/info_card.dart';
import 'package:destiny/widgets/tour_card.dart';
import 'package:destiny/widgets/vehicle_card.dart';
import 'package:destiny/widgets/video_hero.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Tour>> _toursFuture;
  late Future<List<Accommodation>> _accommodationsFuture;
  late Future<List<Vehicle>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _toursFuture = _apiService.getTours();
    _accommodationsFuture = _apiService.getAccommodations();
    _vehiclesFuture = _apiService.getVehicles();
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Removed the Scaffold and AppBar from this widget.
    // The main header is now handled by NavigationScreen.
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VideoHero(),
            _buildIntroSection(),
            _buildSectionHeader(context, 'Featured Tours'),
            const SizedBox(height: 16),
            _buildFeaturedToursSection(),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Top Stays', onViewMore: () {
              // Note: This button still works to navigate to the full list,
              // which is now different from the "Stays" tab. This can be kept
              // or removed based on your desired UX.
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccommodationListScreen()));
            }),
            const SizedBox(height: 16),
            _buildAccommodationsSection(),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Popular Rentals', onViewMore: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleListScreen()));
            }),
            const SizedBox(height: 16),
            _buildVehiclesSection(),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'More Services'),
            const SizedBox(height: 16),
            _buildInfoCardSection(),
            const SizedBox(height: 32),
            _buildAwardsSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Builds the introductory text section below the hero video.
  Widget _buildIntroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Your Destiny',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.catchPhrase,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  /// A reusable widget for section headers (e.g., "Featured Tours").
  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onViewMore}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (onViewMore != null)
            TextButton(
              onPressed: onViewMore,
              child: const Text('View More'),
            )
        ],
      ),
    );
  }

  /// Builds the carousel slider for featured tours.
  Widget _buildFeaturedToursSection() {
    return FutureBuilder<List<Tour>>(
      future: _toursFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 290, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.textSecondary)),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No tours available at the moment.', style: TextStyle(color: AppTheme.textSecondary)),
          ));
        }

        final featuredTours = snapshot.data!.where((t) => t.isFeatured).toList();
        if (featuredTours.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No featured tours at the moment.', style: TextStyle(color: AppTheme.textSecondary)),
          ));
        }

        return CarouselSlider.builder(
          itemCount: featuredTours.length,
          itemBuilder: (context, index, realIndex) {
            return TourCard(tour: featuredTours[index], isFeatured: true);
          },
          options: CarouselOptions(
            height: 290,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.85,
          ),
        );
      },
    );
  }

  /// Builds the horizontal list for top accommodations.
  Widget _buildAccommodationsSection() {
    return FutureBuilder<List<Accommodation>>(
      future: _accommodationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.textSecondary)),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No accommodations available.'));
        }

        final accommodations = snapshot.data!;
        return SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: min(accommodations.length, 5),
            itemBuilder: (context, index) {
              final accommodation = accommodations[index];
              return AccommodationCard(
                accommodation: accommodation,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccommodationDetailsScreen(accommodation: accommodation),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the horizontal list for popular rental vehicles.
  Widget _buildVehiclesSection() {
    return FutureBuilder<List<Vehicle>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.textSecondary)),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No vehicles available.'));
        }

        final vehicles = snapshot.data!;
        return SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: min(vehicles.length, 5),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
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
          ),
        );
      },
    );
  }

  /// Builds the static info cards for other services.
  Widget _buildInfoCardSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          InfoCard(
            icon: FontAwesomeIcons.planeDeparture,
            title: 'Seamless Air Travel',
            subtitle: 'Book domestic & international flights with ease through our expert agents.',
          ),
          SizedBox(height: 12),
          InfoCard(
            icon: FontAwesomeIcons.solidStar,
            title: 'Exclusive Member Perks',
            subtitle: 'Subscribe to unlock special discounts and priority services.',
          ),
          SizedBox(height: 12),
          InfoCard(
            icon: FontAwesomeIcons.passport,
            title: 'Hassle-Free Visa Assistance',
            subtitle: 'Let our experts handle your visa applications from start to finish.',
          ),
        ],
      ),
    );
  }

  /// Builds the "Our Accolades" section in the footer.
  Widget _buildAwardsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        children: [
          Text('Our Accolades', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AwardCard(
                imagePath: 'assets/images/golden.jpg',
                title: 'Gold Winner',
                subtitle: 'Best Customer Service',
              ),
              AwardCard(
                imagePath: 'assets/images/legend.jpg',
                title: 'Hall of Fame',
                subtitle: 'Legends in Hospitality',
              ),
            ],
          )
        ],
      ),
    );
  }
}