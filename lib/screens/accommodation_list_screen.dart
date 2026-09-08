import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/accommodation.dart';
import 'package:destiny/screens/accommodation_details_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/widgets/accommodation_card.dart';
import 'package:destiny/widgets/destiny_discovery.dart';
import 'package:flutter/material.dart';

class AccommodationListScreen extends StatefulWidget {
  const AccommodationListScreen({super.key});

  @override
  State<AccommodationListScreen> createState() =>
      _AccommodationListScreenState();
}

class _AccommodationListScreenState extends State<AccommodationListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Accommodation>> _future;
  List<Accommodation> _all = [];
  String _query = '';
  String _typeFilter = 'All';
  bool _featuredOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _future = _apiService.getAccommodations().then((items) {
      if (mounted) setState(() => _all = items);
      return items;
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  List<String> get _types {
    final set = <String>{};
    for (final item in _all) {
      final t = item.type.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty || _typeFilter != 'All' || _featuredOnly;

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _typeFilter = 'All';
      _featuredOnly = false;
    });
  }

  List<Accommodation> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((item) {
      final matchesQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.city.toLowerCase().contains(q) ||
          item.country.toLowerCase().contains(q);
      final matchesType =
          _typeFilter == 'All' || item.type.trim() == _typeFilter;
      final matchesFeature = !_featuredOnly || item.isFeatured;
      return matchesQuery && matchesType && matchesFeature;
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
                child: DestinyDiscoveryIntro(
                  eyebrow: 'Stays',
                  title: 'Places worth lingering',
                  subtitle:
                      'Browse Destiny stays with photography-first cards, clear locations, and nightly rates when available.',
                  isDesktop: isDesktop,
                  pagePad: pagePad,
                  maxWidth: maxContent,
                  searchController: _searchController,
                  searchHint: 'Search stays by name or destination',
                  onSearchChanged: (v) => setState(() => _query = v),
                  trailing: DestinyDestinaAssist(
                    prompt:
                        '“Quiet lodge near Victoria Falls for four nights…”',
                    onTap: () => showDestinyPreviewMessage(
                      context,
                      'Destina planning is coming soon — browse stays below.',
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: DestinyControlsBand(
                  pagePad: pagePad,
                  maxWidth: maxContent,
                  resultCount: _all.isEmpty ? null : _filtered.length,
                  hasActiveFilters: _hasActiveFilters,
                  onClear: _clearFilters,
                  chips: [
                    for (final type in _types)
                      DestinyFilterChip(
                        label: type,
                        selected: _typeFilter == type,
                        onTap: () => setState(() => _typeFilter = type),
                      ),
                    DestinyFilterChip(
                      label: 'Destiny Picks',
                      selected: _featuredOnly,
                      onTap: () =>
                          setState(() => _featuredOnly = !_featuredOnly),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<Accommodation>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _all.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: DestinyMessageState(
                        title: 'Loading stays',
                        subtitle: 'Gathering lodges, resorts, and hideaways…',
                        loading: true,
                      ),
                    );
                  }
                  if (snapshot.hasError && _all.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: DestinyMessageState(
                        title: 'Unable to load stays',
                        subtitle:
                            'Please check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      ),
                    );
                  }

                  final items = _filtered;
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: DestinyMessageState(
                        title: 'No matching stays',
                        subtitle: _hasActiveFilters
                            ? 'Try clearing search or filters to see more properties.'
                            : 'No stays are available right now.',
                        actionLabel:
                            _hasActiveFilters ? 'Clear filters' : 'Retry',
                        onAction: _hasActiveFilters ? _clearFilters : _refresh,
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
                            itemCount: items.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: isDesktop ? 20 : 14,
                              mainAxisSpacing: isDesktop ? 20 : 14,
                              childAspectRatio:
                                  isDesktop ? 0.74 : (isTablet ? 0.70 : 0.72),
                            ),
                            itemBuilder: (context, index) {
                              final stay = items[index];
                              return AccommodationCard(
                                accommodation: stay,
                                expand: true,
                                imageHeight: isDesktop ? 200 : 176,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AccommodationDetailsScreen(
                                        accommodation: stay,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
