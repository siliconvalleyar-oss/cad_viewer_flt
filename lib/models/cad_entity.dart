/// Entidades CAD del modelo de dominio (docs/DATA_MODEL.md §5).
///
/// Dart puro (sin Flutter). Base `sealed` con 14 subtipos; el patrón
/// `copyWith` usa un sentinel (`unset`) para distinguir "no cambiar" de
/// "poner a null" en campos opcionales (`color`, `lineType`, `lineWeight`).
library;

import 'package:collection/collection.dart';

import 'cad_enums.dart';

/// Sentinel: diferencia "parámetro no proporcionado" de "null explícito".
const Object unset = Object();

/// Punto 3D (coordenadas internas en mm, ADR-0007).
class CadPoint3 {
  const CadPoint3(this.x, this.y, [this.z = 0]);

  /// Coordenada X.
  final double x;

  /// Coordenada Y.
  final double y;

  /// Coordenada Z (0 en dibujos 2D).
  final double z;

  CadPoint3 copyWith({double? x, double? y, double? z}) => CadPoint3(
        x ?? this.x,
        y ?? this.y,
        z ?? this.z,
      );

  @override
  bool operator ==(Object other) =>
      other is CadPoint3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// Vértice de LWPOLYLINE (FORMATS §4): posición + bulge del segmento saliente.
class LwVertex {
  const LwVertex(this.x, this.y, {this.bulge = 0});

  /// Coordenada X.
  final double x;

  /// Coordenada Y.
  final double y;

  /// Bulge del segmento siguiente (`tan(θ/4)`); 0 = segmento recto.
  final double bulge;

  LwVertex copyWith({double? x, double? y, Object? bulge = unset}) =>
      LwVertex(
        x ?? this.x,
        y ?? this.y,
        bulge: identical(bulge, unset) ? this.bulge : bulge as double,
      );

  @override
  bool operator ==(Object other) =>
      other is LwVertex && other.x == x && other.y == y && other.bulge == bulge;

  @override
  int get hashCode => Object.hash(x, y, bulge);

  @override
  String toString() => 'LwVertex($x, $y, b:$bulge)';
}

/// Límite (boundary path) de un HATCH.
class HatchBoundary {
  const HatchBoundary({required this.points, this.closed = true});

  /// Vértices del contorno (ordenados).
  final List<CadPoint3> points;

  /// `true` si el contorno está cerrado.
  final bool closed;

  HatchBoundary copyWith({
    List<CadPoint3>? points,
    bool? closed,
  }) =>
      HatchBoundary(points: points ?? this.points, closed: closed ?? this.closed);

  @override
  bool operator ==(Object other) =>
      other is HatchBoundary &&
      const ListEquality<CadPoint3>().equals(other.points, points) &&
      other.closed == closed;

  @override
  int get hashCode => Object.hash(
        const ListEquality<CadPoint3>().hash(points),
        closed,
      );
}

/// Base de todas las entidades CAD (DATA_MODEL §5.1).
sealed class CadEntity {
  const CadEntity({
    required this.handle,
    required this.layer,
    this.color,
    this.lineType,
    this.lineWeight,
  });

  /// Identificador único (handle DXF o generado).
  final String handle;

  /// Nombre de capa.
  final String layer;

  /// ACI override; `null` = ByLayer (heredar de la capa).
  final int? color;

  /// Tipo de línea override; `null` = heredar.
  final String? lineType;

  /// Grosor override en mm; `null` = heredar.
  final double? lineWeight;

  /// Tipo polimórfico.
  CadEntityType get type;

  /// Copia inmutable con campos modificados.
  ///
  /// Reglas: no proporcionar un parámetro = conservar el valor actual; pasar
  /// `null` explícito = limpiar un campo opcional (color/lineType/lineWeight).
  /// Los parámetros opcionales usan el sentinel `unset` como default interno
  /// para distinguir "no pasado" de "null explícito".
  CadEntity copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
  });
}

