import 'dart:async';
import 'package:destiny/resources/app_colors.dart';
import 'package:destiny/screens/accommodation_list_screen.dart';
import 'package:destiny/screens/contact_screen.dart';
import 'package:destiny/screens/flights_screen.dart';
import 'package:destiny/screens/home_screen.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/my_bookings_screen.dart';
import 'package:destiny/screens/my_trips_screen.dart';
import 'package:destiny/screens/profile_screen.dart';
import 'package:destiny/screens/travel_documents_screen.dart';
import 'package:destiny/screens/tour_list_screen.dart';
import 'package:destiny/screens/vehicle_list_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        MyBookingsScreen(),
        TravelDocumentsScreen(userId: _sqlUserId!),
        ProfileScreen(),
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

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
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
      icon: const Icon(Icons.menu, color: AppColors.textPrimary),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'my_trips',
          child: ListTile(
              leading: Icon(Icons.flight_takeoff_outlined),
              title: Text('My Trips')),
        ),
        const PopupMenuItem<String>(
          value: 'my_bookings',
          child: ListTile(
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('My Bookings')),
        ),
        const PopupMenuItem<String>(
          value: 'travel_documents',
          child: ListTile(
              leading: Icon(Icons.folder_open_outlined),
              title: Text('Travel Documents')),
        ),
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
              leading: Icon(Icons.person_outline), title: Text('Profile')),
        ),
        const PopupMenuItem<String>(
          value: 'contact',
          child: ListTile(
              leading: Icon(Icons.contact_mail_outlined),
              title: Text('Contact Us')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _getWidgetOptions(context);
    final isContactScreen = _selectedIndex == 9;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        titleSpacing: 0,
        title: Image.asset(
          'assets/images/bar_logo2.png',
          height: 70,
          width: 210,
        ),
        centerTitle: false,
        actions: [
          _buildPopupMenu(),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.route),
            activeIcon: Icon(FontAwesomeIcons.route),
            label: 'Tours',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hotel_outlined),
            activeIcon: Icon(Icons.hotel),
            label: 'Stays',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_takeoff_outlined),
            activeIcon: Icon(Icons.flight_takeoff),
            label: 'Flights',
          ),
        ],
        currentIndex: _selectedIndex < 5 ? _selectedIndex : 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}
