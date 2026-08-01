import 'package:cad_viewer/utils/line_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLineTypePattern', () {
    const filePatterns = <String, List<double>>{
      'DASHED': [0.5, -0.25],
      'MY_CUSTOM': [2.0, -1.0],
    };

    test('exacto de la tabla del archivo gana', () {
      expect(resolveLineTypePattern('DASHED', filePatterns), [0.5, -0.25]);
      expect(resolveLineTypePattern('MY_CUSTOM', filePatterns), [2.0, -1.0]);
    });

    test('insensible a mayúsculas en la tabla del archivo', () {
      expect(resolveLineTypePattern('my_custom', filePatterns), [2.0, -1.0]);
      expect(resolveLineTypePattern('Dashed', filePatterns), [0.5, -0.25]);
    });

    test('fallback estándar AutoCAD incluye variantes escaladas', () {
      // La queja del usuario: DASHED2 (media escala) no se renderizaba.
      expect(resolveLineTypePattern('DASHED2', const {}), [0.375, -0.1875]);
      expect(resolveLineTypePattern('DASHEDX2', const {}), [1.0, -0.5]);
      expect(resolveLineTypePattern('HIDDEN2', const {}), [0.1875, -0.09375]);
      expect(resolveLineTypePattern('CENTERX2', const {}), [2.5, -0.5, 0.5, -0.5]);
      expect(resolveLineTypePattern('DASHDOT2', const {}), [0.375, -0.1875, 0.0, -0.1875]);
      expect(resolveLineTypePattern('ACAD_ISO02W100', const {}), [0.5, -0.25]);
    });

    test('fallback estándar insensible a mayúsculas', () {
      expect(resolveLineTypePattern('dashed2', const {}), [0.375, -0.1875]);
    });

    test('desconocido y vacío → null', () {
      expect(resolveLineTypePattern('NO_EXISTE', filePatterns), isNull);
      expect(resolveLineTypePattern('', filePatterns), isNull);
      expect(resolveLineTypePattern('   ', filePatterns), isNull);
    });
  });
}