/// Segmento de línea (DATA_MODEL §5.2).
class CadLine extends CadEntity {
  const CadLine({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  CadEntityType get type => CadEntityType.line;

  @override
  CadLine copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
  }) =>
      CadLine(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        x1: x1 ?? this.x1,
        y1: y1 ?? this.y1,
        x2: x2 ?? this.x2,
        y2: y2 ?? this.y2,
      );

  @override
  bool operator ==(Object other) =>
      other is CadLine &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;

  @override
  int get hashCode =>
      Object.hash(handle, layer, color, lineType, lineWeight, x1, y1, x2, y2);
}

/// Círculo (DATA_MODEL §5.2).
class CadCircle extends CadEntity {
  const CadCircle({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.cx,
    required this.cy,
    required this.radius,
  });

  final double cx;
  final double cy;
  final double radius;

  @override
  CadEntityType get type => CadEntityType.circle;

  @override
  CadCircle copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    double? cx,
    double? cy,
    double? radius,
  }) =>
      CadCircle(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        radius: radius ?? this.radius,
      );

  @override
  bool operator ==(Object other) =>
      other is CadCircle &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.cx == cx &&
      other.cy == cy &&
      other.radius == radius;

  @override
  int get hashCode =>
      Object.hash(handle, layer, color, lineType, lineWeight, cx, cy, radius);
}

/// Arco (ángulos en radianes).
class CadArc extends CadEntity {
  const CadArc({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
  });

  final double cx;
  final double cy;
  final double radius;
  final double startAngle;
  final double endAngle;

  @override
  CadEntityType get type => CadEntityType.arc;

  @override
  CadArc copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    double? cx,
    double? cy,
    double? radius,
    double? startAngle,
    double? endAngle,
  }) =>
      CadArc(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        radius: radius ?? this.radius,
        startAngle: startAngle ?? this.startAngle,
        endAngle: endAngle ?? this.endAngle,
      );

  @override
  bool operator ==(Object other) =>
      other is CadArc &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.cx == cx &&
      other.cy == cy &&
      other.radius == radius &&
      other.startAngle == startAngle &&
      other.endAngle == endAngle;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        cx,
        cy,
        radius,
        startAngle,
        endAngle,
      );
}

/// Elipse (rotación en radianes; ejes mayor/menor en mm).
class CadEllipse extends CadEntity {
  const CadEllipse({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.cx,
    required this.cy,
    required this.majorRadius,
    required this.minorRadius,
    required this.rotation,
  });

  final double cx;
  final double cy;
  final double majorRadius;
  final double minorRadius;
  final double rotation;

  @override
  CadEntityType get type => CadEntityType.ellipse;

  @override
  CadEllipse copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    double? cx,
    double? cy,
    double? majorRadius,
    double? minorRadius,
    double? rotation,
  }) =>
      CadEllipse(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        majorRadius: majorRadius ?? this.majorRadius,
        minorRadius: minorRadius ?? this.minorRadius,
        rotation: rotation ?? this.rotation,
      );

  @override
  bool operator ==(Object other) =>
      other is CadEllipse &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.cx == cx &&
      other.cy == cy &&
      other.majorRadius == majorRadius &&
      other.minorRadius == minorRadius &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        cx,
        cy,
        majorRadius,
        minorRadius,
        rotation,
      );
}

/// Polilínea ligera (R2000+, LWPOLYLINE).
class CadLwPolyline extends CadEntity {
  const CadLwPolyline({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.points,
    this.closed = false,
  });

  /// Vértices (posición + bulge).
  final List<LwVertex> points;

  /// `true` si la polilínea está cerrada.
  final bool closed;

  @override
  CadEntityType get type => CadEntityType.lwPolyline;

  @override
  CadLwPolyline copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    List<LwVertex>? points,
    bool? closed,
  }) =>
      CadLwPolyline(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        points: points ?? this.points,
        closed: closed ?? this.closed,
      );

  @override
  bool operator ==(Object other) =>
      other is CadLwPolyline &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      const ListEquality<LwVertex>().equals(other.points, points) &&
      other.closed == closed;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        const ListEquality<LwVertex>().hash(points),
        closed,
      );
}

