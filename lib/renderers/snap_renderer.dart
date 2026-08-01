/// Indicador visual del snap activo (docs/EDITING.md §7, RF-SNAP-10).
///
/// Forma según el modo (EDITING §7): endpoint = cuadrado, midpoint =
/// triángulo, center = círculo, quadrant = rombo, intersection = X,
/// nearest = punto, grid = cruz, polar = cruz con barra.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models/cad_enums.dart';
import '../utils/coordinate_transform.dart';

/// Pinta el marcador de snap en el canvas (mundo).
class SnapRenderer {
  const SnapRenderer();

  /// Tamaño de medio marcador en píxeles.
  static const double halfSize = 6;

  void paint(
    ui.Canvas canvas,
    CoordinateTransform t,
    double wx,
    double wy,
    SnapMode mode,
    ui.Color color,
  ) {
    final cx = t.worldToScreenX(wx);
    final cy = t.worldToScreenY(wy);
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6;

    switch (mode) {
      case SnapMode.endpoint:
        final r = ui.Rect.fromCenter(
          center: ui.Offset(cx, cy),
          width: halfSize * 2,
          height: halfSize * 2,
        );
        canvas.drawRect(r, paint);
      case SnapMode.midpoint:
        final path = ui.Path()
          ..moveTo(cx, cy - halfSize)
          ..lineTo(cx + halfSize, cy + halfSize)
          ..lineTo(cx - halfSize, cy + halfSize)
          ..close();
        canvas.drawPath(path, paint);
      case SnapMode.center:
        canvas.drawCircle(ui.Offset(cx, cy), halfSize, paint);
      case SnapMode.quadrant:
        final path = ui.Path()
          ..moveTo(cx, cy - halfSize)
          ..lineTo(cx + halfSize, cy)
          ..lineTo(cx, cy + halfSize)
          ..lineTo(cx - halfSize, cy)
          ..close();
        canvas.drawPath(path, paint);
      case SnapMode.intersection:
        canvas.drawLine(
          ui.Offset(cx - halfSize, cy - halfSize),
          ui.Offset(cx + halfSize, cy + halfSize),
          paint,
        );
        canvas.drawLine(
          ui.Offset(cx - halfSize, cy + halfSize),
          ui.Offset(cx + halfSize, cy - halfSize),
          paint,
        );
      case SnapMode.nearest:
        canvas.drawCircle(ui.Offset(cx, cy), 2, paint);
      case SnapMode.grid:
        canvas.drawLine(ui.Offset(cx - halfSize, cy), ui.Offset(cx + halfSize, cy), paint);
        canvas.drawLine(ui.Offset(cx, cy - halfSize), ui.Offset(cx, cy + halfSize), paint);
      case SnapMode.polar:
        final ang = math.atan2(wy - 0, wx - 0) * 0; // sin uso
        canvas.drawLine(
          ui.Offset(cx - halfSize * math.cos(ang) - 0, cy - halfSize),
          ui.Offset(cx + halfSize, cy + halfSize * 0),
          paint,
        );
        canvas.drawLine(ui.Offset(cx - halfSize, cy), ui.Offset(cx + halfSize, cy), paint);
        canvas.drawLine(ui.Offset(cx, cy - halfSize), ui.Offset(cx, cy + halfSize), paint);
    }
  }
}
