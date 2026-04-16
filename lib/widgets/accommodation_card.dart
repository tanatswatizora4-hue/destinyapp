import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:flutter/material.dart';

class AccommodationCard extends StatelessWidget {
  final Accommodation accommodation;
  final VoidCallback? onTap;

  const AccommodationCard({super.key, required this.accommodation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
              CachedNetworkImage(
                imageUrl: accommodation.mainImageUrl,
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
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accommodation.type.toUpperCase(),
                      style: textTheme.bodySmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accommodation.name,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${accommodation.city}, ${accommodation.country}',
                            style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
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

