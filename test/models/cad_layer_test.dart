import 'package:cad_viewer/models/cad_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CadLayer', () {
    const layer = CadLayer(name: 'WALLS', color: 1);

    test('defaults', () {
      expect(layer.color, 1);
      expect(layer.lineType, 'Continuous');
      expect(layer.visible, isTrue);
      expect(layer.locked, isFalse);
      expect(layer.frozen, isFalse);
      expect(layer.isCurrent, isFalse);
      expect(layer.displayColor, isNull);
    });

    test('frozen prevalece sobre visible (isRenderable)', () {
      const frozen = CadLayer(name: 'F', frozen: true);
      const hidden = CadLayer(name: 'H', visible: false);
      const normal = CadLayer(name: 'N');
      expect(frozen.isRenderable, isFalse);
      expect(hidden.isRenderable, isFalse);
      expect(normal.isRenderable, isTrue);
    });

    test('locked es visible pero no editable', () {
      const locked = CadLayer(name: 'L', locked: true);
      expect(locked.isRenderable, isTrue);
      expect(locked.locked, isTrue);
    });

    test('copyWith', () {
      final updated = layer.copyWith(visible: false, color: 3);
      expect(updated.visible, isFalse);
      expect(updated.color, 3);
      expect(updated.name, 'WALLS');
      expect(updated.lineType, 'Continuous');
    });

    test('copyWith permite limpiar displayColor', () {
      const colored = CadLayer(name: 'X', displayColor: 0xFF00FF00);
      final cleared = colored.copyWith(displayColor: null);
      expect(cleared.displayColor, isNull);
      // No pasar el parámetro conserva el valor.
      expect(colored.copyWith().displayColor, 0xFF00FF00);
    });

    test('igualdad por valor', () {
      const same = CadLayer(name: 'WALLS', color: 1);
      expect(layer, same);
      expect(layer.hashCode, same.hashCode);
      expect(layer.copyWith(color: 2), isNot(layer));
    });
  });
}
