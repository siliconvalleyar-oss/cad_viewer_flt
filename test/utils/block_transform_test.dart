/// Tests del transform de bloques con espejos (docs/CHANGELOG v0.4.8).
///
/// Cuando un INSERT tiene escala negativa en un solo eje (espejo), los arcos
/// y bulges deben reflejarse; sin este manejo las puertas insertadas con
/// `esc=(-1,1)` dibujaban sus curvas por el lado equivocado.
library;

import 'dart:math' as math;

import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/utils/block_transform.dart';
import 'package:flutter_test/flutter_test.dart';

CadInsert _insert({
  double scaleX = 1,
  double scaleY = 1,
  double rotation = 0,
}) =>
    CadInsert(
      handle: 'h',
      layer: '0',
      blockName: 'B',
      x: 0,
      y: 0,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
    );

/// Normaliza a (−π, π] (valor principal de atan2).
double _wrap(double a) {
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}

/// Compara dos ángulos como equivalentes módulo 2π (tolera −π ≡ π).
void _expectAngle(double actual, double expected) {
  var a = actual % (2 * math.pi);
  var e = expected % (2 * math.pi);
  if (a < 0) {
    a += 2 * math.pi;
  }
  if (e < 0) {
    e += 2 * math.pi;
  }
  expect(a, closeTo(e, 1e-9));
}

