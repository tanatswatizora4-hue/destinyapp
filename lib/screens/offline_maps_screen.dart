// File: offline_maps_screen.dart
// Root: destiny/lib/screens/
import 'package:destiny/resources/app_strings.dart';
import 'package:destiny/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';

class OfflineMapsScreen extends StatelessWidget {
  const OfflineMapsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(titleText: AppStrings.offlineMapsTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 20),
              const Text(
                'Offline Maps Feature Coming Soon!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Download maps for your tours and navigate without an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
