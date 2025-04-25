import 'package:flutter/material.dart';
import '../core/localization_service.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                const Icon(
                  Icons.health_and_safety,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),

                // App Title
                const Text(
                  'BMI Calculator',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // App Subtitle
                Text(
                  'Select Your Language',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 48),

                // Language Selection Buttons
                _buildLanguageButton(
                  context,
                  'English',
                  'en',
                  'assets/icons/us_flag.png',
                ),
                const SizedBox(height: 16),
                _buildLanguageButton(
                  context,
                  'العربية',
                  'ar',
                  'assets/icons/arab_flag.png',
                ),
                const SizedBox(height: 16),
                _buildLanguageButton(
                  context,
                  'Français',
                  'fr',
                  'assets/icons/france_flag.png',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(
      BuildContext context,
      String language,
      String languageCode,
      String flagAsset,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Change the language
          LocalizationService.changeLocale(languageCode);

          // Navigate to the login screen
          Navigator.pushReplacementNamed(context, '/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // We'll display a placeholder icon instead of flag images
            Icon(
              languageCode == 'ar' ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            Text(
              language,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}