// File: custom_app_bar.dart
// Root: destiny/lib/widgets/
import 'package:destiny/resources/app_colors.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;

  const CustomAppBar({Key? key, required this.titleText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1, // Subtle shadow for a professional look
      leadingWidth: 70, // Adjust width to give enough space for the logo

      // Leading widget for the logo on the far left
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0), // Padding from the left edge
        child: Image.asset(
          'assets/images/app_bar_logo.png', // Your logo image
          height: 36, // Adjust height as needed
          width: 36, // Adjust width as needed
        ),
      ),

      // Title widget for the page name
      title: Align(
        alignment: Alignment.centerLeft, // Align title to the left
        child: Text(
          titleText,
          style: const TextStyle(
            color: AppColors.textPrimary, // Or any color that fits your theme
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      centerTitle: false, // Ensure title is left-aligned
      automaticallyImplyLeading: false, // Prevents default back button
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
