import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccommodationCard extends StatelessWidget {
  final Accommodation accommodation;
  final VoidCallback? onTap;
  final double? width;
  final double imageHeight;
  final bool expand;

  const AccommodationCard({
    super.key,
    required this.accommodation,
    this.onTap,
    this.width,
    this.imageHeight = 186,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final location = accommodation.locationLabel;
    final from = accommodation.fromPrice;

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Hero(
                  tag: 'accommodation_image_${accommodation.id}',
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: TravelNetworkImage(
                      imageUrl: accommodation.mainImageUrl,
                    ),
                  ),
                ),
                if (accommodation.isFeatured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Destiny Pick',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (accommodation.type.trim().isNotEmpty)
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
          if (from != null && from > 0) ...[
            const SizedBox(height: 8),
            Text(
              'From ${currency.format(from)} / night',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
          ],
        ],
      ),
    );

    if (expand) return content;
    return SizedBox(width: width ?? 280.0, child: content);
  }
}
