import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;
  final double? width;
  final bool landscape;
  final bool expand;

  const VehicleCard({
    super.key,
    required this.vehicle,
    this.onTap,
    this.width,
    this.landscape = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final cardWidth = width ?? (landscape ? 340.0 : 260.0);
    final name = vehicle.displayName;
    final location = vehicle.locationLabel;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Stack(
            children: [
              Hero(
                tag: 'vehicle_image_${vehicle.id}',
                child: SizedBox(
                  height: landscape ? 132 : 160,
                  width: double.infinity,
                  child: TravelNetworkImage(imageUrl: vehicle.mainImageUrl),
                ),
              ),
              if (vehicle.isFeatured)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vehicle.type.trim().isNotEmpty)
                Text(
                  vehicle.type.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontSize: 10,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 1,
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
              const SizedBox(height: 8),
              Text(
                '${currencyFormat.format(vehicle.pricePerDay)}/day',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final card = Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
          ),
          child: column,
        ),
      ),
    );

    if (expand) return card;
    return SizedBox(width: cardWidth, child: card);
  }
}
