import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static Color? primaryColor = Colors.red[900];
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Colors.white;
  static const Color errorColor = Colors.red;
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryTextColor = Color(0xFF757575);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor ?? Colors.red,
        secondary: accentColor,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor),
        bodyLarge: TextStyle(fontSize: 16.0, color: textColor),
        bodyMedium: TextStyle(fontSize: 14.0, color: secondaryTextColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor ?? Colors.red[900],
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:  BorderSide(color: primaryColor ?? Colors.red, width: 2),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor ?? Colors.red,
        secondary: accentColor,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16.0, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor ?? Colors.red, width: 2),
        ),
      ),
    );
  }
}