import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/screens/tour_details_screen.dart';
import 'package:flutter/material.dart';

class TourCard extends StatelessWidget {
  final Tour tour;
  final bool isFeatured;

  const TourCard({
    super.key,
    required this.tour,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TourDetailsScreen(tour: tour),
          ),
        );
      },
      child: Card(
        margin: isFeatured
            ? const EdgeInsets.symmetric(vertical: 16.0)
            : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'tour_image_${tour.id}',
                  child: CachedNetworkImage(
                    imageUrl: tour.mainImageUrl,
                    height: 180,
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
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${tour.price.toStringAsFixed(0)}',
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour.title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        tour.duration,
                        style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

