import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';

/// Centers child within Destiny content max-widths.
class DestinyContentShell extends StatelessWidget {
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const DestinyContentShell({
    super.key,
    required this.maxWidth,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Discovery page intro: eyebrow, headline, supporting copy, optional search.
class DestinyDiscoveryIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool isDesktop;
  final double pagePad;
  final double maxWidth;
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final Widget? trailing;

  const DestinyDiscoveryIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.isDesktop,
    required this.pagePad,
    required this.maxWidth,
    this.searchController,
    this.searchHint = 'Search…',
    this.onSearchChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppTheme.surface,
      child: DestinyContentShell(
        maxWidth: maxWidth,
        padding: EdgeInsets.fromLTRB(pagePad, isDesktop ? 28 : 18, pagePad, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  eyebrow,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
                fontSize: isDesktop ? 36 : 28,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                  fontSize: isDesktop ? 16 : 14.5,
                ),
              ),
            ),
            if (searchController != null && onSearchChanged != null) ...[
              const SizedBox(height: 20),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class DestinyFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DestinyFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.border.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
          ),
        ),
      ),
    );
  }
}

class DestinyControlsBand extends StatelessWidget {
  final double pagePad;
  final double maxWidth;
  final List<Widget> chips;
  final int? resultCount;
  final bool hasActiveFilters;
  final VoidCallback? onClear;

  const DestinyControlsBand({
    super.key,
    required this.pagePad,
    required this.maxWidth,
    required this.chips,
    this.resultCount,
    this.hasActiveFilters = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceAlt,
      child: DestinyContentShell(
        maxWidth: maxWidth,
        padding: EdgeInsets.fromLTRB(pagePad, 14, pagePad, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (resultCount != null || hasActiveFilters) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (resultCount != null)
                    Text(
                      '$resultCount result${resultCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  const Spacer(),
                  if (hasActiveFilters && onClear != null)
                    TextButton(
                      onPressed: onClear,
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DestinyMessageState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DestinyMessageState({
    super.key,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                Icon(
                  Icons.travel_explore_outlined,
                  size: 40,
                  color: AppTheme.textSecondary.withValues(alpha: 0.55),
                ),
              if (!loading) const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Destina assist band — preview-only CTA until Destina is live.
class DestinyDestinaAssist extends StatelessWidget {
  final String prompt;
  final VoidCallback onTap;
  final bool compact;

  const DestinyDestinaAssist({
    super.key,
    required this.prompt,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.navy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 14 : 18,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Destina',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Ask'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DestinyMediaGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String heroTag;
  final double height;

  const DestinyMediaGallery({
    super.key,
    required this.imageUrls,
    required this.heroTag,
    this.height = 280,
  });

  @override
  State<DestinyMediaGallery> createState() => _DestinyMediaGalleryState();
}

class _DestinyMediaGalleryState extends State<DestinyMediaGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls;
    if (images.isEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const TravelNetworkImage(imageUrl: ''),
      );
    }

    return Column(
      children: [
        Hero(
          tag: widget.heroTag,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => TravelNetworkImage(imageUrl: images[i]),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _index;
                return Container(
                  width: active ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary
                        : AppTheme.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class DestinyMobileCtaBar extends StatelessWidget {
  final String priceLabel;
  final String priceCaption;
  final String ctaLabel;
  final VoidCallback onPressed;

  const DestinyMobileCtaBar({
    super.key,
    required this.priceLabel,
    required this.priceCaption,
    required this.ctaLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceCaption,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                ),
                child: Text(ctaLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DestinyDesktopBookingRail extends StatelessWidget {
  final String title;
  final String priceLabel;
  final String priceCaption;
  final String disclaimer;
  final String ctaLabel;
  final VoidCallback onPressed;
  final Widget? extra;

  const DestinyDesktopBookingRail({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.priceCaption,
    required this.disclaimer,
    required this.ctaLabel,
    required this.onPressed,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            priceCaption,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            priceLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 14),
            extra!,
          ],
          const SizedBox(height: 16),
          Text(
            disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

void showDestinyPreviewMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.primary,
    ),
  );
}
