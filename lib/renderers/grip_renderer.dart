/// Renderizado de grips (docs/EDITING.md §8, RF-EDI-11).
///
/// Los grips son puntos de control editables de la entidad seleccionada:
/// cuadrados (inactivos) y relleno rojo (activo). Tamaño constante en
/// píxeles (no escala con el zoom).
library;

import 'dart:ui' as ui;

import '../models/cad_entity.dart';

/// Pinta los grips de edición en coordenadas de mundo.
class GripRenderer {
  const GripRenderer();

  /// Tamaño de medio grip en píxeles.
  static const double halfSize = 5;

  void paint(
    ui.Canvas canvas,
    List<CadPoint3> grips,
    int? activeIndex,
    double scale,
    ui.Color gripColor,
    ui.Color activeColor,
  ) {
    if (grips.isEmpty) {
      return;
    }
    final inactivePaint = ui.Paint()
      ..color = gripColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final activePaint = ui.Paint()..color = activeColor;

    for (var i = 0; i < grips.length; i++) {
      final g = grips[i];
      final sx = g.x * scale;
      final sy = g.y * scale;
      final rect = ui.Rect.fromCenter(
        center: ui.Offset(sx, sy),
        width: halfSize * 2,
        height: halfSize * 2,
      );
      if (i == activeIndex) {
        canvas.drawRect(rect, activePaint);
      } else {
        canvas.drawRect(rect, inactivePaint);
      }
    }
  }
}
