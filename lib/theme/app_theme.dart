/// Temas de la app (docs/AESTHETICS.md, RF-TEMA).
///
/// 6 temas: Claro, Oscuro, Blueprint Premium, Poster Publicitario, Infografía
/// Educativa y AutoCAD Dark. Cada uno define un [AppThemePalette] con los
/// roles semánticos del diseño; `toThemeData()` construye el `ThemeData`.
library;

import 'package:flutter/material.dart';

import '../models/cad_enums.dart';

/// Paleta completa de un tema (roles del diseño, AESTHETICS.md).
class AppThemePalette {
  const AppThemePalette({
    required this.name,
    required this.id,
    required this.appBackground,
    required this.canvasBackground,
    required this.grid,
    required this.axisX,
    required this.axisY,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.surface,
    required this.surfaceElevated,
    required this.outline,
    required this.error,
    required this.success,
    required this.selection,
    required this.snap,
    required this.grip,
    required this.gripActive,
    required this.measure,
    required this.isDark,
  });

  /// Nombre legible.
  final String name;

  /// Identificador.
  final String id;

  final Color appBackground;
  final Color canvasBackground;
  final Color grid;
  final Color axisX;
  final Color axisY;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color surface;
  final Color surfaceElevated;
  final Color outline;
  final Color error;
  final Color success;
  final Color selection;
  final Color snap;
  final Color grip;
  final Color gripActive;
  final Color measure;
  final bool isDark;

  /// `true` si el tema fuerza líneas claras (Blueprint/Poster/Infografía).
  bool get forcesLightLines => id == 'blueprint' || id == 'poster' || id == 'infographic';

  /// Tema `ThemeData` de Flutter derivado de la paleta.
  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      outline: outline,
      surfaceContainerHighest: surfaceElevated,
      onSurfaceVariant: textSecondary,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: appBackground,
      fontFamily: 'Inter',
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: appBackground.withValues(alpha: 0.85),
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}

/// Catálogo de los 6 temas (AESTHETICS.md §2).
abstract final class AppThemes {
  static const List<AppThemePalette> all = <AppThemePalette>[
    light,
    dark,
    blueprint,
    poster,
    infographic,
    autocad,
  ];

  static const AppThemePalette light = AppThemePalette(
    name: 'Claro',
    id: 'light',
    appBackground: Color(0xFFF5F7FA),
    canvasBackground: Color(0xFFFFFFFF),
    grid: Color(0xFFD0D5DD),
    axisX: Color(0xFFE53E3E),
    axisY: Color(0xFF2B6CB0),
    textPrimary: Color(0xFF1A202C),
    textSecondary: Color(0xFF4A5568),
    accent: Color(0xFF3182CE),
    onAccent: Colors.white,
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    outline: Color(0xFFCBD5E0),
    error: Color(0xFFE53E3E),
    success: Color(0xFF38A169),
    selection: Color(0xFF3182CE),
    snap: Color(0xFFD69E2E),
    grip: Color(0xFF3182CE),
    gripActive: Color(0xFFE53E3E),
    measure: Color(0xFF38A169),
    isDark: false,
  );

  static const AppThemePalette dark = AppThemePalette(
    name: 'Oscuro',
    id: 'dark',
    appBackground: Color(0xFF1A1D23),
    canvasBackground: Color(0xFF1E2128),
    grid: Color(0xFF3A3F4A),
    axisX: Color(0xFFFC8181),
    axisY: Color(0xFF63B3ED),
    textPrimary: Color(0xFFEDF2F7),
    textSecondary: Color(0xFFA0AEC0),
    accent: Color(0xFF63B3ED),
    onAccent: Color(0xFF0B1B2B),
    surface: Color(0xFF1E2128),
    surfaceElevated: Color(0xFF232731),
    outline: Color(0xFF3A3F4A),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    selection: Color(0xFF63B3ED),
    snap: Color(0xFFF6E05E),
    grip: Color(0xFF63B3ED),
    gripActive: Color(0xFFFC8181),
    measure: Color(0xFF68D391),
    isDark: true,
  );

  static const AppThemePalette blueprint = AppThemePalette(
    name: 'Blueprint Premium',
    id: 'blueprint',
    appBackground: Color(0xFF0A0E14),
    canvasBackground: Color(0xFF0F1923),
    grid: Color(0xFF1E2A38),
    axisX: Color(0xFFE53E3E),
    axisY: Color(0xFF63B3ED),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFFA0AEC0),
    accent: Color(0xFF63B3ED),
    onAccent: Color(0xFF0B1B2B),
    surface: Color(0xFF0F1923),
    surfaceElevated: Color(0xFF16222F),
    outline: Color(0xFF2A3A4D),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    selection: Color(0xFF63B3ED),
    snap: Color(0xFFF6E05E),
    grip: Color(0xFF63B3ED),
    gripActive: Color(0xFFF6E05E),
    measure: Color(0xFF68D391),
    isDark: true,
  );

  static const AppThemePalette poster = AppThemePalette(
    name: 'Poster Publicitario',
    id: 'poster',
    appBackground: Color(0xFF0F172A),
    canvasBackground: Color(0xFF0F172A),
    grid: Color(0xFF1E293B),
    axisX: Color(0xFFF6C90E),
    axisY: Color(0xFFF59E0B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    accent: Color(0xFFF6C90E),
    onAccent: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF263449),
    outline: Color(0xFF334155),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    selection: Color(0xFFF6C90E),
    snap: Color(0xFFF59E0B),
    grip: Color(0xFFF6C90E),
    gripActive: Color(0xFFF59E0B),
    measure: Color(0xFF68D391),
    isDark: true,
  );

  static const AppThemePalette infographic = AppThemePalette(
    name: 'Infografía Educativa',
    id: 'infographic',
    appBackground: Color(0xFF0F172A),
    canvasBackground: Color(0xFF0F172A),
    grid: Color(0xFF1E293B),
    axisX: Color(0xFFF6C90E),
    axisY: Color(0xFF94A3B8),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    accent: Color(0xFFF6C90E),
    onAccent: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF263449),
    outline: Color(0xFF334155),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    selection: Color(0xFFF6C90E),
    snap: Color(0xFFF59E0B),
    grip: Color(0xFFF6C90E),
    gripActive: Color(0xFFF59E0B),
    measure: Color(0xFF68D391),
    isDark: true,
  );

  static const AppThemePalette autocad = AppThemePalette(
    name: 'AutoCAD Dark',
    id: 'autocad',
    appBackground: Color(0xFF1E1E1E),
    canvasBackground: Color(0xFF1A1A1A),
    grid: Color(0xFF2D2D30),
    axisX: Color(0xFFE53E3E),
    axisY: Color(0xFF2B6CB0),
    textPrimary: Color(0xFFCCCCCC),
    textSecondary: Color(0xFF8A8A8A),
    accent: Color(0xFF00BCD4),
    onAccent: Color(0xFF001F24),
    surface: Color(0xFF252526),
    surfaceElevated: Color(0xFF2B2B2D),
    outline: Color(0xFF3E3E42),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    selection: Color(0xFF00BCD4),
    snap: Color(0xFFFFD700),
    grip: Color(0xFF00BCD4),
    gripActive: Color(0xFFFFD700),
    measure: Color(0xFF4CAF50),
    isDark: true,
  );

  /// Devuelve el tema por modo.
  static AppThemePalette byMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => light,
        AppThemeMode.dark => dark,
        AppThemeMode.blueprint => blueprint,
        AppThemeMode.poster => poster,
        AppThemeMode.infographic => infographic,
        AppThemeMode.autocad => autocad,
      };
}
