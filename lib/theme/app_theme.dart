import 'package:flutter/material.dart';

/// Builds the app's Material 3 themes from a seed color.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed) => _base(seed, Brightness.light);
  static ThemeData dark(Color seed) => _base(seed, Brightness.dark);

  static ThemeData _base(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
        dataTextStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      ),
    );
  }

  /// Accent color choices shown in Settings.
  static const List<Color> accentOptions = [
    Color(0xFF6750A4), // Violet
    Color(0xFF0B57D0), // Blue
    Color(0xFF006A60), // Teal
    Color(0xFF2E7D32), // Green
    Color(0xFFB3261E), // Red
    Color(0xFFE8710A), // Orange
    Color(0xFFC2185B), // Pink
  ];
}
