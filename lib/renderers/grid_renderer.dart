/// Renderizado de la rejilla cartesiana (docs/AESTHETICS.md, RF-RENDER-07).
///
/// El paso de la rejilla se adapta a la escala: se elige un paso de la serie
/// decimal (1/2/5 × 10^n) que ocupe al menos ~24 px en pantalla, evitando el
/// caso de borde "grid con espaciado < 4 px" (REQUIREMENTS §6, caso 15).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models/cad_enums.dart';
import '../utils/coordinate_transform.dart';

/// Pinta la rejilla en el canvas dado el transform de vista.
class GridRenderer {
  const GridRenderer();

  /// Paso ideal (mm) para que la rejilla sea legible a la escala actual.
  static double adaptiveStep(double scale, double minPx) {
    final raw = minPx / scale;
    if (raw <= 0 || !raw.isFinite) {
      return 1;
    }
    // Serie 1-2-5 × 10^n.
    final pow10 = math.pow(10, (math.log(raw) / math.ln10).floor());
    final candidates = <double>[pow10.toDouble(), 2 * pow10.toDouble(), 5 * pow10.toDouble(), 10 * pow10.toDouble()];
    for (final c in candidates) {
      if (c >= raw) {
        return c;
      }
    }
    return candidates.last;
  }

  /// Pinta la rejilla visible en el viewport.
  void paint(
    ui.Canvas canvas,
    CoordinateTransform t,
    double viewportW,
    double viewportH,
    ui.Color color,
    GridType type,
  ) {
    if (type == GridType.none) {
      return;
    }
    final step = adaptiveStep(t.scale, 24);
    if (step <= 0) {
      return;
    }
    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = ui.PaintingStyle.stroke;

    final wx0 = t.screenToWorldX(0);
    final wx1 = t.screenToWorldX(viewportW);
    final minWx = wx0 < wx1 ? wx0 : wx1;
    final maxWx = wx0 < wx1 ? wx1 : wx0;
    // Con la Y invertida, screenToWorldY(0) es el mundo ARRIBA y
    // screenToWorldY(viewportH) el mundo ABAJO; con la rotación 180° el
    // orden de X también se invierte: ordenamos ambos rangos.
    final wyTop = t.screenToWorldY(0);
    final wyBottom = t.screenToWorldY(viewportH);
    final minWy = wyTop < wyBottom ? wyTop : wyBottom;
    final maxWy = wyTop < wyBottom ? wyBottom : wyTop;

    final x0 = (minWx / step).floor() * step;
    final y0 = (minWy / step).floor() * step;

    if (type == GridType.lines) {
      for (var x = x0; x <= maxWx; x += step) {
        final sx = t.worldToScreenX(x);
        if (sx < -1 || sx > viewportW + 1) {
          continue;
        }
        canvas.drawLine(ui.Offset(sx, 0), ui.Offset(sx, viewportH), paint);
      }
      for (var y = y0; y <= maxWy; y += step) {
        final sy = t.worldToScreenY(y);
        if (sy < -1 || sy > viewportH + 1) {
          continue;
        }
        canvas.drawLine(ui.Offset(0, sy), ui.Offset(viewportW, sy), paint);
      }
    } else {
      // Dots: puntos en las intersecciones.
      final dotPaint = ui.Paint()..color = color;
      for (var x = x0; x <= maxWx; x += step) {
        final sx = t.worldToScreenX(x);
        if (sx < 0 || sx > viewportW) {
          continue;
        }
        for (var y = y0; y <= maxWy; y += step) {
          final sy = t.worldToScreenY(y);
          if (sy < 0 || sy > viewportH) {
            continue;
          }
          canvas.drawCircle(ui.Offset(sx, sy), 1.2, dotPaint);
        }
      }
    }
  }
}
