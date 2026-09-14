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

export 'package:destiny/config/dev_auth_config.dart' show devBypassAuth;

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
        LoginScreen.routeName: (_) => const LoginScreen(),
      },
      // Session restore: wait for Supabase auth bootstrap, then always use the
      // public navigation shell. Protected routes gate inside NavigationScreen.
      // [devBypassAuth] only controls whether gated actions open LoginScreen.
      home: StreamBuilder<AuthState>(
        stream: SupabaseAuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              Supabase.instance.client.auth.currentSession == null) {
            return const SplashScreen();
          }
          return const NavigationScreen();
        },
      ),
    );
  }
}
