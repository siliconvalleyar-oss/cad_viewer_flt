/// Transformación de entidades de bloque al espacio mundial (INSERT).
///
/// Aplica traslación + escala + rotación de la inserción a cada entidad
/// interna del bloque. Maneja correctamente los **espejos** (escala negativa
/// en X o Y, `scaleX·scaleY < 0`): en un espejo la orientación se invierte,
/// por lo que los ángulos se reflejan y el orden de inicio/fin de los arcos
/// se invierte (y el signo del bulge de LWPOLYLINE se niega). Sin este
/// manejo, las puertas/griferías insertadas con `esc=(-1,1)` dibujaban sus
/// arcos y curvas por el lado equivocado, "sobresaliendo" del vector.
library;

import 'dart:math' as math;

import '../models/cad_entity.dart';

/// `true` si la inserción es un espejo (escala negativa en un solo eje).
bool _isMirrored(CadInsert parent) => parent.scaleX * parent.scaleY < 0;

/// Escala promedio (aproximación para círculos/arcos/elipses con escala
/// no uniforme).
double _avgScale(CadInsert parent) =>
    (parent.scaleX.abs() + parent.scaleY.abs()) / 2;

/// Mapea un ángulo local (radianes) al espacio transformado por la
/// inserción (escala + rotación + posible espejo).
///
/// Con escala uniforme positiva + rotación `rot` devuelve `θ + rot`; con
/// espejo el resultado se refleja (p. ej. `θ → rot - θ` para espejo X).
double _mapAngle(double theta, CadInsert parent) {
  final c = math.cos(parent.rotation);
  final s = math.sin(parent.rotation);
  final dx = math.cos(theta);
  final dy = math.sin(theta);
  final wx = c * parent.scaleX * dx - s * parent.scaleY * dy;
  final wy = s * parent.scaleX * dx + c * parent.scaleY * dy;
  // Normaliza a (−π, π] para salida determinista (atan2(-0.0, -1.0) = -π
  // mientras atan2(0.0, -1.0) = π; ambos son el mismo ángulo módulo 2π).
  var angle = math.atan2(wy, wx);
  if (angle <= -math.pi) {
    angle += 2 * math.pi;
  }
  return angle;
}

/// Devuelve una copia de [e] con sus coordenadas transformadas por la
/// inserción (tx/ty ya incluyen traslación+escala+rotación del bloque).
///
/// [tx]/[ty] transforman un punto local del bloque al mundo.
CadEntity transformBlockEntity(
  CadEntity e,
  double Function(double, double) tx,
  double Function(double, double) ty,
  CadInsert parent,
) {
  final mirrored = _isMirrored(parent);
  switch (e) {
    case final CadLine l:
      return l.copyWith(
        x1: tx(l.x1, l.y1), y1: ty(l.x1, l.y1),
        x2: tx(l.x2, l.y2), y2: ty(l.x2, l.y2),
      );
    case final CadCircle c:
      return c.copyWith(
        cx: tx(c.cx, c.cy), cy: ty(c.cx, c.cy),
        radius: c.radius * _avgScale(parent),
      );
    case final CadArc a:
      final cxn = tx(a.cx, a.cy);
      final cyn = ty(a.cx, a.cy);
      var start = _mapAngle(a.startAngle, parent);
      var end = _mapAngle(a.endAngle, parent);
      if (mirrored) {
        // El espejo invierte el sentido del barrido: se intercambian los
        // extremos para que el arco quede del lado correcto.
        final t = start;
        start = end;
        end = t;
      }
      return a.copyWith(
        cx: cxn, cy: cyn,
        radius: a.radius * _avgScale(parent),
        startAngle: start,
        endAngle: end,
      );
    case final CadEllipse el:
      return el.copyWith(
        cx: tx(el.cx, el.cy), cy: ty(el.cx, el.cy),
        majorRadius: el.majorRadius * _avgScale(parent),
        minorRadius: el.minorRadius * _avgScale(parent),
        rotation: _mapAngle(el.rotation, parent),
      );
    case final CadLwPolyline p:
      return p.copyWith(
        points: [
          for (final v in p.points)
            v.copyWith(
              x: tx(v.x, v.y),
              y: ty(v.x, v.y),
              // El espejo invierte el lado de la curva del bulge.
              bulge: mirrored ? -v.bulge : v.bulge,
            ),
        ],
      );
    case final CadPolyline p:
      return p.copyWith(
        points: [
          for (final pt in p.points)
            pt.copyWith(x: tx(pt.x, pt.y), y: ty(pt.x, pt.y)),
        ],
      );
    case final CadText t:
      return t.copyWith(
        x: tx(t.x, t.y), y: ty(t.x, t.y),
        height: t.height * parent.scaleY.abs(),
        rotation: _mapAngle(t.rotation, parent),
      );
    case final CadMText m:
      return m.copyWith(
        x: tx(m.x, m.y), y: ty(m.x, m.y),
        height: m.height * parent.scaleY.abs(),
        rotation: _mapAngle(m.rotation, parent),
      );
    case final CadInsert nested:
      // El insert anidado se expresa en coordenadas del bloque padre.
      return nested.copyWith(
        x: tx(nested.x, nested.y),
        y: ty(nested.x, nested.y),
        scaleX: nested.scaleX * parent.scaleX,
        scaleY: nested.scaleY * parent.scaleY,
        rotation: _mapAngle(nested.rotation, parent),
      );
    case final CadPoint pt:
      return pt.copyWith(x: tx(pt.x, pt.y), y: ty(pt.x, pt.y));
    case final CadHatch h:
      return h.copyWith(
        boundaries: [
          for (final b in h.boundaries)
            b.copyWith(
              points: [
                for (final p in b.points)
                  p.copyWith(x: tx(p.x, p.y), y: ty(p.x, p.y)),
              ],
            ),
        ],
      );
    case final CadSpline s:
      return s.copyWith(
        controlPoints: [
          for (final p in s.controlPoints)
            p.copyWith(x: tx(p.x, p.y), y: ty(p.x, p.y)),
        ],
      );
    case final CadDim d:
      return d.copyWith(
        x1: tx(d.x1, d.y1), y1: ty(d.x1, d.y1),
        x2: tx(d.x2, d.y2), y2: ty(d.x2, d.y2),
        x3: tx(d.x3, d.y3), y3: ty(d.x3, d.y3),
        x4: tx(d.x4, d.y4), y4: ty(d.x4, d.y4),
        textHeight: d.textHeight * parent.scaleY.abs(),
        arrowSize: d.arrowSize * parent.scaleY.abs(),
      );
    case final Cad3dFace f:
      return f.copyWith(
        corners: [
          for (final p in f.corners)
            p.copyWith(x: tx(p.x, p.y), y: ty(p.x, p.y)),
        ],
      );
    case final CadSolid s:
      return s.copyWith(
        corners: [
          for (final p in s.corners)
            p.copyWith(x: tx(p.x, p.y), y: ty(p.x, p.y)),
        ],
      );
  }
}
