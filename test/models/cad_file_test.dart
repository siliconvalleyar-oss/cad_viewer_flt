import 'package:cad_viewer/models/cad_block.dart';
import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_enums.dart';
import 'package:cad_viewer/models/cad_file.dart';
import 'package:cad_viewer/models/cad_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CadFile fileWith(List<CadEntity> entities, {List<CadBlock> blocks = const []}) {
    return CadFile(
      fileName: 'test.dxf',
      version: 'AC1015',
      entities: entities,
      blocks: blocks,
    );
  }

  group('getBounds', () {
    test('línea', () {
      final file = fileWith(const [
        CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 10, y2: 5),
      ]);
      final b = file.getBounds();
      expect(b.minX, 0);
      expect(b.minY, 0);
      expect(b.maxX, 10);
      expect(b.maxY, 5);
    });

    test('círculo', () {
      final file = fileWith(const [
        CadCircle(handle: '1', layer: '0', cx: 5, cy: 5, radius: 2),
      ]);
      final b = file.getBounds();
      expect(b.minX, 3);
      expect(b.minY, 3);
      expect(b.maxX, 7);
      expect(b.maxY, 7);
    });

    test('arco usa radio (circunscrito)', () {
      final file = fileWith(const [
        CadArc(
          handle: '1',
          layer: '0',
          cx: 0,
          cy: 0,
          radius: 5,
          startAngle: 0,
          endAngle: 1.5708,
        ),
      ]);
      final b = file.getBounds();
      expect(b.maxX, 5);
      expect(b.maxY, 5);
    });

    test('polilínea ligera con bulge', () {
      final file = fileWith(const [
        CadLwPolyline(
          handle: '1',
          layer: '0',
          points: [
            LwVertex(0, 0),
            LwVertex(10, 0, bulge: 0.5),
            LwVertex(10, 10),
          ],
        ),
      ]);
      final b = file.getBounds();
      expect(b.minX, 0);
      expect(b.maxX, 10);
      expect(b.maxY, 10);
    });

    test('INSERT resuelve bloque (traslación + escala)', () {
      const block = CadBlock(
        name: 'B',
        entities: [
          CadCircle(handle: 'b1', layer: '0', cx: 0, cy: 0, radius: 2),
        ],
      );
      final file = fileWith(
        const [
          CadInsert(handle: 'i', layer: '0', blockName: 'B', x: 10, y: 20),
        ],
        blocks: const [block],
      );
      final b = file.getBounds();
      // Bounds local del bloque: [-2,-2]..[2,2] trasladado a (10,20).
      expect(b.minX, 8);
      expect(b.minY, 18);
      expect(b.maxX, 12);
      expect(b.maxY, 22);
    });

    test('INSERT sin bloque: solo el punto de inserción', () {
      final file = fileWith(const [
        CadInsert(handle: 'i', layer: '0', blockName: 'NO_EXISTE', x: 3, y: 4),
      ]);
      final b = file.getBounds();
      expect(b.minX, 3);
      expect(b.maxX, 3);
      expect(b.minY, 4);
      expect(b.maxY, 4);
    });

    test('varias entidades unen bounds', () {
      final file = fileWith(const [
        CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 1, y2: 1),
        CadCircle(handle: '2', layer: '0', cx: 20, cy: 30, radius: 2),
      ]);
      final b = file.getBounds();
      expect(b.minX, 0);
      expect(b.minY, 0);
      expect(b.maxX, 22);
      expect(b.maxY, 32);
    });

    test('archivo vacío → bounds vacío', () {
      final file = fileWith(const []);
      expect(file.getBounds().isEmpty, isTrue);
    });
  });

  group('header', () {
    test('defaults', () {
      const file = CadFile(fileName: 'x.dxf');
      expect(file.header.units, UnitsType.mm);
      expect(file.header.insUnits, 4);
      expect(file.version, 'AC1015');
      expect(file.format, FileFormat.dxf);
    });
  });

  group('capas', () {
    test('layerByName', () {
      const file = CadFile(
        fileName: 'x.dxf',
        layers: [
          CadLayer(name: '0'),
          CadLayer(name: 'WALLS', color: 1),
        ],
      );
      expect(file.layerByName('WALLS')?.color, 1);
      expect(file.layerByName('NO'), isNull);
    });

    test('capa inexistente en getBounds no rompe', () {
      final file = fileWith(const [
        CadLine(handle: '1', layer: 'FANTASMA', x1: 0, y1: 0, x2: 1, y2: 1),
      ]);
      expect(file.getBounds().maxX, 1);
    });
  });

  group('bloques', () {
    test('blockByName', () {
      const file = CadFile(
        fileName: 'x.dxf',
        blocks: [CadBlock(name: 'B')],
      );
      expect(file.blockByName('B')?.name, 'B');
      expect(file.blockByName('X'), isNull);
    });

    test('bounds local del bloque', () {
      const block = CadBlock(
        name: 'B',
        entities: [
          CadLine(handle: '1', layer: '0', x1: -5, y1: 0, x2: 5, y2: 3),
        ],
      );
      final b = block.getBounds();
      expect(b.minX, -5);
      expect(b.maxY, 3);
    });
  });
}
