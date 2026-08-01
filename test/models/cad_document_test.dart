import 'package:cad_viewer/models/cad_document.dart';
import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_file.dart';
import 'package:cad_viewer/models/cad_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CadFile baseFile() {
    return const CadFile(
      fileName: 'plano.dxf',
      version: 'AC1015',
      layers: [
        CadLayer(name: '0'),
        CadLayer(name: 'WALLS', color: 1),
      ],
      entities: [
        CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
        CadCircle(handle: '2', layer: 'WALLS', cx: 5, cy: 5, radius: 2),
      ],
    );
  }

  group('fromCadFile', () {
    test('copia entidades, capas y bloques', () {
      final doc = CadDocument.fromCadFile(baseFile());
      expect(doc.entities.length, 2);
      expect(doc.layers.length, 2);
      expect(doc.dirty, isFalse);
      expect(doc.documentVersion, 0);
      expect(doc.currentLayer, '0');
    });

    test('getEntity por handle', () {
      final doc = CadDocument.fromCadFile(baseFile());
      expect(doc.getEntity('1'), isA<CadLine>());
      expect(doc.getEntity('99'), isNull);
    });
  });

  group('getVisibleEntities', () {
    test('filtra capa invisible y congelada', () {
      const file = CadFile(
        fileName: 'x.dxf',
        layers: [
          CadLayer(name: '0'),
          CadLayer(name: 'HIDDEN', visible: false),
          CadLayer(name: 'FROZEN', frozen: true),
        ],
        entities: [
          CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 1, y2: 1),
          CadLine(handle: '2', layer: 'HIDDEN', x1: 0, y1: 0, x2: 1, y2: 1),
          CadLine(handle: '3', layer: 'FROZEN', x1: 0, y1: 0, x2: 1, y2: 1),
        ],
      );
      final doc = CadDocument.fromCadFile(file);
      final visible = doc.getVisibleEntities();
      expect(visible.length, 1);
      expect(visible.single.handle, '1');
    });

    test('capa inexistente se considera visible', () {
      const file = CadFile(
        fileName: 'x.dxf',
        entities: [
          CadLine(handle: '1', layer: 'FANTASMA', x1: 0, y1: 0, x2: 1, y2: 1),
        ],
      );
      final doc = CadDocument.fromCadFile(file);
      expect(doc.getVisibleEntities().length, 1);
    });
  });

  group('exportCadFile', () {
    test('exporta archivo limpio sin estado de sesión', () {
      const file = CadFile(
        fileName: 'plano.dxf',
        layers: [
          CadLayer(name: '0'),
          CadLayer(name: 'WALLS', color: 1, displayColor: 0xFF00FF00),
        ],
        entities: [
          CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
        ],
      );
      final doc = CadDocument.fromCadFile(file)
          .withSelection({'1'})
          .withCurrentLayer('WALLS')
          .markDirty();
      final exported = doc.exportCadFile();

      // Estado de sesión NO se exporta.
      expect(
        exported.layers.firstWhere((l) => l.name == 'WALLS').displayColor,
        isNull,
      );
      expect(
        exported.layers.firstWhere((l) => l.name == 'WALLS').isCurrent,
        isFalse,
      );
      expect(exported.entities.length, 1);
      expect(exported.fileName, 'plano.dxf');
      expect(exported.version, 'AC1015');
    });

    test('no altera el archivo base', () {
      final doc = CadDocument.fromCadFile(baseFile());
      final exported = doc.exportCadFile();
      expect(exported, doc.cadFile);
    });
  });

  group('dirty y version', () {
    test('markDirty / markSaved', () {
      final doc = CadDocument.fromCadFile(baseFile());
      expect(doc.markDirty().dirty, isTrue);
      expect(doc.markDirty().markSaved().dirty, isFalse);
    });

    test('addEntity marca dirty y sube documentVersion', () {
      final doc = CadDocument.fromCadFile(baseFile());
      final next = doc.addEntity(
        const CadLine(handle: '3', layer: '0', x1: 1, y1: 1, x2: 2, y2: 2),
      );
      expect(next.dirty, isTrue);
      expect(next.documentVersion, 1);
      expect(next.entities.length, 3);
      expect(doc.entities.length, 2); // original intacto (inmutable)
    });

    test('removeEntity', () {
      final doc = CadDocument.fromCadFile(baseFile());
      final next = doc.removeEntity('2');
      expect(next.entities.length, 1);
      expect(next.getEntity('2'), isNull);
    });

    test('setEntityProps', () {
      final doc = CadDocument.fromCadFile(baseFile());
      final updated = doc.setEntityProps(
        '1',
        const CadLine(handle: '1', layer: '0', x1: 100, y1: 0, x2: 10, y2: 0),
      );
      final line = updated.getEntity('1')! as CadLine;
      expect(line.x1, 100);
      expect(updated.documentVersion, 1);
    });
  });
}
