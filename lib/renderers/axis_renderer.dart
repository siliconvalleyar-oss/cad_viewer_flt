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

    // BUG-14 (reporte QA, doc §B): ejes acotados alrededor del origen
    // (como el icono UCS de AutoCAD) en lugar de cruzar todo el viewport,
    // para no "atravesar" el dibujo cuando el origen está en una esquina.
    final len = math.min(viewportW, viewportH) * 0.25;

    // Eje X: del origen hacia la derecha y la izquierda (acotado).
    canvas.drawLine(ui.Offset(ox - len, oy), ui.Offset(ox + len, oy), paintX);
    _arrow(canvas, ui.Offset(ox + len - 12, oy), math.pi, axisX);

    // Eje Y: del origen hacia arriba y abajo (acotado).
    canvas.drawLine(ui.Offset(ox, oy - len), ui.Offset(ox, oy + len), paintY);
    _arrow(canvas, ui.Offset(ox, oy - len + 12), -math.pi / 2, axisY);
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
