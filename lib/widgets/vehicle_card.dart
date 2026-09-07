import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;
  final double? width;

  /// When true, uses a wider landscape tile distinct from stay cards.
  final bool landscape;

  const VehicleCard({
    super.key,
    required this.vehicle,
    this.onTap,
    this.width,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final cardWidth = width ?? (landscape ? 340.0 : 260.0);
    final name = '${vehicle.make} ${vehicle.model}'.trim();

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
          ),
          clipBehavior: Clip.antiAlias,
          child: landscape
              ? Row(
                  children: [
                    SizedBox(
                      width: cardWidth * 0.46,
                      height: 132,
                      child: TravelNetworkImage(
                        imageUrl: vehicle.mainImageUrl,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: _VehicleMeta(
                          name: name,
                          type: vehicle.type,
                          priceLabel:
                              '${currencyFormat.format(vehicle.pricePerDay)}/day',
                          textTheme: textTheme,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 148,
                      width: double.infinity,
                      child: TravelNetworkImage(
                        imageUrl: vehicle.mainImageUrl,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: _VehicleMeta(
                        name: name,
                        type: vehicle.type,
                        priceLabel:
                            '${currencyFormat.format(vehicle.pricePerDay)}/day',
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _VehicleMeta extends StatelessWidget {
  final String name;
  final String type;
  final String priceLabel;
  final TextTheme textTheme;

  const _VehicleMeta({
    required this.name,
    required this.type,
    required this.priceLabel,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            type.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          priceLabel,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}
