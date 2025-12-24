// grades_theme.dart
import 'package:flutter/material.dart';

class GradesTheme {
  static const Color primaryBlack = Colors.black87;
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color mediumGrey = Color(0xFFE0E0E0);
  static const Color darkGrey = Color(0xFF757575);
  static const Color textBlack = Colors.black87;
  static const Color textGrey = Color(0xFF616161);

  static BoxDecoration cardDecoration = BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: mediumGrey, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration gradientCardDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryBlack, Colors.black54],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
  );

  static TextStyle get headerStyle => TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: textBlack,
    letterSpacing: -0.5,
  );

  static TextStyle get titleStyle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textBlack,
    letterSpacing: 0.2,
  );

  static TextStyle get bodyStyle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textBlack,
  );

  static TextStyle get subtitleStyle => TextStyle(
    fontSize: 13,
    color: darkGrey,
    fontWeight: FontWeight.w500,
  );
}