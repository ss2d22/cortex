import 'package:flutter/material.dart';

class AppTheme {
  // Core brand colors
  static const Color primaryColor = Color(0xFF6366F1);    // Indigo
  static const Color secondaryColor = Color(0xFF8B5CF6);  // Purple
  static const Color accentColor = Color(0xFF06B6D4);     // Cyan

  // Background colors
  static const Color backgroundColor = Color(0xFF0F0F23);
  static const Color surfaceColor = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252542);
  static const Color cardColor = Color(0xFF1E1E38);

  // Memory type colors
  static const Color episodicColor = Color(0xFF3B82F6);   // Blue - experiences
  static const Color semanticColor = Color(0xFF10B981);   // Emerald - facts
  static const Color proceduralColor = Color(0xFFF59E0B); // Amber - patterns
  static const Color workingColor = Color(0xFFEC4899);    // Pink - active

  // Strength/decay gradient
  static const Color strengthHigh = Color(0xFF22C55E);    // Green
  static const Color strengthMedium = Color(0xFFEAB308);  // Yellow
  static const Color strengthLow = Color(0xFFEF4444);     // Red

  // Emotional valence colors
  static const Color positiveColor = Color(0xFF34D399);   // Emerald light
  static const Color neutralColor = Color(0xFF94A3B8);    // Slate
  static const Color negativeColor = Color(0xFFF87171);   // Red light

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Get color for memory strength (0-1)
  static Color getStrengthColor(double strength) {
    if (strength >= 0.7) return strengthHigh;
    if (strength >= 0.4) return strengthMedium;
    return strengthLow;
  }

  // Get color with opacity based on strength
  static Color getStrengthColorWithOpacity(double strength) {
    final baseColor = getStrengthColor(strength);
    return baseColor.withOpacity(0.3 + strength * 0.7);
  }

  // Memory type gradients
  static LinearGradient get episodicGradient => const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get semanticGradient => const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get proceduralGradient => const LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get workingGradient => const LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration glassDecoration({Color? borderColor}) => BoxDecoration(
    color: surfaceColor.withOpacity(0.8),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: borderColor ?? Colors.white.withOpacity(0.1),
      width: 1,
    ),
  );

  // Text styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textMuted,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: textMuted,
  );

  // Button styles
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  );

  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
    backgroundColor: surfaceLight,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  );

  static ButtonStyle get ghostButton => TextButton.styleFrom(
    foregroundColor: textSecondary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  );

  // Theme data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      background: backgroundColor,
      surface: surfaceColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: headingSmall,
      iconTheme: IconThemeData(color: textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: textMuted,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: bodyMedium.copyWith(color: textMuted),
    ),
    dividerColor: Colors.white.withOpacity(0.1),
    iconTheme: const IconThemeData(color: textSecondary),
  );
}

// Memory category to color mapping
extension MemoryCategoryColors on String {
  Color get categoryColor {
    switch (toLowerCase()) {
      case 'episodic':
        return AppTheme.episodicColor;
      case 'semantic':
        return AppTheme.semanticColor;
      case 'procedural':
        return AppTheme.proceduralColor;
      case 'working':
        return AppTheme.workingColor;
      default:
        return AppTheme.textMuted;
    }
  }
}
