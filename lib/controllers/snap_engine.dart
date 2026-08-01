/// Motor de snapping (docs/EDITING.md §7, RF-SNAP).
///
/// Resuelve el punto de snap más cercano dentro de una tolerancia en píxeles
/// (convertida a mundo según el zoom actual) sobre las entidades visibles.
/// Prioridades (EDITING §7): endpoint/intersection (1), midpoint/center (2),
/// quadrant (3), nearest (4), grid (5), polar (6).
library;

import 'dart:math' as math;

import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../utils/geometry.dart';

/// Configuración de snapping del usuario (persistida).
class SnapSettings {
  const SnapSettings({
    this.enabled = true,
    this.ortho = false,
    this.endpoint = true,
    this.midpoint = true,
    this.center = true,
    this.intersection = true,
    this.quadrant = true,
    this.nearest = true,
    this.grid = false,
    this.polar = true,
    this.tolerancePx = 12,
    this.gridStep = 10,
    this.polarStepDeg = 15,
  });

  /// Snap global.
  final bool enabled;

  /// Ortho (F8): restringe a ejes X/Y.
  final bool ortho;

  final bool endpoint;
  final bool midpoint;
  final bool center;
  final bool intersection;
  final bool quadrant;
  final bool nearest;
  final bool grid;

  /// Polar (ángulos múltiplos de [polarStepDeg]).
  final bool polar;

  /// Tolerancia en píxeles.
  final double tolerancePx;

  /// Paso de la rejilla (mm).
  final double gridStep;

  /// Paso polar en grados.
  final double polarStepDeg;

  SnapSettings copyWith({
    bool? enabled,
    bool? ortho,
    bool? endpoint,
    bool? midpoint,
    bool? center,
    bool? intersection,
    bool? quadrant,
    bool? nearest,
    bool? grid,
    bool? polar,
    double? tolerancePx,
    double? gridStep,
    double? polarStepDeg,
  }) =>
      SnapSettings(
        enabled: enabled ?? this.enabled,
        ortho: ortho ?? this.ortho,
        endpoint: endpoint ?? this.endpoint,
        midpoint: midpoint ?? this.midpoint,
        center: center ?? this.center,
        intersection: intersection ?? this.intersection,
        quadrant: quadrant ?? this.quadrant,
        nearest: nearest ?? this.nearest,
        grid: grid ?? this.grid,
        polar: polar ?? this.polar,
        tolerancePx: tolerancePx ?? this.tolerancePx,
        gridStep: gridStep ?? this.gridStep,
        polarStepDeg: polarStepDeg ?? this.polarStepDeg,
      );

  /// Serialización para persistencia (claves coinciden con `_loadSnapSettings`).
  Map<String, Object> toJson() => {
        'enabled': enabled,
        'ortho': ortho,
        'endpoint': endpoint,
        'midpoint': midpoint,
        'center': center,
        'intersection': intersection,
        'quadrant': quadrant,
        'nearest': nearest,
        'grid': grid,
        'polar': polar,
        'tolerancePx': tolerancePx,
        'gridStep': gridStep,
        'polarStepDeg': polarStepDeg,
      };
}

/// Resultado de un snap.
class SnapResult {
  const SnapResult({
    required this.point,
    required this.mode,
    this.entity,
  });

  /// Punto de mundo (mm).
  final CadPoint3 point;

  /// Modo que ganó.
  final SnapMode mode;

  /// Entidad origen (si aplica).
  final CadEntity? entity;

  /// Prioridad del modo (menor = más importante).
  int get priority => SnapEngine._priority(mode);
}

/// Motor de snapping.
class SnapEngine {
  SnapEngine(this.settings);

  /// Configuración activa.
  SnapSettings settings;

  /// Punto de ancla para coordenadas relativas/polares (punto base).
  CadPoint3? anchor;

