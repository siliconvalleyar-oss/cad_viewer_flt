/// Comandos concretos de edición (docs/EDITING.md §3).
///
/// Todos implementan `execute`/`undo` sobre `CadDocument` inmutable. Los
/// comandos destructivos usan memento (guardan las entidades borradas); los
/// transformativos usan la operación inversa.
library;

import 'dart:math' as math;

import '../models/cad_document.dart';
import '../models/cad_entity.dart';
import '../models/cad_layer.dart';
import 'command_stack.dart';

int _nextHandleSeed = 0x1000;

/// Genera un handle único para entidades nuevas.
String nextHandle() => (_nextHandleSeed++).toRadixString(16);

/// Crea entidades nuevas.
class CommandCreate extends CadCommand {
  CommandCreate(this.entities);

  /// Entidades a crear.
  final List<CadEntity> entities;

  @override
  String get description =>
      'Crear ${entities.length == 1 ? _typeLabel(entities.first) : '${entities.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) {
    var result = doc;
    for (final e in entities) {
      result = result.addEntity(e);
    }
    return result;
  }

  @override
  CadDocument undo(CadDocument doc) {
    var result = doc;
    for (final e in entities) {
      result = result.removeEntity(e.handle);
    }
    return result;
  }
}

/// Borra entidades por handle (guarda memento para undo).
class CommandDelete extends CadCommand {
  CommandDelete(this.entities);

  /// Entidades borradas (memento).
  final List<CadEntity> entities;

  @override
  String get description =>
      'Borrar ${entities.length == 1 ? '1 entidad' : '${entities.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) {
    var result = doc;
    for (final e in entities) {
      result = result.removeEntity(e.handle);
    }
    return result;
  }

  @override
  CadDocument undo(CadDocument doc) {
    var result = doc;
    for (final e in entities) {
      result = result.addEntity(e);
    }
    return result;
  }
}

/// Mueve entidades (delta). La operación inversa deshace el movimiento.
class CommandMove extends CadCommand {
  CommandMove(this.handles, this.dx, this.dy);

  /// Handles a mover.
  final Set<String> handles;

  /// Desplazamiento X (mm).
  final double dx;

  /// Desplazamiento Y (mm).
  final double dy;

  @override
  String get description =>
      'Mover ${handles.length == 1 ? '1 entidad' : '${handles.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) => _applyTransform(doc, (e) => _move(e, dx, dy));

  @override
  CadDocument undo(CadDocument doc) => _applyTransform(doc, (e) => _move(e, -dx, -dy));

  CadDocument _applyTransform(CadDocument doc, CadEntity Function(CadEntity) f) {
    var result = doc;
    for (final h in handles) {
      final e = doc.getEntity(h);
      if (e != null) {
        result = result.setEntityProps(h, f(e));
      }
    }
    return result;
  }
}

/// Rota entidades alrededor de un centro (radianes).
class CommandRotate extends CadCommand {
  CommandRotate(this.handles, this.angle, this.centerX, this.centerY);

  final Set<String> handles;
  final double angle;
  final double centerX;
  final double centerY;

  @override
  String get description =>
      'Rotar ${handles.length == 1 ? '1 entidad' : '${handles.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) =>
      _apply(doc, (e) => _rotate(e, angle, centerX, centerY));

  @override
  CadDocument undo(CadDocument doc) =>
      _apply(doc, (e) => _rotate(e, -angle, centerX, centerY));

  CadDocument _apply(CadDocument doc, CadEntity Function(CadEntity) f) {
    var result = doc;
    for (final h in handles) {
      final e = doc.getEntity(h);
      if (e != null) {
        result = result.setEntityProps(h, f(e));
      }
    }
    return result;
  }
}

/// Escala entidades alrededor de un centro.
class CommandScale extends CadCommand {
  CommandScale(this.handles, this.factor, this.centerX, this.centerY);

  final Set<String> handles;
  final double factor;
  final double centerX;
  final double centerY;

  @override
  String get description =>
      'Escalar ${handles.length == 1 ? '1 entidad' : '${handles.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) =>
      _apply(doc, (e) => _scale(e, factor, centerX, centerY));

  @override
  CadDocument undo(CadDocument doc) =>
      _apply(doc, (e) => _scale(e, 1 / factor, centerX, centerY));

  CadDocument _apply(CadDocument doc, CadEntity Function(CadEntity) f) {
    var result = doc;
    for (final h in handles) {
      final e = doc.getEntity(h);
      if (e != null) {
        result = result.setEntityProps(h, f(e));
      }
    }
    return result;
  }
}

