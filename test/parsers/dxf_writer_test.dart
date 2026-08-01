import 'package:cad_viewer/models/cad_enums.dart';
import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_file.dart';
import 'package:cad_viewer/parsers/dxf_parser.dart';
import 'package:cad_viewer/parsers/dxf_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const writer = DxfWriter();

  CadFile fileWith(List<CadEntity> entities) =>
      CadFile(fileName: 't.dxf', version: 'AC1015', entities: entities);

  group('DIMENSION (BUG-20: preservar estilo y tipo raw)', () {
    test('escribe el estilo (code 3) y el código raw 70 (32) en lugar de 0', () {
      const dim = CadDim(
        handle: 'D1',
        layer: '0',
        dimType: DimType.aligned,
        dimTypeRawCode: 32,
        style: 'TOTO-COTAS',
        x1: 0, y1: 0, x2: 5, y2: 0, x3: 0, y3: 0, x4: 10, y4: 0,
        textHeight: 2.5,
        arrowSize: 2.5,
        measurement: 10,
      );
      final result = writer.write(fileWith(const [dim]));
      expect(result.error, isNull);
      final content = result.content!;
      // Estilo (code 3) presente.
      expect(content, contains('\n  3\nTOTO-COTAS\n'));
      // Tipo raw 32 (alineada + bit 0x20) en vez de 0.
      expect(content, contains('\n 70\n32\n'));
      // El bloque *D1 se conserva (referencia de la cota).
      expect(content, contains('*D1'));
    });

    test('sin dimTypeRawCode: escribe el dxfCode del enum', () {
      const dim = CadDim(
        handle: 'D1',
        layer: '0',
        dimType: DimType.aligned,
        x1: 0, y1: 0, x2: 5, y2: 0, x3: 0, y3: 0, x4: 10, y4: 0,
      );
      final result = writer.write(fileWith(const [dim]));
      expect(result.error, isNull);
      expect(result.content!, contains('\n 70\n1\n'));
    });
  });

  group('DIMSTYLE y header de cota (BUG-23: fuentes desproporcionadas)', () {
    test('escribe la tabla DIMSTYLE con dimtxt/dimasz de las cotas', () {
      const dim = CadDim(
        handle: 'D1',
        layer: '0',
        dimType: DimType.aligned,
        style: 'TOTO-COTAS',
        x1: 0, y1: 0, x2: 5, y2: 0, x3: 0, y3: 0, x4: 10, y4: 0,
        textHeight: 2.5,
        arrowSize: 2.5,
      );
      final result = writer.write(fileWith(const [dim]));
      expect(result.error, isNull);
      final content = result.content!;
      expect(content, contains('DIMSTYLE'));
      expect(content, contains('AcDbDimStyleTableRecord'));
      expect(content, contains('TOTO-COTAS'));
      // dimtxt (140) y dimasz (41) del estilo. _formatDouble usa 8
      // decimales para no enteros: 2.5 → '2.50000000'.
      expect(content, contains('\n140\n2.50000000\n'));
      expect(content, contains('\n 41\n2.50000000\n'));
      // DIMSCALE del registro DIMSTYLE es el grupo 40 a secas (no
      // 9/$DIMSCALE). El registro termina en 77 (DIMTAD) tras el 140.
      expect(content, contains('\n 40\n1\n'));
      expect(content, contains('\n 77\n1\n'));
    });

    test(r'escribe $DIMTXT/$DIMASZ en el header', () {
      const dim = CadDim(
        handle: 'D1',
        layer: '0',
        dimType: DimType.aligned,
        x1: 0, y1: 0, x2: 5, y2: 0, x3: 0, y3: 0, x4: 10, y4: 0,
        textHeight: 1.5,
        arrowSize: 1.0,
      );
      final result = writer.write(fileWith(const [dim]));
      expect(result.error, isNull);
      final content = result.content!;
      expect(content, contains(r'$DIMTXT'));
      expect(content, contains('\n 40\n1.50000000\n'));
      expect(content, contains(r'$DIMASZ'));
      expect(content, contains('\n 40\n1\n'));
    });

    test('roundtrip: el texto de cota conserva su altura', () {
      const dim = CadDim(
        handle: 'D1',
        layer: '0',
        dimType: DimType.aligned,
        dimTypeRawCode: 32,
        style: 'TOTO-COTAS',
        x1: 0, y1: 0, x2: 5, y2: 0, x3: 0, y3: 0, x4: 10, y4: 0,
        textHeight: 2.5,
        arrowSize: 2.5,
      );
      final result = writer.write(fileWith(const [dim]));
      expect(result.error, isNull);
      final rt = DxfParserWrapper().parse(result.content!);
      expect(rt.error, isNull);
      final rtDim = rt.cadFile!.entities.single as CadDim;
      expect(rtDim.textHeight, closeTo(2.5, 1e-9));
      expect(rtDim.arrowSize, closeTo(2.5, 1e-9));
    });
  });

  group('campos comunes (BUG-21: 62 BYLAYER, 370 lineweight, precisión)', () {
    test('escribe 62=256 (BYLAYER) explícito y 370 en centésimas de mm', () {
      const line = CadLine(
        handle: 'L1',
        layer: 'WALLS',
        x1: 0, y1: 0, x2: 10, y2: 5,
        lineWeight: 0.30,
      );
      final result = writer.write(fileWith(const [line]));
      expect(result.error, isNull);
      final content = result.content!;
      expect(content, contains('\n 62\n256\n'));
      expect(content, contains('\n370\n30\n')); // 0.30 mm = 30 centésimas.
    });

    test('escribe 62 con el color override cuando existe', () {
      const line = CadLine(
        handle: 'L1',
        layer: '0',
        color: 3,
        x1: 0, y1: 0, x2: 10, y2: 5,
      );
      final result = writer.write(fileWith(const [line]));
      expect(result.content!, contains('\n 62\n3\n'));
    });

    test('precisión: coordenadas con 8 decimales (no 6)', () {
      const line = CadLine(
        handle: 'L1',
        layer: '0',
        x1: 1477.13392900523, y1: 0, x2: 10, y2: 5,
      );
      final result = writer.write(fileWith(const [line]));
      final content = result.content!;
      // 1477.13392900523 → toStringAsFixed(8) = 1477.13392901.
      expect(content, contains('1477.13392901'));
    });
  });
}
