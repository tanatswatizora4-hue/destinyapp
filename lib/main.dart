import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/repositories/catalog_inventory_repository.dart';
import 'package:destiny/repositories/chained_inventory_repository.dart';
import 'package:destiny/repositories/supabase_inventory_repository.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/screens/splash_screen.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/utils/destiny_media_legacy_map.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Import this
import 'firebase_options.dart';

/// DEV ONLY — UI redesign preview.
/// Set to `false` (or remove this flag + the bypass branch) to restore
/// the production auth landing/login flow. Does not delete Firebase Auth.
const bool devBypassAuth = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add these lines for edge-to-edge display
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Owned-media → bymapara uploads fallback while Storage objects catch up.
  await DestinyMediaLegacyMap.load();

  // Inventory precedence (first non-empty wins; never merges sources):
  // 1) Supabase PostgREST when anon key is configured
  // 2) Public destiny-media catalog.json when uploaded
  // 3) Bundled Destiny catalog asset (owned paths; legacy image fallback)
  // Legacy bymapara PHP inventory reads are retired from this chain.
  // Bookings/profile/docs still use ApiService → bymapara intentionally.
  ApiService.inventoryRepository = ChainedInventoryRepository([
    SupabaseInventoryRepository(),
    StorageCatalogInventoryRepository(),
    AssetCatalogInventoryRepository(),
  ]);

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
      // Easy to remove: delete the `devBypassAuth` ternary and keep only
      // the StreamBuilder below when restoring production auth gating.
      home: devBypassAuth
          ? const NavigationScreen()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // Check if Firebase connection is still loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                // Check if the user is authenticated
                if (snapshot.hasData) {
                  // User is signed in, show the main navigation screen
                  return const NavigationScreen();
                } else {
                  // User is not signed in, show the login screen
                  return const LoginScreen();
                }
              },
            ),
    );
  }
}
