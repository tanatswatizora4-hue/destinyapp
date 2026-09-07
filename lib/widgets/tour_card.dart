import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/screens/tour_details_screen.dart';
import 'package:destiny/utils/tour_display.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';

/// Tour discovery / featured card.
///
/// - [isFeatured] = true: fixed-size editorial rail card (Home Destiny Picks).
/// - [isFeatured] = false: responsive discovery card for Tours grid.
/// Destiny Pick badge uses [Tour.isFeatured] from the API in both modes.
class TourCard extends StatelessWidget {
  final Tour tour;
  final bool isFeatured;
  final double? width;
  final double? height;

  const TourCard({
    super.key,
    required this.tour,
    this.isFeatured = false,
    this.width,
    this.height,
  });

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TourDetailsScreen(tour: tour),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isFeatured) {
      return _EditorialRailCard(
        tour: tour,
        width: width,
        height: height,
        onTap: () => _openDetails(context),
      );
    }
    return _DiscoveryTourCard(
      tour: tour,
      width: width,
      onTap: () => _openDetails(context),
    );
  }
}

class _EditorialRailCard extends StatelessWidget {
  final Tour tour;
  final double? width;
  final double? height;
  final VoidCallback onTap;

  const _EditorialRailCard({
    required this.tour,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardWidth = width ?? 360.0;
    final cardHeight = height ?? 420.0;
    final duration = TourDisplay.meaningfulDuration(tour.duration);

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navy.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'tour_image_${tour.id}',
                    child: TravelNetworkImage(imageUrl: tour.mainImageUrl),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x330A2540),
                          Color(0x000A2540),
                          Color(0xCC0A2540),
                          Color(0xF20A2540),
                        ],
                        stops: [0.0, 0.35, 0.72, 1.0],
                      ),
                    ),
                  ),
                  if (tour.isFeatured)
                    const Positioned(
                      top: 16,
                      left: 16,
                      child: _DestinyPickBadge(onDark: true),
                    ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.title,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            fontSize: 22,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (duration != null)
                              Expanded(
                                child: Text(
                                  duration,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              const Spacer(),
                            Text(
                              TourDisplay.formatFromPrice(tour.price),
                              style: textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryTourCard extends StatefulWidget {
  final Tour tour;
  final double? width;
  final VoidCallback onTap;

  const _DiscoveryTourCard({
    required this.tour,
    required this.onTap,
    this.width,
  });

  @override
  State<_DiscoveryTourCard> createState() => _DiscoveryTourCardState();
}

class _DiscoveryTourCardState extends State<_DiscoveryTourCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final duration = TourDisplay.meaningfulDuration(widget.tour.duration);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              width: widget.width,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withValues(
                      alpha: _hovered ? 0.12 : 0.06,
                    ),
                    blurRadius: _hovered ? 24 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'tour_image_${widget.tour.id}',
                            child: TravelNetworkImage(
                              imageUrl: widget.tour.mainImageUrl,
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x220A2540),
                                  Color(0x000A2540),
                                  Color(0x550A2540),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                          if (widget.tour.isFeatured)
                            const Positioned(
                              top: 12,
                              left: 12,
                              child: _DestinyPickBadge(onDark: true),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tour.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          if (duration != null) ...[
                            Text(
                              duration,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            TourDisplay.formatFromPrice(widget.tour.price),
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinyPickBadge extends StatelessWidget {
  final bool onDark;

  const _DestinyPickBadge({required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.28)
              : AppTheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        'Destiny Pick',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onDark ? Colors.white : AppTheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
