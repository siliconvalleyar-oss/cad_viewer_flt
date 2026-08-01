/// Painter principal del canvas (docs/ARCHITECTURE.md §3.3, ADR-0006).
///
/// Orden de pintado (docs/skills/CAD_RENDERERS.md): fondo → grid → ejes →
/// entidades visibles (con culling +20%) → overlays de medición → selección
/// (halo) → grips → snap. `shouldRepaint` compara los version counters para
/// repintado granular.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controllers/cad_view_model.dart';
import '../controllers/snap_engine.dart';
import '../models/bounds.dart';
import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../models/cad_layer.dart';
import '../utils/coordinate_transform.dart';
import '../utils/geometry.dart';
import '../utils/units.dart';
import 'axis_renderer.dart';
import 'grid_renderer.dart';
import 'grip_renderer.dart';
import 'layer_manager.dart';
import 'snap_renderer.dart';

/// Datos de una entidad con su color resuelto (para evitar re-resolver).
class _PaintEntity {
  const _PaintEntity(this.entity, this.color);

  final CadEntity entity;
  final Color color;
}

/// Painter del canvas CAD.
class CadPainter extends CustomPainter {
  CadPainter({
    required this.transform,
    required this.entities,
    required this.layers,
    required this.units,
    required this.backgroundColor,
    required this.gridColor,
    required this.axisXColor,
    required this.axisYColor,
    required this.selectionColor,
    required this.snapColor,
    required this.gripColor,
    required this.gripActiveColor,
    required this.measureColor,
    required this.entityColorResolver,
    required this.gridType,
    required this.showAxes,
    required this.showCrosshair,
    required this.crosshairWorld,
    required this.selectedHandles,
    required this.grips,
    required this.activeGripIndex,
    required this.activeSnap,
    required this.draftPoints,
    required this.previewPoint,
    required this.measurePoints,
    required this.measureMode,
    required this.previewDx,
    required this.previewDy,
    required this.previewAngle,
    required this.previewFactor,
    required this.transformBase,
    required this.isDrawing,
    required this.documentVersion,
    required this.selectionVersion,
    required this.transformVersion,
  });

  final CoordinateTransform transform;
  final List<CadEntity> entities;
  final List<CadLayer> layers;

  /// Unidad de visualización (para etiquetas de cota, RF-UNI-01).
  final UnitsType units;
  final Color backgroundColor;
  final Color gridColor;
  final Color axisXColor;
  final Color axisYColor;
  final Color selectionColor;
  final Color snapColor;
  final Color gripColor;
  final Color gripActiveColor;
  final Color measureColor;
  final Color Function(CadEntity) entityColorResolver;
  final GridType gridType;
  final bool showAxes;
  final bool showCrosshair;
  final CadPoint3? crosshairWorld;
  final Set<String> selectedHandles;
  final List<CadPoint3> grips;
  final int? activeGripIndex;
  final SnapResult? activeSnap;
  final List<CadPoint3> draftPoints;
  final CadPoint3? previewPoint;
  final List<CadPoint3> measurePoints;
  final MeasureMode measureMode;
  final double previewDx;
  final double previewDy;
  final double previewAngle;
  final double previewFactor;
  final CadPoint3? transformBase;
  final bool isDrawing;
  final int documentVersion;
  final int selectionVersion;
  final int transformVersion;

  // Renderers delegados (reutilización).
  final GridRenderer _grid = const GridRenderer();
  final AxisRenderer _axes = const AxisRenderer();
  final GripRenderer _grips = const GripRenderer();
  final SnapRenderer _snap = const SnapRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    final vw = size.width;
    final vh = size.height;

    // 1. Fondo.
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    // 2. Grid.
    if (gridType != GridType.none) {
      _grid.paint(canvas, transform, vw, vh, gridColor, gridType);
    }

    // 3. Ejes.
    if (showAxes) {
      _axes.paint(canvas, transform, vw, vh, axisXColor, axisYColor);
    }

