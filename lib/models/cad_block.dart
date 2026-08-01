/// Definición de bloque (docs/DATA_MODEL.md §6).
///
/// Dart puro. `getBounds()` devuelve el bounding box **local** (antes de la
/// transformación de inserción).
library;

import 'package:collection/collection.dart';

import 'bounds.dart';
import 'cad_entity.dart';

/// Bloque: conjunto de entidades con punto base de inserción.
class CadBlock {
  const CadBlock({
    required this.name,
    this.basePoint = const CadPoint3(0, 0, 0),
    this.entities = const [],
  });

  /// Nombre del bloque.
  final String name;

  /// Punto base de inserción.
  final CadPoint3 basePoint;

  /// Entidades internas (pueden contener INSERT anidados).
  final List<CadEntity> entities;

  /// Bounding box local (coordenadas del bloque, sin transformación).
  Bounds getBounds() {
    var bounds = const Bounds.empty();
    for (final entity in entities) {
      bounds = bounds.expandToInclude(_entityBounds(entity));
    }
    return bounds;
  }

  CadBlock copyWith({
    String? name,
    CadPoint3? basePoint,
    List<CadEntity>? entities,
  }) =>
      CadBlock(
        name: name ?? this.name,
        basePoint: basePoint ?? this.basePoint,
        entities: entities ?? this.entities,
      );

  @override
  bool operator ==(Object other) =>
      other is CadBlock &&
      other.name == name &&
      other.basePoint == basePoint &&
      const ListEquality<CadEntity>().equals(other.entities, entities);

  @override
  int get hashCode => Object.hash(
        name,
        basePoint,
        const ListEquality<CadEntity>().hash(entities),
      );

  @override
  String toString() => 'CadBlock($name, ${entities.length} entidades)';
}

/// Bounds de una entidad individual (sin resolución de bloques anidados).
Bounds _entityBounds(CadEntity entity) {
  var bounds = const Bounds.empty();
  switch (entity) {
    case final CadLine l:
      bounds = bounds
          .expandToIncludePoint(l.x1, l.y1)
          .expandToIncludePoint(l.x2, l.y2);
    case final CadCircle c:
      bounds = bounds
          .expandToIncludePoint(c.cx - c.radius, c.cy - c.radius)
          .expandToIncludePoint(c.cx + c.radius, c.cy + c.radius);
    case final CadArc a:
      bounds = bounds
          .expandToIncludePoint(a.cx - a.radius, a.cy - a.radius)
          .expandToIncludePoint(a.cx + a.radius, a.cy + a.radius);
    case final CadEllipse e:
      final r = e.majorRadius;
      bounds = bounds
          .expandToIncludePoint(e.cx - r, e.cy - r)
          .expandToIncludePoint(e.cx + r, e.cy + r);
    case final CadLwPolyline p:
      for (final v in p.points) {
        bounds = bounds.expandToIncludePoint(v.x, v.y);
      }
    case final CadPolyline p:
      for (final pt in p.points) {
        bounds = bounds.expandToIncludePoint(pt.x, pt.y);
      }
    case final CadText t:
      bounds = bounds
          .expandToIncludePoint(t.x - t.height, t.y - t.height)
          .expandToIncludePoint(t.x + t.height, t.y + t.height);
    case final CadMText m:
      bounds = bounds
          .expandToIncludePoint(m.x - m.height, m.y - m.height)
          .expandToIncludePoint(m.x + m.width + m.height, m.y + m.height);
    case final CadInsert i:
      bounds = bounds.expandToIncludePoint(i.x, i.y);
    case final CadPoint pt:
      bounds = bounds.expandToIncludePoint(pt.x, pt.y);
    case final CadHatch h:
      for (final b in h.boundaries) {
        for (final pt in b.points) {
          bounds = bounds.expandToIncludePoint(pt.x, pt.y);
        }
      }
    case final CadSpline s:
      for (final pt in s.controlPoints) {
        bounds = bounds.expandToIncludePoint(pt.x, pt.y);
      }
    case final CadDim d:
      bounds = bounds
          .expandToIncludePoint(d.x1, d.y1)
          .expandToIncludePoint(d.x2, d.y2)
          .expandToIncludePoint(d.x3, d.y3)
          .expandToIncludePoint(d.x4, d.y4);
    case final Cad3dFace f:
      for (final pt in f.corners) {
        bounds = bounds.expandToIncludePoint(pt.x, pt.y);
      }
    case final CadSolid s:
      for (final pt in s.corners) {
        bounds = bounds.expandToIncludePoint(pt.x, pt.y);
      }
  }
  return bounds;
}
