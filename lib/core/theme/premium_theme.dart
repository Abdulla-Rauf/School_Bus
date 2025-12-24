import 'package:flutter/material.dart';

class PremiumTheme {
  // Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF1E1E1E);
  static const Color neonLime = Color(0xFFFFD700); // The main accent
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF888888);
  static const Color lightGrey = Color(0xFFCCCCCC);

  // Gradients & Shadows
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonLime, Color(0xFFE6B800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> neonShadow = [
    BoxShadow(
      color: neonLime.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: neonLime,
      scaffoldBackgroundColor: black,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: neonLime,
        secondary: neonLime,
        surface: darkGrey,
        background: black,
        onPrimary: black,
        onSecondary: black,
        onSurface: white,
        onBackground: white,
        error: Color(0xFFFF4444),
      ),

      // Typography
      fontFamily: 'SF Pro Display',
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: white, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: white, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: white, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: white),
        bodyMedium: TextStyle(color: lightGrey),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'SF Pro Display',
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: darkGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: white.withOpacity(0.1), width: 1),
        ),
      ),

      // Input Decoration Theme (TextFields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkGrey,
        hintStyle: const TextStyle(color: grey),
        labelStyle: const TextStyle(color: lightGrey),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neonLime, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonLime,
          foregroundColor: black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100), // Pill shape
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonLime,
        foregroundColor: black,
        elevation: 10,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: white),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: black,
        selectedItemColor: neonLime,
        unselectedItemColor: grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
    );
  }
}
