/// Resolución de color de entidades (docs/ARCHITECTURE.md §3.3).
///
/// Jerarquía: override de entidad (color ACI) → displayColor de capa →
/// color ACI de capa → blanco por defecto. El resultado se devuelve como
/// ARGB; el painter lo combina con el tema (aci_colors + override por tema).
///
/// Con [canvasBackground] (ARGB del lienzo) se aplica además una adaptación
/// de contraste WCAG: el ACI 7 (blanco) y colores claros se oscurecen sobre
/// fondos claros (tema "Claro"), y colores muy oscuros se aclaran sobre
/// fondos oscuros. Sin esto, las capas blancas desaparecen sobre el lienzo
/// blanco del tema claro (bug reportado: se veían las cotas pero no los
/// vectores).
library;

import 'dart:ui' show Color;

import '../models/cad_entity.dart';
import '../models/cad_file.dart';
import '../models/cad_layer.dart';
import '../utils/aci_colors.dart';

/// Resuelve el color de una entidad según capa y overrides.
class LayerManager {
  const LayerManager(this.file, {this.canvasBackground});

  /// Archivo del que se resuelven las capas.
  final CadFile file;

  /// ARGB del color del lienzo (fondo del canvas). `null` = sin adaptación.
  final int? canvasBackground;

  /// Color efectivo de la entidad (ARGB), adaptado al fondo si se conoce.
  Color entityColor(CadEntity entity) {
    final layer = file.layerByName(entity.layer);
    // 1. Override de la entidad.
    if (entity.color != null) {
      return _adapted(aciToArgb(entity.color!));
    }
    // 2. displayColor de capa (override de visualización, RF-CAPA-04).
    if (layer?.displayColor != null) {
      return _adapted(layer!.displayColor!);
    }
    // 3. ACI de la capa.
    if (layer != null) {
      return _adapted(aciToArgb(layer.color));
    }
    // 4. Capa inexistente → blanco (caso de borde #2 de REQUIREMENTS).
    return _adapted(0xFFFFFFFF);
  }

  /// Color de la capa (para el panel de capas).
  Color layerColor(CadLayer layer) {
    if (layer.displayColor != null) {
      return _adapted(layer.displayColor!);
    }
    return _adapted(aciToArgb(layer.color));
  }

  /// Aplica la adaptación de contraste si hay fondo conocido.
  Color _adapted(int argb) {
    final bg = canvasBackground;
    if (bg == null) {
      return Color(argb);
    }
    return Color(ensureContrast(argb, bg));
  }
}
