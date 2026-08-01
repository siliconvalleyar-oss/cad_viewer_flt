/// Renderizado de ejes X/Y (docs/AESTHETICS.md, RF-RENDER-08).
///
/// Eje X rojo, eje Y azul, con flechas y etiquetas. Si el origen está fuera
/// de la vista, los ejes se ocultan (RF-RENDER-08).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../utils/coordinate_transform.dart';

/// Pinta los ejes cartesianos.
class AxisRenderer {
  const AxisRenderer();

  /// `true` si el origen (0,0) está dentro del viewport.
  bool originVisible(CoordinateTransform t, double vw, double vh) {
    final ox = t.worldToScreenX(0);
    final oy = t.worldToScreenY(0);
    return ox >= 0 && ox <= vw && oy >= 0 && oy <= vh;
  }

  void paint(
    ui.Canvas canvas,
    CoordinateTransform t,
    double viewportW,
    double viewportH,
    ui.Color axisX,
    ui.Color axisY,
  ) {
    final ox = t.worldToScreenX(0);
    final oy = t.worldToScreenY(0);
    if (ox < 0 || ox > viewportW || oy < 0 || oy > viewportH) {
      return; // Origen fuera de vista: ocultar ejes.
    }

    final paintX = ui.Paint()
      ..color = axisX
      ..strokeWidth = 1.4
      ..style = ui.PaintingStyle.stroke;
    final paintY = ui.Paint()
      ..color = axisY
      ..strokeWidth = 1.4
      ..style = ui.PaintingStyle.stroke;

    // Eje X.
    canvas.drawLine(ui.Offset(0, oy), ui.Offset(viewportW, oy), paintX);
    _arrow(canvas, ui.Offset(viewportW - 12, oy), math.pi, axisX);

    // Eje Y.
    canvas.drawLine(ui.Offset(ox, 0), ui.Offset(ox, viewportH), paintY);
    _arrow(canvas, ui.Offset(ox, 12), -math.pi / 2, axisY);
  }

  void _arrow(ui.Canvas canvas, ui.Offset tip, double angle, ui.Color color) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    final path = ui.Path();
    final size = 6.0;
    path.moveTo(tip.dx + size * math.cos(angle), tip.dy + size * math.sin(angle));
    path.lineTo(
      tip.dx + size * math.cos(angle + 2.6),
      tip.dy + size * math.sin(angle + 2.6),
    );
    path.lineTo(
      tip.dx + size * math.cos(angle - 2.6),
      tip.dy + size * math.sin(angle - 2.6),
    );
    path.close();
    canvas.drawPath(path, paint);
  }
}
