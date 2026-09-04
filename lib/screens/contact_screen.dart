// File: lib/screens/contact_screen.dart
// Root: destiny/lib/screens/

import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/resources/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.catchPhrase,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildContactCard(
                      icon: Icons.location_on_outlined,
                      title: 'Our Office',
                      subtitle: AppStrings.address,
                      color: AppTheme.textSecondary,
                    ),
                    const Divider(height: 32),
                    _buildContactCard(
                      icon: Icons.email_outlined,
                      title: 'Email Us',
                      subtitle: AppStrings.emailInfo,
                      color: AppTheme.textSecondary,
                      onTap: () => _launchUrl('mailto:${AppStrings.emailInfo}'),
                    ),
                    const Divider(height: 32),
                    _buildContactCard(
                      icon: Icons.chat_outlined,
                      title: 'WhatsApp Us',
                      subtitle: '+263 77 977 0430',
                      color: const Color(0xFF25D366),
                      onTap: () => _launchUrl('https://wa.me/263779770430'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Follow Our Journey',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialIcon(
                  Icons.facebook,
                  AppStrings.facebookUrl,
                  color: const Color(0xFF1877F2),
                ),
                _buildSocialIcon(
                  Icons.camera_alt_outlined,
                  AppStrings.instagramUrl,
                  color: const Color(0xFFC13584),
                ),
                _buildSocialIcon(
                  Icons.alternate_email,
                  AppStrings.twitterUrl,
                  color: const Color(0xFF1DA1F2),
                ),
                _buildSocialIcon(
                  Icons.business_outlined,
                  AppStrings.linkedinUrl,
                  color: const Color(0xFF0A66C2),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              AppStrings.finalCallToAction,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url, {required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 30, color: color),
        onPressed: () => _launchUrl(url),
      ),
    );
  }
}