  /// Resuelve el snap más cercano a [px, py] (mundo) sobre [entities].
  ///
  /// Devuelve el mejor resultado o `null` si no hay snap dentro de la
  /// tolerancia (en cuyo caso el cursor usa el punto crudo).
  SnapResult? snap({
    required double px,
    required double py,
    required List<CadEntity> entities,
    required double scalePxPerMm,
  }) {
    if (!settings.enabled) {
      return null;
    }
    final tolerance = settings.tolerancePx / scalePxPerMm;
    final candidates = <SnapResult>[];

    for (final e in entities) {
      _collectCandidates(e, px, py, candidates);
    }

    if (settings.intersection && candidates.isNotEmpty) {
      _collectIntersections(entities, px, py, candidates);
    }

    if (settings.grid) {
      final gx = (px / settings.gridStep).round() * settings.gridStep;
      final gy = (py / settings.gridStep).round() * settings.gridStep;
      final d = distance(px, py, gx, gy);
      if (d <= tolerance) {
        candidates.add(SnapResult(point: CadPoint3(gx, gy), mode: SnapMode.grid));
      }
    }

    // Mejor candidato (menor distancia; desempate por prioridad).
    SnapResult? best;
    var bestDist = double.infinity;
    for (final c in candidates) {
      final d = distance(px, py, c.point.x, c.point.y);
      if (d > tolerance) {
        continue;
      }
      if (d < bestDist - 1e-9 ||
          (d.abs() - bestDist).abs() < 1e-9 &&
              (best == null || c.priority < best.priority)) {
        best = c;
        bestDist = d;
      }
    }

    var point = best?.point ?? CadPoint3(px, py);
    var mode = best?.mode;

    // Polar: fuerza el ángulo a múltiplos del paso si está activo.
    if (settings.polar && anchor != null) {
      final rawAngle = angleOf(point.x - anchor!.x, point.y - anchor!.y);
      final stepRad = settings.polarStepDeg * math.pi / 180;
      final snapped = (rawAngle / stepRad).round() * stepRad;
      if (settings.polar) {
        final dist = distance(anchor!.x, anchor!.y, point.x, point.y);
        final p = CadPoint3(
          anchor!.x + dist * math.cos(snapped),
          anchor!.y + dist * math.sin(snapped),
        );
        if (best == null || distance(px, py, p.x, p.y) <= tolerance + 1e-6) {
          point = p;
          mode = mode ?? SnapMode.polar;
        }
      }
    }

    // Ortho: restringe el desplazamiento respecto al ancla a X o Y puro.
    if (settings.ortho && anchor != null) {
      final dx = point.x - anchor!.x;
      final dy = point.y - anchor!.y;
      if (dx.abs() >= dy.abs()) {
        point = CadPoint3(anchor!.x + dx, anchor!.y);
      } else {
        point = CadPoint3(anchor!.x, anchor!.y + dy);
      }
      mode = mode ?? SnapMode.polar;
    }

    if (best == null && mode == null) {
      return null;
    }
    return SnapResult(point: point, mode: mode ?? best!.mode, entity: best?.entity);
  }

  void _collectCandidates(
    CadEntity e,
    double px,
    double py,
    List<SnapResult> candidates,
  ) {
    switch (e) {
      case final CadLine l:
        if (settings.endpoint) {
          candidates
            ..add(SnapResult(point: CadPoint3(l.x1, l.y1), mode: SnapMode.endpoint, entity: e))
            ..add(SnapResult(point: CadPoint3(l.x2, l.y2), mode: SnapMode.endpoint, entity: e));
        }
        if (settings.midpoint) {
          candidates.add(
            SnapResult(
              point: CadPoint3((l.x1 + l.x2) / 2, (l.y1 + l.y2) / 2),
              mode: SnapMode.midpoint,
              entity: e,
            ),
          );
        }
        if (settings.nearest) {
          candidates.add(
            SnapResult(
              point: projectOnSegment(px, py, l.x1, l.y1, l.x2, l.y2),
              mode: SnapMode.nearest,
              entity: e,
            ),
          );
        }
      case final CadCircle c:
        if (settings.center) {
          candidates.add(SnapResult(point: CadPoint3(c.cx, c.cy), mode: SnapMode.center, entity: e));
        }
        if (settings.quadrant) {
          for (var i = 0; i < 4; i++) {
            final ang = i * math.pi / 2;
            candidates.add(
              SnapResult(
                point: pointOnCircle(c.cx, c.cy, c.radius, ang),
                mode: SnapMode.quadrant,
                entity: e,
              ),
            );
          }
        }
        if (settings.nearest) {
          final ang = angleOf(px - c.cx, py - c.cy);
          candidates.add(
            SnapResult(
              point: pointOnCircle(c.cx, c.cy, c.radius, ang),
              mode: SnapMode.nearest,
              entity: e,
            ),
          );
        }
      case final CadArc a:
        if (settings.center) {
          candidates.add(SnapResult(point: CadPoint3(a.cx, a.cy), mode: SnapMode.center, entity: e));
        }
        if (settings.endpoint) {
          candidates
            ..add(
              SnapResult(
                point: pointOnCircle(a.cx, a.cy, a.radius, a.startAngle),
                mode: SnapMode.endpoint,
                entity: e,
              ),
            )
            ..add(
              SnapResult(
                point: pointOnCircle(a.cx, a.cy, a.radius, a.endAngle),
                mode: SnapMode.endpoint,
                entity: e,
              ),
            );
        }
        if (settings.nearest) {
          final ang = angleOf(px - a.cx, py - a.cy);
          candidates.add(
            SnapResult(
              point: pointOnCircle(a.cx, a.cy, a.radius, ang),
              mode: SnapMode.nearest,
              entity: e,
            ),
          );
        }
      case final CadEllipse el:
        if (settings.center) {
          candidates.add(SnapResult(point: CadPoint3(el.cx, el.cy), mode: SnapMode.center, entity: e));
        }
        if (settings.quadrant) {
          for (var i = 0; i < 4; i++) {
            final pt = pointOnEllipse(
              el.cx, el.cy, el.majorRadius, el.minorRadius, el.rotation,
              i * math.pi / 2,
            );
            candidates.add(SnapResult(point: pt, mode: SnapMode.quadrant, entity: e));
          }
        }
      case final CadLwPolyline p:
        _polylinePoints(p.points.map((v) => CadPoint3(v.x, v.y)).toList(), e, px, py, candidates);
      case final CadPolyline p:
        _polylinePoints(p.points, e, px, py, candidates);
      case final CadText t:
        candidates.add(SnapResult(point: CadPoint3(t.x, t.y), mode: SnapMode.endpoint, entity: e));
      case final CadMText m:
        candidates.add(SnapResult(point: CadPoint3(m.x, m.y), mode: SnapMode.endpoint, entity: e));
      case final CadInsert i:
        candidates.add(SnapResult(point: CadPoint3(i.x, i.y), mode: SnapMode.endpoint, entity: e));
      case final CadPoint pt:
        candidates.add(SnapResult(point: CadPoint3(pt.x, pt.y), mode: SnapMode.endpoint, entity: e));
      case final CadSpline s:
        for (final cp in s.controlPoints) {
          candidates.add(SnapResult(point: cp, mode: SnapMode.endpoint, entity: e));
        }
      case final CadDim d:
        candidates
          ..add(SnapResult(point: CadPoint3(d.x1, d.y1), mode: SnapMode.endpoint, entity: e))
          ..add(SnapResult(point: CadPoint3(d.x2, d.y2), mode: SnapMode.endpoint, entity: e))
          ..add(SnapResult(point: CadPoint3(d.x3, d.y3), mode: SnapMode.endpoint, entity: e))
          ..add(SnapResult(point: CadPoint3(d.x4, d.y4), mode: SnapMode.endpoint, entity: e));
      case final Cad3dFace f:
        for (final c in f.corners) {
          candidates.add(SnapResult(point: c, mode: SnapMode.endpoint, entity: e));
        }
      case CadHatch():
        break;
    }
  }

