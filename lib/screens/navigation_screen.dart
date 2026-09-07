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

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  int? _sqlUserId;
  late StreamSubscription<User?> _authSubscription;
  final ApiService _apiService = ApiService();
  bool _isLoadingSqlId = true;

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
        const HomeScreen(),
        const TourListScreen(),
        const AccommodationListScreen(),
        const VehicleListScreen(),
        FlightsScreen(userId: _sqlUserId!),
        MyTripsScreen(userId: _sqlUserId!),
        const MyBookingsScreen(),
        TravelDocumentsScreen(userId: _sqlUserId!),
        const ProfileScreen(),
        const ContactScreen(),
      ];
    } else {
      // If the user is not authenticated, show a placeholder for protected screens.
      return <Widget>[
        const HomeScreen(),
        const TourListScreen(),
        const AccommodationListScreen(),
        const VehicleListScreen(),
        _buildPlaceholder('Please sign in to plan a trip.'),
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
    final protectedIndices = [4, 5, 6, 7, 8];

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
    });
  }

  /// Primary-nav highlight follows the same rule as the previous bottom bar:
  /// indices 0–4 highlight themselves; overflow destinations fall back to Home.
  int get _primaryHighlightIndex =>
      _selectedIndex < 5 ? _selectedIndex : 0;

  Widget _buildPopupMenu({required bool compact}) {
    // Padding lives outside PopupMenuButton so the entire visible control is
    // the button's hit target (margin on the child left dead zones / web misses).
    return Padding(
      padding: EdgeInsets.only(right: compact ? 10 : 16),
      child: PopupMenuButton<String>(
        tooltip: compact ? 'Menu' : 'Account',
        padding: EdgeInsets.zero,
        offset: const Offset(0, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppTheme.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        onSelected: (value) {
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
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'my_trips',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flight_takeoff_outlined),
              title: Text('My Trips'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'my_bookings',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('My Bookings'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'travel_documents',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_open_outlined),
              title: Text('Travel Documents'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'profile',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline),
              title: Text('Profile'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'contact',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.contact_mail_outlined),
              title: Text('Contact Us'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.exit_to_app, color: AppColors.accent),
              title: Text('Logout', style: TextStyle(color: AppColors.accent)),
            ),
          ),
        ],
        child: compact
            ? Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              )
            : Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text(
                      'Account',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool isDesktop}) {
    return AppBar(
      backgroundColor: AppTheme.surface.withValues(alpha: 0.96),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: isDesktop ? 72 : 64,
      titleSpacing: isDesktop ? 20 : 12,
      automaticallyImplyLeading: false,
      // Decorative only — must not intercept AppBar title/actions hit tests
      // (especially PopupMenuButton on Flutter web).
      flexibleSpace: IgnorePointer(
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
        _buildPopupMenu(compact: !isDesktop),
      ],
    );
  }

  Widget _buildFloatingDock({required bool isTablet}) {
    // Material elevation keeps the dock above extendBody content for hit tests.
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: SafeArea(
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
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
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
                    child: Row(
                      children: [
                        for (var i = 0; i < _primaryDestinations.length; i++)
                          Expanded(
                            child: _DockNavItem(
                              destination: _primaryDestinations[i],
                              selected: _primaryHighlightIndex == i,
                              onTap: () => _onItemTapped(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: !isDesktop,
      appBar: _buildAppBar(isDesktop: isDesktop),
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

  const _DesktopTopNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _DesktopNavLink(
              destination: destinations[i],
              selected: selectedIndex == i,
              onTap: () => onTap(i),
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

  const _DesktopNavLink({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
