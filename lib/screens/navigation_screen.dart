import 'dart:async';
import 'dart:ui';

import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/resources/app_colors.dart';
import 'package:destiny/screens/accommodation_list_screen.dart';
import 'package:destiny/screens/contact_screen.dart';
import 'package:destiny/screens/flights_screen.dart';
import 'package:destiny/screens/home_screen.dart';
import 'package:destiny/screens/my_bookings_screen.dart';
import 'package:destiny/screens/my_trips_screen.dart';
import 'package:destiny/screens/profile_screen.dart';
import 'package:destiny/screens/travel_documents_screen.dart';
import 'package:destiny/screens/tour_list_screen.dart';
import 'package:destiny/screens/vehicle_list_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  /// Account-area tabs that require sign-in.
  /// Public: 0 Home, 1 Tours, 2 Stays, 3 Vehicles, 4 Flights, 9 Contact.
  static const List<int> protectedNavIndices = [5, 6, 7, 8];

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  int? _sqlUserId;
  late StreamSubscription<User?> _authSubscription;
  final ApiService _apiService = ApiService();
  bool _isLoadingSqlId = true;
  /// Home desktop hero overlay becomes solid after the user scrolls.
  bool _homeHeroScrolled = false;

  static const _primaryDestinations = <_NavDestination>[
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'Tours',
      icon: Icons.route_outlined,
      activeIcon: Icons.route_rounded,
    ),
    _NavDestination(
      label: 'Stays',
      icon: Icons.hotel_outlined,
      activeIcon: Icons.hotel_rounded,
    ),
    _NavDestination(
      label: 'Vehicles',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
    ),
    _NavDestination(
      label: 'Flights',
      icon: Icons.flight_takeoff_outlined,
      activeIcon: Icons.flight_takeoff_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is signed in, fetch the corresponding SQL ID
        try {
          final userData = await _apiService.syncUserWithSql(
              user.uid, user.displayName ?? '', user.email ?? '');
          setState(() {
            _sqlUserId = userData['id'];
            _isLoadingSqlId = false;
          });
        } catch (e) {
          debugPrint('Failed to sync user with SQL: $e');
          setState(() {
            _sqlUserId = null;
            _isLoadingSqlId = false;
          });
        }
      } else {
        // User is signed out, reset the SQL ID
        setState(() {
          _sqlUserId = null;
          _isLoadingSqlId = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // A list of widgets that are conditionally built based on selected index
  List<Widget> _getWidgetOptions(BuildContext context) {
    if (_isLoadingSqlId) {
      return List.filled(
        10,
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_sqlUserId != null) {
      return <Widget>[
        HomeScreen(
          onScrollOffsetChanged: (offset) {
            final scrolled = offset > 72;
            if (scrolled != _homeHeroScrolled) {
              setState(() => _homeHeroScrolled = scrolled);
            }
          },
        ),
        const TourListScreen(),
        const AccommodationListScreen(),
        const VehicleListScreen(),
        FlightsScreen(userId: _sqlUserId),
        MyTripsScreen(userId: _sqlUserId!),
        const MyBookingsScreen(),
        TravelDocumentsScreen(userId: _sqlUserId!),
        const ProfileScreen(),
        const ContactScreen(),
      ];
    } else {
      // Public browse tabs remain available when signed out.
      // Account-area tabs (5–8) show placeholders until sign-in.
      return <Widget>[
        HomeScreen(
          onScrollOffsetChanged: (offset) {
            final scrolled = offset > 72;
            if (scrolled != _homeHeroScrolled) {
              setState(() => _homeHeroScrolled = scrolled);
            }
          },
        ),
        const TourListScreen(),
        const AccommodationListScreen(),
        const VehicleListScreen(),
        const FlightsScreen(),
        _buildPlaceholder('Please sign in to view your trips.'),
        _buildPlaceholder('Please sign in to view your bookings.'),
        _buildPlaceholder('Please sign in to view your travel documents.'),
        _buildPlaceholder('Please sign in to view your profile.'),
        const ContactScreen(),
      ];
    }
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    // Public: 0 Home, 1 Tours, 2 Stays, 3 Vehicles, 4 Flights, 9 Contact.
    // Protected account area: 5 My Trips, 6 Bookings, 7 Docs, 8 Profile.
    const protectedIndices = NavigationScreen.protectedNavIndices;

    if (protectedIndices.contains(index) && _sqlUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be signed in to access this feature.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
      if (index != 0) {
        _homeHeroScrolled = false;
      }
    });
  }

  /// Primary-nav highlight follows the same rule as the previous bottom bar:
  /// indices 0–4 highlight themselves; overflow destinations fall back to Home.
  int get _primaryHighlightIndex =>
      _selectedIndex < 5 ? _selectedIndex : 0;

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'my_trips':
        _onItemTapped(5);
        break;
      case 'my_bookings':
        _onItemTapped(6);
        break;
      case 'travel_documents':
        _onItemTapped(7);
        break;
      case 'profile':
        _onItemTapped(8);
        break;
      case 'contact':
        _onItemTapped(9);
        break;
      case 'logout':
        AuthService().signOut();
        break;
    }
  }

  Future<void> _openAccountMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(buttonContext, rootOverlay: true);
    final overlay = overlayState?.context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !buttonContext.mounted) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: buttonContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'my_trips',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flight_takeoff_outlined),
            title: Text('My Trips'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'my_bookings',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('My Bookings'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'travel_documents',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.folder_open_outlined),
            title: Text('Travel Documents'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'contact',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.contact_mail_outlined),
            title: Text('Contact Us'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.exit_to_app, color: AppColors.accent),
            title: Text('Logout', style: TextStyle(color: AppColors.accent)),
          ),
        ),
      ],
    );

    if (selected != null && mounted) {
      _handleMenuSelection(selected);
    }
  }

  Widget _buildPopupMenu({
    required bool compact,
    bool onHero = false,
  }) {
    // Explicit InkWell + showMenu so the visible control is the sole hit target.
    final fg = onHero ? Colors.white : AppColors.textPrimary;
    final fgMuted =
        onHero ? Colors.white.withValues(alpha: 0.82) : AppColors.textSecondary;
    final fill = onHero
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.surfaceAlt;
    final border = onHero
        ? Colors.white.withValues(alpha: 0.28)
        : AppTheme.border;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 10 : 16),
      child: Builder(
        builder: (buttonContext) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key(compact ? 'nav_menu_button' : 'nav_account_button'),
              onTap: () => _openAccountMenu(buttonContext),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: compact
                    ? SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.menu_rounded,
                            color: fg,
                            size: 22,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 18, color: fg),
                              const SizedBox(width: 8),
                              Text(
                                'Account',
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: fgMuted),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required bool isDesktop,
    required bool overlayHomeHero,
  }) {
    final toolbarHeight = isDesktop ? 72.0 : 64.0;

    return AppBar(
      backgroundColor:
          overlayHomeHero ? Colors.transparent : AppTheme.surface.withValues(alpha: 0.96),
      elevation: 0,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: overlayHomeHero,
      toolbarHeight: toolbarHeight,
      titleSpacing: isDesktop ? 20 : 12,
      automaticallyImplyLeading: false,
      // Decorative only — must not intercept AppBar title/actions hit tests.
      flexibleSpace: overlayHomeHero
          ? IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            )
          : IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.96),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
      title: isDesktop
          ? Row(
              children: [
                Image.asset(
                  'assets/images/bar_logo2.png',
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Center(
                    child: _DesktopTopNav(
                      destinations: _primaryDestinations,
                      selectedIndex: _primaryHighlightIndex,
                      onTap: _onItemTapped,
                      onHero: overlayHomeHero,
                    ),
                  ),
                ),
              ],
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/bar_logo2.png',
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
      actions: [
        _buildPopupMenu(
          compact: !isDesktop,
          onHero: overlayHomeHero,
        ),
      ],
    );
  }

  Widget _buildFloatingDock({required bool isTablet}) {
    // Blur is decorative only (IgnorePointer). Interactive row sits above so
    // BackdropFilter cannot swallow primary-tab taps on Flutter web.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 28 : 14,
          0,
          isTablet ? 28 : 14,
          10,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 560 : 480,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: const ColoredBox(color: Color(0xE6FFFFFF)),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < _primaryDestinations.length; i++)
                            Expanded(
                              child: _DockNavItem(
                                key: Key('dock_nav_$i'),
                                destination: _primaryDestinations[i],
                                selected: _primaryHighlightIndex == i,
                                onTap: () => _onItemTapped(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _getWidgetOptions(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 700 && width < 1024;
    // Home desktop only: present nav over the cinematic hero (no white bar).
    // After scroll, restore solid chrome for contrast over Destina/Picks.
    final overlayHomeHero =
        isDesktop && _selectedIndex == 0 && !_homeHeroScrolled;

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: !isDesktop,
      extendBodyBehindAppBar: overlayHomeHero,
      appBar: _buildAppBar(
        isDesktop: isDesktop,
        overlayHomeHero: overlayHomeHero,
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar:
          isDesktop ? null : _buildFloatingDock(isTablet: isTablet),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _DockNavItem extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _DockNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    width: selected ? 14 : 0,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopNav extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool onHero;

  const _DesktopTopNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _DesktopNavLink(
              key: Key('desktop_nav_$i'),
              destination: destinations[i],
              selected: selectedIndex == i,
              onTap: () => onTap(i),
              onHero: onHero,
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopNavLink extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool onHero;

  const _DesktopNavLink({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedFg =
        onHero ? Colors.white : AppColors.primary;
    final Color idleFg = onHero
        ? Colors.white.withValues(alpha: 0.88)
        : AppColors.textPrimary;
    final Color idleIcon = onHero
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.textSecondary;
    final Color selectedFill = onHero
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.primary.withValues(alpha: 0.09);
    final Color selectedBorder = onHero
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedFill : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? selectedBorder : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 18,
                color: selected ? selectedFg : idleIcon,
              ),
              const SizedBox(width: 8),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? selectedFg : idleFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
