import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/repositories/supabase_inventory_repository.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/screens/splash_screen.dart';
import 'package:destiny/screens/staff/staff_ops_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DEV ONLY — UI redesign preview.
///
/// When true, skips the login gate for browsing Home/Tours/Stays/Vehicles/Flights.
/// Does **not** bypass backend authorization: commerce and staff APIs still
/// require a real Supabase Auth access token. Unauthenticated users cannot
/// submit bookings/enquiries or access staff ops successfully.
const bool devBypassAuth = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await initializeDestinySupabase();

  // M2 cutover: tours/stays/vehicles/awards read Destiny Supabase PostgREST only.
  ApiService.inventoryRepository = SupabaseInventoryRepository();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Destiny Travel & Tours',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routes: {
        StaffOpsScreen.routeName: (_) => const StaffOpsScreen(),
      },
      // Easy to remove: delete the `devBypassAuth` ternary and keep only
      // the StreamBuilder below when restoring production auth gating.
      home: devBypassAuth
          ? const NavigationScreen()
          : StreamBuilder<AuthState>(
              stream: SupabaseAuthService().authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const SplashScreen();
                }

                final session = snapshot.data?.session ??
                    Supabase.instance.client.auth.currentSession;
                if (session != null) {
                  return const NavigationScreen();
                }
                return const LoginScreen();
              },
            ),
    );
  }
}
