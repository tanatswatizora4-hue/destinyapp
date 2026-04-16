import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/screens/login_screen.dart';
import 'package:destiny/screens/navigation_screen.dart';
import 'package:destiny/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Import this
import 'firebase_options.dart';

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
      home: StreamBuilder<User?>(
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
