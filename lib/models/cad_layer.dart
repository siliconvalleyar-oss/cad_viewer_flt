/// Capa del dibujo (docs/DATA_MODEL.md §4).
///
/// Dart puro: `displayColor` se almacena como `int?` ARGB (0xAARRGGBB) para no
/// depender de Flutter; la UI lo convierte con `Color(displayColor)`. Los
/// flags `visible/locked/frozen/isCurrent` son estado de sesión y no se
/// escriben al DXF (DATA_MODEL §11.5).
library;

/// Definición de capa.
class CadLayer {
  const CadLayer({
    required this.name,
    this.color = 7,
    this.lineType = 'Continuous',
    this.lineWeight,
    this.visible = true,
    this.locked = false,
    this.frozen = false,
    this.displayColor,
    this.isCurrent = false,
  });

  /// Nombre de capa (único).
  final String name;

  /// Índice ACI (1–255); 7 = blanco.
  final int color;

  /// Tipo de línea (`Continuous`, `DASHED`…).
  final String lineType;

  /// Grosor en mm (override).
  final double? lineWeight;

  /// Visible en pantalla.
  final bool visible;

  /// Bloqueada (visible pero no editable/seleccionable).
  final bool locked;

  /// Congelada (no se renderiza ni edita; prevalece sobre `visible`).
  final bool frozen;

  /// Override de color de visualización ARGB (no afecta al archivo).
  final int? displayColor;

  /// Es la capa activa (entidades nuevas).
  final bool isCurrent;

  /// `true` si la capa se renderiza: `frozen` prevalece sobre `visible`.
  bool get isRenderable => visible && !frozen;

  CadLayer copyWith({
    String? name,
    int? color,
    String? lineType,
    Object? lineWeight = unset,
    bool? visible,
    bool? locked,
    bool? frozen,
    Object? displayColor = unset,
    bool? isCurrent,
  }) =>
      CadLayer(
        name: name ?? this.name,
        color: color ?? this.color,
        lineType: lineType ?? this.lineType,
        lineWeight: identical(lineWeight, unset)
            ? this.lineWeight
            : lineWeight as double?,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        frozen: frozen ?? this.frozen,
        displayColor: identical(displayColor, unset)
            ? this.displayColor
            : displayColor as int?,
        isCurrent: isCurrent ?? this.isCurrent,
      );

  @override
  bool operator ==(Object other) =>
      other is CadLayer &&
      other.name == name &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.visible == visible &&
      other.locked == locked &&
      other.frozen == frozen &&
      other.displayColor == displayColor &&
      other.isCurrent == isCurrent;

  @override
  int get hashCode => Object.hash(
        name,
        color,
        lineType,
        lineWeight,
        visible,
        locked,
        frozen,
        displayColor,
        isCurrent,
      );

  @override
  String toString() =>
      'CadLayer($name, ACI:$color, visible:$visible, locked:$locked, frozen:$frozen)';
}

const Object unset = Object();
