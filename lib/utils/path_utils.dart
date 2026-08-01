/// Utilidades de trazado de paths (docs/skills/CAD_RENDERERS.md).
///
/// Flutter no expone un patrón de guiones en `Paint`, así que se construye
/// un `Path` fragmentado a partir de las métricas del path original
/// (`PathMetrics`/`extractPath`). Los patrones de DXF (tabla LTYPE) usan
/// unidades de dibujo; el llamador los escala a píxeles antes de llamar aquí.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Path;

/// Devuelve un [Path] que repite [pattern] (en píxeles) a lo largo de cada
/// contorno de [source]. El patrón alterna trazo/espacio: índice par =
/// segmento dibujado, índice impar = hueco.
///
/// Nota: los elementos ≤ 0 se saltan (el llamador debe escalar/clampar el
/// patrón a píxeles mínimos visibles antes de llamar aquí; los "puntos" del
/// DXF, elemento 0, deben pasar como un trazo mínimo).
///
/// Si [pattern] está vacío, devuelve [source] sin cambios (línea continua).
Path dashPath(Path source, List<double> pattern) {
  if (pattern.isEmpty) {
    return source;
  }
  // Guarda defensiva: un patrón sin ningún elemento positivo nunca avanzaría
  // (riesgo de bucle infinito); se devuelve el path sólido.
  if (pattern.every((e) => e <= 0)) {
    return source;
  }
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    while (distance < metric.length) {
      final len = pattern[index % pattern.length];
      if (len <= 0) {
        // Elemento 0/negativo inesperado: se salta para no bloquear.
        index++;
        continue;
      }
      final end = math.min(distance + len, metric.length);
      if (index.isEven) {
        result.addPath(metric.extractPath(distance, end), Offset.zero);
      }
      distance = end;
      index++;
    }
  }
  return result;
}
