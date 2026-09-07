import 'package:carousel_slider/carousel_slider.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:destiny/utils/tour_display.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TourDetailsScreen extends StatefulWidget {
  final Tour tour;
  const TourDetailsScreen({super.key, required this.tour});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  int _galleryIndex = 0;

  void _showBookingCanvas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingSheetContent(tour: widget.tour),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: isDesktop ? _buildDesktop(context) : _buildMobile(context),
          bottomNavigationBar: isDesktop
              ? null
              : _MobileBookingBar(
                  tour: widget.tour,
                  onBook: _showBookingCanvas,
                ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    final tour = widget.tour;
    final duration = TourDisplay.meaningfulDuration(tour.duration);
    final images = tour.resolvedImageUrls;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 360,
          pinned: true,
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: _TourGallery(
              images: images,
              heroTag: 'tour_image_${tour.id}',
              height: 360,
              index: _galleryIndex,
              onIndexChanged: (i) => setState(() => _galleryIndex = i),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tour.isFeatured) ...[
                  const _DestinyPickBadge(),
                  const SizedBox(height: 12),
                ],
                Text(
                  tour.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (duration != null)
                      _MetaPill(
                        icon: Icons.schedule_rounded,
                        label: duration,
                      ),
                    Text(
                      TourDisplay.formatFromPrice(tour.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _AboutSection(description: tour.description),
                if (tour.amenities.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _InclusionsSection(amenities: tour.amenities),
                ],
                if (tour.itinerary.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _ItinerarySection(items: tour.itinerary),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final tour = widget.tour;
    final duration = TourDisplay.meaningfulDuration(tour.duration);
    final images = tour.resolvedImageUrls;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ColoredBox(
            color: AppTheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppTheme.contentWideMaxWidth,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to tours'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTheme.contentWideMaxWidth,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: _TourGallery(
                              images: images,
                              heroTag: 'tour_image_${tour.id}',
                              height: 460,
                              index: _galleryIndex,
                              onIndexChanged: (i) =>
                                  setState(() => _galleryIndex = i),
                            ),
                          ),
                          if (images.length > 1) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, i) {
                                  final selected = i == _galleryIndex;
                                  return InkWell(
                                    onTap: () =>
                                        setState(() => _galleryIndex = i),
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      width: 104,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.border,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: TravelNetworkImage(
                                        imageUrl: images[i],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          if (tour.isFeatured) ...[
                            const _DestinyPickBadge(),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            tour.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navy,
                                  height: 1.12,
                                ),
                          ),
                          if (duration != null) ...[
                            const SizedBox(height: 12),
                            _MetaPill(
                              icon: Icons.schedule_rounded,
                              label: duration,
                            ),
                          ],
                          const SizedBox(height: 28),
                          _AboutSection(description: tour.description),
                          if (tour.amenities.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _InclusionsSection(amenities: tour.amenities),
                          ],
                          if (tour.itinerary.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _ItinerarySection(items: tour.itinerary),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 340,
                      child: _DesktopBookingRail(
                        tour: tour,
                        duration: duration,
                        onBook: _showBookingCanvas,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourGallery extends StatelessWidget {
  final List<String> images;
  final String heroTag;
  final double height;
  final int index;
  final ValueChanged<int> onIndexChanged;

  const _TourGallery({
    required this.images,
    required this.heroTag,
    required this.height,
    required this.index,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: const ColoredBox(color: AppTheme.imagePlaceholder),
      );
    }

    if (images.length == 1) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Hero(
          tag: heroTag,
          child: TravelNetworkImage(imageUrl: images.first),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: heroTag,
            child: CarouselSlider.builder(
              itemCount: images.length,
              itemBuilder: (context, i, _) {
                return TravelNetworkImage(imageUrl: images[i]);
              },
              options: CarouselOptions(
                height: height,
                viewportFraction: 1,
                enableInfiniteScroll: images.length > 1,
                onPageChanged: (i, _) => onIndexChanged(i),
                initialPage: index,
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinyPickBadge extends StatelessWidget {
  const _DestinyPickBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Destiny Pick',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String description;

  const _AboutSection({required this.description});

  @override
  Widget build(BuildContext context) {
    final text = description.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this journey',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.65,
                  fontSize: 15.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _InclusionsSection extends StatelessWidget {
  final List<Amenity> amenities;

  const _InclusionsSection({required this.amenities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's included",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
        ),
        const SizedBox(height: 14),
        ...amenities.map((amenity) {
          final included = amenity.included;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  included
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: 20,
                  color: included ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    amenity.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: included
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight:
                              included ? FontWeight.w600 : FontWeight.w500,
                          decoration: included
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ItinerarySection extends StatelessWidget {
  final List<Itinerary> items;

  const _ItinerarySection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Itinerary',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
        ),
        const SizedBox(height: 16),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          final activity = item.activity.trim();
          final date = item.date.trim();
          final location = item.location.trim();
          final description = item.description.trim();

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: AppTheme.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activity.isNotEmpty)
                          Text(
                            activity,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                        if (date.isNotEmpty || location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (date.isNotEmpty) date,
                              if (location.isNotEmpty) location,
                            ].join(' · '),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.5,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MobileBookingBar extends StatelessWidget {
  final Tour tour;
  final VoidCallback onBook;

  const _MobileBookingBar({
    required this.tour,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: AppTheme.border.withValues(alpha: 0.9)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    TourDisplay.formatPrice(tour.price),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopBookingRail extends StatelessWidget {
  final Tour tour;
  final String? duration;
  final VoidCallback onBook;

  const _DesktopBookingRail({
    required this.tour,
    required this.duration,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan this tour',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'From',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              TourDisplay.formatPrice(tour.price),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
            ),
            if (duration != null) ...[
              const SizedBox(height: 14),
              _MetaPill(icon: Icons.schedule_rounded, label: duration!),
            ],
            const SizedBox(height: 18),
            Text(
              'An agent will confirm availability and travel dates after you request this tour.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Book this tour'),
              ),
            ),
          ],
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
        if (mounted) {
          setState(() {
            _sqlId = appUser.sqlId;
          });
        }
      }
    }
  }

  void _incrementTravelers() => setState(() => _travelerCount++);
  void _decrementTravelers() => setState(() {
        if (_travelerCount > 1) _travelerCount--;
      });

  Future<void> _confirmBooking() async {
    if (_sqlId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book this tour.'),
          backgroundColor: AppTheme.accent,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      // Existing API contract — dates remain placeholders until booking IA is redesigned.
      await _apiService.createBooking(
        sqlId: _sqlId!,
        itemId: widget.tour.id,
        itemType: 'tour',
        numTravelers: _travelerCount,
        totalPrice: widget.tour.price * _travelerCount,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking Confirmed! One of our agents will contact you. Please complete your contact details in My Profile.',
          ),
          backgroundColor: AppTheme.primary,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking Failed: ${e.toString()}'),
          backgroundColor: AppTheme.accent,
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
    final totalPrice = widget.tour.price * _travelerCount;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Request this tour',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.tour.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Travel dates are confirmed by a Destiny agent after your request — this is not a self-serve calendar booking.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Travelers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _decrementTravelers,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Text(
                          '$_travelerCount',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        IconButton(
                          onPressed: _incrementTravelers,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimated total',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      TourDisplay.formatPrice(totalPrice),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isBooking ? null : _confirmBooking,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Confirm request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
