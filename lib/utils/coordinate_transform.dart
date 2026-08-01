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
///
/// Con [flipX] / [flipY] se aplica un **espejo** de la vista (horizontal /
/// vertical): algunos archivos vienen espejados (no solo rotados) y sin
/// esto se ven reflejados. Los tres flags se combinan con XOR: un giro 180°
/// es un espejo doble, y espejo(X) + giro = espejo(Y).
class CoordinateTransform {
  const CoordinateTransform({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotate180 = false,
    this.flipX = false,
    this.flipY = false,
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

  /// `true` = espejo horizontal de la vista (niega X; fix de archivos
  /// espejados). Combinado con [rotate180] equivale a [flipY].
  final bool flipX;

  /// `true` = espejo vertical de la vista (no invierte Y; fix de archivos
  /// espejados). Combinado con [rotate180] equivale a [flipX].
  final bool flipY;

  /// Signo efectivo del eje X mundo→pantalla (+1 normal, -1 giro/espejo).
  double get signX => (rotate180 ^ flipX) ? -1.0 : 1.0;

  /// Signo efectivo del eje Y mundo→pantalla (-1 invertida, +1 giro/espejo).
  double get signY => (rotate180 ^ flipY) ? 1.0 : -1.0;

  /// Convierte coordenada de mundo → lienzo.
  double worldToScreenX(double wx) => signX * wx * scale + offsetX;

  /// Convierte coordenada de mundo → lienzo (Y invertida; con [rotate180]
  /// y/o [flipY] el signo efectivo cambia).
  double worldToScreenY(double wy) => signY * wy * scale + offsetY;

  /// Convierte coordenada de lienzo → mundo.
  double screenToWorldX(double sx) => (sx - offsetX) / scale * signX;

  /// Convierte coordenada de lienzo → mundo (Y invertida + rotación).
  double screenToWorldY(double sy) => (sy - offsetY) / scale * signY;

  /// Convierte un tamaño de mundo (mm) a píxeles.
  double worldToScreenSize(double worldSize) => worldSize * scale;

  /// Convierte un tamaño de pantalla (px) a mundo (mm).
  double screenToWorldSize(double screenSize) => screenSize / scale;

  /// Mapea un **ángulo de mundo** (radianes) a su ángulo en pantalla bajo la
  /// vista actual. Base: -θ (Y invertida). Giro 180°: -θ+π. Espejo X: θ+π.
  /// Espejo Y: θ. Los espejos REFLEJAN el ángulo (no suman π como el giro).
  double screenAngle(double worldAngle) =>
      signX * signY * worldAngle + (signX < 0 ? math.pi : 0);

  /// Signo aplicado al **barrido** (sweep) de arcos/elipses: +1 conserva el
  /// sentido, -1 lo invierte (depende de la orientación efectiva de la
  /// vista, signX*signY).
  double get sweepSign => signX * signY;

  /// Mapea un **vector de dirección** (dx, dy) en mundo a su ángulo en
  /// pantalla (para flechas de cota, orientaciones, etc.).
  double screenVectorAngle(double dx, double dy) =>
      math.atan2(signY * dy, signX * dx);

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
  /// Robusto ante [rotate180]/[flipX]/[flipY] (usa las inversas reales).
  CoordinateTransform zoomAt(double factor, double screenX, double screenY) {
    final newScale = (scale * factor).clamp(0.0001, 1000000.0);
    final wx = screenToWorldX(screenX);
    final wy = screenToWorldY(screenY);
    return CoordinateTransform(
      scale: newScale,
      offsetX: screenX - signX * wx * newScale,
      offsetY: screenY - signY * wy * newScale,
      rotate180: rotate180,
      flipX: flipX,
      flipY: flipY,
    );
  }

  /// Matriz de ajuste a pantalla (fit): escala al 80% del viewport y centra
  /// el bounds (RF-RENDER-04). Con [rotate180]/[flipX]/[flipY] centra igual
  /// pero con las fórmulas de offset de la vista transformada.
  static CoordinateTransform fitToScreen(
    Bounds worldBounds,
    double viewportWidth,
    double viewportHeight, {
    double padding = 0.8,
    bool rotate180 = false,
    bool flipX = false,
    bool flipY = false,
  }) {
    if (worldBounds.isEmpty || viewportWidth <= 0 || viewportHeight <= 0) {
      return CoordinateTransform(
        rotate180: rotate180,
        flipX: flipX,
        flipY: flipY,
      );
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
    final sx = (rotate180 ^ flipX) ? -1.0 : 1.0;
    final sy = (rotate180 ^ flipY) ? 1.0 : -1.0;
    // signX*cx*s + ox = W/2 → ox = W/2 - signX*cx*s
    return CoordinateTransform(
      scale: s,
      offsetX: viewportWidth / 2 - sx * cx * s,
      offsetY: viewportHeight / 2 - sy * cy * s,
      rotate180: rotate180,
      flipX: flipX,
      flipY: flipY,
    );
  }
}
