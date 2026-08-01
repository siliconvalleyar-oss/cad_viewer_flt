import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CadLine', () {
    const line = CadLine(
      handle: '1',
      layer: 'WALLS',
      x1: 0,
      y1: 0,
      x2: 10,
      y2: 5,
    );

    test('igualdad por valor', () {
      const same = CadLine(
        handle: '1',
        layer: 'WALLS',
        x1: 0,
        y1: 0,
        x2: 10,
        y2: 5,
      );
      expect(line, same);
      expect(line.hashCode, same.hashCode);
    });

    test('desigualdad por campo', () {
      expect(line.copyWith(x2: 20), isNot(line));
      expect(line.copyWith(handle: '2'), isNot(line));
      expect(line.copyWith(layer: '0'), isNot(line));
    });

    test('copyWith conserva el resto', () {
      final moved = line.copyWith(x1: 5, y1: 5);
      expect(moved.x1, 5);
      expect(moved.y1, 5);
      expect(moved.x2, 10);
      expect(moved.y2, 5);
      expect(moved.handle, '1');
    });

    test('copyWith permite poner color a null explícito', () {
      const withColor = CadLine(
        handle: '1',
        layer: '0',
        color: 1,
        x1: 0,
        y1: 0,
        x2: 1,
        y2: 1,
      );
      final cleared = withColor.copyWith(color: null);
      expect(cleared.color, isNull);
      // No pasar el parámetro conserva el valor.
      expect(withColor.copyWith().color, 1);
    });

    test('defaults base', () {
      expect(line.color, isNull);
      expect(line.lineType, isNull);
      expect(line.lineWeight, isNull);
    });

    test('type es line', () {
      expect(line.type, CadEntityType.line);
    });
  });

  group('CadCircle', () {
    const circle = CadCircle(handle: 'c', layer: '0', cx: 5, cy: 5, radius: 2);
    test('igualdad y copyWith', () {
      expect(circle.copyWith(radius: 3).radius, 3);
      expect(circle.copyWith(radius: 3), isNot(circle));
      expect(circle.copyWith(cy: 6), isNot(circle));
    });
  });

  group('CadArc', () {
    const arc = CadArc(
      handle: 'a',
      layer: '0',
      cx: 0,
      cy: 0,
      radius: 5,
      startAngle: 0,
      endAngle: 1.5708,
    );
    test('ángulos en radianes', () {
      expect(arc.startAngle, 0);
      expect(arc.endAngle, 1.5708);
    });
  });

  group('CadEllipse', () {
    const ellipse = CadEllipse(
      handle: 'e',
      layer: '0',
      cx: 0,
      cy: 0,
      majorRadius: 4,
      minorRadius: 2,
      rotation: 0,
    );
    test('ejes', () {
      expect(ellipse.majorRadius, 4);
      expect(ellipse.minorRadius, 2);
    });
  });

  group('CadLwPolyline', () {
    const pline = CadLwPolyline(
      handle: 'p',
      layer: '0',
      points: [
        LwVertex(0, 0),
        LwVertex(10, 0, bulge: 0.5),
        LwVertex(10, 10),
      ],
      closed: true,
    );
    test('vértices con bulge', () {
      expect(pline.points.length, 3);
      expect(pline.points[1].bulge, 0.5);
      expect(pline.closed, isTrue);
    });
    test('igualdad por lista', () {
      final same = pline.copyWith();
      expect(pline, same);
    });
  });

  group('CadPolyline', () {
    const pline = CadPolyline(
      handle: 'p',
      layer: '0',
      points: [
        CadPoint3(0, 0),
        CadPoint3(10, 0, 1),
      ],
    );
    test('puntos 3D', () {
      expect(pline.points[1].z, 1);
    });
  });

  group('CadText / CadMText', () {
    const text = CadText(
      handle: 't',
      layer: 'TEXT',
      text: 'Hola',
      x: 1,
      y: 2,
      height: 2.5,
      rotation: 0,
      style: 'Standard',
      horizontalAlign: 0,
    );
    const mtext = CadMText(
      handle: 'm',
      layer: 'TEXT',
      text: 'Nota',
      x: 1,
      y: 2,
      height: 2.5,
      attachmentPoint: 1,
      width: 20,
    );
    test('campos', () {
      expect(text.text, 'Hola');
      expect(text.style, 'Standard');
      expect(mtext.attachmentPoint, 1);
      expect(mtext.width, 20);
    });
  });

  group('CadInsert', () {
    const insert = CadInsert(
      handle: 'i',
      layer: '0',
      blockName: 'BOLT',
      x: 10,
      y: 10,
      scaleX: 1,
      scaleY: 1,
      rotation: 0.7854,
    );
    test('referencia a bloque', () {
      expect(insert.blockName, 'BOLT');
      expect(insert.rotation, 0.7854);
    });
  });

  group('CadPoint', () {
    const point = CadPoint(handle: 'pt', layer: '0', x: 3, y: 4);
    test('coordenadas', () {
      expect(point.x, 3);
      expect(point.y, 4);
    });
  });

  group('CadHatch', () {
    const hatch = CadHatch(
      handle: 'h',
      layer: 'HATCH',
      patternName: 'SOLID',
      boundaries: [
        HatchBoundary(
          points: [
            CadPoint3(0, 0),
            CadPoint3(10, 0),
            CadPoint3(10, 10),
            CadPoint3(0, 10),
          ],
        ),
      ],
    );
    test('boundaries', () {
      expect(hatch.patternName, 'SOLID');
      expect(hatch.boundaries.single.points.length, 4);
    });
  });

  group('CadSpline', () {
    const spline = CadSpline(
      handle: 's',
      layer: '0',
      degree: 3,
      controlPoints: [
        CadPoint3(0, 0),
        CadPoint3(10, 20),
        CadPoint3(20, -10),
        CadPoint3(30, 10),
      ],
      knots: [0, 0, 0, 1, 2, 2, 2],
    );
    test('grado y puntos de control', () {
      expect(spline.degree, 3);
      expect(spline.controlPoints.length, 4);
      expect(spline.knots.length, 7);
    });
  });

  group('CadDim', () {
    const dim = CadDim(
      handle: 'd',
      layer: 'DIMS',
      dimType: DimType.aligned,
      x1: 0,
      y1: 0,
      x2: 10,
      y2: 0,
      x3: 5,
      y3: 2,
      text: '10',
      style: 'Standard',
    );
    test('dimType y puntos de definición', () {
      expect(dim.dimType, DimType.aligned);
      expect(dim.x3, 5);
      expect(dim.text, '10');
    });
  });

  group('Cad3dFace', () {
    const face = Cad3dFace(
      handle: 'f',
      layer: '0',
      corners: [
        CadPoint3(0, 0, 0),
        CadPoint3(10, 0, 0),
        CadPoint3(10, 10, 5),
        CadPoint3(0, 10, 0),
      ],
    );
    test('4 esquinas', () {
      expect(face.corners.length, 4);
      expect(face.type, CadEntityType.face3d);
    });
  });

  group('subtipos distintos no son iguales', () {
    test('CadLine != CadCircle', () {
      const line = CadLine(handle: '1', layer: '0', x1: 0, y1: 0, x2: 1, y2: 1);
      const circle = CadCircle(handle: '1', layer: '0', cx: 0, cy: 0, radius: 1);
      expect(line, isNot(circle));
    });
  });
}