/// Polilínea pesada (R12, POLYLINE + VERTEX/SEQEND).
class CadPolyline extends CadEntity {
  const CadPolyline({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.points,
    this.closed = false,
  });

  /// Vértices 3D.
  final List<CadPoint3> points;

  /// `true` si la polilínea está cerrada.
  final bool closed;

  @override
  CadEntityType get type => CadEntityType.polyline;

  @override
  CadPolyline copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    List<CadPoint3>? points,
    bool? closed,
  }) =>
      CadPolyline(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        points: points ?? this.points,
        closed: closed ?? this.closed,
      );

  @override
  bool operator ==(Object other) =>
      other is CadPolyline &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      const ListEquality<CadPoint3>().equals(other.points, points) &&
      other.closed == closed;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        const ListEquality<CadPoint3>().hash(points),
        closed,
      );
}

/// Texto de una línea (TEXT).
class CadText extends CadEntity {
  const CadText({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.text,
    required this.x,
    required this.y,
    required this.height,
    this.rotation = 0,
    this.style,
    this.horizontalAlign = 0,
  });

  final String text;
  final double x;
  final double y;
  final double height;
  final double rotation;
  final String? style;
  final int horizontalAlign;

  @override
  CadEntityType get type => CadEntityType.text;

  @override
  CadText copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    String? text,
    double? x,
    double? y,
    double? height,
    double? rotation,
    Object? style = unset,
    int? horizontalAlign,
  }) =>
      CadText(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        style: identical(style, unset) ? this.style : style as String?,
        horizontalAlign: horizontalAlign ?? this.horizontalAlign,
      );

  @override
  bool operator ==(Object other) =>
      other is CadText &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.text == text &&
      other.x == x &&
      other.y == y &&
      other.height == height &&
      other.rotation == rotation &&
      other.style == style &&
      other.horizontalAlign == horizontalAlign;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        text,
        x,
        y,
        height,
        rotation,
        style,
        horizontalAlign,
      );
}

/// Texto multilínea (MTEXT).
class CadMText extends CadEntity {
  const CadMText({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.text,
    required this.x,
    required this.y,
    required this.height,
    this.rotation = 0,
    this.attachmentPoint = 1,
    this.width = 0,
  });

  final String text;
  final double x;
  final double y;
  final double height;
  final double rotation;
  final int attachmentPoint;
  final double width;

  @override
  CadEntityType get type => CadEntityType.mtext;

  @override
  CadMText copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    String? text,
    double? x,
    double? y,
    double? height,
    double? rotation,
    int? attachmentPoint,
    double? width,
  }) =>
      CadMText(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        attachmentPoint: attachmentPoint ?? this.attachmentPoint,
        width: width ?? this.width,
      );

  @override
  bool operator ==(Object other) =>
      other is CadMText &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.text == text &&
      other.x == x &&
      other.y == y &&
      other.height == height &&
      other.rotation == rotation &&
      other.attachmentPoint == attachmentPoint &&
      other.width == width;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        text,
        x,
        y,
        height,
        rotation,
        attachmentPoint,
        width,
      );
}

/// Referencia a bloque (INSERT).
class CadInsert extends CadEntity {
  const CadInsert({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.blockName,
    required this.x,
    required this.y,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  final String blockName;
  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double rotation;

  @override
  CadEntityType get type => CadEntityType.insert;

  @override
  CadInsert copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    String? blockName,
    double? x,
    double? y,
    double? scaleX,
    double? scaleY,
    double? rotation,
  }) =>
      CadInsert(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        blockName: blockName ?? this.blockName,
        x: x ?? this.x,
        y: y ?? this.y,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
        rotation: rotation ?? this.rotation,
      );

  @override
  bool operator ==(Object other) =>
      other is CadInsert &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.blockName == blockName &&
      other.x == x &&
      other.y == y &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        blockName,
        x,
        y,
        scaleX,
        scaleY,
        rotation,
      );
}