/// Copia entidades con un delta y handles nuevos (para poder deshacer).
class CommandCopy extends CadCommand {
  CommandCopy(this.entities, this.dx, this.dy)
      : copies = entities
            .map((e) => _move(e, dx, dy).copyWith(handle: nextHandle()))
            .toList();

  /// Entidades originales.
  final List<CadEntity> entities;

  /// Delta de copia.
  final double dx;

  /// Desplazamiento Y.
  final double dy;

  /// Copias creadas (memento para undo).
  final List<CadEntity> copies;

  @override
  String get description =>
      'Copiar ${entities.length == 1 ? '1 entidad' : '${entities.length} entidades'}';

  @override
  CadDocument execute(CadDocument doc) {
    var result = doc;
    for (final c in copies) {
      result = result.addEntity(c);
    }
    return result;
  }

  @override
  CadDocument undo(CadDocument doc) {
    var result = doc;
    for (final c in copies) {
      result = result.removeEntity(c.handle);
    }
    return result;
  }
}

/// Modifica las propiedades de una entidad (antes → después, memento).
class CommandModifyProps extends CadCommand {
  CommandModifyProps(this.handle, this.before, this.after);

  final String handle;
  final CadEntity before;
  final CadEntity after;

  @override
  String get description => 'Modificar entidad';

  @override
  CadDocument execute(CadDocument doc) => doc.setEntityProps(handle, after);

  @override
  CadDocument undo(CadDocument doc) => doc.setEntityProps(handle, before);
}

/// Crea una capa.
class CommandLayerCreate extends CadCommand {
  CommandLayerCreate(this.layer);

  final CadLayer layer;

  @override
  String get description => 'Crear capa ${layer.name}';

  @override
  CadDocument execute(CadDocument doc) => doc.copyWith(
        layers: [...doc.layers, layer],
      );

  @override
  CadDocument undo(CadDocument doc) => doc.copyWith(
        layers: doc.layers.where((l) => l.name != layer.name).toList(),
      );
}

/// Borra una capa vacía.
class CommandLayerDelete extends CadCommand {
  CommandLayerDelete(this.layer);

  final CadLayer layer;

  @override
  String get description => 'Borrar capa ${layer.name}';

  @override
  CadDocument execute(CadDocument doc) => doc.copyWith(
        layers: doc.layers.where((l) => l.name != layer.name).toList(),
      );

  @override
  CadDocument undo(CadDocument doc) => doc.copyWith(
        layers: [...doc.layers, layer],
      );
}

/// Renombra una capa (actualiza también las entidades de esa capa).
class CommandLayerRename extends CadCommand {
  CommandLayerRename(this.oldName, this.newName);

  final String oldName;
  final String newName;

  @override
  String get description => 'Renombrar capa $oldName → $newName';

  @override
  CadDocument execute(CadDocument doc) => _rename(doc, oldName, newName);

  @override
  CadDocument undo(CadDocument doc) => _rename(doc, newName, oldName);

  CadDocument _rename(CadDocument doc, String from, String to) {
    final newLayers = doc.layers
        .map((l) => l.name == from ? l.copyWith(name: to) : l)
        .toList();
    final newEntities = doc.entities
        .map((e) => e.layer == from ? e.copyWith(layer: to) : e)
        .toList();
    final newBlocks = doc.blocks;
    return doc.copyWith(layers: newLayers, entities: newEntities, blocks: newBlocks);
  }
}

// ---------------------------------------------------------------------------
// Transformaciones geométricas puras.
// ---------------------------------------------------------------------------

