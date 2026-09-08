import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/utils/destiny_media_url.dart';
import 'package:flutter/material.dart';

/// Tasteful travel image — resolves via [DestinyMediaUrl], intentional fallbacks.
///
/// Accepts raw API paths, Destiny Supabase refs, absolute URLs, or `assets/...`.
class TravelNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TravelNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = DestinyMediaUrl.resolve(imageUrl);

    final Widget image;
    if (DestinyMediaUrl.isAssetRef(resolved)) {
      image = Image.asset(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => const _TravelImageFallback(loading: false),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: resolved,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (context, url) => const _TravelImageFallback(loading: true),
        errorWidget: (context, url, error) =>
            const _TravelImageFallback(loading: false),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _TravelImageFallback extends StatelessWidget {
  final bool loading;

  const _TravelImageFallback({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.imagePlaceholder,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            )
          else
            Icon(
              Icons.landscape_outlined,
              size: 36,
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
            ),
          if (!loading) ...[
            const SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
