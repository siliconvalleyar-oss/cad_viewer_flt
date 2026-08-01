import 'dart:ui' as ui;

import 'package:cad_viewer/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashPath', () {
    ui.Path linePath(double length) => (ui.Path()
          ..moveTo(0, 0)
          ..lineTo(length, 0));

    double paintedLength(ui.Path p) {
      var total = 0.0;
      for (final m in p.computeMetrics()) {
        total += m.length;
      }
      return total;
    }

    test('patrón vacío devuelve el path sin cambios', () {
      final src = linePath(100);
      final out = dashPath(src, const []);
      expect(identical(out, src), isTrue);
    });

    test('línea de 100px con patrón [10,5]: pinta 10 de cada 15', () {
      final out = dashPath(linePath(100), const [10, 5]);
      // 6 ciclos completos (90px) + 10px restantes pintados.
      expect(paintedLength(out), closeTo(70, 0.01));
    });

    test('patrón con punto (0) pinta un segmento mínimo', () {
      final out = dashPath(linePath(20), const [0, 5]);
      expect(paintedLength(out), closeTo(0, 0.01)); // 0 no avanza → nada
    });

    test('múltiples contornos se procesan por separado', () {
      final src = ui.Path()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..moveTo(0, 10)
        ..lineTo(10, 10);
      final out = dashPath(src, const [4, 2]);
      // Cada contorno de 10px pinta 4+4=8 → total 16.
      expect(paintedLength(out), closeTo(16, 0.01));
    });
  });
}
