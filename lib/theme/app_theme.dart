import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand palette — deep navy + electric cyan accent
  static const Color _bgBase = Color(0xFF0D1117);
  static const Color _bgSurface = Color(0xFF161B22);
  static const Color _bgCard = Color(0xFF21262D);
  static const Color _accent = Color(0xFF00D4FF);
  static const Color _accentSecondary = Color(0xFF7C3AED);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _success = Color(0xFF39D353);
  static const Color _warning = Color(0xFFF0A500);
  static const Color _error = Color(0xFFFF6B6B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bgBase,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accentSecondary,
        surface: _bgSurface,
        onPrimary: _bgBase,
        onSurface: _textPrimary,
        error: _error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: _textPrimary),
          bodyMedium: TextStyle(color: _textSecondary),
          labelLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bgBase,
        foregroundColor: _textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _bgSurface,
        selectedItemColor: _accent,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: _bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: _bgBase,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _bgCard,
        labelStyle: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
        side: const BorderSide(color: Color(0xFF30363D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerColor: const Color(0xFF30363D),
      extensions: const [
        AppColors(
          bgBase: _bgBase,
          bgSurface: _bgSurface,
          bgCard: _bgCard,
          accent: _accent,
          accentSecondary: _accentSecondary,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          success: _success,
          warning: _warning,
          error: _error,
        ),
      ],
    );
  }
}

/// Custom color extension for easy access in widgets
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bgBase;
  final Color bgSurface;
  final Color bgCard;
  final Color accent;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;

  const AppColors({
    required this.bgBase,
    required this.bgSurface,
    required this.bgCard,
    required this.accent,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
  });

  @override
  AppColors copyWith({
    Color? bgBase, Color? bgSurface, Color? bgCard, Color? accent,
    Color? accentSecondary, Color? textPrimary, Color? textSecondary,
    Color? success, Color? warning, Color? error,
  }) {
    return AppColors(
      bgBase: bgBase ?? this.bgBase,
      bgSurface: bgSurface ?? this.bgSurface,
      bgCard: bgCard ?? this.bgCard,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
