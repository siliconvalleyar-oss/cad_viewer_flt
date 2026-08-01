/// Contenido de un archivo CAD (docs/DATA_MODEL.md §3).
///
/// Dart puro. `CadFile` es el contenido del archivo (inmutable por
/// convención); la sesión editable vive en `CadDocument` (cad_document.dart).
library;

import 'package:collection/collection.dart';

import 'bounds.dart';
import 'cad_block.dart';
import 'cad_entity.dart';
import 'cad_enums.dart';
import 'cad_layer.dart';

/// Variables de encabezado del dibujo (DATA_MODEL §3, CadHeader).
class CadHeader {
  const CadHeader({
    this.units = UnitsType.mm,
    this.extMin = const CadPoint3(0, 0, 0),
    this.extMax = const CadPoint3(0, 0, 0),
    this.baseAngle = 0,
    this.insUnits = 4,
  });

  /// Unidad del dibujo (normalizada a mm internamente).
  final UnitsType units;

  /// Límite mínimo del dibujo.
  final CadPoint3 extMin;

  /// Límite máximo del dibujo.
  final CadPoint3 extMax;

  /// Ángulo base en radianes.
  final double baseAngle;

  /// Valor crudo de `$INSUNITS`.
  final int insUnits;

  CadHeader copyWith({
    UnitsType? units,
    CadPoint3? extMin,
    CadPoint3? extMax,
    double? baseAngle,
    int? insUnits,
  }) =>
      CadHeader(
        units: units ?? this.units,
        extMin: extMin ?? this.extMin,
        extMax: extMax ?? this.extMax,
        baseAngle: baseAngle ?? this.baseAngle,
        insUnits: insUnits ?? this.insUnits,
      );

  @override
  bool operator ==(Object other) =>
      other is CadHeader &&
      other.units == units &&
      other.extMin == extMin &&
      other.extMax == extMax &&
      other.baseAngle == baseAngle &&
      other.insUnits == insUnits;

  @override
  int get hashCode => Object.hash(units, extMin, extMax, baseAngle, insUnits);
}

/// Contenido de un archivo CAD: cabecera, capas, bloques y entidades.
class CadFile {
  const CadFile({
    required this.fileName,
    this.format = FileFormat.dxf,
    this.version = 'AC1015',
    this.header = const CadHeader(),
    this.layers = const [],
    this.entities = const [],
    this.blocks = const [],
  });

  /// Nombre del archivo de origen.
  final String fileName;

  /// Formato (dxf, dwg, unknown).
  final FileFormat format;

  /// Versión DXF leída de `$ACADVER` (AC1009, AC1015…) o inferida.
  final String version;

  /// Variables de encabezado.
  final CadHeader header;

  /// Definiciones de capas.
  final List<CadLayer> layers;

  /// Entidades del dibujo (model space).
  final List<CadEntity> entities;

  /// Definiciones de bloques.
  final List<CadBlock> blocks;

  /// Busca una capa por nombre; `null` si no existe.
  CadLayer? layerByName(String name) {
    for (final layer in layers) {
      if (layer.name == name) {
        return layer;
      }
    }
    return null;
  }

  /// Busca un bloque por nombre; `null` si no existe.
  CadBlock? blockByName(String name) {
    for (final block in blocks) {
      if (block.name == name) {
        return block;
      }
    }
    return null;
  }

  /// Bounding box del dibujo en model space.
  ///
  /// Considera todas las entidades; las referencias a bloque (`INSERT`) se
  /// resuelven con el bounds local del bloque trasladado y escalado por la
  /// inserción (si el bloque no existe, solo el punto de inserción).
  Bounds getBounds() {
    var bounds = const Bounds.empty();
    for (final entity in entities) {
      bounds = bounds.expandToInclude(_entityBounds(entity, this));
    }
    return bounds;
  }

  CadFile copyWith({
    String? fileName,
    FileFormat? format,
    String? version,
    CadHeader? header,
    List<CadLayer>? layers,
    List<CadEntity>? entities,
    List<CadBlock>? blocks,
  }) =>
      CadFile(
        fileName: fileName ?? this.fileName,
        format: format ?? this.format,
        version: version ?? this.version,
        header: header ?? this.header,
        layers: layers ?? this.layers,
        entities: entities ?? this.entities,
        blocks: blocks ?? this.blocks,
      );

  @override
  bool operator ==(Object other) =>
      other is CadFile &&
      other.fileName == fileName &&
      other.format == format &&
      other.version == version &&
      other.header == header &&
      const ListEquality<CadLayer>().equals(other.layers, layers) &&
      const ListEquality<CadEntity>().equals(other.entities, entities) &&
      const ListEquality<CadBlock>().equals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(
        fileName,
        format,
        version,
        header,
        const ListEquality<CadLayer>().hash(layers),
        const ListEquality<CadEntity>().hash(entities),
        const ListEquality<CadBlock>().hash(blocks),
      );

  @override
  String toString() =>
      'CadFile($fileName, v$version, ${entities.length} entidades, ${layers.length} capas)';
}

/// Bounds de una entidad; resuelve bloques referenciados por INSERT.
Bounds _entityBounds(CadEntity entity, CadFile file) {
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
      // Resuelve el bloque referenciado (traslación + escala).
      final block = file.blockByName(i.blockName);
      if (block != null && !block.getBounds().isEmpty) {
        final local = block.getBounds();
        bounds = bounds
            .expandToIncludePoint(
              i.x + local.minX * i.scaleX,
              i.y + local.minY * i.scaleY,
            )
            .expandToIncludePoint(
              i.x + local.maxX * i.scaleX,
              i.y + local.maxY * i.scaleY,
            );
      } else {
        bounds = bounds.expandToIncludePoint(i.x, i.y);
      }
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
      if (s.fitPoints != null) {
        for (final pt in s.fitPoints!) {
          bounds = bounds.expandToIncludePoint(pt.x, pt.y);
        }
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
  }
  return bounds;
}
