import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';

class AccommodationCard extends StatelessWidget {
  final Accommodation accommodation;
  final VoidCallback? onTap;
  final double? width;
  final double imageHeight;

  const AccommodationCard({
    super.key,
    required this.accommodation,
    this.onTap,
    this.width,
    this.imageHeight = 186,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardWidth = width ?? 280.0;
    final location = [
      if (accommodation.city.trim().isNotEmpty) accommodation.city.trim(),
      if (accommodation.country.trim().isNotEmpty) accommodation.country.trim(),
    ].join(', ');

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: TravelNetworkImage(
                  imageUrl: accommodation.mainImageUrl,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              accommodation.type.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              accommodation.name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                location,
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
