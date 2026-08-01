/// Bounding box en 2D (plano XY), Dart puro.
///
/// Sustituye a `dart:ui`/`Rect` en la capa de modelos para mantenerla libre
/// de Flutter (TESTING §1, "Modelo puro Dart"). La UI convierte a `Rect`
/// cuando lo necesita (`Offset`/`Size`).
library;

/// Caja alineada a ejes definida por sus extremos.
class Bounds {
  /// Caja con extremos explícitos. Requiere `minX <= maxX` y `minY <= maxY`
  /// salvo que se use [Bounds.empty].
  const Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  /// Caja vacía: `min` > `max` (ningún punto contenido).
  const Bounds.empty()
      : minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;

  /// Caja de un solo punto.
  const Bounds.point(double x, double y)
      : this(minX: x, minY: y, maxX: x, maxY: y);

  /// Mínimo X.
  final double minX;

  /// Mínimo Y.
  final double minY;

  /// Máximo X.
  final double maxX;

  /// Máximo Y.
  final double maxY;

  /// `true` si la caja no contiene ningún punto.
  bool get isEmpty => minX > maxX || minY > maxY;

  /// Ancho (0 si vacía).
  double get width => isEmpty ? 0 : maxX - minX;

  /// Alto (0 si vacía).
  double get height => isEmpty ? 0 : maxY - minY;

  /// Centro X.
  double get centerX => isEmpty ? 0 : (minX + maxX) / 2;

  /// Centro Y.
  double get centerY => isEmpty ? 0 : (minY + maxY) / 2;

  /// `true` si el punto está dentro (inclusive).
  bool contains(double x, double y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  /// Expande esta caja para incluir un punto y devuelve el resultado.
  Bounds expandToIncludePoint(double x, double y) {
    if (isEmpty) {
      return Bounds.point(x, y);
    }
    return Bounds(
      minX: x < minX ? x : minX,
      minY: y < minY ? y : minY,
      maxX: x > maxX ? x : maxX,
      maxY: y > maxY ? y : maxY,
    );
  }

  /// Expande esta caja para incluir [other] y devuelve el resultado.
  Bounds expandToInclude(Bounds other) {
    if (other.isEmpty) {
      return this;
    }
    if (isEmpty) {
      return other;
    }
    return Bounds(
      minX: other.minX < minX ? other.minX : minX,
      minY: other.minY < minY ? other.minY : minY,
      maxX: other.maxX > maxX ? other.maxX : maxX,
      maxY: other.maxY > maxY ? other.maxY : maxY,
    );
  }

  /// `true` si ambas cajas se superponen (área positiva).
  bool intersects(Bounds other) =>
      !isEmpty &&
      !other.isEmpty &&
      minX <= other.maxX &&
      maxX >= other.minX &&
      minY <= other.maxY &&
      maxY >= other.minY;

  @override
  bool operator ==(Object other) =>
      other is Bounds &&
      other.minX == minX &&
      other.minY == minY &&
      other.maxX == maxX &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() =>
      isEmpty ? 'Bounds(empty)' : 'Bounds($minX, $minY, $maxX, $maxY)';
}