CadEntity _move(CadEntity e, double dx, double dy) {
  switch (e) {
    case final CadLine l:
      return l.copyWith(x1: l.x1 + dx, y1: l.y1 + dy, x2: l.x2 + dx, y2: l.y2 + dy);
    case final CadCircle c:
      return c.copyWith(cx: c.cx + dx, cy: c.cy + dy);
    case final CadArc a:
      return a.copyWith(cx: a.cx + dx, cy: a.cy + dy);
    case final CadEllipse el:
      return el.copyWith(cx: el.cx + dx, cy: el.cy + dy);
    case final CadLwPolyline p:
      return p.copyWith(
        points: p.points
            .map((v) => v.copyWith(x: v.x + dx, y: v.y + dy))
            .toList(),
      );
    case final CadPolyline p:
      return p.copyWith(
        points: p.points.map((pt) => pt.copyWith(x: pt.x + dx, y: pt.y + dy)).toList(),
      );
    case final CadText t:
      return t.copyWith(x: t.x + dx, y: t.y + dy);
    case final CadMText m:
      return m.copyWith(x: m.x + dx, y: m.y + dy);
    case final CadInsert i:
      return i.copyWith(x: i.x + dx, y: i.y + dy);
    case final CadPoint pt:
      return pt.copyWith(x: pt.x + dx, y: pt.y + dy);
    case final CadHatch h:
      return h.copyWith(
        boundaries: h.boundaries
            .map(
              (b) => b.copyWith(
                points: b.points.map((p) => p.copyWith(x: p.x + dx, y: p.y + dy)).toList(),
              ),
            )
            .toList(),
      );
    case final CadSpline s:
      return s.copyWith(
        controlPoints:
            s.controlPoints.map((p) => p.copyWith(x: p.x + dx, y: p.y + dy)).toList(),
      );
    case final CadDim d:
      return d.copyWith(
        x1: d.x1 + dx, y1: d.y1 + dy,
        x2: d.x2 + dx, y2: d.y2 + dy,
        x3: d.x3 + dx, y3: d.y3 + dy,
        x4: d.x4 + dx, y4: d.y4 + dy,
      );
    case final Cad3dFace f:
      return f.copyWith(
        corners: f.corners.map((p) => p.copyWith(x: p.x + dx, y: p.y + dy)).toList(),
      );
    case final CadSolid s:
      return s.copyWith(
        corners: s.corners.map((p) => p.copyWith(x: p.x + dx, y: p.y + dy)).toList(),
      );
  }
}

CadEntity _rotate(CadEntity e, double angle, double cx, double cy) {
  (double, double) rot(double x, double y) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final dx = x - cx;
    final dy = y - cy;
    return (cx + dx * cos - dy * sin, cy + dx * sin + dy * cos);
  }

  switch (e) {
    case final CadLine l:
      final (x1, y1) = rot(l.x1, l.y1);
      final (x2, y2) = rot(l.x2, l.y2);
      return l.copyWith(x1: x1, y1: y1, x2: x2, y2: y2);
    case final CadCircle c:
      final (x, y) = rot(c.cx, c.cy);
      return c.copyWith(cx: x, cy: y);
    case final CadArc a:
      final (x, y) = rot(a.cx, a.cy);
      return a.copyWith(cx: x, cy: y, startAngle: a.startAngle + angle, endAngle: a.endAngle + angle);
    case final CadEllipse el:
      final (x, y) = rot(el.cx, el.cy);
      return el.copyWith(cx: x, cy: y, rotation: el.rotation + angle);
    case final CadLwPolyline p:
      return p.copyWith(
        points: p.points
            .map((v) {
              final (x, y) = rot(v.x, v.y);
              return v.copyWith(x: x, y: y);
            })
            .toList(),
      );
    case final CadPolyline p:
      return p.copyWith(
        points: p.points
            .map((pt) {
              final (x, y) = rot(pt.x, pt.y);
              return pt.copyWith(x: x, y: y);
            })
            .toList(),
      );
    case final CadText t:
      final (x, y) = rot(t.x, t.y);
      return t.copyWith(x: x, y: y, rotation: t.rotation + angle);
    case final CadMText m:
      final (x, y) = rot(m.x, m.y);
      return m.copyWith(x: x, y: y, rotation: m.rotation + angle);
    case final CadInsert i:
      final (x, y) = rot(i.x, i.y);
      return i.copyWith(x: x, y: y, rotation: i.rotation + angle);
    case final CadPoint pt:
      final (x, y) = rot(pt.x, pt.y);
      return pt.copyWith(x: x, y: y);
    case final CadHatch h:
      return h.copyWith(
        boundaries: h.boundaries
            .map(
              (b) => b.copyWith(
                points: b.points
                    .map((p) {
                      final (x, y) = rot(p.x, p.y);
                      return p.copyWith(x: x, y: y);
                    })
                    .toList(),
              ),
            )
            .toList(),
      );
    case final CadSpline s:
      return s.copyWith(
        controlPoints: s.controlPoints
            .map((p) {
              final (x, y) = rot(p.x, p.y);
              return p.copyWith(x: x, y: y);
            })
            .toList(),
      );
    case final CadDim d:
      final (x1, y1) = rot(d.x1, d.y1);
      final (x2, y2) = rot(d.x2, d.y2);
      final (x3, y3) = rot(d.x3, d.y3);
      final (x4, y4) = rot(d.x4, d.y4);
      return d.copyWith(x1: x1, y1: y1, x2: x2, y2: y2, x3: x3, y3: y3, x4: x4, y4: y4);
    case final Cad3dFace f:
      return f.copyWith(
        corners: f.corners
            .map((p) {
              final (x, y) = rot(p.x, p.y);
              return p.copyWith(x: x, y: y);
            })
            .toList(),
      );
    case final CadSolid s:
      return s.copyWith(
        corners: s.corners
            .map((p) {
              final (x, y) = rot(p.x, p.y);
              return p.copyWith(x: x, y: y);
            })
            .toList(),
      );
  }
}

