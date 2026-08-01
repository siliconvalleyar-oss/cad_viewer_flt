/// Bounding box en 2D (plano XY), Dart puro.
///
/// Sustituye a `dart:ui`/`Rect` en la capa de modelos para mantenerla libre
/// de Flutter (TESTING §1, "Modelo puro Dart"). La UI convierte a `Rect`
/// cuando lo necesita (`Offset`/`Size`).
library;

import 'dart:math' as math;

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

/// Unión robusta de cajas: descarta **outliers** para el fit-to-screen.
///
/// Problema: un dibujo real puede contener entidades "flotantes" (un punto
/// con coordenadas enormes, un texto/cota gigante fuera de escala) que, si
/// se incluyen en el bounds, aplastan el resto del plano (se ve diminuto y
/// desproporcionado). Esta función calcula la caja central (mediana del
/// centro y del tamaño de cada entidad) y descarta las entidades cuya
/// distancia o tamaño excedan un factor de la mediana.
///
/// Devuelve [Bounds.empty] si no hay cajas.
Bounds robustUnion(List<Bounds> boxes) {
  final valid = boxes.where((b) => !b.isEmpty).toList();
  if (valid.isEmpty) {
    return const Bounds.empty();
  }
  if (valid.length <= 2) {
    var u = const Bounds.empty();
    for (final b in valid) {
      u = u.expandToInclude(b);
    }
    return u;
  }

  // Centro mediano (x e y por separado).
  final xs = valid.map((b) => b.centerX).toList()..sort();
  final ys = valid.map((b) => b.centerY).toList()..sort();
  final cx = xs[xs.length ~/ 2];
  final cy = ys[ys.length ~/ 2];

  // Distancia de cada caja al centro mediano.
  final dists = valid
      .map((b) => math.sqrt(math.pow(b.centerX - cx, 2) + math.pow(b.centerY - cy, 2)))
      .toList()
    ..sort();
  final medianDist = dists[dists.length ~/ 2];

  // Tamaño mediano (diagonal).
  final sizes = valid
      .map((b) => math.sqrt(math.pow(b.width, 2) + math.pow(b.height, 2)))
      .toList()
    ..sort();
  final medianSize = sizes[sizes.length ~/ 2];

  // Distancia: rechaza "flotantes" lejanos (factor generoso de la mediana).
  // Piso con medianSize*10: si muchas entidades coinciden (medianDist ≈ 0),
  // no rechazar entidades legítimas ligeramente separadas del núcleo.
  final distLimit = math.max(math.max(medianDist * 100, medianSize * 10), 1e-9);
  // Tamaño: solo rechaza entidades ABSURDAMENTE grandes (1000× la mediana),
  // para no cortar elementos legítimos grandes (p. ej. un marco de plano).
  final sizeLimit = math.max(medianSize * 1000, 1e-9);

  // Acepta entidades cercanas al núcleo Y de tamaño razonable.
  var result = const Bounds.empty();
  for (var i = 0; i < valid.length; i++) {
    final b = valid[i];
    final d = math.sqrt(math.pow(b.centerX - cx, 2) + math.pow(b.centerY - cy, 2));
    final s = math.sqrt(math.pow(b.width, 2) + math.pow(b.height, 2));
    if (d <= distLimit && s <= sizeLimit) {
      result = result.expandToInclude(b);
    }
  }
  if (result.isEmpty) {
    // Todos eran outliers (caso degenerado): usa todo.
    for (final b in valid) {
      result = result.expandToInclude(b);
    }
  }
  return result;
}
