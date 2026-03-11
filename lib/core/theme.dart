import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryDark = Color(0xFF0A0E21);
  static const Color primaryMid = Color(0xFF1A1F3A);
  static const Color surfaceDark = Color(0xFF141829);
  static const Color surfaceMid = Color(0xFF1E2240);
  static const Color surfaceLight = Color(0xFF252A4A);

  // Accent Colors
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentPurple = Color(0xFF7B2FFF);
  static const Color accentPink = Color(0xFFFF2DAF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentOrange = Color(0xFFFF9100);
  static const Color accentRed = Color(0xFFFF5252);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentCyan, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E2240), Color(0xFF252A4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [accentRed, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Colors
  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0xFF8E92B0);
  static const Color textMuted = Color(0xFF5A5E7A);

  // Shadows
  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ];

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: primaryDark,
        colorScheme: const ColorScheme.dark(
          primary: accentCyan,
          secondary: accentPurple,
          surface: surfaceDark,
          error: accentRed,
          onPrimary: primaryDark,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surfaceMid,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceMid,
          hintStyle: const TextStyle(color: textMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: surfaceLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentCyan, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentRed, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentCyan,
            foregroundColor: primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentCyan,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentCyan,
          foregroundColor: primaryDark,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceMid,
          contentTextStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceDark,
          selectedItemColor: accentCyan,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: surfaceLight,
          thickness: 1,
        ),
      );
}

// Category definitions with icons and colors
class VaultCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> defaultFields;

  const VaultCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.defaultFields,
  });

  static const List<VaultCategory> categories = [
    VaultCategory(
      id: 'password',
      label: 'Passwords',
      icon: Icons.lock_outline,
      color: AppTheme.accentCyan,
      defaultFields: ['username', 'password', 'url', 'notes'],
    ),
    VaultCategory(
      id: 'card',
      label: 'Cards',
      icon: Icons.credit_card,
      color: AppTheme.accentPurple,
      defaultFields: [
        'cardHolder',
        'cardNumber',
        'expiryDate',
        'cvv',
        'pin',
        'notes'
      ],
    ),
    VaultCategory(
      id: 'note',
      label: 'Secure Notes',
      icon: Icons.note_alt_outlined,
      color: AppTheme.accentGreen,
      defaultFields: ['content'],
    ),
    VaultCategory(
      id: 'identity',
      label: 'Identity',
      icon: Icons.person_outline,
      color: AppTheme.accentOrange,
      defaultFields: [
        'firstName',
        'lastName',
        'email',
        'phone',
        'address',
        'dateOfBirth',
        'notes'
      ],
    ),
  ];

  static VaultCategory getById(String id) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories[0],
    );
  }
}

