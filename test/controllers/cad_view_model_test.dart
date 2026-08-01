import 'package:cad_viewer/controllers/cad_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('preferencias de cotas y texto (CadViewModel)', () {
    test('se persisten y restauran', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);

      vm.setDimTextScale(2.5);
      vm.setDimArrowScale(1.5);
      vm.setDimFontFamily('monospace');
      // Deja terminar la escritura asíncrona.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('dimTextScale'), 2.5);
      expect(prefs.getDouble('dimArrowScale'), 1.5);
      expect(prefs.getString('dimFontFamily'), 'monospace');

      // Nueva instancia restaura los valores.
      final vm2 = CadViewModel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm2.dimTextScale, 2.5);
      expect(vm2.dimArrowScale, 1.5);
      expect(vm2.dimFontFamily, 'monospace');
    });

    test('defaults sin preferencias guardadas', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.dimTextScale, 1.0);
      expect(vm.dimArrowScale, 1.0);
      expect(vm.dimFontFamily, '');
    });

    test('la escala se clampa a [0.2, 5.0]', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);

      vm.setDimTextScale(50);
      expect(vm.dimTextScale, 5.0);
      vm.setDimTextScale(0.01);
      expect(vm.dimTextScale, 0.2);
      vm.setDimArrowScale(-3);
      expect(vm.dimArrowScale, 0.2);
    });

    test('setter de fuente acepta vacío (predeterminada)', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.setDimFontFamily('serif');
      expect(vm.dimFontFamily, 'serif');
      vm.setDimFontFamily('');
      expect(vm.dimFontFamily, '');
    });
  });

  group('giro de vista 180° (rotateView)', () {
    test('toggle mantiene el punto del mundo en el centro del viewport',
        () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.scale = 2;
      vm.offsetX = 100;
      vm.offsetY = 50;

      final wx0 = vm.transform.screenToWorldX(200);
      final wy0 = vm.transform.screenToWorldY(150);

      await vm.toggleRotateView(400, 300);
      expect(vm.rotateView, isTrue);
      expect(vm.transform.rotate180, isTrue);
      // El punto que estaba en el centro (200,150) sigue en el centro.
      expect(vm.transform.worldToScreenX(wx0), closeTo(200, 1e-6));
      expect(vm.transform.worldToScreenY(wy0), closeTo(150, 1e-6));

      // Segundo toggle: vuelve a la orientación original.
      await vm.toggleRotateView(400, 300);
      expect(vm.rotateView, isFalse);
      expect(vm.transform.rotate180, isFalse);
      expect(vm.transform.worldToScreenX(wx0), closeTo(200, 1e-6));
      expect(vm.transform.worldToScreenY(wy0), closeTo(150, 1e-6));
    });

    test('se persiste por archivo y se restaura al cargar', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.currentPath = '/tmp/plano.dxf';
      await vm.toggleRotateView(400, 300);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('rotatedFiles'), contains('/tmp/plano.dxf'));

      // Desactivar para este archivo la quita de la lista.
      await vm.toggleRotateView(400, 300);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prefs.getStringList('rotatedFiles'), isNot(contains('/tmp/plano.dxf')));
    });
  });

  group('espejo de vista (flipXView/flipYView)', () {
    test('toggleFlipXView mantiene el punto del mundo en el centro del viewport',
        () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.scale = 2;
      vm.offsetX = 100;
      vm.offsetY = 50;

      final wx0 = vm.transform.screenToWorldX(200);
      final wy0 = vm.transform.screenToWorldY(150);

      await vm.toggleFlipXView(400, 300);
      expect(vm.flipXView, isTrue);
      expect(vm.transform.flipX, isTrue);
      // El punto que estaba en el centro (200,150) sigue en el centro.
      expect(vm.transform.worldToScreenX(wx0), closeTo(200, 1e-6));
      expect(vm.transform.worldToScreenY(wy0), closeTo(150, 1e-6));

      // Segundo toggle: vuelve a la orientación original.
      await vm.toggleFlipXView(400, 300);
      expect(vm.flipXView, isFalse);
      expect(vm.transform.worldToScreenX(wx0), closeTo(200, 1e-6));
      expect(vm.transform.worldToScreenY(wy0), closeTo(150, 1e-6));
    });

    test('toggleFlipYView mantiene el centro y no altera flipXView', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.scale = 3;
      vm.offsetX = 90;
      vm.offsetY = 40;

      final wx0 = vm.transform.screenToWorldX(200);
      final wy0 = vm.transform.screenToWorldY(150);

      await vm.toggleFlipYView(400, 300);
      expect(vm.flipYView, isTrue);
      expect(vm.flipXView, isFalse);
      expect(vm.transform.worldToScreenX(wx0), closeTo(200, 1e-6));
      expect(vm.transform.worldToScreenY(wy0), closeTo(150, 1e-6));
    });

    test('se persisten por archivo y se restauran al cargar', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = CadViewModel();
      await Future<void>.delayed(Duration.zero);
      vm.currentPath = '/tmp/espejo.dxf';
      await vm.toggleFlipXView(400, 300);
      await vm.toggleFlipYView(400, 300);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('flippedXFiles'), contains('/tmp/espejo.dxf'));
      expect(prefs.getStringList('flippedYFiles'), contains('/tmp/espejo.dxf'));

      // Desactivar para este archivo los quita de las listas.
      await vm.toggleFlipXView(400, 300);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prefs.getStringList('flippedXFiles'), isNot(contains('/tmp/espejo.dxf')));
      expect(prefs.getStringList('flippedYFiles'), contains('/tmp/espejo.dxf'));
    });
  });
}
