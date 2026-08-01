/// Tipos de línea (patrones de guiones) estándar (docs/FORMATS.md §3).
///
/// Patrones en unidades de dibujo (positivo = trazo, negativo = espacio,
/// 0 = punto), según `acad.lin` de AutoCAD y las ISO equivalentes. Se usan
/// como fallback cuando el archivo no define la tabla LTYPE o referencia un
/// tipo conocido pero no definido (muy común en exportaciones).
library;

/// Patrones estándar de AutoCAD (incluye las variantes escaladas `2` =
/// media escala y `X2` = doble escala, que AutoCAD referencia por nombre).
const Map<String, List<double>> standardLineTypePatterns = {
  'DASHED': [0.5, -0.25],
  'DASHED2': [0.375, -0.1875],
  'DASHEDX2': [1.0, -0.5],
  'HIDDEN': [0.25, -0.125],
  'HIDDEN2': [0.1875, -0.09375],
  'HIDDENX2': [0.5, -0.25],
  'CENTER': [1.25, -0.25, 0.25, -0.25],
  'CENTER2': [0.75, -0.125, 0.125, -0.125],
  'CENTERX2': [2.5, -0.5, 0.5, -0.5],
  'DOT': [0.0, -0.25],
  'DOT2': [0.0, -0.125],
  'DOTX2': [0.0, -0.5],
  'DASHDOT': [0.5, -0.25, 0.0, -0.25],
  'DASHDOT2': [0.375, -0.1875, 0.0, -0.1875],
  'DASHDOTX2': [1.0, -0.5, 0.0, -0.5],
  'PHANTOM': [2.5, -0.25, 0.5, -0.25, 0.5, -0.25],
  'PHANTOM2': [1.25, -0.125, 0.25, -0.125, 0.25, -0.125],
  'PHANTOMX2': [5.0, -0.5, 1.0, -0.5, 1.0, -0.5],
  'BORDER': [0.5, -0.25, 0.5, -0.25, 0.0, -0.25],
  'BORDER2': [0.25, -0.125, 0.25, -0.125, 0.0, -0.125],
  'BORDERX2': [1.0, -0.5, 1.0, -0.5, 0.0, -0.5],
  'DIVIDE': [0.5, -0.25, 0.0, -0.25, 0.0, -0.25],
  'DIVIDE2': [0.25, -0.125, 0.0, -0.125, 0.0, -0.125],
  'DIVIDEX2': [1.0, -0.5, 0.0, -0.5, 0.0, -0.5],
  // ISO 128 (nombres ACAD_ISO*nW100).
  'ACAD_ISO02W100': [0.5, -0.25], // ISO dash
  'ACAD_ISO03W100': [1.0, -0.5], // ISO dash (espaciado amplio)
  'ACAD_ISO04W100': [0.5, -0.25, 0.5, -0.25, 0.0, -0.25], // ISO long-dash dot
  'ACAD_ISO05W100': [2.5, -0.25, 0.25, -0.25], // ISO long-dash short-dash
  'ACAD_ISO06W100': [2.5, -0.25, 0.5, -0.25, 0.25, -0.25], // ISO long-dash double-dot
  'ACAD_ISO07W100': [1.0, -0.25, 0.5, -0.25, 0.25, -0.25], // ISO dot dash
  'ACAD_ISO08W100': [1.0, -0.25, 0.0, -0.25], // ISO long-dash dot
  'ACAD_ISO09W100': [2.0, -0.5, 0.0, -0.5, 0.0, -0.5], // ISO long-dash double-dot
  'ACAD_ISO10W100': [1.0, -0.25, 0.0, -0.25, 0.0, -0.25], // ISO dash dot
  'ACAD_ISO11W100': [2.0, -0.25, 0.25, -0.25], // ISO double-dash
  'ACAD_ISO12W100': [1.0, -0.25, 0.25, -0.25], // ISO double-dash (corto)
  'ACAD_ISO13W100': [3.0, -0.25, 0.25, -0.25], // ISO triple-dash
  'ACAD_ISO14W100': [1.0, -0.25, 0.0, -0.25, 0.0, -0.25, 0.0, -0.25], // ISO dash dot
  'ACAD_ISO15W100': [2.5, -0.25, 0.5, -0.25, 0.25, -0.25], // ISO long-dash double-dot
};

/// Resuelve el patrón de guiones de un tipo de línea:
/// 1) tabla LTYPE del archivo (exacto), 2) tabla LTYPE (insensible a
/// mayúsculas), 3) patrón estándar de AutoCAD/ISO. `null` si se desconoce.
///
/// `Continuous` (o vacío) no aparece aquí: el llamador lo trata como sólido.
List<double>? resolveLineTypePattern(
  String name,
  Map<String, List<double>> filePatterns,
) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final exact = filePatterns[trimmed];
  if (exact != null) {
    return exact;
  }
  final upper = trimmed.toUpperCase();
  for (final entry in filePatterns.entries) {
    if (entry.key.toUpperCase() == upper) {
      return entry.value;
    }
  }
  return standardLineTypePatterns[upper];
}
