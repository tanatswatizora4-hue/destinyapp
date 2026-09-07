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
import 'package:destiny/widgets/travel_network_image.dart';
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
          final pagePad = isDesktop ? 32.0 : (isTablet ? 20.0 : 16.0);
          final heroHeight = isDesktop ? 520.0 : (isTablet ? 460.0 : 400.0);
          final shortcutOverlap = isDesktop ? 40.0 : 34.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCluster(
                  context,
                  heroHeight: heroHeight,
                  isDesktop: isDesktop,
                  pagePad: pagePad,
                  shortcutOverlap: shortcutOverlap,
                ),
                SizedBox(height: shortcutOverlap + 12),
                _ContentShell(
                  maxWidth: AppTheme.contentMaxWidth,
                  padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 0),
                  child: _buildAskDestinaCompact(context, isDesktop: isDesktop),
                ),
                const SizedBox(height: 22),
                _SectionBand(
                  color: AppTheme.surfaceAlt,
                  child: _ContentShell(
                    maxWidth: AppTheme.contentWideMaxWidth,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      26,
                      isDesktop ? 24 : pagePad,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Destiny Picks',
                          subtitle: 'Featured journeys worth the flight',
                          onViewMore: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TourListScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildFeaturedToursSection(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildEditorialMoment(context, isDesktop: isDesktop),
                _SectionBand(
                  color: AppTheme.surface,
                  child: _ContentShell(
                    maxWidth: AppTheme.contentWideMaxWidth,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      24,
                      isDesktop ? 40 : pagePad,
                      26,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Top Stays',
                          subtitle: 'Places guests actually want to linger',
                          onViewMore: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AccommodationListScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildAccommodationsSection(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          pagePad: pagePad,
                        ),
                      ],
                    ),
                  ),
                ),
                _SectionBand(
                  color: AppTheme.surfaceAlt,
                  child: _ContentShell(
                    maxWidth: AppTheme.contentWideMaxWidth,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      24,
                      isDesktop ? 40 : pagePad,
                      26,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Popular Rentals',
                          subtitle: 'Get around with confidence',
                          onViewMore: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VehicleListScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildVehiclesSection(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildDarkDestinaBand(context, isDesktop: isDesktop),
                _SectionBand(
                  color: AppTheme.surface,
                  child: _ContentShell(
                    maxWidth: AppTheme.contentMaxWidth,
                    padding: EdgeInsets.fromLTRB(pagePad, 24, pagePad, 18),
                    child: _buildTrustSection(context, isDesktop: isDesktop),
                  ),
                ),
                _SectionBand(
                  color: const Color(0xFFE8EEF5),
                  child: _ContentShell(
                    maxWidth: AppTheme.contentMaxWidth,
                    padding: EdgeInsets.fromLTRB(pagePad, 22, pagePad, 36),
                    child: _buildAwardsSection(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCluster(
    BuildContext context, {
    required double heroHeight,
    required bool isDesktop,
    required double pagePad,
    required double shortcutOverlap,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
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
                      Color(0x590A2540),
                      Color(0x8C0A2540),
                      Color(0xE60A2540),
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? AppTheme.contentWideMaxWidth
                          : AppTheme.contentMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 40 : pagePad,
                        20,
                        isDesktop ? 40 : pagePad,
                        shortcutOverlap + 28,
                      ),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _HeroCopy(
                                    textTheme: textTheme,
                                    isDesktop: true,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 5,
                                  child: _HeroSearchField(
                                    onSubmitted: (_) {
                                      _showPreviewMessage(
                                        'Search is coming soon — browse Destiny Picks below.',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeroCopy(
                                  textTheme: textTheme,
                                  isDesktop: false,
                                ),
                                const SizedBox(height: 16),
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
        ),
        Positioned(
          left: pagePad,
          right: pagePad,
          bottom: -shortcutOverlap,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTheme.contentMaxWidth,
              ),
              child: _buildServiceShortcuts(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceShortcuts(BuildContext context) {
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

    // Distinct from the global floating dock: labeled service discovery tiles
    // (solid surface, square icon wells) rather than another nav bar.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Plan your trip',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.2,
                      fontSize: 12.5,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Book a service',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11.5,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in shortcuts) ...[
                        _ServiceShortcutTile(data: item),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < shortcuts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _ServiceShortcutTile(data: shortcuts[i])),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAskDestinaCompact(
    BuildContext context, {
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 14 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.07),
            const Color(0xFFEEF4FB),
            Colors.white,
          ],
        ),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: isDesktop
          ? Row(
              children: [
                _DestinaMark(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Destina',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '“5 nights in Zanzibar for two, around \$2,500…”',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppTheme.primary,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Start planning'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DestinaMark(),
                    const SizedBox(width: 10),
                    Text(
                      'Ask Destina',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '“5 nights in Zanzibar for two, around \$2,500…”',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppTheme.primary,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: const Text('Start planning'),
                  ),
                ),
              ],
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
                      fontSize: 28,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
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
              foregroundColor: AppTheme.accent,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('View all'),
          ),
      ],
    );
  }

  Widget _buildFeaturedToursSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    return FutureBuilder<List<Tour>>(
      future: _toursFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 380);
        }
        if (snapshot.hasError) {
          return const _SectionMessage(text: 'Unable to load tours right now.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SectionMessage(
            text: 'No tours available at the moment.',
          );
        }

        final featuredTours =
            snapshot.data!.where((t) => t.isFeatured).toList();
        if (featuredTours.isEmpty) {
          return const _SectionMessage(
            text: 'No featured tours at the moment.',
          );
        }

        final cardWidth = isDesktop ? 380.0 : (isTablet ? 320.0 : 280.0);
        final cardHeight = isDesktop ? 440.0 : (isTablet ? 400.0 : 360.0);

        return SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featuredTours.length,
            separatorBuilder: (_, __) => SizedBox(width: isDesktop ? 18 : 12),
            itemBuilder: (context, index) {
              return TourCard(
                tour: featuredTours[index],
                isFeatured: true,
                width: cardWidth,
                height: cardHeight,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEditorialMoment(
    BuildContext context, {
    required bool isDesktop,
  }) {
    return FutureBuilder<List<Tour>>(
      future: _toursFuture,
      builder: (context, snapshot) {
        final featured = snapshot.data
                ?.where((t) => t.isFeatured)
                .toList() ??
            const <Tour>[];
        final tour = featured.isNotEmpty ? featured.first : null;

        return SizedBox(
          height: isDesktop ? 280 : 240,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tour != null)
                TravelNetworkImage(imageUrl: tour.mainImageUrl)
              else
                Image.asset(
                  'assets/images/legend.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppTheme.navy),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF20A2540),
                      Color(0x990A2540),
                      Color(0x330A2540),
                    ],
                  ),
                ),
              ),
              _ContentShell(
                maxWidth: AppTheme.contentWideMaxWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48 : 20,
                  vertical: 28,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Travel, edited for real life',
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    fontSize: isDesktop ? 36 : 28,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tour?.title ??
                              'From weekend escapes to once-in-a-lifetime routes.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccommodationsSection({
    required bool isDesktop,
    required bool isTablet,
    required double pagePad,
  }) {
    return FutureBuilder<List<Accommodation>>(
      future: _accommodationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 280);
        }
        if (snapshot.hasError) {
          return const _SectionMessage(text: 'Unable to load stays right now.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _SectionMessage(text: 'No accommodations available.');
        }

        final accommodations = snapshot.data!.take(6).toList();

        if (isDesktop || isTablet) {
          final columns = isDesktop ? 3 : 2;
          return LayoutBuilder(
            builder: (context, gridConstraints) {
              const spacing = 14.0;
              final itemWidth =
                  (gridConstraints.maxWidth - spacing * (columns - 1)) /
                      columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: [
                  for (final accommodation in accommodations)
                    AccommodationCard(
                      accommodation: accommodation,
                      width: itemWidth,
                      imageHeight: isDesktop ? 210 : 180,
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
          height: 268,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accommodations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final accommodation = accommodations[index];
              return AccommodationCard(
                accommodation: accommodation,
                width: 240,
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

  Widget _buildVehiclesSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    return FutureBuilder<List<Vehicle>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 160);
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

        if (isDesktop) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final vehicle in vehicles.take(3))
                    VehicleCard(
                      vehicle: vehicle,
                      width: itemWidth,
                      landscape: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleDetailsScreen(vehicle: vehicle),
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
          height: isTablet ? 150 : 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return VehicleCard(
                vehicle: vehicle,
                width: isTablet ? 340 : 250,
                landscape: isTablet,
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

  Widget _buildDarkDestinaBand(
    BuildContext context, {
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      color: AppTheme.navy,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 36 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentWideMaxWidth),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your private travel desk',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 32,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Destina helps shape itineraries, budgets and logistics — coming soon as a product experience.',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.82),
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: AppTheme.accent,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Notify me'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your private travel desk',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Destina helps shape itineraries, budgets and logistics — coming soon.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: AppTheme.accent,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: const Text('Notify me'),
                    ),
                  ],
                ),
        ),
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
                fontSize: 28,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Support that stays with you after booking.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final useRow = constraints.maxWidth >= 860;
            if (useRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: _TrustCard(item: items[i], index: i)),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TrustCard(item: items[i], index: i),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAwardsSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'Our Accolades',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recognition that reflects our promise of exceptional hospitality.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 18),
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
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final TextTheme textTheme;
  final bool isDesktop;

  const _HeroCopy({required this.textTheme, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where will destiny take you?',
          style: textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.05,
            fontSize: isDesktop ? 48 : 32,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Flights, stays, tours and unforgettable journeys.',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
            height: 1.3,
            fontSize: isDesktop ? 18 : 15,
          ),
        ),
      ],
    );
  }
}

class _DestinaMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _SectionBand extends StatelessWidget {
  final Color color;
  final Widget child;

  const _SectionBand({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color, child: child);
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
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withValues(alpha: 0.96),
      child: TextField(
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: 'Search destinations, tours, or stays',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.96),
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
            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
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

class _ServiceShortcutTile extends StatelessWidget {
  final _ServiceShortcutData data;

  const _ServiceShortcutTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(data.icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
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
  final int index;

  const _TrustCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final accentBar = index == 1 ? AppTheme.accent : AppTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: accentBar,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppTheme.primary, size: 22),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}
