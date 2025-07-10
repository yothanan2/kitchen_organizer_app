// lib/main.dart
// NEW THEME: A subtle and cozy style based on soft grays and a muted green accent.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: KitchenOrganizerApp(),
    ),
  );
}

class KitchenOrganizerApp extends StatelessWidget {
  const KitchenOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- NEW SUBTLE COZY PALETTE ---
    const primaryColor = Color(0xFF484848); // A soft, dark charcoal for primary elements
    const secondaryColor = Color(0xFF81A18B); // A muted, sage green accent
    const backgroundColor = Color(0xFFF7F7F7); // A very light, clean gray background
    final textColor = Colors.grey[850]!; // A dark, but not pure black, for text

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      background: backgroundColor,
      onBackground: textColor,
      surface: Colors.white,
      onSurface: textColor,
      brightness: Brightness.light,
    );
    // --- END OF NEW PALETTE ---

    return MaterialApp(
      title: 'Kitchen Organizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,

        fontFamily: 'Lato',
        fontFamilyFallback: const ['Noto Color Emoji'],

        textTheme: TextTheme(
          displayLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          displayMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          displaySmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          headlineLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          headlineMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          headlineSmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          titleLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: textColor),
          titleMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.w600, color: textColor),
          titleSmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.w600, color: textColor),
          bodyLarge: TextStyle(fontSize: 18, color: textColor),
          bodyMedium: TextStyle(fontSize: 16, color: textColor),
          bodySmall: TextStyle(fontSize: 14, color: Colors.grey[700]),
          labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1, // Softer elevation
          titleTextStyle: TextStyle(fontFamily: 'DistinctStyleSans', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),

        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: secondaryColor,
          indicatorSize: TabBarIndicatorSize.tab,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Lato'),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: secondaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),

        cardTheme: CardThemeData(
          elevation: 0, // A flatter, more modern look for cards
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!, width: 1), // Subtle border
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const AuthGate(),
    );
  }
}