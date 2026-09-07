import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/tour.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/tour_card.dart';
import 'package:flutter/material.dart';

enum _TourFeatureFilter { all, featured }

enum _TourPriceFilter {
  all,
  under1000,
  from1000to2000,
  over2000,
}

class TourListScreen extends StatefulWidget {
  const TourListScreen({super.key});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Tour>> _toursFuture;
  List<Tour> _allTours = [];
  String _query = '';
  _TourFeatureFilter _featureFilter = _TourFeatureFilter.all;
  _TourPriceFilter _priceFilter = _TourPriceFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTours() {
    _toursFuture = _apiService.getTours().then((tours) {
      if (mounted) {
        setState(() => _allTours = tours);
      }
      return tours;
    });
  }

  Future<void> _refresh() async {
    setState(_loadTours);
    await _toursFuture;
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _featureFilter != _TourFeatureFilter.all ||
      _priceFilter != _TourPriceFilter.all;

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _featureFilter = _TourFeatureFilter.all;
      _priceFilter = _TourPriceFilter.all;
    });
  }

  List<Tour> get _filteredTours {
    return _allTours.where((tour) {
      final matchesQuery = _query.trim().isEmpty ||
          tour.title.toLowerCase().contains(_query.trim().toLowerCase());

      final matchesFeature = _featureFilter == _TourFeatureFilter.all ||
          (_featureFilter == _TourFeatureFilter.featured && tour.isFeatured);

      final matchesPrice = switch (_priceFilter) {
        _TourPriceFilter.all => true,
        _TourPriceFilter.under1000 => tour.price > 0 && tour.price < 1000,
        _TourPriceFilter.from1000to2000 =>
          tour.price >= 1000 && tour.price <= 2000,
        _TourPriceFilter.over2000 => tour.price > 2000,
      };

      return matchesQuery && matchesFeature && matchesPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final isTablet = width >= 700 && width < 1024;
        final pagePad = isDesktop ? 32.0 : (isTablet ? 20.0 : 16.0);
        final columns = isDesktop ? 3 : (isTablet ? 2 : 1);
        final maxContent = isDesktop
            ? AppTheme.contentWideMaxWidth
            : AppTheme.contentMaxWidth;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DiscoveryIntro(
                  pagePad: pagePad,
                  maxWidth: maxContent,
                  isDesktop: isDesktop,
                  searchController: _searchController,
                  onSearchChanged: (value) {
                    setState(() => _query = value);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: _ControlsBand(
                  pagePad: pagePad,
                  maxWidth: maxContent,
                  featureFilter: _featureFilter,
                  priceFilter: _priceFilter,
                  resultCount: _allTours.isEmpty ? null : _filteredTours.length,
                  hasActiveFilters: _hasActiveFilters,
                  onFeatureChanged: (value) {
                    setState(() => _featureFilter = value);
                  },
                  onPriceChanged: (value) {
                    setState(() => _priceFilter = value);
                  },
                  onClear: _clearFilters,
                ),
              ),
              FutureBuilder<List<Tour>>(
                future: _toursFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _allTours.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ToursMessageState(
                        title: 'Loading journeys',
                        subtitle: 'Gathering Destinations and packages…',
                        loading: true,
                      ),
                    );
                  }

                  if (snapshot.hasError && _allTours.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ToursMessageState(
                        title: 'Unable to load tours',
                        subtitle:
                            'Please check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      ),
                    );
                  }

                  final tours = _filteredTours;
                  if (tours.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ToursMessageState(
                        title: 'No matching tours',
                        subtitle: _hasActiveFilters
                            ? 'Try clearing search or filters to see more journeys.'
                            : 'No tours are available right now.',
                        actionLabel:
                            _hasActiveFilters ? 'Clear filters' : null,
                        onAction: _hasActiveFilters ? _clearFilters : null,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePad, 8, pagePad, 32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContent),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tours.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: isDesktop ? 20 : 14,
                              mainAxisSpacing: isDesktop ? 20 : 14,
                              childAspectRatio: isDesktop
                                  ? 0.72
                                  : (isTablet ? 0.70 : 0.74),
                            ),
                            itemBuilder: (context, index) {
                              return TourCard(tour: tours[index]);
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Space for floating dock on mobile/tablet.
              SliverToBoxAdapter(
                child: SizedBox(height: isDesktop ? 24 : 88),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiscoveryIntro extends StatelessWidget {
  final double pagePad;
  final double maxWidth;
  final bool isDesktop;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _DiscoveryIntro({
    required this.pagePad,
    required this.maxWidth,
    required this.isDesktop,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppTheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pagePad, isDesktop ? 28 : 18, pagePad, 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
                      'Tours',
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
                  'Find your next journey',
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
                    'Browse curated packages with clear durations and pricing — photography first, details when you need them.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                      fontSize: isDesktop ? 16 : 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search tours by title…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.border.withValues(alpha: 0.9),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsBand extends StatelessWidget {
  final double pagePad;
  final double maxWidth;
  final _TourFeatureFilter featureFilter;
  final _TourPriceFilter priceFilter;
  final int? resultCount;
  final bool hasActiveFilters;
  final ValueChanged<_TourFeatureFilter> onFeatureChanged;
  final ValueChanged<_TourPriceFilter> onPriceChanged;
  final VoidCallback onClear;

  const _ControlsBand({
    required this.pagePad,
    required this.maxWidth,
    required this.featureFilter,
    required this.priceFilter,
    required this.resultCount,
    required this.hasActiveFilters,
    required this.onFeatureChanged,
    required this.onPriceChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceAlt.withValues(alpha: 0.55),
      child: Padding(
        padding: EdgeInsets.fromLTRB(pagePad, 14, pagePad, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: featureFilter == _TourFeatureFilter.all &&
                          priceFilter == _TourPriceFilter.all,
                      onTap: () {
                        onFeatureChanged(_TourFeatureFilter.all);
                        onPriceChanged(_TourPriceFilter.all);
                      },
                    ),
                    _FilterChip(
                      label: 'Destiny Picks',
                      selected: featureFilter == _TourFeatureFilter.featured,
                      accent: true,
                      onTap: () => onFeatureChanged(
                        featureFilter == _TourFeatureFilter.featured
                            ? _TourFeatureFilter.all
                            : _TourFeatureFilter.featured,
                      ),
                    ),
                    _FilterChip(
                      label: 'Under \$1,000',
                      selected: priceFilter == _TourPriceFilter.under1000,
                      onTap: () => onPriceChanged(
                        priceFilter == _TourPriceFilter.under1000
                            ? _TourPriceFilter.all
                            : _TourPriceFilter.under1000,
                      ),
                    ),
                    _FilterChip(
                      label: '\$1,000–\$2,000',
                      selected: priceFilter == _TourPriceFilter.from1000to2000,
                      onTap: () => onPriceChanged(
                        priceFilter == _TourPriceFilter.from1000to2000
                            ? _TourPriceFilter.all
                            : _TourPriceFilter.from1000to2000,
                      ),
                    ),
                    _FilterChip(
                      label: 'Over \$2,000',
                      selected: priceFilter == _TourPriceFilter.over2000,
                      onTap: () => onPriceChanged(
                        priceFilter == _TourPriceFilter.over2000
                            ? _TourPriceFilter.all
                            : _TourPriceFilter.over2000,
                      ),
                    ),
                    if (hasActiveFilters)
                      TextButton(
                        onPressed: onClear,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                if (resultCount != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$resultCount ${resultCount == 1 ? 'journey' : 'journeys'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        accent ? AppTheme.accent : AppTheme.primary;

    return Material(
      color: selected
          ? selectedColor.withValues(alpha: 0.10)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.35)
                  : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? selectedColor : AppTheme.textPrimary,
                  fontSize: 13,
                ),
          ),
        ),
      ),
    );
  }
}

class _ToursMessageState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToursMessageState({
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
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.landscape_outlined,
                  size: 40,
                  color: AppTheme.textSecondary.withValues(alpha: 0.55),
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