CadEntity _scale(CadEntity e, double factor, double cx, double cy) {
  double sc(double v, double center) => center + (v - center) * factor;

  switch (e) {
    case final CadLine l:
      return l.copyWith(x1: sc(l.x1, cx), y1: sc(l.y1, cy), x2: sc(l.x2, cx), y2: sc(l.y2, cy));
    case final CadCircle c:
      return c.copyWith(cx: sc(c.cx, cx), cy: sc(c.cy, cy), radius: c.radius * factor);
    case final CadArc a:
      return a.copyWith(cx: sc(a.cx, cx), cy: sc(a.cy, cy), radius: a.radius * factor);
    case final CadEllipse el:
      return el.copyWith(
        cx: sc(el.cx, cx),
        cy: sc(el.cy, cy),
        majorRadius: el.majorRadius * factor,
        minorRadius: el.minorRadius * factor,
      );
    case final CadLwPolyline p:
      return p.copyWith(
        points: p.points
            .map((v) => v.copyWith(x: sc(v.x, cx), y: sc(v.y, cy)))
            .toList(),
      );
    case final CadPolyline p:
      return p.copyWith(
        points: p.points.map((pt) => pt.copyWith(x: sc(pt.x, cx), y: sc(pt.y, cy))).toList(),
      );
    case final CadText t:
      return t.copyWith(x: sc(t.x, cx), y: sc(t.y, cy), height: t.height * factor);
    case final CadMText m:
      return m.copyWith(x: sc(m.x, cx), y: sc(m.y, cy), height: m.height * factor);
    case final CadInsert i:
      return i.copyWith(
        x: sc(i.x, cx),
        y: sc(i.y, cy),
        scaleX: i.scaleX * factor,
        scaleY: i.scaleY * factor,
      );
    case final CadPoint pt:
      return pt.copyWith(x: sc(pt.x, cx), y: sc(pt.y, cy));
    case final CadHatch h:
      return h.copyWith(
        boundaries: h.boundaries
            .map(
              (b) => b.copyWith(
                points: b.points.map((p) => p.copyWith(x: sc(p.x, cx), y: sc(p.y, cy))).toList(),
              ),
            )
            .toList(),
      );
    case final CadSpline s:
      return s.copyWith(
        controlPoints:
            s.controlPoints.map((p) => p.copyWith(x: sc(p.x, cx), y: sc(p.y, cy))).toList(),
      );
    case final CadDim d:
      return d.copyWith(
        x1: sc(d.x1, cx), y1: sc(d.y1, cy),
        x2: sc(d.x2, cx), y2: sc(d.y2, cy),
        x3: sc(d.x3, cx), y3: sc(d.y3, cy),
        x4: sc(d.x4, cx), y4: sc(d.y4, cy),
        textHeight: d.textHeight * factor,
        arrowSize: d.arrowSize * factor,
        measurement: d.measurement == null ? null : d.measurement! * factor,
      );
    case final Cad3dFace f:
      return f.copyWith(
        corners: f.corners.map((p) => p.copyWith(x: sc(p.x, cx), y: sc(p.y, cy))).toList(),
      );
    case final CadSolid s:
      return s.copyWith(
        corners: s.corners.map((p) => p.copyWith(x: sc(p.x, cx), y: sc(p.y, cy))).toList(),
      );
  }
}

String _typeLabel(CadEntity e) => switch (e) {
      CadLine() => 'línea',
      CadCircle() => 'círculo',
      CadArc() => 'arco',
      CadEllipse() => 'elipse',
      CadLwPolyline() || CadPolyline() => 'polilínea',
      CadText() || CadMText() => 'texto',
      CadInsert() => 'bloque',
      CadPoint() => 'punto',
      CadHatch() => 'sombreado',
      CadSpline() => 'spline',
      CadDim() => 'dimensión',
      Cad3dFace() => 'cara 3D',
      CadSolid() => 'sólido',
    };
