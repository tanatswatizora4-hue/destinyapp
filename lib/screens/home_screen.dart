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
import 'package:destiny/utils/tour_display.dart';
import 'package:destiny/widgets/accommodation_card.dart';
import 'package:destiny/widgets/award_card.dart';
import 'package:destiny/widgets/tour_card.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:destiny/widgets/vehicle_card.dart';
import 'package:flutter/material.dart';

/// Home-local wide measure — keeps Tours on [AppTheme.contentWideMaxWidth].
const double _homeWideMax = 1520;

/// Canonical Home photographic surfaces (Destiny-owned refs, not absolute URLs).
const String _homeHeroPosterRef = 'destiny-media/home/hero/main.webp';
const String _homeTravelPartnerRef =
    'destiny-media/home/editorial/travel-partner.webp';
const String _homeDestinationInspirationRef =
    'destiny-media/home/editorial/destination-inspiration.webp';

class HomeScreen extends StatefulWidget {
  final ValueChanged<double>? onScrollOffsetChanged;

  const HomeScreen({super.key, this.onScrollOffsetChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Tour>> _toursFuture;
  late Future<List<Accommodation>> _accommodationsFuture;
  late Future<List<Vehicle>> _vehiclesFuture;

  static const Color _coolMist = Color(0xFFE6EDF4);
  static const Color _coolBand = Color(0xFFDDE6EF);
  static const Color _coolDeep = Color(0xFFD2DCE8);

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
          final pagePad = isDesktop ? 36.0 : (isTablet ? 22.0 : 16.0);
          // Cinematic hero — desktop accounts for transparent AppBar overlay.
          final heroHeight = isDesktop ? 640.0 : (isTablet ? 500.0 : 430.0);

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                widget.onScrollOffsetChanged?.call(notification.metrics.pixels);
              }
              return false;
            },
            child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCluster(
                  context,
                  heroHeight: heroHeight,
                  isDesktop: isDesktop,
                  pagePad: pagePad,
                ),
                // Soft cool surface → Destina (first component after hero).
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFEAF0F6),
                        _coolMist,
                        _coolBand,
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: isDesktop ? 32 : 24),
                      _ContentShell(
                        maxWidth: _homeWideMax,
                        padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 28),
                        child: _buildAskDestinaCompact(
                          context,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ],
                  ),
                ),
                _SectionBand(
                  color: _coolDeep,
                  child: _ContentShell(
                    maxWidth: _homeWideMax,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      32,
                      isDesktop ? 28 : pagePad,
                      34,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Destiny Picks',
                          subtitle: 'Featured journeys worth the flight',
                          eyebrow: 'Curated',
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
                    maxWidth: _homeWideMax,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      30,
                      isDesktop ? 40 : pagePad,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Top Stays',
                          subtitle: 'Places guests actually want to linger',
                          eyebrow: 'Stay',
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
                        const SizedBox(height: 16),
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
                    maxWidth: _homeWideMax,
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : pagePad,
                      30,
                      isDesktop ? 40 : pagePad,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          title: 'Popular Rentals',
                          subtitle: 'Get around with confidence',
                          eyebrow: 'Drive',
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
                  color: const Color(0xFFF3F6FA),
                  child: _ContentShell(
                    maxWidth: AppTheme.contentMaxWidth,
                    padding: EdgeInsets.fromLTRB(pagePad, 28, pagePad, 22),
                    child: _buildTrustSection(context, isDesktop: isDesktop),
                  ),
                ),
                _SectionBand(
                  color: _coolMist,
                  child: _ContentShell(
                    maxWidth: AppTheme.contentMaxWidth,
                    padding: EdgeInsets.fromLTRB(pagePad, 26, pagePad, 40),
                    child: _buildAwardsSection(context),
                  ),
                ),
              ],
            ),
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
  }) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Primary Home hero — Destiny-owned photograph (video disabled on Home).
          TravelNetworkImage(
            imageUrl: _homeHeroPosterRef,
            fit: BoxFit.cover,
            width: double.infinity,
            height: heroHeight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x660A2540),
                  Color(0x8C0A2540),
                  Color(0xF00A2540),
                ],
                stops: [0.0, 0.38, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      isDesktop ? _homeWideMax : AppTheme.contentMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : pagePad,
                    isDesktop ? 88 : 24,
                    isDesktop ? 40 : pagePad,
                    isDesktop ? 40 : 28,
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
                            const SizedBox(width: 36),
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _HeroSearchField(
                                  onSubmitted: (_) {
                                    _showPreviewMessage(
                                      'Search is coming soon — browse Destiny Picks below.',
                                    );
                                  },
                                ),
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
                            const SizedBox(height: 18),
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

  Widget _buildAskDestinaCompact(
    BuildContext context, {
    required bool isDesktop,
  }) {
    // Substantial navy signature panel — not a thin strip.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 18,
        vertical: isDesktop ? 26 : 20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A2540),
            Color(0xFF123A5C),
            Color(0xFF1A4A72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                const _DestinaMark(onDark: true),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Destina',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '“5 nights in Zanzibar for two, around \$2,500…”',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                FilledButton(
                  onPressed: () => _showPreviewMessage(
                    'Destina planning is coming soon — explore Destiny Picks meanwhile.',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                    const _DestinaMark(onDark: true),
                    const SizedBox(width: 12),
                    Text(
                      'Ask Destina',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '“5 nights in Zanzibar for two, around \$2,500…”',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _showPreviewMessage(
                      'Destina planning is coming soon — explore Destiny Picks meanwhile.',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
    String? eyebrow,
    VoidCallback? onViewMore,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eyebrow.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                  width: 22,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('View all'),
          ),
      ],
    );
  }

  /// Sizes Destiny Pick cards so an integer column count fits the shell width.
  /// Prefers 4 on desktop when comfortable; never relies on a clipped peek.
  double _destinyPickCardWidth({
    required double availableWidth,
    required double gap,
    required bool isDesktop,
    required bool isTablet,
  }) {
    if (!isDesktop && !isTablet) {
      // Mobile carousel keeps a fixed card; existing horizontal scroll behavior.
      return 292.0;
    }

    final preferredColumns = isDesktop ? 4 : 2;
    final minCard = isDesktop ? 280.0 : 260.0;

    var columns = preferredColumns;
    while (columns > 1) {
      final candidate = (availableWidth - gap * (columns - 1)) / columns;
      if (candidate >= minCard) break;
      columns--;
    }

    // Exact integer-pixel fit so the last visible card is never clipped.
    return ((availableWidth - gap * (columns - 1)) / columns).floorToDouble();
  }

  Widget _buildFeaturedToursSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    return FutureBuilder<List<Tour>>(
      future: _toursFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 400);
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

        // Fit complete cards in the Home content width — never clip a partial.
        final cardHeight = isDesktop ? 460.0 : (isTablet ? 420.0 : 372.0);
        final gap = isDesktop ? 20.0 : 12.0;
        final leadDuration =
            TourDisplay.meaningfulDuration(featuredTours.first.duration);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadDuration != null) ...[
              Text(
                'Lead pick · $leadDuration',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                final cardWidth = _destinyPickCardWidth(
                  availableWidth: available,
                  gap: gap,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
                return SizedBox(
                  height: cardHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    itemCount: featuredTours.length,
                    separatorBuilder: (_, __) => SizedBox(width: gap),
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditorialMoment(
    BuildContext context, {
    required bool isDesktop,
  }) {
    void openTours() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TourListScreen()),
      );
    }

    return ColoredBox(
      color: AppTheme.navy,
      child: SizedBox(
        height: isDesktop ? 340 : 300,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Owned editorial photography via Destiny media resolver.
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: isDesktop ? 0.58 : 1,
                child: const TravelNetworkImage(
                  imageUrl: _homeTravelPartnerRef,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isDesktop
                      ? const [
                          Color(0xFF0A2540),
                          Color(0xF20A2540),
                          Color(0x660A2540),
                          Color(0x1A0A2540),
                        ]
                      : const [
                          Color(0xF20A2540),
                          Color(0xCC0A2540),
                          Color(0x990A2540),
                        ],
                  stops: isDesktop
                      ? const [0.0, 0.32, 0.62, 1.0]
                      : const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            _ContentShell(
              maxWidth: _homeWideMax,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 20,
                vertical: 32,
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
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'DESTINY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'More than a booking.\nA travel partner.',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                  fontSize: isDesktop ? 40 : 30,
                                  letterSpacing: -0.6,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'From weekend escapes to once-in-a-lifetime routes — crafted with you.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: openTours,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Explore journeys'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF071B30),
            Color(0xFF0A2540),
            Color(0xFF123A5C),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 44 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _homeWideMax),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DESTINA',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 10),
                          Text(
                            'Destina helps shape itineraries, budgets and logistics — coming soon as a product experience.',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.82),
                                      height: 1.4,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    FilledButton(
                      onPressed: () => _showPreviewMessage(
                        'We’ll notify you when Destina launches.',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Notify me'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DESTINA',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.6,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => _showPreviewMessage(
                        'We’ll notify you when Destina launches.',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        Row(
          children: [
            Container(
              width: 18,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SUPPORT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 18),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'RECOGNITION',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
        // Accolades copy stays native; photography is destination-inspiration.webp.
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AwardCard(
              imagePath: _homeDestinationInspirationRef,
              title: 'Gold Winner',
              subtitle: 'Best Customer Service',
            ),
            SizedBox(width: 12),
            AwardCard(
              imagePath: _homeDestinationInspirationRef,
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
        Row(
          children: [
            Container(
              width: 20,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Discover more',
              style: textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: isDesktop ? 13 : 12,
              ),
            ),
          ],
        ),
        SizedBox(height: isDesktop ? 14 : 10),
        Text(
          'Where will destiny take you?',
          style: textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.05,
            fontSize: isDesktop ? 52 : 34,
            letterSpacing: -0.9,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : 8),
        Text(
          'Flights, stays, tours and unforgettable journeys.',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
            height: 1.35,
            fontSize: isDesktop ? 18 : 15,
          ),
        ),
      ],
    );
  }
}

class _DestinaMark extends StatelessWidget {
  final bool onDark;

  const _DestinaMark({this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.12) : AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        border: onDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.2))
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome,
        color: onDark ? Colors.white : Colors.white,
        size: 22,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
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
