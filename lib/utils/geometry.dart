/// Geometría analítica 2D (docs/ARCHITECTURE.md §3.6, EDITING.md §7).
///
/// Dart puro. Funciones de distancia, intersecciones, ángulos, área y
/// geometría de arcos/elipses/bulges usadas por hit-testing, snapping,
/// medición y renderizado.
library;

import 'dart:math' as math;

import '../models/bounds.dart';
import '../models/cad_entity.dart';

/// Tolerancia epsilon para comparaciones de punto flotante.
const double epsilon = 1e-9;

/// Distancia euclidiana entre dos puntos.
double distance(double x1, double y1, double x2, double y2) =>
    math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

/// Distancia al cuadrado (evita sqrt en hot paths).
double distanceSq(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return dx * dx + dy * dy;
}

/// Distancia mínima de un punto a un segmento.
double distancePointToSegment(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;
  if (lenSq < epsilon) {
    return distance(px, py, x1, y1);
  }
  var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  final cx = x1 + t * dx;
  final cy = y1 + t * dy;
  return distance(px, py, cx, cy);
}

/// Proyección ortogonal de un punto sobre un segmento (para snap nearest).
CadPoint3 projectOnSegment(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;
  if (lenSq < epsilon) {
    return CadPoint3(x1, y1);
  }
  var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  return CadPoint3(x1 + t * dx, y1 + t * dy);
}

/// Intersección de dos segmentos [a1,a2] y [b1,b2].
///
/// Devuelve el punto o `null` si no se intersectan (o son paralelos).
CadPoint3? segmentIntersection(
  double a1x, double a1y, double a2x, double a2y,
  double b1x, double b1y, double b2x, double b2y,
) {
  final d1x = a2x - a1x;
  final d1y = a2y - a1y;
  final d2x = b2x - b1x;
  final d2y = b2y - b1y;
  final denom = d1x * d2y - d1y * d2x;
  if (denom.abs() < epsilon) {
    return null;
  }
  final t = ((b1x - a1x) * d2y - (b1y - a1y) * d2x) / denom;
  final u = ((b1x - a1x) * d1y - (b1y - a1y) * d1x) / denom;
  if (t < -epsilon || t > 1 + epsilon || u < -epsilon || u > 1 + epsilon) {
    return null;
  }
  return CadPoint3(a1x + t * d1x, a1y + t * d1y);
}

/// Ángulo en radianes del vector (x, y) respecto al eje X positivo.
double angleOf(double x, double y) => math.atan2(y, x);

/// Ángulo normalizado a [0, 2π).
double normalizeAngle(double angle) {
  var a = angle % (2 * math.pi);
  if (a < 0) {
    a += 2 * math.pi;
  }
  return a;
}

/// Diferencia angular mínima (firmada) entre dos ángulos.
double angleDelta(double from, double to) {
  var d = normalizeAngle(to) - normalizeAngle(from);
  if (d > math.pi) {
    d -= 2 * math.pi;
  }
  if (d < -math.pi) {
    d += 2 * math.pi;
  }
  return d;
}

/// Punto sobre un círculo.
CadPoint3 pointOnCircle(double cx, double cy, double radius, double angle) =>
    CadPoint3(cx + radius * math.cos(angle), cy + radius * math.sin(angle));

