/// Resolución de color de entidades (docs/ARCHITECTURE.md §3.3).
///
/// Jerarquía: override de entidad (color ACI) → displayColor de capa →
/// color ACI de capa → blanco por defecto. El resultado se devuelve como
/// ARGB; el painter lo combina con el tema (aci_colors + override por tema).
library;

import 'dart:ui' show Color;

import '../models/cad_entity.dart';
import '../models/cad_file.dart';
import '../models/cad_layer.dart';
import '../utils/aci_colors.dart';

/// Resuelve el color de una entidad según capa y overrides.
///
/// Devuelve un [Color]. [defaultAci] permite que el tema adapte el ACI 7
/// (blanco → oscuro en tema claro, etc.).
class LayerManager {
  const LayerManager(this.file);

  /// Archivo del que se resuelven las capas.
  final CadFile file;

  /// Color efectivo de la entidad (ARGB).
  Color entityColor(CadEntity entity) {
    final layer = file.layerByName(entity.layer);
    // 1. Override de la entidad.
    if (entity.color != null) {
      return _argb(aciToArgb(entity.color!));
    }
    // 2. displayColor de capa (override de visualización, RF-CAPA-04).
    if (layer?.displayColor != null) {
      return Color(layer!.displayColor!);
    }
    // 3. ACI de la capa.
    if (layer != null) {
      return _argb(aciToArgb(layer.color));
    }
    // 4. Capa inexistente → blanco (caso de borde #2 de REQUIREMENTS).
    return const Color(0xFFFFFFFF);
  }

  /// Color de la capa (para el panel de capas).
  Color layerColor(CadLayer layer) {
    if (layer.displayColor != null) {
      return Color(layer.displayColor!);
    }
    return _argb(aciToArgb(layer.color));
  }

  Color _argb(int value) => Color(value);
}