    // 4. Entidades (con culling).
    final visibleRect = _visibleWorldRect(vw, vh);
    final painted = <_PaintEntity>[];
    for (final e in entities) {
      if (!_cull(e, visibleRect)) {
        continue;
      }
      final color = entityColorResolver(e);
      painted.add(_PaintEntity(e, color));
    }
    // Orden: sombreados primero, luego el resto.
    painted.sort((a, b) {
      bool isHatch(CadEntity e) => e is CadHatch;
      final ah = isHatch(a.entity) ? 0 : 1;
      final bh = isHatch(b.entity) ? 0 : 1;
      return ah.compareTo(bh);
    });
    for (final p in painted) {
      _paintEntity(canvas, p.entity, p.color);
    }

    // 5. Overlay de medición (temporal, sin crear entidades).
    _paintMeasure(canvas, vw, vh);

    // 6. Vista previa de creación (rubber band).
    if (isDrawing && draftPoints.isNotEmpty && previewPoint != null) {
      _paintDraftPreview(canvas);
    }

    // 7. Selección (halo).
    _paintSelectionHalo(canvas);

    // 8. Grips.
    if (grips.isNotEmpty) {
      _grips.paint(canvas, grips, activeGripIndex, transform.scale, gripColor, gripActiveColor);
    }

    // 9. Snap.
    final snap = activeSnap;
    if (snap != null) {
      _snap.paint(canvas, transform, snap.point.x, snap.point.y, snap.mode, snapColor);
    }

