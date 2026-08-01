/// Transformación de coordenadas mundo ↔ canvas (docs/ARCHITECTURE.md §3.6).
///
/// Dart puro: el `CadViewModel` posee `scale` y `offset` (vista), y el
/// painter los aplica. Este módulo convierte puntos, tamaños y rectángulos
/// entre el espacio del mundo (mm) y el del lienzo (píxeles).
library;

import 'dart:math' as math;

import '../models/bounds.dart';

/// Transformación de vista: `screen = world * scale + offset` (X) y
/// `screenY = -worldY * scale + offsetY` (Y **invertida**).
///
/// El mundo CAD tiene el eje Y hacia arriba; la pantalla lo tiene hacia
/// abajo, por eso Y se niega (si no, los dibujos se ven volteados 180°).
///
/// Con [rotate180] se aplica además una **rotación de 180° en el plano**
/// (ambos ejes negados): algunos DXF traen el dibujo en un UCS rotado 180°
/// (o vector de extrusión (0,0,-1)) y sin esto se ven girados en plano.
class CoordinateTransform {
  const CoordinateTransform({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotate180 = false,
  });

  /// Píxeles por unidad de mundo (mm).
  final double scale;

  /// Desplazamiento en X (px).
  final double offsetX;

  /// Desplazamiento en Y (px).
  final double offsetY;

  /// `true` = rotar la vista 180° en el plano (fix de archivos con UCS
  /// rotado). Niega ambos ejes mundo→pantalla.
  final bool rotate180;

  /// Convierte coordenada de mundo → lienzo.
  double worldToScreenX(double wx) =>
      (rotate180 ? -wx : wx) * scale + offsetX;

  /// Convierte coordenada de mundo → lienzo (Y invertida; con [rotate180]
  /// además se niega X, lo que equivale a rotar 180° en el plano).
  double worldToScreenY(double wy) =>
      (rotate180 ? wy : -wy) * scale + offsetY;

  /// Convierte coordenada de lienzo → mundo.
  double screenToWorldX(double sx) => (rotate180 ? offsetX - sx : sx - offsetX) / scale;

  /// Convierte coordenada de lienzo → mundo (Y invertida + rotación).
  double screenToWorldY(double sy) => (rotate180 ? sy - offsetY : offsetY - sy) / scale;

  /// Convierte un tamaño de mundo (mm) a píxeles.
  double worldToScreenSize(double worldSize) => worldSize * scale;

  /// Convierte un tamaño de pantalla (px) a mundo (mm).
  double screenToWorldSize(double screenSize) => screenSize / scale;

  /// `true` si el rectángulo de mundo es visible en el viewport (culling,
  /// margen del 20%, docs/PERFORMANCE.md). Robusto ante rotación/inversión:
  /// toma el min/max real de las esquinas en pantalla.
  bool isVisible(Bounds worldBounds, double viewportWidth, double viewportHeight) {
    if (worldBounds.isEmpty) {
      return false;
    }
    final marginX = viewportWidth * 0.2;
    final marginY = viewportHeight * 0.2;
    final sx0 = worldToScreenX(worldBounds.minX);
    final sx1 = worldToScreenX(worldBounds.maxX);
    final sy0 = worldToScreenY(worldBounds.minY);
    final sy1 = worldToScreenY(worldBounds.maxY);
    final minSx = sx0 < sx1 ? sx0 : sx1;
    final maxSx = sx0 < sx1 ? sx1 : sx0;
    final minSy = sy0 < sy1 ? sy0 : sy1;
    final maxSy = sy0 < sy1 ? sy1 : sy0;
    return maxSx >= -marginX &&
        minSx <= viewportWidth + marginX &&
        maxSy >= -marginY &&
        minSy <= viewportHeight + marginY;
  }

  /// Zoom manteniendo el punto del mundo bajo el cursor (píxeles) fijo.
  /// Robusto ante [rotate180] (usa las inversas reales del transform).
  CoordinateTransform zoomAt(double factor, double screenX, double screenY) {
    final newScale = (scale * factor).clamp(0.0001, 1000000.0);
    final wx = screenToWorldX(screenX);
    final wy = screenToWorldY(screenY);
    final dir = rotate180 ? -1.0 : 1.0;
    return CoordinateTransform(
      scale: newScale,
      offsetX: screenX - wx * newScale * dir,
      offsetY: screenY + wy * newScale * dir,
      rotate180: rotate180,
    );
  }

  /// Matriz de ajuste a pantalla (fit): escala al 80% del viewport y centra
  /// el bounds (RF-RENDER-04). Con [rotate180] centra igual pero con las
  /// fórmulas de offset de la vista rotada.
  static CoordinateTransform fitToScreen(
    Bounds worldBounds,
    double viewportWidth,
    double viewportHeight, {
    double padding = 0.8,
    bool rotate180 = false,
  }) {
    if (worldBounds.isEmpty || viewportWidth <= 0 || viewportHeight <= 0) {
      return CoordinateTransform(rotate180: rotate180);
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
    if (rotate180) {
      // -cx*s + ox = W/2 → ox = W/2 + cx*s ;  cy*s + oy = H/2 → oy = H/2 - cy*s
      return CoordinateTransform(
        scale: s,
        offsetX: viewportWidth / 2 + cx * s,
        offsetY: viewportHeight / 2 - cy * s,
        rotate180: true,
      );
    }
    return CoordinateTransform(
      scale: s,
      offsetX: viewportWidth / 2 - cx * s,
      offsetY: viewportHeight / 2 + cy * s,
    );
  }
}
