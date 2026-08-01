/// Transformación de coordenadas mundo ↔ canvas (docs/ARCHITECTURE.md §3.6).
///
/// Dart puro: el `CadViewModel` posee `scale` y `offset` (vista), y el
/// painter los aplica. Este módulo convierte puntos, tamaños y rectángulos
/// entre el espacio del mundo (mm) y el del lienzo (píxeles).
library;

import 'dart:math' as math;

import '../models/bounds.dart';

/// Transformación de vista: `screen = world * scale + offset`.
class CoordinateTransform {
  const CoordinateTransform({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  /// Píxeles por unidad de mundo (mm).
  final double scale;

  /// Desplazamiento en X (px).
  final double offsetX;

  /// Desplazamiento en Y (px).
  final double offsetY;

  /// Convierte coordenada de mundo → lienzo.
  double worldToScreenX(double wx) => wx * scale + offsetX;

  /// Convierte coordenada de mundo → lienzo.
  double worldToScreenY(double wy) => wy * scale + offsetY;

  /// Convierte coordenada de lienzo → mundo.
  double screenToWorldX(double sx) => (sx - offsetX) / scale;

  /// Convierte coordenada de lienzo → mundo.
  double screenToWorldY(double sy) => (sy - offsetY) / scale;

  /// Convierte un tamaño de mundo (mm) a píxeles.
  double worldToScreenSize(double worldSize) => worldSize * scale;

  /// Convierte un tamaño de pantalla (px) a mundo (mm).
  double screenToWorldSize(double screenSize) => screenSize / scale;

  /// `true` si el rectángulo de mundo es visible en el viewport (culling,
  /// margen del 20%, docs/PERFORMANCE.md).
  bool isVisible(Bounds worldBounds, double viewportWidth, double viewportHeight) {
    if (worldBounds.isEmpty) {
      return false;
    }
    final marginX = viewportWidth * 0.2;
    final marginY = viewportHeight * 0.2;
    final minSx = worldToScreenX(worldBounds.minX);
    final maxSx = worldToScreenX(worldBounds.maxX);
    final minSy = worldToScreenY(worldBounds.minY);
    final maxSy = worldToScreenY(worldBounds.maxY);
    return maxSx >= -marginX &&
        minSx <= viewportWidth + marginX &&
        maxSy >= -marginY &&
        minSy <= viewportHeight + marginY;
  }

  /// Matriz de ajuste a pantalla (fit): escala al 80% del viewport y centra
  /// el bounds (RF-RENDER-04).
  static CoordinateTransform fitToScreen(
    Bounds worldBounds,
    double viewportWidth,
    double viewportHeight, {
    double padding = 0.8,
  }) {
    if (worldBounds.isEmpty || viewportWidth <= 0 || viewportHeight <= 0) {
      return const CoordinateTransform();
    }
    final boundsW = worldBounds.width <= 0 ? 1.0 : worldBounds.width;
    final boundsH = worldBounds.height <= 0 ? 1.0 : worldBounds.height;
    final s = math.min(
          viewportWidth / boundsW,
          viewportHeight / boundsH,
        ) *
        padding;
    final cx = worldBounds.centerX;
    final cy = worldBounds.centerY;
    return CoordinateTransform(
      scale: s,
      offsetX: viewportWidth / 2 - cx * s,
      offsetY: viewportHeight / 2 - cy * s,
    );
  }
}
