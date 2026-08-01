/// Enumeraciones de dominio del modelo (docs/DATA_MODEL.md §10 y §5).
///
/// Archivo Dart puro (sin dependencias de Flutter): testeable en cualquier
/// runtime. Solo importa `dart:core`.
library;

/// Tipos polimórficos de las entidades CAD (DATA_MODEL §5.2).
enum CadEntityType {
  line,
  circle,
  arc,
  ellipse,
  lwPolyline,
  polyline,
  text,
  mtext,
  insert,
  point,
  hatch,
  spline,
  dim,
  face3d,
}

/// Tipo de dimensión según los bits bajos de `70` en DXF (FORMATS §4).
enum DimType {
  rotated,
  aligned,
  angular,
  diameter,
  radius,
  angular3Point,
  ordinate;

  /// Código DXF (`dimtype` de `70` & 0x07).
  int get dxfCode => index;

  /// Mapea un código DXF a [DimType]; desconocidos → [DimType.rotated].
  static DimType fromDxfCode(int code) {
    final index = code & 0x07;
    return index < DimType.values.length
        ? DimType.values[index]
        : DimType.rotated;
  }
}

/// Unidades del dibujo (ADR-0007: internamente siempre mm).
///
/// `toMmFactor` convierte un valor de la unidad a mm; `insUnitsCode` es el
/// valor crudo de `$INSUNITS` en DXF (FORMATS §2).
enum UnitsType {
  unitless(1.0, 0),
  mm(1.0, 4),
  cm(10.0, 5),
  m(1000.0, 6),
  inch(25.4, 1);

  const UnitsType(this.toMmFactor, this.insUnitsCode);

  /// Factor de conversión de esta unidad a mm.
  final double toMmFactor;

  /// Valor de `$INSUNITS` asociado.
  final int insUnitsCode;

  /// Mapea un valor de `$INSUNITS`; desconocido → [UnitsType.mm].
  static UnitsType fromInsUnits(int code) => UnitsType.values.firstWhere(
        (u) => u.insUnitsCode == code,
        orElse: () => UnitsType.mm,
      );

  /// Etiqueta en español para la UI.
  String get label => switch (this) {
        UnitsType.unitless => 'Sin unidades',
        UnitsType.mm => 'Milímetros',
        UnitsType.cm => 'Centímetros',
        UnitsType.m => 'Metros',
        UnitsType.inch => 'Pulgadas',
      };
}

/// Modos de snapping (EDITING §7; SnapEngine).
enum SnapMode {
  endpoint,
  midpoint,
  center,
  quadrant,
  intersection,
  nearest,
  grid,
  polar,
}

/// Tipos de rejilla del canvas (AESTHETICS / DESIGN_SYSTEM §2.5).
enum GridType {
  none,
  lines,
  dots,
}

/// Formato de archivo detectado (FORMATS §8, FileHelper).
enum FileFormat {
  dxf,
  dwg,
  dgn,
  unknown,
}

/// Tema de la app (AESTHETICS.md §2, RF-TEMA-01/02).
enum AppThemeMode {
  light,
  dark,
  blueprint,
  poster,
  infographic,
  autocad,
}
