// apptheme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cleanmind/utilis/size_config.dart';

class AppColors {
  static const primary = Colors.deepPurple;

  static const background = Color(0xFF0F0F0F);
  static const surface = Color(0xFF1E1E1E);
  static const border = Color(0xFF333333);
  static const text = Color(0xFFFFFFFF);
  static const textErr = Color(0xFFC56363);
  static const textMuted = Color(0xFF888888);

  static const iconSecondary = Color(0xFF000000);
  static const iconMuted = Color(0xFFB0B0B0);
}

class AppTypography {
  static TextTheme textTheme() {
    return TextTheme(
      // Big Title
      titleLarge: TextStyle(
        fontSize: SizeConfig.blockWidth * 8,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),

      // Medium Title
      titleMedium: TextStyle(
        fontSize: SizeConfig.blockWidth * 4,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),

      // Highlight / Accent
      titleSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),

      // Body text
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
        height: 1.5,
      ),

      // Small body
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
        height: 1.4,
      ),

      // Muted
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.3,
      ),
    );
  }
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: Colors.greenAccent,
        surface: AppColors.surface,
        error: Colors.red,
      ),

      textTheme: AppTypography.textTheme(),

      fontFamily: GoogleFonts.sen().fontFamily,

      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        elevation: 0,
      ),

      iconTheme: const IconThemeData(color: AppColors.primary, size: 24),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.sen(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
