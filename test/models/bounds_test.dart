import 'package:cad_viewer/models/bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bounds', () {
    test('empty y expandToIncludePoint', () {
      var b = const Bounds.empty();
      expect(b.isEmpty, isTrue);
      b = b.expandToIncludePoint(1, 2);
      expect(b.minX, 1);
      expect(b.maxY, 2);
    });
  });

  group('robustUnion (descarta outliers flotantes)', () {
    test('sin outliers: unión normal', () {
      final boxes = [
        Bounds(minX: 0, minY: 0, maxX: 10, maxY: 10),
        Bounds(minX: 5, minY: 5, maxX: 20, maxY: 20),
        Bounds(minX: -5, minY: -5, maxX: 8, maxY: 8),
      ];
      final r = robustUnion(boxes);
      expect(r.minX, -5);
      expect(r.maxX, 20);
      expect(r.minY, -5);
      expect(r.maxY, 20);
    });

    test('descarta una entidad flotante muy lejana', () {
      final boxes = [
        Bounds(minX: 0, minY: 0, maxX: 100, maxY: 100),
        Bounds(minX: 10, minY: 10, maxX: 90, maxY: 90),
        Bounds(minX: 20, minY: 20, maxX: 80, maxY: 80),
        Bounds(minX: 1e9, minY: 1e9, maxX: 1e9 + 1, maxY: 1e9 + 1),
      ];
      final r = robustUnion(boxes);
      // La unión robusta ignora el punto en 1e9.
      expect(r.maxX, lessThan(1000));
      expect(r.maxY, lessThan(1000));
      expect(r.contains(50, 50), isTrue);
    });

    test('descarta una entidad gigante (círculo/texto descomunal)', () {
      final boxes = [
        Bounds(minX: 0, minY: 0, maxX: 100, maxY: 100),
        Bounds(minX: 10, minY: 10, maxX: 90, maxY: 90),
        Bounds(minX: 20, minY: 20, maxX: 80, maxY: 80),
        Bounds(minX: -1e6, minY: -1e6, maxX: 1e6, maxY: 1e6),
      ];
      final r = robustUnion(boxes);
      expect(r.maxX, lessThan(1000));
      expect(r.maxY, lessThan(1000));
    });

    test('archivo con 1-2 entidades: usa la unión completa', () {
      final boxes = [
        Bounds(minX: 0, minY: 0, maxX: 5, maxY: 5),
        Bounds(minX: 1000, minY: 1000, maxX: 1001, maxY: 1001),
      ];
      final r = robustUnion(boxes);
      expect(r.maxX, 1001);
      expect(r.minX, 0);
    });

    test('lista vacía → Bounds.empty', () {
      expect(robustUnion(const []).isEmpty, isTrue);
    });
  });
}
