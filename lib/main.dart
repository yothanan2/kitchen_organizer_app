// lib/main.dart
// UPDATED: Added fontFamilyFallback to properly handle emoji and special characters.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    const primaryColor = Color(0xFF4A6572);
    const secondaryColor = Color(0xFFF9AA33);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Kitchen Organizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),

        fontFamily: 'Lato',

        // --- THIS IS THE NEWLY ADDED LINE ---
        // This tells Flutter which fonts to try if a character (like an emoji)
        // is not found in the primary font.
        fontFamilyFallback: const ['Noto Color Emoji'],

        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          displayMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          displaySmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          headlineLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          headlineMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          headlineSmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          titleLarge: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.bold, color: primaryColor),
          titleMedium: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontFamily: 'DistinctStyleSans', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 14, color: Colors.grey),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
          titleTextStyle: TextStyle(fontFamily: 'DistinctStyleSans', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
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
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),

        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const AuthGate(),
    );
  }
}