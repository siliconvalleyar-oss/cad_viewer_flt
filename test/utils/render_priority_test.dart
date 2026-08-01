/// Tests de la prioridad de renderizado (docs/CORREGIR_instrucciones-… §D).
library;

import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_enums.dart';
import 'package:cad_viewer/utils/render_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CadLine line(String layer) =>
      CadLine(handle: 'h', layer: layer, x1: 0, y1: 0, x2: 1, y2: 0);

  CadDim dim(String layer) => CadDim(
        handle: 'h',
        layer: layer,
        dimType: DimType.aligned,
        x1: 0, y1: 0, x2: 1, y2: 0, x3: 0, y3: 1,
      );

  CadInsert insert(String layer) => CadInsert(
        handle: 'h',
        layer: layer,
        blockName: 'bloque',
        x: 0, y: 0,
      );

  CadText text(String layer) =>
      CadText(handle: 'h', layer: layer, text: 'a', x: 0, y: 0, height: 1);

  CadHatch hatch(String layer) =>
      CadHatch(handle: 'h', layer: layer, patternName: 'SOLID');

  group('renderPriority — doc §D', () {
    test('rellenos (HATCH/SOLID/3DFACE) van detrás de todo (0)', () {
      expect(renderPriority(hatch('0')), 0);
      expect(
        renderPriority(
          CadSolid(handle: 'h', layer: '0', corners: const []),
        ),
        0,
      );
      expect(
        renderPriority(
          Cad3dFace(handle: 'h', layer: '0', corners: const []),
        ),
        0,
      );
    });

    test('muros/estructura: heurística por capa (1)', () {
      expect(renderPriority(line('MUROS')), 1);
      expect(renderPriority(line('CWALL')), 1);
      expect(renderPriority(line('ESTRUCTURA')), 1);
      expect(renderPriority(line('VIGAS')), 1);
    });

    test('columnas (2), puertas (3), ventanas (4)', () {
      expect(renderPriority(line('COLUMNAS')), 2);
      expect(renderPriority(line('PILARES')), 2);
      expect(renderPriority(line('PUERTAS')), 3);
      expect(renderPriority(line('DOORS')), 3);
      expect(renderPriority(line('VENTANAS')), 4);
      expect(renderPriority(line('WINDOWS')), 4);
    });

    test('"SUPPORT" NO es puerta: evita falso positivo de PORT', () {
      // 'PORT' a secas matchearía 'SUPPORT' (capa estructural común);
      // los keys de puerta exigen DOOR*/PUERTA*/PORTAL.
      expect(renderPriority(line('SUPPORT')), isNot(3)); // no puerta
      expect(renderPriority(line('SUPPORT-BRACKETS')), isNot(3));
      expect(renderPriority(line('PORTAL')), 3); // sí es puerta
    });

    test('equipamiento (6) y símbolos (8)', () {
      expect(renderPriority(line('EQUIPAMIENTO')), 6);
      expect(renderPriority(line('MOBILIARIO')), 6);
      expect(renderPriority(line('SIMBOLOS')), 8);
      expect(renderPriority(line('NIVEL')), 8);
    });

    test('geometría general (5) por defecto', () {
      expect(renderPriority(line('0')), 5);
      expect(renderPriority(line('AR-PROYECCION')), 5);
    });

    test('INSERT es bloque (7) incluso en capa de muros', () {
      expect(renderPriority(insert('0')), 7);
      // El tipo gana sobre la heurística de capa.
      expect(renderPriority(insert('MUROS')), 7);
    });

    test('TEXT/MTEXT (9) y DIMENSION (10) encima de todo', () {
      expect(renderPriority(text('TEXTOS')), 9);
      expect(
        renderPriority(
          CadMText(handle: 'h', layer: 'TEXTOS', text: 'a', x: 0, y: 0, height: 1),
        ),
        9,
      );
      expect(renderPriority(dim('COTAS')), 10);
      expect(renderPriority(dim('0')), 10);
    });

    test('el tipo de anotación gana sobre la heurística de capa', () {
      // Un TEXT en una capa llamada "MUROS" es texto y debe pintarse encima.
      expect(renderPriority(text('MUROS')), 9);
      expect(renderPriority(dim('VENTANAS')), 10);
    });

    test('orden completo: relleno < muro < columna < puerta < ventana < geom < equip < bloque < símbolo < texto < cota', () {
      final priorities = [
        renderPriority(hatch('0')), // 0
        renderPriority(line('MUROS')), // 1
        renderPriority(line('COLUMNAS')), // 2
        renderPriority(line('PUERTAS')), // 3
        renderPriority(line('VENTANAS')), // 4
        renderPriority(line('0')), // 5
        renderPriority(line('EQUIP')), // 6
        renderPriority(insert('0')), // 7
        renderPriority(line('SIMBOLOS')), // 8
        renderPriority(text('TEXTOS')), // 9
        renderPriority(dim('COTAS')), // 10
      ];
      for (var i = 0; i < priorities.length - 1; i++) {
        expect(priorities[i] < priorities[i + 1], isTrue,
            reason: 'posición $i (${priorities[i]}) debe ser menor que '
                '${priorities[i + 1]}');
      }
    });
  });
}
