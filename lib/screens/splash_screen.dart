import 'package:flutter/material.dart';
import 'package:destiny/screens/navigation_screen.dart'; // Assuming this is your main navigation screen
import 'package:destiny/config/theme/app_theme.dart';
import 'package:lottie/lottie.dart'; // Import the lottie package

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to the main screen after a delay
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const NavigationScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation for a smooth loading experience
            Lottie.asset(
              'assets/animations/plane_loader.json', // Path to your Lottie animation file
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 24),
            // Display your logo image here
            Image.asset(
              'assets/images/bar_logo2.png',
              height: 250,
              width: 250,
            ),
          ],
        ),
      ),
    );
  }
}