/// Punto (POINT).
class CadPoint extends CadEntity {
  const CadPoint({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  @override
  CadEntityType get type => CadEntityType.point;

  @override
  CadPoint copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    double? x,
    double? y,
  }) =>
      CadPoint(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  @override
  bool operator ==(Object other) =>
      other is CadPoint &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode =>
      Object.hash(handle, layer, color, lineType, lineWeight, x, y);
}

/// Sombreado (HATCH). Solo lectura en v1.0.
class CadHatch extends CadEntity {
  const CadHatch({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.patternName,
    this.boundaries = const [],
    this.scale = 1,
    this.rotation = 0,
  });

  final String patternName;
  final List<HatchBoundary> boundaries;
  final double scale;
  final double rotation;

  @override
  CadEntityType get type => CadEntityType.hatch;

  @override
  CadHatch copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    String? patternName,
    List<HatchBoundary>? boundaries,
    double? scale,
    double? rotation,
  }) =>
      CadHatch(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        patternName: patternName ?? this.patternName,
        boundaries: boundaries ?? this.boundaries,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  @override
  bool operator ==(Object other) =>
      other is CadHatch &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.patternName == patternName &&
      const ListEquality<HatchBoundary>().equals(other.boundaries, boundaries) &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        patternName,
        const ListEquality<HatchBoundary>().hash(boundaries),
        scale,
        rotation,
      );
}

/// Spline (solo mover en v1.0).
class CadSpline extends CadEntity {
  const CadSpline({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.degree,
    this.controlPoints = const [],
    this.knots = const [],
    this.fitPoints,
  });

  final int degree;
  final List<CadPoint3> controlPoints;
  final List<double> knots;
  final List<CadPoint3>? fitPoints;

  @override
  CadEntityType get type => CadEntityType.spline;

  @override
  CadSpline copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    int? degree,
    List<CadPoint3>? controlPoints,
    List<double>? knots,
    Object? fitPoints = unset,
  }) =>
      CadSpline(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        degree: degree ?? this.degree,
        controlPoints: controlPoints ?? this.controlPoints,
        knots: knots ?? this.knots,
        fitPoints: identical(fitPoints, unset)
            ? this.fitPoints
            : fitPoints as List<CadPoint3>?,
      );

  @override
  bool operator ==(Object other) =>
      other is CadSpline &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.degree == degree &&
      const ListEquality<CadPoint3>().equals(other.controlPoints, controlPoints) &&
      const ListEquality<double>().equals(other.knots, knots) &&
      const ListEquality<CadPoint3>().equals(other.fitPoints, fitPoints);

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        degree,
        const ListEquality<CadPoint3>().hash(controlPoints),
        const ListEquality<double>().hash(knots),
        const ListEquality<CadPoint3>().hash(fitPoints),
      );
}

/// Dimensión (solo mover en v1.0).
///
/// Puntos (grupos DXF): `x1/y1` = punto de definición (10/20), `x2/y2` =
/// punto medio del texto (11/21), `x3/y3` = origen de la línea de extensión 1
/// (13/23) y `x4/y4` = origen de la línea de extensión 2 (14/24). La altura
/// de texto y el tamaño de flecha provienen del estilo de cota (DIMSTYLE,
/// dimtxt=140 / dimasz=41) o se calculan de forma proporcional al renderizar.
class CadDim extends CadEntity {
  const CadDim({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.dimType,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.x3,
    required this.y3,
    this.x4 = 0,
    this.y4 = 0,
    this.text,
    this.style,
    this.textHeight = 0,
    this.arrowSize = 0,
    this.measurement,
  });

  final DimType dimType;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  /// Origen de la línea de extensión 2 (grupos 14/24); 0 si ausente.
  final double x4;
  final double y4;
  final String? text;
  final String? style;

  /// Altura de texto de la cota (dimtxt, DIMSTYLE 140); 0 = automática.
  final double textHeight;

  /// Tamaño de flecha (dimasz, DIMSTYLE 41); 0 = derivada de la altura.
  final double arrowSize;