  void _polylinePoints(
    List<CadPoint3> pts,
    CadEntity e,
    double px,
    double py,
    List<SnapResult> candidates,
  ) {
    if (pts.isEmpty) {
      return;
    }
    if (settings.endpoint) {
      candidates
        ..add(SnapResult(point: pts.first, mode: SnapMode.endpoint, entity: e))
        ..add(SnapResult(point: pts.last, mode: SnapMode.endpoint, entity: e));
    }
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (settings.midpoint) {
        candidates.add(
          SnapResult(
            point: CadPoint3((a.x + b.x) / 2, (a.y + b.y) / 2),
            mode: SnapMode.midpoint,
            entity: e,
          ),
        );
      }
      if (settings.nearest) {
        candidates.add(
          SnapResult(
            point: projectOnSegment(px, py, a.x, a.y, b.x, b.y),
            mode: SnapMode.nearest,
            entity: e,
          ),
        );
      }
    }
  }

  /// Intersecciones entre segmentos de entidades cercanas al cursor.
  void _collectIntersections(
    List<CadEntity> entities,
    double px,
    double py,
    List<SnapResult> candidates,
  ) {
    // Solo líneas y polilíneas (presupuesto de rendimiento: pares cercanos).
    final segments = <({double x1, double y1, double x2, double y2, CadEntity e})>[];
    for (final e in entities) {
      switch (e) {
        case final CadLine l:
          segments.add((x1: l.x1, y1: l.y1, x2: l.x2, y2: l.y2, e: e));
        case final CadLwPolyline p:
          for (var i = 0; i < p.points.length - 1; i++) {
            segments.add((
              x1: p.points[i].x, y1: p.points[i].y,
              x2: p.points[i + 1].x, y2: p.points[i + 1].y, e: e,
            ));
          }
        case final CadPolyline p:
          for (var i = 0; i < p.points.length - 1; i++) {
            segments.add((
              x1: p.points[i].x, y1: p.points[i].y,
              x2: p.points[i + 1].x, y2: p.points[i + 1].y, e: e,
            ));
          }
        default:
          break;
      }
    }
    for (var i = 0; i < segments.length; i++) {
      for (var j = i + 1; j < segments.length; j++) {
        final a = segments[i];
        final b = segments[j];
        final p = segmentIntersection(a.x1, a.y1, a.x2, a.y2, b.x1, b.y1, b.x2, b.y2);
        if (p != null) {
          candidates.add(SnapResult(point: p, mode: SnapMode.intersection, entity: a.e));
        }
      }
    }
  }

  static int _priority(SnapMode mode) => switch (mode) {
        SnapMode.endpoint || SnapMode.intersection => 1,
        SnapMode.midpoint || SnapMode.center => 2,
        SnapMode.quadrant => 3,
        SnapMode.nearest => 4,
        SnapMode.grid => 5,
        SnapMode.polar => 6,
      };
}
