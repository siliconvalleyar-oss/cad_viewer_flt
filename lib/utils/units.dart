/// Conversión y formateo de unidades (docs/REQUIREMENTS.md §3.11, ADR-0007).
///
/// Internamente el dibujo se almacena siempre en **mm**; este módulo convierte
/// a la unidad de visualización y formatea valores para la UI.
library;

import '../models/cad_enums.dart';

/// Factor de la unidad de visualización a mm (1 mm = factor).
double unitToMmFactor(UnitsType unit) => unit.toMmFactor;

/// Convierte un valor interno (mm) a la unidad de visualización.
double mmToUnit(double mm, UnitsType unit) => mm / unit.toMmFactor;

/// Convierte un valor en la unidad de visualización a mm internos.
double unitToMm(double value, UnitsType unit) => value * unit.toMmFactor;

/// Formatea un valor en la unidad de visualización con el sufijo.
String formatLength(double mm, UnitsType unit, {int decimals = 2}) {
  final value = mmToUnit(mm, unit);
  final digits = _decimalsFor(unit, decimals);
  final numStr = value.toStringAsFixed(digits);
  return '$numStr ${unit.symbol}';
}

/// Formatea un valor sin unidad (áreas, factores).
String formatNumber(double value, {int decimals = 2}) =>
    value.toStringAsFixed(decimals);

/// Sufijo de la unidad.
extension UnitsTypeLabel on UnitsType {
  String get symbol => switch (this) {
        UnitsType.unitless => '',
        UnitsType.mm => 'mm',
        UnitsType.cm => 'cm',
        UnitsType.m => 'm',
        UnitsType.inch => 'in',
      };

  String get label => switch (this) {
        UnitsType.unitless => 'Sin unidades',
        UnitsType.mm => 'Milímetros (mm)',
        UnitsType.cm => 'Centímetros (cm)',
        UnitsType.m => 'Metros (m)',
        UnitsType.inch => 'Pulgadas (in)',
      };
}

int _decimalsFor(UnitsType unit, int fallback) => switch (unit) {
      UnitsType.m => 3,
      _ => fallback,
    };

/// Redondea a una precisión razonable evitando -0.0.
double cleanDouble(double v) {
  if (v.abs() < 1e-9) {
    return 0;
  }
  final rounded = (v * 1e9).round() / 1e9;
  return rounded == 0 ? 0 : rounded;
}
