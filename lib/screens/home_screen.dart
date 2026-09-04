import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/screens/accommodation_details_screen.dart';
import 'package:destiny/screens/accommodation_list_screen.dart';
import 'package:destiny/screens/tour_list_screen.dart';
import 'package:destiny/screens/vehicle_details_screen.dart';
import 'package:destiny/screens/vehicle_list_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/accommodation_card.dart';
import 'package:destiny/widgets/award_card.dart';
import 'package:destiny/widgets/tour_card.dart';
import 'package:destiny/widgets/vehicle_card.dart';
import 'package:destiny/widgets/video_hero.dart';
import 'package:flutter/material.dart';

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
    setState(_loadData);
  }

  void _showPreviewMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = width >= 1024;
          final isTablet = width >= 700 && width < 1024;
          final horizontalPad = isDesktop ? 28.0 : (isTablet ? 20.0 : 16.0);
          final heroHeight = isDesktop ? 460.0 : (isTablet ? 420.0 : 380.0);
          final cardWidth = isDesktop ? 300.0 : (isTablet ? 280.0 : 260.0);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(context, heroHeight: heroHeight, isDesktop: isDesktop),
                _ContentShell(
                  maxWidth: AppTheme.contentMaxWidth,
                  padding: EdgeInsets.fromLTRB(horizontalPad, 28, horizontalPad, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildServiceShortcuts(context, isDesktop: isDesktop),
                      const SizedBox(height: 36),
                      _buildSectionHeader(
                        context,
                        title: 'Destiny Picks',
                        subtitle: 'Featured tours curated for unforgettable journeys',
                        onViewMore: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TourListScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeaturedToursSection(cardWidth: cardWidth),
                      const SizedBox(height: 40),
                      _buildSectionHeader(
                        context,
                        title: 'Top Stays',
                        subtitle: 'Handpicked places to rest and recharge',
                        onViewMore: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccommodationListScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildAccommodationsSection(
                        cardWidth: cardWidth,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                      ),
                      const SizedBox(height: 40),
                      _buildSectionHeader(
                        context,
                        title: 'Popular Rentals',
                        subtitle: 'Reliable vehicles for every itinerary',
                        onViewMore: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleListScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildVehiclesSection(cardWidth: cardWidth * 0.92),
                      const SizedBox(height: 40),
                      _buildAskDestina(context),
                      const SizedBox(height: 40),
                      _buildTrustSection(context, isDesktop: isDesktop),
                      const SizedBox(height: 40),
                      _buildAwardsSection(context),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(
    BuildContext context, {
    required double heroHeight,
    required bool isDesktop,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoHero(height: heroHeight),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x660A2540),
                  Color(0x990A2540),
                  Color(0xE60A2540),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 36 : 20,
                    24,
                    isDesktop ? 36 : 20,
                    isDesktop ? 40 : 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where will destiny take you?',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          fontSize: isDesktop ? 42 : 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Flights, stays, tours and unforgettable journeys.',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _HeroSearchField(
                        onSubmitted: (_) {
                          _showPreviewMessage(
                            'Search is coming soon — browse Destiny Picks below.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceShortcuts(BuildContext context, {required bool isDesktop}) {
    final shortcuts = <_ServiceShortcutData>[
      _ServiceShortcutData(
        label: 'Flights',
        icon: Icons.flight_takeoff_outlined,
        onTap: () => _showPreviewMessage(
          'Open Flights from the bottom navigation to plan air travel.',
        ),
      ),
      _ServiceShortcutData(
        label: 'Stays',
        icon: Icons.hotel_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccommodationListScreen()),
          );
        },
      ),
      _ServiceShortcutData(
        label: 'Tours',
        icon: Icons.route_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TourListScreen()),
          );
        },
      ),
      _ServiceShortcutData(
        label: 'Vehicles',
        icon: Icons.directions_car_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VehicleListScreen()),
          );
        },
      ),
      _ServiceShortcutData(
        label: 'Visas',
        icon: Icons.badge_outlined,
        onTap: () => _showPreviewMessage(
          'Visa assistance is available via Contact — Destina planning coming soon.',
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 12 : 4,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  for (final item in shortcuts) ...[
                    _ServiceShortcutChip(data: item),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                for (final item in shortcuts)
                  Expanded(child: _ServiceShortcutChip(data: item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    VoidCallback? onViewMore,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (onViewMore != null)
          TextButton(
            onPressed: onViewMore,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('View all'),
          ),
      ],
    );
  }

  Widget _buildFeaturedToursSection({required double cardWidth}) {
    return FutureBuilder<List<Tour>>(
      future: _toursFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 310);
        }
        if (snapshot.hasError) {
          return const _SectionMessage(text: 'Unable to load tours right now.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SectionMessage(text: 'No tours available at the moment.');
        }

        final featuredTours =
            snapshot.data!.where((t) => t.isFeatured).toList();
        if (featuredTours.isEmpty) {
          return const _SectionMessage(text: 'No featured tours at the moment.');
        }

        return SizedBox(
          height: 310,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featuredTours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return TourCard(
                tour: featuredTours[index],
                isFeatured: true,
                width: cardWidth,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAccommodationsSection({
    required double cardWidth,
    required bool isDesktop,
    required bool isTablet,
  }) {
    return FutureBuilder<List<Accommodation>>(
      future: _accommodationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 290);
        }
        if (snapshot.hasError) {
          return const _SectionMessage(
            text: 'Unable to load stays right now.',
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SectionMessage(text: 'No accommodations available.');
        }

        final accommodations = snapshot.data!.take(5).toList();

        if (isDesktop || isTablet) {
          final columns = isDesktop ? 3 : 2;
          return LayoutBuilder(
            builder: (context, gridConstraints) {
              const spacing = 16.0;
              final itemWidth =
                  (gridConstraints.maxWidth - spacing * (columns - 1)) /
                      columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final accommodation
                      in accommodations.take(columns * 2))
                    AccommodationCard(
                      accommodation: accommodation,
                      width: itemWidth,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccommodationDetailsScreen(
                              accommodation: accommodation,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        }

        return SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accommodations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final accommodation = accommodations[index];
              return AccommodationCard(
                accommodation: accommodation,
                width: cardWidth,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccommodationDetailsScreen(
                        accommodation: accommodation,
                      ),
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

  Widget _buildVehiclesSection({required double cardWidth}) {
    return FutureBuilder<List<Vehicle>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 270);
        }
        if (snapshot.hasError) {
          return const _SectionMessage(
            text: 'Unable to load rentals right now.',
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SectionMessage(text: 'No vehicles available.');
        }

        final vehicles = snapshot.data!.take(5).toList();
        return SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return VehicleCard(
                vehicle: vehicle,
                width: cardWidth,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VehicleDetailsScreen(vehicle: vehicle),
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

  Widget _buildAskDestina(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF0A325C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Destina',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ask Destina',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tell me where you want to go. We'll help plan the rest.",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: Colors.white,
              disabledForegroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            child: const Text('Start planning'),
          ),
          const SizedBox(height: 8),
          Text(
            'Planning assistant preview — coming soon.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSection(BuildContext context, {required bool isDesktop}) {
    const items = [
      _TrustItem(
        icon: Icons.support_agent_outlined,
        title: 'Flight support',
        subtitle: 'Expert help for domestic and international travel.',
      ),
      _TrustItem(
        icon: Icons.badge_outlined,
        title: 'Visa assistance',
        subtitle: 'Guidance from application to approval.',
      ),
      _TrustItem(
        icon: Icons.handshake_outlined,
        title: 'Personal travel consultant',
        subtitle: 'A dedicated planner for your journey.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Travel with confidence',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Trusted support at every step of your trip.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final useRow = constraints.maxWidth >= 860;
            if (useRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: _TrustCard(item: items[i])),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _TrustCard(item: items[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAwardsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            'Our Accolades',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recognition that reflects our promise of exceptional hospitality.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 22),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AwardCard(
                imagePath: 'assets/images/golden.jpg',
                title: 'Gold Winner',
                subtitle: 'Best Customer Service',
              ),
              SizedBox(width: 12),
              AwardCard(
                imagePath: 'assets/images/legend.jpg',
                title: 'Hall of Fame',
                subtitle: 'Legends in Hospitality',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentShell extends StatelessWidget {
  final double maxWidth;
  final EdgeInsets padding;
  final Widget child;

  const _ContentShell({
    required this.maxWidth,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _HeroSearchField extends StatelessWidget {
  final ValueChanged<String>? onSubmitted;

  const _HeroSearchField({this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: TextField(
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
        decoration: InputDecoration(
          hintText: 'Search destinations, tours, or stays',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        ),
      ),
    );
  }
}

class _ServiceShortcutData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ServiceShortcutData({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _ServiceShortcutChip extends StatelessWidget {
  final _ServiceShortcutData data;

  const _ServiceShortcutChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 24, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              data.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _TrustCard extends StatelessWidget {
  final _TrustItem item;

  const _TrustCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppTheme.primary, size: 26),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  final double height;

  const _SectionLoading({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  final String text;

  const _SectionMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}
