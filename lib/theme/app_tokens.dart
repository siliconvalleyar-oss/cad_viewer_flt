// Design tokens — fuente única de verdad (docs/DESIGN_SYSTEM.md §2).
//
// Convención de nombres: `categoría.variante` (spacing.md, radius.lg,
// elevation.z2, opacity.ghost, color.surface, type.body, bp.sm, motion.fast).
// En código: constantes Dart agrupadas por categoría. Prohibido valores
// literales en la UI (P3): siempre referenciar estos tokens.

import 'package:flutter/material.dart';

/// Escala de espaciado sobre grid de 4 dp (DESIGN_SYSTEM §2.1).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios de componentes (DESIGN_SYSTEM §2.2).
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;
}

/// Elevación por niveles (DESIGN_SYSTEM §2.3).
abstract final class AppElevation {
  static const List<BoxShadow> z0 = <BoxShadow>[];

  static const List<BoxShadow> z1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 1,
    ),
  ];

  static const List<BoxShadow> z2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> z3 = <BoxShadow>[
    BoxShadow(
      color: Color(0x29000000),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  static const List<BoxShadow> z4 = <BoxShadow>[
    BoxShadow(
      color: Color(0x2E000000),
      offset: Offset(0, 6),
      blurRadius: 12,
    ),
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 3),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> z5 = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      offset: Offset(0, 10),
      blurRadius: 20,
    ),
    BoxShadow(
      color: Color(0x24000000),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];
}

/// Opacidades semánticas (DESIGN_SYSTEM §2.4).
abstract final class AppOpacity {
  static const double scrim = 0.5;
  static const double overlay = 0.15;
  static const double ghost = 0.30;
  static const double disabled = 0.38;
  static const double muted = 0.60;
  static const double highlight = 0.85;
}

/// Roles de color semánticos por tema (DESIGN_SYSTEM §2.5).
class AppColorScheme {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.onBackground,
    required this.onSurfaceMuted,
    required this.primary,
    required this.onPrimary,
    required this.outline,
    required this.error,
    required this.success,
    required this.grid,
    required this.snap,
    required this.axisX,
    required this.axisY,
    required this.selection,
    required this.gripActive,
  });

  /// Fondo de app.
  final Color background;

  /// Canvas, paneles.
  final Color surface;

  /// Sheets, controles flotantes.
  final Color surfaceElevated;

  /// Texto principal.
  final Color onBackground;

  /// Texto secundario.
  final Color onSurfaceMuted;

  /// Acentos, botones primarios.
  final Color primary;

  /// Texto sobre primary.
  final Color onPrimary;

  /// Bordes, separadores.
  final Color outline;

  /// Errores.
  final Color error;

  /// Confirmaciones.
  final Color success;

  /// Rejilla del canvas.
  final Color grid;

  /// Indicador de snap (amarillo).
  final Color snap;

  /// Eje X.
  final Color axisX;

  /// Eje Y.
  final Color axisY;

  /// Halo de selección, grips inactivos.
  final Color selection;

  /// Grip activo.
  final Color gripActive;
}

/// Paletas base: claro y oscuro (DESIGN_SYSTEM §2.5). Los 6 temas de
/// AESTHETICS.md se derivarán de estos roles en Fase 7.
abstract final class AppColors {
  static const AppColorScheme light = AppColorScheme(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1A202C),
    onSurfaceMuted: Color(0xFF4A5568),
    primary: Color(0xFF3182CE),
    onPrimary: Color(0xFFFFFFFF),
    outline: Color(0xFFCBD5E0),
    error: Color(0xFFE53E3E),
    success: Color(0xFF38A169),
    grid: Color(0xFFD0D5DD),
    snap: Color(0xFFD69E2E),
    axisX: Color(0xFFE53E3E),
    axisY: Color(0xFF2B6CB0),
    selection: Color(0xFF3182CE),
    gripActive: Color(0xFFE53E3E),
  );

  static const AppColorScheme dark = AppColorScheme(
    background: Color(0xFF1A1D23),
    surface: Color(0xFF1E2128),
    surfaceElevated: Color(0xFF232731),
    onBackground: Color(0xFFEDF2F7),
    onSurfaceMuted: Color(0xFFA0AEC0),
    primary: Color(0xFF63B3ED),
    onPrimary: Color(0xFF0B1B2B),
    outline: Color(0xFF3A3F4A),
    error: Color(0xFFFC8181),
    success: Color(0xFF68D391),
    grid: Color(0xFF3A3F4A),
    snap: Color(0xFFF6E05E),
    axisX: Color(0xFFFC8181),
    axisY: Color(0xFF63B3ED),
    selection: Color(0xFF63B3ED),
    gripActive: Color(0xFFFC8181),
  );
}

/// Escala tipográfica (DESIGN_SYSTEM §2.6). Inter + JetBrains Mono; los
/// assets de fuentes se incorporan en Fase 7 (AESTHETICS.md).
abstract final class AppType {
  static const TextStyle display = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.06,
  );

  static const TextStyle property = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.055,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}

/// Breakpoints (DESIGN_SYSTEM §2.7). Usar con LayoutBuilder.
abstract final class AppBreakpoints {
  static const double xs = 360;
  static const double sm = 600;
  static const double md = 840;
  static const double lg = 1200;

  /// `bp.xs`: < 360 dp.
  static bool isXs(double width) => width < xs;

  /// `bp.sm`: 360–600 dp.
  static bool isSm(double width) => width >= xs && width < sm;

  /// `bp.md`: 600–840 dp.
  static bool isMd(double width) => width >= sm && width < md;

  /// `bp.lg`: 840–1200 dp.
  static bool isLg(double width) => width >= md && width < lg;

  /// `bp.xl`: > 1200 dp.
  static bool isXl(double width) => width >= lg;
}

/// Motion: curvas y duraciones (DESIGN_SYSTEM §4).
abstract final class AppMotion {
  /// Transiciones de UI generales.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Entradas destacadas, sheets.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.4);

  /// Salidas y desapariciones.
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Zoom, feedback de control.
  static const Curve fastOutSlowIn = Cubic(0.4, 0.0, 0.2, 1.0);

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration hero = Duration(milliseconds: 500);

  /// Duración de SnackBar estándar (4 s; 6 s con acción de undo).
  static const Duration snackbar = Duration(seconds: 4);
  static const Duration snackbarUndoable = Duration(seconds: 6);
}
