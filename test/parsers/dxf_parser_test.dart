import 'package:cad_viewer/models/cad_enums.dart';
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

  group('BLOCK: las entidades internas se asocian al bloque (fix banera.dxf)', () {
    test('el bloque se puebla con sus entidades y el INSERT lo resuelve', () {
      // Estructura real de files_cad/banera.dxf: el diseño (LINE/ARC/CIRCLE)
      // vive en el bloque "banera" y un INSERT en ENTITIES lo instancia.
      // Antes, el parser acumulaba entidades con copyWith pero nunca las
      // escribía de vuelta en la lista `blocks` → todos los bloques quedaban
      // con 0 entidades y solo se veía la cota.
      const dxf = '''
0
SECTION
2
BLOCKS
0
BLOCK
5
A
2
banera
70
0
10
0.0
20
0.0
30
0.0
0
LINE
5
B
8
0
10
0.0
20
0.0
11
100.0
21
50.0
0
ARC
5
F
8
0
10
10.0
20
10.0
40
5.0
50
0.0
51
90.0
0
ENDBLK
0
ENDSEC
0
SECTION
2
ENTITIES
0
DIMENSION
5
C
8
0
10
0.0
20
0.0
0
INSERT
5
E
8
0
2
banera
10
-1100
20
300
41
1.0
42
1.0
50
0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'banera.dxf');
      expect(result.error, isNull);
      expect(result.warnings, isEmpty);
      final file = result.cadFile!;
      // El bloque existe y AHORA tiene sus entidades internas.
      final block = file.blockByName('banera');
      expect(block, isNotNull);
      expect(block!.entities, hasLength(2));
      expect(block.entities[0], isA<CadLine>());
      expect(block.entities[1], isA<CadArc>());
      // Entidades: DIMENSION + INSERT.
      expect(file.entities, hasLength(2));
      final insert = file.entities.whereType<CadInsert>().single;
      expect(insert.blockName, 'banera');
      expect(insert.x, closeTo(-1100, 1e-9));
      expect(insert.y, closeTo(300, 1e-9));
    });

    test('el bloque *Model_Space normaliza sus entidades al modelo', () {
      const dxf = '''
0
SECTION
2
BLOCKS
0
BLOCK
5
A
2
*Model_Space
70
0
10
0.0
20
0.0
30
0.0
0
LINE
5
B
8
0
10
0.0
20
0.0
11
50.0
21
25.0
0
ENDBLK
0
ENDSEC
0
SECTION
2
ENTITIES
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'model.dxf');
      expect(result.error, isNull);
      // El espacio modelo vacío se llena con las entidades del bloque.
      expect(result.cadFile!.entities, hasLength(1));
      expect(result.cadFile!.entities.single, isA<CadLine>());
    });
  });

  group('bloques anónimos (*D…, *X3) se conservan (BUG-07)', () {
    test('solo se excluyen *Model_Space y *Paper_Space', () {
      const dxf = '''
0
SECTION
2
BLOCKS
0
BLOCK
5
A
2
*X3
70
0
10
0.0
20
0.0
30
0.0
0
LINE
5
B
8
0
10
0.0
20
0.0
11
5.0
21
5.0
0
ENDBLK
0
BLOCK
5
C
2
*Model_Space
70
0
10
0.0
20
0.0
30
0.0
0
ENDBLK
0
BLOCK
5
D
2
*Paper_Space
70
0
10
0.0
20
0.0
30
0.0
0
ENDBLK
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'anon.dxf');
      expect(result.error, isNull);
      final file = result.cadFile!;
      // *X3 (bloque dinámico referenciado por INSERT) se conserva con su
      // geometría; los espacios de modelo/papel NO son bloques de dibujo.
      final x3 = file.blockByName('*X3');
      expect(x3, isNotNull);
      expect(x3!.entities, hasLength(1));
      expect(file.blockByName('*Model_Space'), isNull);
      expect(file.blockByName('*Paper_Space'), isNull);
    });

    test('el INSERT a un bloque anónimo encuentra el bloque', () {
      const dxf = '''
0
SECTION
2
BLOCKS
0
BLOCK
5
A
2
*X3
70
0
10
0.0
20
0.0
30
0.0
0
LINE
5
B
8
0
10
0.0
20
0.0
11
5.0
21
5.0
0
ENDBLK
0
ENDSEC
0
SECTION
2
ENTITIES
0
INSERT
5
E
8
0
2
*X3
10
100
20
200
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'anon2.dxf');
      expect(result.error, isNull);
      final file = result.cadFile!;
      final insert = file.entities.whereType<CadInsert>().single;
      expect(insert.blockName, '*X3');
      expect(file.blockByName(insert.blockName), isNotNull);
    });
  });

  group('DIMENSION: estilo fallback y código raw (BUG-12/BUG-20)', () {
    test('estilo inexistente cae al primer DIMSTYLE; raw 70 se conserva', () {
      const dxf = '''
0
SECTION
2
TABLES
0
DIMSTYLE
2
Standard
70
0
140
2.5
41
2.5
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
DIMENSION
5
D1
8
0
3
TOTO-COTAS
70
32
10
0.0
20
0.0
11
5.0
21
0.0
13
0.0
23
0.0
14
10.0
24
0.0
42
10.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'dim.dxf');
      expect(result.error, isNull);
      final d = result.cadFile!.entities.single as CadDim;
      expect(d.style, 'TOTO-COTAS');
      // BUG-12: texto/flecha del primer DIMSTYLE en vez de 0.
      expect(d.textHeight, closeTo(2.5, 1e-9));
      expect(d.arrowSize, closeTo(2.5, 1e-9));
      // BUG-20: el código raw 32 (alineada + bit 0x20) se conserva.
      // El enum base queda rotated (32 & 0x07 = 0) pero el raw 32 se
      // preserva para que el writer no degrade el archivo.
      expect(d.dimTypeRawCode, 32);
      expect(d.dimType, DimType.rotated);
    });

    test('estilo existente se usa directo', () {
      const dxf = '''
0
SECTION
2
TABLES
0
DIMSTYLE
2
TOTO-COTAS
70
0
140
1.5
41
1.0
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
DIMENSION
5
D1
8
0
3
TOTO-COTAS
70
0
10
0.0
20
0.0
11
5.0
21
0.0
13
0.0
23
0.0
14
10.0
24
0.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'dim2.dxf');
      expect(result.error, isNull);
      final d = result.cadFile!.entities.single as CadDim;
      expect(d.textHeight, closeTo(1.5, 1e-9));
      expect(d.arrowSize, closeTo(1.0, 1e-9));
    });

    test('sin DIMSTYLE y sin 140/41: textHeight 0 (automático al pintar)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
DIMENSION
5
D1
8
0
70
0
10
0.0
20
0.0
11
5.0
21
0.0
13
0.0
23
0.0
14
10.0
24
0.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'dim3.dxf');
      expect(result.error, isNull);
      final d = result.cadFile!.entities.single as CadDim;
      expect(d.textHeight, 0);
      expect(d.arrowSize, 0);
      expect(d.dimTypeRawCode, 0);
    });
  });

  group('HEADER: variables de código 9 (fix crítico)', () {
    test(r'lee $ACADVER y $INSUNITS (antes nunca se parseaban)', () {
      // El bloque de variables del HEADER estaba anidado dentro de
      // 'if (pair.code == 0)' y como usan código 9 nunca se ejecutaba:
      // original.dxf (AC1021/$INSUNITS=0) se parseaba como AC1015/mm.
      const dxf = '''
0
SECTION
2
HEADER
9
\$ACADVER
1
AC1021
9
\$INSUNITS
70
0
9
\$LTSCALE
70
1
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'hdr.dxf');
      expect(result.error, isNull);
      final file = result.cadFile!;
      expect(file.version, 'AC1021');
      expect(file.header.insUnits, 0);
      expect(file.header.units, UnitsType.unitless);
    });

    test(r'variables no reconocidas (p. ej. $LTSCALE) no rompen el parseo', () {
      const dxf = '''
0
SECTION
2
HEADER
9
\$LTSCALE
70
1
9
\$ACADVER
1
AC1015
0
ENDSEC
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
5.0
21
5.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'hdr2.dxf');
      expect(result.error, isNull);
      expect(result.cadFile!.version, 'AC1015');
      expect(result.cadFile!.entities, hasLength(1));
    });
  });

  group(r'DIMENSION: $DIMTXT del header como fallback (BUG-23)', () {
    test(r'sin DIMSTYLE en tabla, usa $DIMTXT del header', () {
      const dxf = '''
0
SECTION
2
HEADER
9
\$DIMTXT
40
1.5
0
ENDSEC
0
SECTION
2
ENTITIES
0
DIMENSION
5
D1
8
0
3
TOTO-COTAS
70
0
10
0.0
20
0.0
11
5.0
21
0.0
13
0.0
23
0.0
14
10.0
24
0.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'dim4.dxf');
      expect(result.error, isNull);
      final d = result.cadFile!.entities.single as CadDim;
      // BUG-23: sin DIMSTYLE, el dimtxt del header evita el 0.
      expect(d.textHeight, closeTo(1.5, 1e-9));
      expect(d.arrowSize, closeTo(1.5, 1e-9));
    });

    test(r'sin DIMSTYLE y sin $DIMTXT: textHeight 0 (automático al pintar)', () {
      const dxf = '''
0
SECTION
2
ENTITIES
0
DIMENSION
5
D1
8
0
70
0
10
0.0
20
0.0
11
5.0
21
0.0
13
0.0
23
0.0
14
10.0
24
0.0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'dim5.dxf');
      expect(result.error, isNull);
      final d = result.cadFile!.entities.single as CadDim;
      expect(d.textHeight, 0);
      expect(d.arrowSize, 0);
    });
  });

  group('entidades en sección OBJECTS (robustez, no aplica a banera.dxf)', () {
    test('se rescatan tipos conocidos sin generar warnings espurios', () {
      // dxfrw 0.6.3 a veces deja entidades sueltas en OBJECTS; se rescatan
      // solo los tipos conocidos. DICTIONARY no es entidad → sin warning.
      const dxf = '''
0
SECTION
2
OBJECTS
0
DICTIONARY
5
D
0
INSERT
5
E
8
0
2
banera
10
-1100
20
300
41
1.0
42
1.0
50
0
0
ENDSEC
0
EOF
''';
      final result = parser.parse(dxf, fileName: 'obj.dxf');
      expect(result.error, isNull);
      expect(result.warnings, isEmpty);
      final insert = result.cadFile!.entities.whereType<CadInsert>().single;
      expect(insert.blockName, 'banera');
      expect(insert.x, closeTo(-1100, 1e-9));
    });
  });
}