/// Punto sobre una elipse (rotación en radianes).
CadPoint3 pointOnEllipse(
  double cx,
  double cy,
  double majorRadius,
  double minorRadius,
  double rotation,
  double param,
) {
  final cosP = math.cos(param);
  final sinP = math.sin(param);
  final cosR = math.cos(rotation);
  final sinR = math.sin(rotation);
  final x = majorRadius * cosP * cosR - minorRadius * sinP * sinR;
  final y = majorRadius * cosP * sinR + minorRadius * sinP * cosR;
  return CadPoint3(cx + x, cy + y);
}  /// Punto en t∈[0,1] del segmento con bulge (tan(θ/4) del arco).
  ///
  /// `t=0` → inicio, `t=1` → fin. Calcula el centro del arco con
  /// [bulgeCenter] y barre el ángulo incluido θ = 4·atan(bulge).
  /// (Corregido: antes dividía por ~0 y generaba puntos a ~1e9, dibujando
  /// líneas gigantes fuera del dibujo.)
  CadPoint3 pointOnBulge(
    double x1,
    double y1,
    double x2,
    double y2,
    double bulge,
    double t,
  ) {
    if (bulge.abs() < epsilon) {
      return CadPoint3(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
    }
    final center = bulgeCenter(x1, y1, x2, y2, bulge);
    if (center == null) {
      return CadPoint3(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
    }
    final r = distance(center.x, center.y, x1, y1);
    if (r < epsilon) {
      return CadPoint3(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
    }
    final start = math.atan2(y1 - center.y, x1 - center.x);
    final sweep = 4 * math.atan(bulge); // firmado: CCW con bulge > 0
    final ang = start + sweep * t;
    return CadPoint3(
      center.x + r * math.cos(ang),
      center.y + r * math.sin(ang),
    );
  }

/// Centro del arco definido por un segmento con bulge (para grips/snap).
CadPoint3? bulgeCenter(double x1, double y1, double x2, double y2, double b) {
  if (b.abs() < epsilon) {
    return null;
  }
  final midX = (x1 + x2) / 2;
  final midY = (y1 + y2) / 2;
  final chord = distance(x1, y1, x2, y2);
  if (chord < epsilon) {
    return null;
  }
  // Distancia centro→punto medio del segmento.
  final h = chord * (1 - math.pow(b, 2)) / (4 * b);
  final perpX = -(y2 - y1) / chord;
  final perpY = (x2 - x1) / chord;
  return CadPoint3(midX + perpX * h, midY + perpY * h);
}

/// `true` si el punto está dentro del polígono (ray casting; semi-abierto).
///
/// El punto exactamente sobre el borde cuenta como dentro. Útil para
/// hit-testing de áreas rellenas (SOLID/TRACE, HATCH).
bool pointInPolygon(double px, double py, List<CadPoint3> pts) {
  if (pts.length < 3) {
    return false;
  }
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i];
    final b = pts[j];
    final crosses = (a.y > py) != (b.y > py) &&
        px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x;
    if (crosses) {
      inside = !inside;
    }
  }
  return inside;
}

/// Área de un polígono (fórmula del cordón / shoelace). Signo = orientación.
double polygonArea(List<CadPoint3> pts) {
  if (pts.length < 3) {
    return 0;
  }
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

/// Distancia punto → entidad (hit-testing). Tolera arcos y elipses
/// muestreando segmentos. Devuelve distancia mínima aproximada.
double distanceToEntity(CadEntity e, double px, double py) {
  switch (e) {
    case final CadLine l:
      return distancePointToSegment(px, py, l.x1, l.y1, l.x2, l.y2);
    case final CadCircle c:
      return (distance(px, py, c.cx, c.cy) - c.radius).abs();
    case final CadArc a:
      final d = distance(px, py, a.cx, a.cy);
      if (d > a.radius) {
        return d - a.radius;
      }
      // Dentro del círculo: distancia al arco muestreado.
      var best = double.infinity;
      for (var i = 0; i <= 32; i++) {
        final t = i / 32;
        final ang = a.startAngle + angleDelta(a.startAngle, a.endAngle) * t;
        final pt = pointOnCircle(a.cx, a.cy, a.radius, ang);
        best = math.min(best, distance(px, py, pt.x, pt.y));
      }
      return best;
    case final CadEllipse el:
      var best = double.infinity;
      for (var i = 0; i <= 32; i++) {
        final t = i / 32;
        final pt = pointOnEllipse(
          el.cx, el.cy, el.majorRadius, el.minorRadius, el.rotation,
          t * 2 * math.pi,
        );
        best = math.min(best, distance(px, py, pt.x, pt.y));
      }
      return best;
    case final CadLwPolyline p:
      // BUG-10 (reporte QA): solo envolver el último→primero cuando la
      // polilínea está CERRADA; en abierta el cierre fantasma hacía que
      // tocar cerca del inicio seleccionara la polilínea erróneamente.
      var best = double.infinity;
      for (var i = 0; i < p.points.length; i++) {
        final v = p.points[i];
        if (!p.closed && i == p.points.length - 1) {
          break;
        }
        final next = p.points[(i + 1) % p.points.length];
        best = math.min(
          best,
          distancePointToSegment(px, py, v.x, v.y, next.x, next.y),
        );
      }
      return best;
    case final CadPolyline p:
      var best = double.infinity;
      for (var i = 0; i < p.points.length - 1; i++) {
        best = math.min(
          best,
          distancePointToSegment(
            px, py, p.points[i].x, p.points[i].y,
            p.points[i + 1].x, p.points[i + 1].y,
          ),
        );
      }
      if (p.closed && p.points.isNotEmpty) {
        final last = p.points.last;
        final first = p.points.first;
        best = math.min(best, distancePointToSegment(px, py, last.x, last.y, first.x, first.y));
      }
      return best;
    case final CadText t:
      return distance(px, py, t.x, t.y);
    case final CadMText m:
      return distance(px, py, m.x, m.y);
    case final CadInsert i:
      return distance(px, py, i.x, i.y);
    case final CadPoint pt:
      return distance(px, py, pt.x, pt.y);
    case final CadSpline s:
      var best = double.infinity;
      for (var i = 0; i < s.controlPoints.length; i++) {
        best = math.min(best, distance(px, py, s.controlPoints[i].x, s.controlPoints[i].y));
      }
      return best;
    case final CadDim d:
      return math.min(
        math.min(
          math.min(distance(px, py, d.x1, d.y1), distance(px, py, d.x2, d.y2)),
          distance(px, py, d.x3, d.y3),
        ),
        distance(px, py, d.x4, d.y4),
      );
    case final Cad3dFace f:
      var best = double.infinity;
      for (var i = 0; i < f.corners.length - 1; i++) {
        best = math.min(
          best,
          distancePointToSegment(
            px, py, f.corners[i].x, f.corners[i].y,
            f.corners[i + 1].x, f.corners[i + 1].y,
          ),
        );
      }
      return best;
    case final CadSolid s:
      // Área rellena: un clic en el interior también selecciona (punto en
      // polígono); si está fuera, distancia mínima al contorno.
      if (pointInPolygon(px, py, s.corners)) {
        return 0;
      }
      var best = double.infinity;
      for (var i = 0; i < s.corners.length - 1; i++) {
        best = math.min(
          best,
          distancePointToSegment(
            px, py, s.corners[i].x, s.corners[i].y,
            s.corners[i + 1].x, s.corners[i + 1].y,
          ),
        );
      }
      if (s.corners.length > 2) {
        final first = s.corners.first;
        final last = s.corners.last;
        best = math.min(
          best,
          distancePointToSegment(px, py, last.x, last.y, first.x, first.y),
        );
      }
      return best;
    case final CadHatch h:
      var best = double.infinity;
      for (final b in h.boundaries) {
        for (var i = 0; i < b.points.length; i++) {
          final a = b.points[i];
          final c = b.points[(i + 1) % b.points.length];
          best = math.min(
            best,
            distancePointToSegment(px, py, a.x, a.y, c.x, c.y),
          );
        }
      }
      return best;
  }
}

/// `true` si el punto está dentro del rectángulo (window selection).
bool pointInRect(double px, double py, Bounds rect) =>
    rect.contains(px, py);

/// Altura de texto de cota proporcional a la medida, con clamps.
///
/// [rawH] viene del DIMSTYLE (dimtxt) o de una altura derivada; [scale] es
/// px por unidad de mundo. Devuelve una altura en unidades de mundo tal que
/// el texto nunca quede por debajo de [minPx] px en pantalla (legibilidad)
/// ni por encima del 10% de la longitud medida (evita cotas descomunales
/// cuando el archivo trae dimtxt en otras unidades y generaba líneas de
/// extensión fuera de rango).
double clampDimTextHeight(
  double rawH,
  double length,
  double scale, {
  double minPx = 12,
}) {
  final minH = minPx / scale;
  final maxH = math.max(length * 0.10, minH);
  return rawH.clamp(minH, maxH).toDouble();
}

/// Tamaño de flecha de cota proporcional, nunca desproporcionado.
///
/// Devuelve un tamaño en unidades de mundo con mínimo legible ([minPx] px)
/// y máximo 30% de la longitud medida (evita flechas gigantes de archivos
/// con dimasz en otras unidades).
double clampDimArrowSize(
  double raw,
  double length,
  double scale,
  double textH, {
  double minPx = 4,
}) {
  final minA = math.max(minPx / scale, textH * 0.25);
  final maxA = math.max(length * 0.30, minA);
  return raw.clamp(minA, maxA).toDouble();
}
