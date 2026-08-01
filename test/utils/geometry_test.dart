import 'package:cad_viewer/utils/geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pointOnBulge', () {
    test('t=0 y t=1 son los extremos del segmento', () {
      final p0 = pointOnBulge(0, 0, 10, 0, 0.5, 0);
      final p1 = pointOnBulge(0, 0, 10, 0, 0.5, 1);
      expect(p0.x, closeTo(0, 1e-6));
      expect(p0.y, closeTo(0, 1e-6));
      expect(p1.x, closeTo(10, 1e-6));
      expect(p1.y, closeTo(0, 1e-6));
    });

    test('punto medio con bulge 0.5: flecha = cuerda*|b|/2', () {
      // Chord (0,0)→(10,0), b=0.5 → flecha (sagitta) = 10*0.5/2 = 2.5.
      final m = pointOnBulge(0, 0, 10, 0, 0.5, 0.5);
      expect(m.x, closeTo(5, 1e-6));
      expect(m.y, closeTo(-2.5, 1e-6));
    });

    test('semicírculo (b=1): punto medio a 5 del centro de la cuerda', () {
      // Chord (0,0)→(10,0), b=1 → semicírculo con radio 5.
      final m = pointOnBulge(0, 0, 10, 0, 1.0, 0.5);
      expect(m.x, closeTo(5, 1e-6));
      expect(m.y, closeTo(-5, 1e-6));
    });

    test('sin bulge (b=0): interpolación lineal', () {
      final p = pointOnBulge(0, 0, 10, 0, 0, 0.25);
      expect(p.x, closeTo(2.5, 1e-6));
      expect(p.y, closeTo(0, 1e-6));
    });

    test('bulge negativo: arco hacia el otro lado', () {
      final m = pointOnBulge(0, 0, 10, 0, -0.5, 0.5);
      expect(m.x, closeTo(5, 1e-6));
      expect(m.y, closeTo(2.5, 1e-6));
    });

    test('no genera coordenadas gigantes (bug del *0 / epsilon)', () {
      // Antes: d=0 → perp*arrow ~ 1e9 → líneas fuera del dibujo.
      for (var b = 0.1; b <= 2.0; b += 0.2) {
        for (var t = 0.0; t <= 1.0; t += 0.25) {
          final p = pointOnBulge(0, 0, 100, 50, b, t);
          expect(p.x.abs() < 1e4, isTrue, reason: 'b=$b t=$t → ${p.x}');
          expect(p.y.abs() < 1e4, isTrue, reason: 'b=$b t=$t → ${p.y}');
        }
      }
    });
  });

  group('bulgeCenter', () {
    test('centro de semicírculo está en el punto medio', () {
      final c = bulgeCenter(0, 0, 10, 0, 1.0)!;
      expect(c.x, closeTo(5, 1e-6));
      expect(c.y, closeTo(0, 1e-6));
    });

    test('distancia centro→extremos = radio', () {
      final c = bulgeCenter(0, 0, 10, 0, 0.5)!;
      final r1 = distance(c.x, c.y, 0, 0);
      final r2 = distance(c.x, c.y, 10, 0);
      expect(r1, closeTo(r2, 1e-6));
    });
  });

  group('clampDimTextHeight', () {
    test('mínimo legible en pantalla (12 px al alejar)', () {
      // scale 0.1 px/unidad → 12 px = 120 unidades de mundo.
      expect(clampDimTextHeight(2, 1000, 0.1), closeTo(120, 1e-6));
    });

    test('máximo proporcional: 10% de la medida', () {
      // scale alto → el piso de 12 px (0.12 unidades) no domina.
      expect(clampDimTextHeight(20000, 100, 100), closeTo(10, 1e-6));
      expect(clampDimTextHeight(50, 100, 100), closeTo(10, 1e-6));
    });

    test('valores normales pasan sin cambio', () {
      expect(clampDimTextHeight(4, 100, 100), closeTo(4, 1e-6));
    });
  });

  group('clampDimArrowSize', () {
    test('máximo 30% de la medida', () {
      expect(clampDimArrowSize(500, 100, 1.0, 4), closeTo(30, 1e-6));
    });

    test('mínimo legible (4 px) y proporcional al texto', () {
      final a = clampDimArrowSize(0.1, 1000, 0.1, 4);
      // 4 px = 40 unidades; no menor que 25% del texto (1).
      expect(a, closeTo(40, 1e-6));
    });

    test('valores normales pasan sin cambio', () {
      // scale alto → piso de 4 px (0.04 unidades) no domina.
      expect(clampDimArrowSize(2.5, 100, 100, 4), closeTo(2.5, 1e-6));
    });
  });
}