    // 10. Crosshair.
    if (showCrosshair && crosshairWorld != null && !isDrawing) {
      _paintCrosshair(canvas, crosshairWorld!, vw, vh);
    }
  }

  // -------------------------------------------------------------------------
  // Entidades.
  // -------------------------------------------------------------------------

  void _paintEntity(Canvas canvas, CadEntity e, Color color) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, e.lineWeight ?? 1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (e) {
      case final CadLine l:
        canvas.drawLine(
          Offset(transform.worldToScreenX(l.x1), transform.worldToScreenY(l.y1)),
          Offset(transform.worldToScreenX(l.x2), transform.worldToScreenY(l.y2)),
          stroke,
        );
      case final CadCircle c:
        final cx = transform.worldToScreenX(c.cx);
        final cy = transform.worldToScreenY(c.cy);
        final r = c.radius * transform.scale;
        canvas.drawCircle(Offset(cx, cy), r, stroke);
      case final CadArc a:
        final cx = transform.worldToScreenX(a.cx);
        final cy = transform.worldToScreenY(a.cy);
        final r = a.radius * transform.scale;
        final sweep = angleDelta(a.startAngle, a.endAngle);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          a.startAngle,
          sweep,
          false,
          stroke,
        );
      case final CadEllipse el:
        _paintEllipse(canvas, el, stroke);
      case final CadLwPolyline p:
        _paintLwPolyline(canvas, p, stroke);
      case final CadPolyline p:
        final path = Path();
        if (p.points.isNotEmpty) {
          path.moveTo(
            transform.worldToScreenX(p.points.first.x),
            transform.worldToScreenY(p.points.first.y),
          );
          for (final pt in p.points.skip(1)) {
            path.lineTo(transform.worldToScreenX(pt.x), transform.worldToScreenY(pt.y));
          }
          if (p.closed) {
            path.close();
          }
        }
        canvas.drawPath(path, stroke);
      case final CadText t:
        _paintText(canvas, t.text, t.x, t.y, t.height, t.rotation, color, t.horizontalAlign);
      case final CadMText m:
        _paintText(canvas, m.text, m.x, m.y, m.height, m.rotation, color, 0);
      case final CadInsert i:
        _paintInsertPlaceholder(canvas, i, stroke);
      case final CadPoint pt:
        final sx = transform.worldToScreenX(pt.x);
        final sy = transform.worldToScreenY(pt.y);
        canvas.drawCircle(Offset(sx, sy), 2.5, Paint()..color = color);
      case final CadHatch h:
        _paintHatch(canvas, h, color);
      case final CadSpline s:
        _paintSpline(canvas, s, stroke);
      case final CadDim d:
        _paintDimension(canvas, d, stroke, color);
      case final Cad3dFace f:
        if (f.corners.length < 2) {
          break;
        }
        final path = Path()
          ..moveTo(
            transform.worldToScreenX(f.corners.first.x),
            transform.worldToScreenY(f.corners.first.y),
          );
        for (final c in f.corners.skip(1)) {
          path.lineTo(transform.worldToScreenX(c.x), transform.worldToScreenY(c.y));
        }
        path.close();
        canvas.drawPath(path, stroke);
    }
  }

  void _paintEllipse(Canvas canvas, CadEllipse el, Paint stroke) {
    final cx = transform.worldToScreenX(el.cx);
    final cy = transform.worldToScreenY(el.cy);
    // Elipse rotada: dibuja mediante rect transformado.
    final w = el.majorRadius * 2 * transform.scale;
    final h = el.minorRadius * 2 * transform.scale;
    if (w < 0.5 || h < 0.5) {
      canvas.drawCircle(Offset(cx, cy), 0.5, stroke);
      return;
    }
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(el.rotation);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), stroke);
    canvas.restore();
  }

  void _paintLwPolyline(Canvas canvas, CadLwPolyline p, Paint stroke) {
    if (p.points.isEmpty) {
      return;
    }
    final pts = p.points;
    // Bulges: muestrear arcos; si no hay bulges, dibujar rectas.
    final hasBulge = pts.any((v) => v.bulge != 0);
    final path = Path();
    final first = pts.first;
    path.moveTo(transform.worldToScreenX(first.x), transform.worldToScreenY(first.y));
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (hasBulge && a.bulge != 0) {
        for (var t = 1; t <= 12; t++) {
          final pt = pointOnBulge(a.x, a.y, b.x, b.y, a.bulge, t / 12);
          path.lineTo(transform.worldToScreenX(pt.x), transform.worldToScreenY(pt.y));
        }
      } else {
        path.lineTo(transform.worldToScreenX(b.x), transform.worldToScreenY(b.y));
      }
    }
    if (p.closed) {
      final last = pts.last;
      final firstPt = pts.first;
      path.lineTo(transform.worldToScreenX(firstPt.x), transform.worldToScreenY(firstPt.y));
    }
    canvas.drawPath(path, stroke);
  }

  void _paintText(
    Canvas canvas,
    String text,
    double wx,
    double wy,
    double height,
    double rotation,
    Color color,
    int halign,
  ) {
    if (text.isEmpty) {
      return;
    }
    final size = height * transform.scale;
    if (size < 2) {
      return; // LOD: texto ilegible a zoom lejano.
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final sx = transform.worldToScreenX(wx);
    final sy = transform.worldToScreenY(wy);
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(rotation);
    final dx = halign == 1
        ? -painter.width / 2
        : halign == 2
            ? -painter.width
            : 0.0;
    painter.paint(canvas, Offset(dx, -painter.height));
    canvas.restore();
  }

  void _paintInsertPlaceholder(Canvas canvas, CadInsert i, Paint stroke) {
    // Punto de inserción + cruz (los bloques se resuelven en el ViewModel
    // si se desea; aquí mostramos el punto).
    final sx = transform.worldToScreenX(i.x);
    final sy = transform.worldToScreenY(i.y);
    canvas.drawCircle(Offset(sx, sy), 3, stroke);
    canvas.drawLine(Offset(sx - 5, sy), Offset(sx + 5, sy), stroke);
    canvas.drawLine(Offset(sx, sy - 5), Offset(sx, sy + 5), stroke);
  }

  void _paintHatch(Canvas canvas, CadHatch h, Color color) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    for (final b in h.boundaries) {
      if (b.points.length < 2) {
        continue;
      }
      final path = Path()
        ..moveTo(
          transform.worldToScreenX(b.points.first.x),
          transform.worldToScreenY(b.points.first.y),
        );
      for (final pt in b.points.skip(1)) {
        path.lineTo(transform.worldToScreenX(pt.x), transform.worldToScreenY(pt.y));
      }
      if (b.closed) {
        path.close();
      }
      canvas.drawPath(path, fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintSpline(Canvas canvas, CadSpline s, Paint stroke) {
    final pts = s.controlPoints;
    if (pts.length < 2) {
      return;
    }
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final sx = transform.worldToScreenX(pts[i].x);
      final sy = transform.worldToScreenY(pts[i].y);
      if (i == 0) {
        path.moveTo(sx, sy);
      } else {
        path.lineTo(sx, sy);
      }
    }
    canvas.drawPath(path, stroke);
  }

  void _paintDimension(Canvas canvas, CadDim d, Paint stroke, Color color) {
    // Puntos de la cota: origen de línea de extensión 1 (x3/y3) y 2 (x4/y4);
    // si falta el segundo (archivos sin 14/24), se cae al punto de definición
    // (x1/y1). El punto de texto (x2/y2) decide el lado de la línea de cota.
    var ax = d.x3;
    var ay = d.y3;
    var bx = d.x4;
    var by = d.y4;
    final hasExt2 = d.x4 != 0 || d.y4 != 0;
    if (!hasExt2) {
      // Sin 14/24: extremos medidos = (x1/y1) y (x3/y3).
      ax = d.x1;
      ay = d.y1;
      bx = d.x3;
      by = d.y3;
    }
    final len = distance(ax, ay, bx, by);
    if (len < 1e-9) {
      return;
    }

    // Altura de texto proporcional: dimtxt del estilo si existe; si no,
    // 4% de la longitud medida (evita el fijo 20 unidades que hacía las
    // cotas gigantes en planos de ~100 m). Se clampa a un mínimo legible
    // en pantalla (~12 px) para que la etiqueta no desaparezca al alejar.
    var textH = d.textHeight > 0 ? d.textHeight : len * 0.04;
    final textPx = textH * transform.scale;
    if (textPx < 12) {
      textH = 12 / transform.scale;
    }
    final arrow = d.arrowSize > 0 ? d.arrowSize : textH * 1.5;

    // Dirección de la medición y su perpendicular.
    final ux = (bx - ax) / len;
    final uy = (by - ay) / len;
    final nx = -uy;
    final ny = ux;
    // Lado hacia el punto de texto (x2/y2).
    final side = ((d.x2 - ax) * nx + (d.y2 - ay) * ny) >= 0 ? 1.0 : -1.0;
    final gap = textH * 1.2 * side;

    // Extremos de la línea de cota (desplazada perpendicularmente).
    final daX = ax + nx * gap;
    final daY = ay + ny * gap;
    final dbX = bx + nx * gap;
    final dbY = by + ny * gap;

    // Líneas de extensión.
    canvas.drawLine(
      _toScreen(ax, ay),
      _toScreen(daX, daY),
      stroke,
    );
    canvas.drawLine(
      _toScreen(bx, by),
      _toScreen(dbX, dbY),
      stroke,
    );

    // Línea de cota.
    canvas.drawLine(_toScreen(daX, daY), _toScreen(dbX, dbY), stroke);

    // Flechas (rellenas, apuntando hacia dentro de la línea de cota).
    _paintDimArrow(canvas, _toScreen(daX, daY), ux, uy, arrow, color);
    _paintDimArrow(canvas, _toScreen(dbX, dbY), -ux, -uy, arrow, color);

    // Etiqueta: texto del archivo, o medición formateada en la unidad
    // de visualización (RF-UNI-01).
    final raw = d.text;
    final label = (raw == null || raw.isEmpty || raw == '<>')
        ? formatLength(d.measurement ?? len, units)
        : raw;
    _paintText(
      canvas,
      label,
      (daX + dbX) / 2,
      (daY + dbY) / 2,
      textH,
      0,
      color,
      1,
    );
  }

  Offset _toScreen(double wx, double wy) =>
      Offset(transform.worldToScreenX(wx), transform.worldToScreenY(wy));

  void _paintDimArrow(
    Canvas canvas,
    Offset tip,
    double dirX,
    double dirY,
    double arrowSize,
    Color color,
  ) {
    final s = math.max(arrowSize * transform.scale, 4.0); // px mínimos
    final ang = math.atan2(dirY, dirX);
    final a1 = ang + 2.6; // ~150°
    final a2 = ang - 2.6;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + s * math.cos(a1), tip.dy + s * math.sin(a1))
      ..lineTo(tip.dx + s * math.cos(a2), tip.dy + s * math.sin(a2))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // -------------------------------------------------------------------------
  // Overlays.
  // -------------------------------------------------------------------------

  void _paintMeasure(Canvas canvas, double vw, double vh) {
    if (measurePoints.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = measureColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final pts = measurePoints
        .map((p) => Offset(transform.worldToScreenX(p.x), transform.worldToScreenY(p.y)))
        .toList();
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, 4, paint);
      return;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], paint);
    }
    if (measureMode == MeasureMode.area && pts.length > 2) {
      canvas.drawLine(pts.last, pts.first, paint);
    }
  }

  void _paintDraftPreview(Canvas canvas) {
    final p = previewPoint!;
    final pts = [...draftPoints, p];
    final paint = Paint()
      ..color = selectionColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final screen = pts
        .map((q) => Offset(transform.worldToScreenX(q.x), transform.worldToScreenY(q.y)))
        .toList();
    for (var i = 0; i < screen.length - 1; i++) {
      canvas.drawLine(screen[i], screen[i + 1], paint);
    }
    // Círculo preview: radio desde el centro.
    if (toolModeFor == ToolMode.circle && draftPoints.isNotEmpty) {
      final c = draftPoints.first;
      final r = distance(c.x, c.y, p.x, p.y) * transform.scale;
      canvas.drawCircle(
        Offset(transform.worldToScreenX(c.x), transform.worldToScreenY(c.y)),
        r,
        paint,
      );
    }
  }

  void _paintSelectionHalo(Canvas canvas) {
    if (selectedHandles.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = selectionColor.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final e in entities) {
      if (!selectedHandles.contains(e.handle)) {
        continue;
      }
      // Halo: bounding box redondeado.
      final b = _entityScreenBounds(e);
      if (b != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(b.inflate(6), const Radius.circular(4)),
          paint,
        );
      }
    }
  }

  void _paintCrosshair(Canvas canvas, CadPoint3 world, double vw, double vh) {
    final sx = transform.worldToScreenX(world.x);
    final sy = transform.worldToScreenY(world.y);
    final paint = Paint()
      ..color = selectionColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final len = 24.0;
    canvas.drawLine(Offset(sx - len, sy), Offset(sx + len, sy), paint);
    canvas.drawLine(Offset(sx, sy - len), Offset(sx, sy + len), paint);
  }

  // -------------------------------------------------------------------------
  // Culling.
  // -------------------------------------------------------------------------

  Bounds _visibleWorldRect(double vw, double vh) {
    final margin = 0.2; // +20% de margen (RF-RENDER-11).
    return Bounds(
      minX: transform.screenToWorldX(-vw * margin),
      minY: transform.screenToWorldY(-vh * margin),
      maxX: transform.screenToWorldX(vw * (1 + margin)),
      maxY: transform.screenToWorldY(vh * (1 + margin)),
    );
  }

  bool _cull(CadEntity e, Bounds view) {
    final b = _entityWorldBounds(e);
    return b.isEmpty || b.intersects(view);
  }

  Bounds _entityWorldBounds(CadEntity e) {
    switch (e) {
      case final CadLine l:
        return Bounds(minX: math.min(l.x1, l.x2), minY: math.min(l.y1, l.y2), maxX: math.max(l.x1, l.x2), maxY: math.max(l.y1, l.y2));
      case final CadCircle c:
        return Bounds(minX: c.cx - c.radius, minY: c.cy - c.radius, maxX: c.cx + c.radius, maxY: c.cy + c.radius);
      case final CadArc a:
        return Bounds(minX: a.cx - a.radius, minY: a.cy - a.radius, maxX: a.cx + a.radius, maxY: a.cy + a.radius);
      case final CadEllipse el:
        final r = el.majorRadius;
        return Bounds(minX: el.cx - r, minY: el.cy - r, maxX: el.cx + r, maxY: el.cy + r);
      case final CadLwPolyline p:
        var b = const Bounds.empty();
        for (final v in p.points) {
          b = b.expandToIncludePoint(v.x, v.y);
        }
        return b;
      case final CadPolyline p:
        var b = const Bounds.empty();
        for (final pt in p.points) {
          b = b.expandToIncludePoint(pt.x, pt.y);
        }
        return b;
      case final CadText t:
        return Bounds(minX: t.x - t.height, minY: t.y - t.height, maxX: t.x + t.height, maxY: t.y + t.height);
      case final CadMText m:
        return Bounds(minX: m.x - m.height, minY: m.y - m.height, maxX: m.x + m.width + m.height, maxY: m.y + m.height);
      case final CadInsert i:
        return Bounds.point(i.x, i.y);
      case final CadPoint pt:
        return Bounds.point(pt.x, pt.y);
      case final CadHatch h:
        var b = const Bounds.empty();
        for (final bd in h.boundaries) {
          for (final p in bd.points) {
            b = b.expandToIncludePoint(p.x, p.y);
          }
        }
        return b;
      case final CadSpline s:
        var b = const Bounds.empty();
        for (final p in s.controlPoints) {
          b = b.expandToIncludePoint(p.x, p.y);
        }
        return b;
      case final CadDim d:
        return Bounds(
          minX: math.min(math.min(math.min(d.x1, d.x2), d.x3), d.x4),
          minY: math.min(math.min(math.min(d.y1, d.y2), d.y3), d.y4),
          maxX: math.max(math.max(math.max(d.x1, d.x2), d.x3), d.x4),
          maxY: math.max(math.max(math.max(d.y1, d.y2), d.y3), d.y4),
        );
      case final Cad3dFace f:
        var b = const Bounds.empty();
        for (final p in f.corners) {
          b = b.expandToIncludePoint(p.x, p.y);
        }
        return b;
    }
  }

  ui.Rect? _entityScreenBounds(CadEntity e) {
    final b = _entityWorldBounds(e);
    if (b.isEmpty) {
      return null;
    }
    return Rect.fromLTRB(
      transform.worldToScreenX(b.minX),
      transform.worldToScreenY(b.minY),
      transform.worldToScreenX(b.maxX),
      transform.worldToScreenY(b.maxY),
    );
  }

  @override
  bool shouldRepaint(covariant CadPainter old) {
    return old.documentVersion != documentVersion ||
        old.selectionVersion != selectionVersion ||
        old.transformVersion != transformVersion ||
        old.gridType != gridType ||
        old.showAxes != showAxes ||
        old.activeSnap != activeSnap ||
        old.measurePoints != measurePoints ||
        old.draftPoints != draftPoints ||
        old.previewPoint != previewPoint ||
        old.grips != grips ||
        old.activeGripIndex != activeGripIndex ||
        old.previewDx != previewDx ||
        old.previewDy != previewDy ||
        old.previewAngle != previewAngle ||
        old.previewFactor != previewFactor;
  }

  // Nota: el painter necesita saber la herramienta para el preview del
  // círculo; se inyecta desde el widget (el painter no depende del VM).
  ToolMode toolModeFor = ToolMode.none;
}
