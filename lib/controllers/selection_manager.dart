/// Gestión de selección (docs/EDITING.md §4, RF-SELECCIÓN).
///
/// Almacena el conjunto de handles seleccionados y aplica las reglas:
/// capas bloqueadas/frozen no son seleccionables; tap en vacío deselecciona;
/// shift+tap alterna; ventana (verde, contención) vs cruzamiento (azul,
/// intersección).
library;

import 'dart:math' as math;

import '../models/bounds.dart';
import '../models/cad_document.dart';
import '../models/cad_entity.dart';
import '../models/cad_layer.dart';

/// Gestor de selección (pure Dart, testeable).
class SelectionManager {
  SelectionManager();

  final Set<String> _handles = <String>{};

  /// Handles seleccionados.
  Set<String> get handles => Set<String>.unmodifiable(_handles);

  /// `true` si no hay selección.
  bool get isEmpty => _handles.isEmpty;

  /// Número de entidades seleccionadas.
  int get count => _handles.length;

  /// Reemplaza la selección.
  void replace(Iterable<String> handles) {
    _handles
      ..clear()
      ..addAll(handles);
  }

  /// Selecciona un solo handle.
  void selectOne(String handle) {
    _handles
      ..clear()
      ..add(handle);
  }

  /// Alterna un handle manteniendo el resto.
  void toggle(String handle) {
    if (!_handles.add(handle)) {
      _handles.remove(handle);
    }
  }

  /// Añade un handle sin limpiar.
  void add(String handle) => _handles.add(handle);

  /// Elimina la selección.
  void clear() => _handles.clear();

  /// `true` si el handle está seleccionado.
  bool contains(String handle) => _handles.contains(handle);

  /// Selecciona todas las entidades de capas no bloqueadas/frozen.
  void selectAll(CadDocument doc) {
    _handles.clear();
    for (final e in doc.entities) {
      if (_isSelectable(doc, e)) {
        _handles.add(e.handle);
      }
    }
  }

  /// Aplica selección por ventana. [window] rectángulo en mundo.
  ///
  /// [crossing] = true (arrastre derecha→izquierda, azul): selecciona las que
  /// tocan el rectángulo. false (izquierda→derecha, verde): solo contenidas.
  void selectWindow(CadDocument doc, Bounds window, {required bool crossing}) {
    _handles.clear();
    for (final e in doc.entities) {
      if (!_isSelectable(doc, e)) {
        continue;
      }
      final b = entityBounds(e);
      final intersects = b.intersects(window);
      final contained = _contained(b, window);
      if (crossing ? intersects : contained) {
        _handles.add(e.handle);
      }
    }
  }

  /// `true` si el punto toca una entidad seleccionable (para drag-move).
  bool hitSelectable(CadDocument doc, String handle) {
    final e = doc.getEntity(handle);
    return e != null && _isSelectable(doc, e);
  }

  bool _isSelectable(CadDocument doc, CadEntity e) {
    final layer = doc.layerByName(e.layer);
    return layer == null || (!layer.locked && !layer.frozen);
  }

  bool _contained(Bounds inner, Bounds outer) =>
      inner.minX >= outer.minX &&
      inner.maxX <= outer.maxX &&
      inner.minY >= outer.minY &&
      inner.maxY <= outer.maxY;
}

/// Bounds aproximado de una entidad (para ventana de selección).
Bounds entityBounds(CadEntity e) {
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
