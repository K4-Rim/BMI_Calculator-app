import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../translations/en.dart' as en;
import '../translations/ar.dart' as ar;
import '../translations/fr.dart' as fr;

class LocalizationService {
  // The current locale
  static Locale? _currentLocale;

  // Default locale
  static const Locale _defaultLocale = Locale('en');

  // Supported locales
  static final List<Locale> _supportedLocales = [
    const Locale('en'),
    const Locale('ar'),
    const Locale('fr'),
  ];

  // Static getter for supported locales
  static List<Locale> get supportedLocales => _supportedLocales;

  // Get the current locale
  static Locale get currentLocale => _currentLocale ?? _defaultLocale;

  // Translation maps for each supported language
  static final Map<String, Map<String, String>> _translations = {
    'en': en.translations,
    'ar': ar.translations,
    'fr': fr.translations,
  };

  // Initialize the localization service
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('locale');

    if (savedLocale != null && _supportedLocales.any((locale) => locale.languageCode == savedLocale)) {
      _currentLocale = Locale(savedLocale);
    } else {
      // Try to use device locale if it's supported
      final deviceLocale = ui.window.locale;
      if (_supportedLocales.any((locale) => locale.languageCode == deviceLocale.languageCode)) {
        _currentLocale = Locale(deviceLocale.languageCode);
      } else {
        _currentLocale = _defaultLocale;
      }
    }
  }

  // Change the current locale
  static Future<void> changeLocale(String languageCode) async {
    if (_supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      _currentLocale = Locale(languageCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale', languageCode);
    }
  }

  // Get a translated string
  static String translate(String key) {
    final langCode = currentLocale.languageCode;
    return _translations[langCode]?[key] ?? _translations['en']?[key] ?? key;
  }
}

// Extension to make it easier to use translations
extension TranslationExtension on String {
  String get tr => LocalizationService.translate(this);
}