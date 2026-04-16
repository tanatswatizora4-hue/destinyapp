import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;

  const VehicleCard({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // FIX: Corrected the currency format initialization
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display the vehicle's primary image
              CachedNetworkImage(
                imageUrl: vehicle.mainImageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, color: AppTheme.textSecondary),
                ),
              ),
              // Display vehicle details
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vehicle.type,
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${currencyFormat.format(vehicle.pricePerDay)}/day',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}