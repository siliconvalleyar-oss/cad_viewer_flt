import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/parsers/dxf_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DxfParserWrapper();

  group('tabla LTYPE', () {
    test('parsea nombre y patrón (49 = trazo/espacio)', () {
      const dxf = '''
0
SECTION
2
TABLES
0
LTYPE
2
DASHED
70
64
3
Dashed __ __ __ __ __ __ __
72
65
73
2
40
0.75
49
0.5
49
-0.25
0
ENDTAB
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'lt.dxf');
      expect(result.error, isNull);
      final file = result.cadFile!;
      expect(file.lineTypes.containsKey('DASHED'), isTrue);
      expect(file.lineTypes['DASHED'], [0.5, -0.25]);
    });

    test('varios LTYPE se acumulan', () {
      const dxf = '''
0
SECTION
2
TABLES
0
LTYPE
2
DASHED
70
64
73
2
40
0.75
49
0.5
49
-0.25
0
LTYPE
2
CENTER
70
64
73
4
40
1.75
49
1.25
49
-0.25
49
0.25
49
-0.25
0
ENDTAB
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'lt2.dxf');
      expect(result.error, isNull);
      final file = result.cadFile!;
      expect(file.lineTypes.keys, containsAll(['DASHED', 'CENTER']));
      expect(file.lineTypes['CENTER'], [1.25, -0.25, 0.25, -0.25]);
    });

    test('sin tabla LTYPE: mapa vacío (fallback estándar en painter)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
LINE
8
0
10
0.0
20
0.0
11
10.0
21
0.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'simple.dxf');
      expect(result.error, isNull);
      expect(result.cadFile!.lineTypes, isEmpty);
      expect(result.cadFile!.entities.length, 1);
    });

    test('los 49 no numéricos se ignoran sin romper', () {
      const dxf = '''
0
SECTION
2
TABLES
0
LTYPE
2
BROKEN
70
64
73
1
40
1.0
49
NO_NUM
0
ENDTAB
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'broken.dxf');
      expect(result.error, isNull);
      // Sin elementos válidos → no se registra.
      expect(result.cadFile!.lineTypes.containsKey('BROKEN'), isFalse);
    });
  });

  group('lineWeight (grupo 370 en centésimas de mm)', () {
    test('370=30 → 0.30 mm', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
LINE
8
0
62
1
6
DASHED2
370
30
10
0.0
20
0.0
11
10.0
21
5.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'lw.dxf');
      expect(result.error, isNull);
      final e = result.cadFile!.entities.single as CadLine;
      expect(e.lineWeight, 0.30);
      expect(e.lineType, 'DASHED2');
    });

    test('370≤0 (BYLAYER) → null (heredar)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
LINE
8
0
370
-1
10
0.0
20
0.0
11
10.0
21
5.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'lw2.dxf');
      expect(result.error, isNull);
      expect(result.cadFile!.entities.single.lineWeight, isNull);
    });
  });

  group('SOLID/TRACE (áreas rellenas, AC1021)', () {
    test('SOLID cuadrilátero con marcador AcDbTrace', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
SOLID
5
758
100
AcDbEntity
8
AR - REVOQUE
62
0
370
-2
100
AcDbTrace
10
1501.34
20
1856.69
30
0
11
1501.36
21
1856.57
31
0
12
1510.0
22
1856.57
32
0
13
1510.0
23
1860.0
33
0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'solid.dxf');
      expect(result.error, isNull);
      final e = result.cadFile!.entities.single as CadSolid;
      expect(e.corners.length, 4);
      expect(e.corners.first.x, closeTo(1501.34, 1e-9));
      expect(e.corners.first.y, closeTo(1856.69, 1e-9));
      expect(e.corners.last.x, closeTo(1510.0, 1e-9));
      expect(e.layer, 'AR - REVOQUE');
    });

    test('TRACE también se parsea como sólido (triángulo: 3ª = 4ª esquina)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
TRACE
5
abc
8
0
10
0.0
20
0.0
11
10.0
21
0.0
12
10.0
22
10.0
13
10.0
23
10.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'trace.dxf');
      expect(result.error, isNull);
      final e = result.cadFile!.entities.single as CadSolid;
      expect(e.corners.length, 4);
      expect(e.corners[2].x, closeTo(10.0, 1e-9));
      expect(e.corners[2].y, closeTo(10.0, 1e-9));
      expect(e.corners[3].x, closeTo(10.0, 1e-9));
    });

    test('no genera aviso de entidad no soportada', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
SOLID
5
1
8
0
10
0.0
20
0.0
11
1.0
21
0.0
12
1.0
22
1.0
13
1.0
23
1.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 's2.dxf');
      expect(result.error, isNull);
      expect(result.warnings, isEmpty);
      expect(result.cadFile!.entities, hasLength(1));
    });
  });
}