void main() {
  group('transformBlockEntity sin espejo (comportamiento previo)', () {
    test('ARC: suma rotación a los ángulos', () {
      final arc = CadArc(
        handle: 'a', layer: '0', cx: 0, cy: 0, radius: 10,
        startAngle: 0, endAngle: math.pi / 2,
      );
      final out = transformBlockEntity(
        arc, (x, y) => x, (x, y) => y, _insert(rotation: math.pi / 2),
      ) as CadArc;
      expect(out.startAngle, closeTo(math.pi / 2, 1e-9));
      expect(out.endAngle, closeTo(math.pi, 1e-9));
    });

    test('LWPOLYLINE: bulge se conserva', () {
      final p = CadLwPolyline(
        handle: 'p', layer: '0',
        points: const [LwVertex(0, 0, bulge: 0.5), LwVertex(1, 0)],
      );
      final out = transformBlockEntity(
        p, (x, y) => x, (x, y) => y, _insert(),
      ) as CadLwPolyline;
      expect(out.points.first.bulge, 0.5);
    });
  });

  group('transformBlockEntity con espejo X (scaleX=-1)', () {
    test('ARC: ángulos reflejados (0°→180°, 90°→90°) y extremos intercambiados', () {
      final arc = CadArc(
        handle: 'a', layer: '0', cx: 0, cy: 0, radius: 10,
        startAngle: 0, endAngle: math.pi / 2,
      );
      final out = transformBlockEntity(
        arc, (x, y) => -x, (x, y) => y, _insert(scaleX: -1),
      ) as CadArc;
      // Reflejado: start 0°→π, end 90°→π/2; intercambiados por el espejo.
      expect(out.startAngle, closeTo(math.pi / 2, 1e-9));
      expect(out.endAngle, closeTo(math.pi, 1e-9));
      expect(out.radius, closeTo(10, 1e-9));
    });

    test('ARC con rotación 252.6° (puertas diagonales): refleja y reordena', () {
      final arc = CadArc(
        handle: 'a', layer: '0', cx: 0, cy: 0, radius: 0.92,
        startAngle: 0, endAngle: 87.5 * math.pi / 180,
      );
      final rot = 252.6 * math.pi / 180;
      final out = transformBlockEntity(
        arc, (x, y) => -x, (x, y) => y, _insert(scaleX: -1, rotation: rot),
      ) as CadArc;
      // Con espejo X y rotación r: θ → π + r − θ (valor principal).
      final expectedStart = _wrap(math.pi + rot - 87.5 * math.pi / 180);
      final expectedEnd = _wrap(math.pi + rot);
      expect(out.startAngle, closeTo(expectedStart, 1e-6));
      expect(out.endAngle, closeTo(expectedEnd, 1e-6));
      // El sweep (diferencia angular) es el del arco original.
      expect(
        _wrap(out.endAngle - out.startAngle).abs(),
        closeTo(87.5 * math.pi / 180, 1e-6),
      );
    });

    test('LWPOLYLINE: bulge se niega con espejo', () {
      final p = CadLwPolyline(
        handle: 'p', layer: '0',
        points: const [LwVertex(0, 0, bulge: 0.5), LwVertex(1, 0)],
      );
      final out = transformBlockEntity(
        p, (x, y) => -x, (x, y) => y, _insert(scaleX: -1),
      ) as CadLwPolyline;
      expect(out.points.first.bulge, -0.5);
    });

    test('TEXT: rotación reflejada (θ → π − θ con rot=0)', () {
      final t = CadText(
        handle: 't', layer: '0', text: 'X', x: 0, y: 0,
        height: 1, rotation: 0.3,
      );
      final out = transformBlockEntity(
        t, (x, y) => -x, (x, y) => y, _insert(scaleX: -1),
      ) as CadText;
      expect(out.rotation, closeTo(math.pi - 0.3, 1e-9));
    });

    test('ELLIPSE: rotación reflejada', () {
      final el = CadEllipse(
        handle: 'e', layer: '0', cx: 0, cy: 0,
        majorRadius: 2, minorRadius: 1, rotation: 0.5,
      );
      final out = transformBlockEntity(
        el, (x, y) => -x, (x, y) => y, _insert(scaleX: -1),
      ) as CadEllipse;
      expect(out.rotation, closeTo(math.pi - 0.5, 1e-9));
    });
  });

  group('transformBlockEntity con espejo Y (scaleY=-1)', () {
    test('ARC: ángulos negados e intercambiados', () {
      final arc = CadArc(
        handle: 'a', layer: '0', cx: 0, cy: 0, radius: 10,
        startAngle: 0, endAngle: math.pi / 2,
      );
      final out = transformBlockEntity(
        arc, (x, y) => x, (x, y) => -y, _insert(scaleY: -1),
      ) as CadArc;
      // Con espejo Y: θ → −θ; 0°→0, 90°→−90°; intercambiados.
      expect(out.startAngle, closeTo(-math.pi / 2, 1e-9));
      expect(out.endAngle, closeTo(0, 1e-9));
    });

    test('LWPOLYLINE: bulge negado', () {
      final p = CadLwPolyline(
        handle: 'p', layer: '0',
        points: const [LwVertex(0, 0, bulge: 0.25), LwVertex(1, 0)],
      );
      final out = transformBlockEntity(
        p, (x, y) => x, (x, y) => -y, _insert(scaleY: -1),
      ) as CadLwPolyline;
      expect(out.points.first.bulge, -0.25);
    });
  });

  group('INSERT anidado con espejo (propagación del padre)', () {
    test('rotación reflejada y escalas multiplicadas', () {
      final nested = CadInsert(
        handle: 'n', layer: '0', blockName: 'Hijo',
        x: 1, y: 2, scaleX: 1, scaleY: 1, rotation: 0.4,
      );
      // Espejo con |scaleX|=|scaleY| (espejo puro + escala uniforme): la
      // fórmula cerrada θ → π + r − θ es exacta. Con escala anisotrópica
      // (p. ej. scaleY=2) el ángulo se distorsiona y no tiene forma cerrada.
      final out = transformBlockEntity(
        nested, (x, y) => -x, (x, y) => y, _insert(scaleX: -2, scaleY: 2, rotation: 0.25),
      ) as CadInsert;
      // Escala: se multiplica con la del padre.
      expect(out.scaleX, closeTo(-2, 1e-9));
      expect(out.scaleY, closeTo(2, 1e-9));
      // Rotación: θ → π + r − θ (espejo X con rotación r).
      expect(out.rotation, closeTo(math.pi + 0.25 - 0.4, 1e-9));
      // Posición transformada por el espejo X (tx/ty que recibe el painter).
      expect(out.x, closeTo(-1, 1e-9));
      expect(out.y, closeTo(2, 1e-9));
    });

    test('espejo Y: rotación → r − θ', () {
      final nested = CadInsert(
        handle: 'n', layer: '0', blockName: 'Hijo',
        x: 0, y: 0, scaleX: 1, scaleY: 1, rotation: 0.3,
      );
      final out = transformBlockEntity(
        nested, (x, y) => x, (x, y) => -y, _insert(scaleY: -1, rotation: 0.1),
      ) as CadInsert;
      expect(out.rotation, closeTo(0.1 - 0.3, 1e-9));
    });
  });

  group('doble espejo (scaleX=-1, scaleY=-1) = rotación 180°', () {
    test('ARC: 0°→180°, 90°→−90° (sin intercambio: no es espejo)', () {
      final arc = CadArc(
        handle: 'a', layer: '0', cx: 0, cy: 0, radius: 10,
        startAngle: 0, endAngle: math.pi / 2,
      );
      final out = transformBlockEntity(
        arc, (x, y) => -x, (x, y) => -y, _insert(scaleX: -1, scaleY: -1),
      ) as CadArc;
      // atan2 puede devolver −π ≡ π para 0°; se comparan módulo 2π.
      _expectAngle(out.startAngle, math.pi);
      _expectAngle(out.endAngle, -math.pi / 2);
      // El sweep es el del arco original (π/2).
      _expectAngle(out.endAngle - out.startAngle, math.pi / 2);
    });

    test('LWPOLYLINE: bulge se conserva (doble espejo no invierte)', () {
      final p = CadLwPolyline(
        handle: 'p', layer: '0',
        points: const [LwVertex(0, 0, bulge: 0.5), LwVertex(1, 0)],
      );
      final out = transformBlockEntity(
        p, (x, y) => -x, (x, y) => -y, _insert(scaleX: -1, scaleY: -1),
      ) as CadLwPolyline;
      expect(out.points.first.bulge, 0.5);
    });
  });
}