  /// Medición real (grupo 42); `null` si no está en el archivo.
  final double? measurement;

  @override
  CadEntityType get type => CadEntityType.dim;

  @override
  CadDim copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    DimType? dimType,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    double? x3,
    double? y3,
    double? x4,
    double? y4,
    Object? text = unset,
    Object? style = unset,
    double? textHeight,
    double? arrowSize,
    Object? measurement = unset,
  }) =>
      CadDim(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        dimType: dimType ?? this.dimType,
        x1: x1 ?? this.x1,
        y1: y1 ?? this.y1,
        x2: x2 ?? this.x2,
        y2: y2 ?? this.y2,
        x3: x3 ?? this.x3,
        y3: y3 ?? this.y3,
        x4: x4 ?? this.x4,
        y4: y4 ?? this.y4,
        text: identical(text, unset) ? this.text : text as String?,
        style: identical(style, unset) ? this.style : style as String?,
        textHeight: textHeight ?? this.textHeight,
        arrowSize: arrowSize ?? this.arrowSize,
        measurement: identical(measurement, unset)
            ? this.measurement
            : measurement as double?,
      );

  @override
  bool operator ==(Object other) =>
      other is CadDim &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.dimType == dimType &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2 &&
      other.x3 == x3 &&
      other.y3 == y3 &&
      other.x4 == x4 &&
      other.y4 == y4 &&
      other.text == text &&
      other.style == style &&
      other.textHeight == textHeight &&
      other.arrowSize == arrowSize &&
      other.measurement == measurement;

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        dimType,
        x1,
        y1,
        x2,
        y2,
        x3,
        y3,
        x4,
        y4,
        text,
        style,
        textHeight,
        arrowSize,
        measurement,
      );
}

/// Sólido 2D (SOLID/TRACE): cuadrilátero o triángulo relleno.
///
/// 4 esquinas (grupos 10-13/20-23); si la 3ª y 4ª coinciden es un
/// triángulo. Se renderiza relleno (con el color de la entidad) y se
/// proyecta en 2D ignorando Z.
class CadSolid extends CadEntity {
  const CadSolid({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.corners,
  });

  /// 4 esquinas (z puede diferir; se ignora al proyectar).
  final List<CadPoint3> corners;

  @override
  CadEntityType get type => CadEntityType.solid;

  @override
  CadSolid copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    List<CadPoint3>? corners,
  }) =>
      CadSolid(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        corners: corners ?? this.corners,
      );

  @override
  bool operator ==(Object other) =>
      other is CadSolid &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      const ListEquality<CadPoint3>().equals(other.corners, corners);

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        const ListEquality<CadPoint3>().hash(corners),
      );
}

/// Cara 3D (solo lectura en v1.0; proyección 2D).
class Cad3dFace extends CadEntity {
  const Cad3dFace({
    required super.handle,
    required super.layer,
    super.color,
    super.lineType,
    super.lineWeight,
    required this.corners,
  });

  /// 4 esquinas (z puede diferir).
  final List<CadPoint3> corners;

  @override
  CadEntityType get type => CadEntityType.face3d;

  @override
  Cad3dFace copyWith({
    String? handle,
    String? layer,
    Object? color = unset,
    Object? lineType = unset,
    Object? lineWeight = unset,
    List<CadPoint3>? corners,
  }) =>
      Cad3dFace(
        handle: handle ?? this.handle,
        layer: layer ?? this.layer,
        color: identical(color, unset) ? this.color : color as int?,
        lineType: identical(lineType, unset) ? this.lineType : lineType as String?,
        lineWeight:
            identical(lineWeight, unset) ? this.lineWeight : lineWeight as double?,
        corners: corners ?? this.corners,
      );

  @override
  bool operator ==(Object other) =>
      other is Cad3dFace &&
      other.handle == handle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      const ListEquality<CadPoint3>().equals(other.corners, corners);

  @override
  int get hashCode => Object.hash(
        handle,
        layer,
        color,
        lineType,
        lineWeight,
        const ListEquality<CadPoint3>().hash(corners),
      );
}
