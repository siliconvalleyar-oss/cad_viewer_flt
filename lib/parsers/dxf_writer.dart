/// Escritor DXF propio (docs/DXF_WRITER_SPEC.md, ADR-0003).
///
/// Serializa un `CadFile` (o la sesión exportada) a DXF ASCII. Soporta:
/// - **R2000 (AC1015)**: handles + subclass markers, todas las entidades.
/// - **R12 (AC1009)**: sin handles ni subclass markers; convierte
///   LWPOLYLINE → POLYLINE pesada (VERTEX/SEQEND) con aviso W-001; omite
///   MTEXT/SPLINE/HATCH con avisos W-002/W-003/W-004 (máxima compatibilidad
///   LibreCAD).
///
/// Devuelve `WriteResult` con el contenido y la lista de avisos (nunca lanza).
library;

import 'dart:math' as math;

import '../models/cad_entity.dart';
import '../models/cad_file.dart';

/// Versión DXF de salida.
enum DxfWriteVersion {
  /// R2000 (AC1015) — por defecto.
  r2000,

  /// R12 (AC1009) — máxima compatibilidad LibreCAD.
  r12,
}

/// Resultado de escritura.
class WriteResult {
  const WriteResult({this.content, this.error, this.warnings = const []});

  /// Contenido DXF listo para guardar; `null` si falló.
  final String? content;

  /// Mensaje de error (si falló).
  final String? error;

  /// Avisos (W-001…W-004).
  final List<String> warnings;
}

/// Writer DXF.
class DxfWriter {
  const DxfWriter();

  /// Serializa un [CadFile] a DXF ASCII.
  WriteResult write(
    CadFile file, {
    DxfWriteVersion version = DxfWriteVersion.r2000,
  }) {
    final warnings = <String>[];
    try {
      final buffer = StringBuffer();
      final isR12 = version == DxfWriteVersion.r12;
      _writeHeader(buffer, file, isR12);
      _writeTables(buffer, file, isR12);
      _writeBlocks(buffer, file, isR12, warnings);
      _writeEntities(buffer, file, isR12, warnings);
      buffer.writeln('  0');
      buffer.writeln('EOF');
      return WriteResult(content: buffer.toString(), warnings: warnings);
    } catch (e) {
      return WriteResult(error: 'No se pudo guardar el archivo: $e');
    }
  }

  void _writeHeader(StringBuffer b, CadFile file, bool r12) {
    b.writeln('  0');
    b.writeln('SECTION');
    b.writeln('  2');
    b.writeln('HEADER');
    _var9(b, r'$ACADVER', r12 ? 'AC1009' : 'AC1015');
    _var70(b, r'$INSUNITS', file.header.insUnits);
    final bounds = file.getBounds();
    if (!bounds.isEmpty) {
      _varPoint(b, r'$EXTMIN', bounds.minX, bounds.minY);
      _varPoint(b, r'$EXTMAX', bounds.maxX, bounds.maxY);
    }
    _var9(b, r'$CLAYER', '0');
    _var70(b, r'$LTSCALE', 1);
    _var70(b, r'$TEXTSIZE', 2.5);
    _var70(b, r'$CELWEIGHT', -1);
    b.writeln('  0');
    b.writeln('ENDSEC');
  }

  void _writeTables(StringBuffer b, CadFile file, bool r12) {
    b.writeln('  0');
    b.writeln('SECTION');
    b.writeln('  2');
    b.writeln('TABLES');

    // Tabla LTYPE (mínima: Continuous).
    b.writeln('  0');
    b.writeln('TABLE');
    b.writeln('  2');
    b.writeln('LTYPE');
    if (!r12) {
      b.writeln('  5');
      b.writeln('5');
      b.writeln('100');
      b.writeln('AcDbSymbolTable');
    }
    b.writeln(' 70');
    b.writeln('1');
    b.writeln('  0');
    b.writeln('LTYPE');
    if (!r12) {
      b.writeln('  5');
      b.writeln('14');
      b.writeln('330');
      b.writeln('5');
      b.writeln('100');
      b.writeln('AcDbSymbolTableRecord');
      b.writeln('100');
      b.writeln('AcDbLinetypeTableRecord');
    }
    b.writeln('  2');
    b.writeln('Continuous');
    b.writeln(' 70');
    b.writeln('0');
    b.writeln('  3');
    b.writeln('Solid line');
    b.writeln(' 72');
    b.writeln('65');
    b.writeln(' 73');
    b.writeln('0');
    b.writeln(' 40');
    b.writeln('0.0');
    b.writeln('  0');
    b.writeln('ENDTAB');

    // Tabla LAYER.
    b.writeln('  0');
    b.writeln('TABLE');
    b.writeln('  2');
    b.writeln('LAYER');
    if (!r12) {
      b.writeln('  5');
      b.writeln('2');
      b.writeln('100');
      b.writeln('AcDbSymbolTable');
    }
    b.writeln(' 70');
    b.writeln('${file.layers.length}');
    for (final layer in file.layers) {
      b.writeln('  0');
      b.writeln('LAYER');
      if (!r12) {
        b.writeln('  5');
        b.writeln(_hexHandle(layer.name.hashCode));
        b.writeln('330');
        b.writeln('2');
        b.writeln('100');
        b.writeln('AcDbSymbolTableRecord');
        b.writeln('100');
        b.writeln('AcDbLayerTableRecord');
      }
      b.writeln('  2');
      b.writeln(layer.name);
      b.writeln(' 70');
      b.writeln('0');
      b.writeln(' 62');
      b.writeln('${layer.color}');
      b.writeln('  6');
      b.writeln(layer.lineType);
    }
    b.writeln('  0');
    b.writeln('ENDTAB');

    b.writeln('  0');
    b.writeln('ENDSEC');
  }

  void _writeBlocks(
    StringBuffer b,
    CadFile file,
    bool r12,
    List<String> warnings,
  ) {
    if (file.blocks.isEmpty) {
      return;
    }
    b.writeln('  0');
    b.writeln('SECTION');
    b.writeln('  2');
    b.writeln('BLOCKS');
    for (final block in file.blocks) {
      b.writeln('  0');
      b.writeln('BLOCK');
      if (!r12) {
        b.writeln('  5');
        b.writeln(_hexHandle(block.name.hashCode));
        b.writeln('100');
        b.writeln('AcDbEntity');
      }
      b.writeln('  8');
      b.writeln('0');
      b.writeln('  2');
      b.writeln(block.name);
      b.writeln(' 70');
      b.writeln('0');
      _pair(b, 10, block.basePoint.x);
      _pair(b, 20, block.basePoint.y);
      _pair(b, 30, block.basePoint.z);
      if (!r12) {
        b.writeln('  3');
        b.writeln(block.name);
        b.writeln('  1');
        b.writeln('');
      }
      for (final e in block.entities) {
        _writeEntity(b, e, r12, warnings, inBlock: true);
      }
      b.writeln('  0');
      b.writeln('ENDBLK');
      if (!r12) {
        b.writeln('  5');
        b.writeln(_hexHandle(block.name.hashCode + 1));
        b.writeln('100');
        b.writeln('AcDbBlockEnd');
      }
    }
    b.writeln('  0');
    b.writeln('ENDSEC');
  }

  void _writeEntities(
    StringBuffer b,
    CadFile file,
    bool r12,
    List<String> warnings,
  ) {
    b.writeln('  0');
    b.writeln('SECTION');
    b.writeln('  2');
    b.writeln('ENTITIES');
    for (final e in file.entities) {
      _writeEntity(b, e, r12, warnings, inBlock: false);
    }
    b.writeln('  0');
    b.writeln('ENDSEC');
  }

  void _writeEntity(
    StringBuffer b,
    CadEntity e,
    bool r12,
    List<String> warnings, {
    required bool inBlock,
  }) {
    switch (e) {
      case final CadLine l:
        b.writeln('  0');
        b.writeln('LINE');
        _common(b, e, r12, 'AcDbLine');
        _pair(b, 10, l.x1); _pair(b, 20, l.y1); _pair(b, 30, 0);
        _pair(b, 11, l.x2); _pair(b, 21, l.y2); _pair(b, 31, 0);
      case final CadCircle c:
        b.writeln('  0');
        b.writeln('CIRCLE');
        _common(b, e, r12, 'AcDbCircle');
        _pair(b, 10, c.cx); _pair(b, 20, c.cy); _pair(b, 30, 0);
        _pair(b, 40, c.radius);
      case final CadArc a:
        b.writeln('  0');
        b.writeln('ARC');
        _common(b, e, r12, 'AcDbCircle');
        if (!r12) {
          _marker(b, 'AcDbArc');
        }
        _pair(b, 10, a.cx); _pair(b, 20, a.cy); _pair(b, 30, 0);
        _pair(b, 40, a.radius);
        _pair(b, 50, _radToDeg(a.startAngle));
        _pair(b, 51, _radToDeg(a.endAngle));
      case final CadEllipse el:
        b.writeln('  0');
        b.writeln('ELLIPSE');
        _common(b, e, r12, 'AcDbEllipse');
        _pair(b, 10, el.cx); _pair(b, 20, el.cy); _pair(b, 30, 0);
        final majorX = el.majorRadius * math.cos(el.rotation);
        final majorY = el.majorRadius * math.sin(el.rotation);
        _pair(b, 11, majorX); _pair(b, 21, majorY); _pair(b, 31, 0);
        _pair(b, 40, el.minorRadius / (el.majorRadius == 0 ? 1 : el.majorRadius));
        _pair(b, 41, 0); _pair(b, 42, 2 * math.pi);
      case final CadLwPolyline p:
        if (r12) {
          _writeHeavyFromLw(b, p, e, r12, warnings);
          return;
        }
        b.writeln('  0');
        b.writeln('LWPOLYLINE');
        _common(b, e, r12, 'AcDbPolyline');
        b.writeln(' 90');
        b.writeln('${p.points.length}');
        b.writeln(' 70');
        b.writeln(p.closed ? '1' : '0');
        b.writeln(' 43');
        b.writeln('0.0');
        for (final v in p.points) {
          _pair(b, 10, v.x);
          _pair(b, 20, v.y);
          if (v.bulge != 0) {
            _pair(b, 42, v.bulge);
          }
        }
      case final CadPolyline p:
        if (r12) {
          b.writeln('  0');
          b.writeln('POLYLINE');
          _commonR12(b, e);
          b.writeln(' 66');
          b.writeln('1');
          b.writeln(' 70');
          b.writeln(p.closed ? '1' : '0');
          for (final pt in p.points) {
            b.writeln('  0');
            b.writeln('VERTEX');
            if (!r12) {
              _marker(b, 'AcDbVertex');
              _marker(b, 'AcDb2dVertex');
            }
            _pair(b, 10, pt.x);
            _pair(b, 20, pt.y);
            _pair(b, 30, pt.z);
          }
          b.writeln('  0');
          b.writeln('SEQEND');
        } else {
          b.writeln('  0');
          b.writeln('POLYLINE');
          _common(b, e, r12, 'AcDbPolyline');
          b.writeln(' 66');
          b.writeln('1');
          b.writeln(' 70');
          b.writeln(p.closed ? '1' : '0');
          for (final pt in p.points) {
            b.writeln('  0');
            b.writeln('VERTEX');
            _marker(b, 'AcDbVertex');
            _marker(b, 'AcDb2dVertex');
            _pair(b, 10, pt.x);
            _pair(b, 20, pt.y);
            _pair(b, 30, pt.z);
          }
          b.writeln('  0');
          b.writeln('SEQEND');
        }
      case final CadText t:
        b.writeln('  0');
        b.writeln('TEXT');
        _common(b, e, r12, 'AcDbText');
        _pair(b, 10, t.x); _pair(b, 20, t.y); _pair(b, 30, 0);
        _pair(b, 40, t.height);
        b.writeln('  1');
        b.writeln(t.text);
        if (t.rotation != 0) {
          _pair(b, 50, _radToDeg(t.rotation));
        }
        if (!r12) {
          _marker(b, 'AcDbText');
        }
      case final CadMText m:
        if (r12) {
          warnings.add('W-002: MTEXT omitido en R12 (entidad ${m.handle})');
          return;
        }
        b.writeln('  0');
        b.writeln('MTEXT');
        _common(b, e, r12, 'AcDbMText');
        _pair(b, 10, m.x); _pair(b, 20, m.y); _pair(b, 30, 0);
        _pair(b, 40, m.height);
        _pair(b, 41, m.width <= 0 ? 100 : m.width);
        b.writeln(' 71');
        b.writeln('1');
        b.writeln('  1');
        b.writeln(m.text);
        b.writeln(' 73');
        b.writeln('1');
        b.writeln(' 44');
        b.writeln('1.0');
      case final CadInsert ins:
        b.writeln('  0');
        b.writeln('INSERT');
        _common(b, e, r12, 'AcDbBlockReference');
        b.writeln('  2');
        b.writeln(ins.blockName);
        _pair(b, 10, ins.x); _pair(b, 20, ins.y); _pair(b, 30, 0);
        if (ins.scaleX != 1) {
          _pair(b, 41, ins.scaleX);
        }
        if (ins.scaleY != 1) {
          _pair(b, 42, ins.scaleY);
        }
        if (ins.rotation != 0) {
          _pair(b, 50, _radToDeg(ins.rotation));
        }
      case final CadPoint pt:
        b.writeln('  0');
        b.writeln('POINT');
        _common(b, e, r12, 'AcDbPoint');
        _pair(b, 10, pt.x); _pair(b, 20, pt.y); _pair(b, 30, 0);
      case final CadHatch h:
        if (r12) {
          warnings.add('W-004: HATCH omitido en R12 (entidad ${h.handle})');
          return;
        }
        _writeHatch(b, h, e, r12);
      case final CadSpline s:
        if (r12) {
          warnings.add('W-003: SPLINE omitido en R12 (entidad ${s.handle})');
          return;
        }
        b.writeln('  0');
        b.writeln('SPLINE');
        _common(b, e, r12, 'AcDbSpline');
        b.writeln(' 70');
        b.writeln('8');
        b.writeln(' 71');
        b.writeln('${s.degree}');
        b.writeln(' 72');
        b.writeln('${s.knots.length}');
        b.writeln(' 73');
        b.writeln('${s.controlPoints.length}');
        b.writeln(' 42');
        b.writeln('0.000000001');
        for (final k in s.knots) {
          _pair(b, 40, k);
        }
        for (final cp in s.controlPoints) {
          _pair(b, 10, cp.x);
          _pair(b, 20, cp.y);
          _pair(b, 30, cp.z);
        }
      case final CadDim d:
        if (r12) {
          warnings.add('W-005: DIMENSION omitida en R12 (entidad ${d.handle})');
          return;
        }
        b.writeln('  0');
        b.writeln('DIMENSION');
        _common(b, e, r12, 'AcDbDimension');
        b.writeln('  2');
        b.writeln('*D1');
        _pair(b, 10, d.x1); _pair(b, 20, d.y1); _pair(b, 30, 0);
        _pair(b, 11, d.x2); _pair(b, 21, d.y2); _pair(b, 31, 0);
        _pair(b, 13, d.x3); _pair(b, 23, d.y3); _pair(b, 33, 0);
        if (d.x4 != 0 || d.y4 != 0) {
          _pair(b, 14, d.x4); _pair(b, 24, d.y4); _pair(b, 34, 0);
        }
        b.writeln(' 70');
        b.writeln('${d.dimType.dxfCode}');
        if (d.text != null) {
          b.writeln('  1');
          b.writeln(d.text!);
        }
        if (d.measurement != null) {
          _pair(b, 42, d.measurement!);
        }
        if (d.textHeight > 0) {
          _pair(b, 140, d.textHeight);
        }
        if (d.arrowSize > 0) {
          _pair(b, 41, d.arrowSize);
        }
      case final Cad3dFace f:
        b.writeln('  0');
        b.writeln('3DFACE');
        _common(b, e, r12, 'AcDbFace');
        for (var i = 0; i < f.corners.length && i < 4; i++) {
          final c = f.corners[i];
          _pair(b, 10 + i, c.x);
          _pair(b, 20 + i, c.y);
          _pair(b, 30 + i, c.z);
        }
    }
  }

  void _writeHeavyFromLw(
    StringBuffer b,
    CadLwPolyline p,
    CadEntity e,
    bool r12,
    List<String> warnings,
  ) {
    if (p.points.length < 2) {
      warnings.add('W-001: LWPOLYLINE con <2 vértices omitida en R12');
      return;
    }
    warnings.add('W-001: LWPOLYLINE ${e.handle} convertida a POLYLINE (R12)');
    b.writeln('  0');
    b.writeln('POLYLINE');
    _commonR12(b, e);
    b.writeln(' 66');
    b.writeln('1');
    b.writeln(' 70');
    b.writeln(p.closed ? '1' : '0');
    for (final v in p.points) {
      b.writeln('  0');
      b.writeln('VERTEX');
      if (!r12) {
        _marker(b, 'AcDbVertex');
        _marker(b, 'AcDb2dVertex');
      }
      _pair(b, 10, v.x);
      _pair(b, 20, v.y);
      _pair(b, 30, 0);
      if (v.bulge != 0) {
        _pair(b, 42, v.bulge);
      }
    }
    b.writeln('  0');
    b.writeln('SEQEND');
  }

  void _writeHatch(StringBuffer b, CadHatch h, CadEntity e, bool r12) {
    b.writeln('  0');
    b.writeln('HATCH');
    _common(b, e, r12, 'AcDbHatch');
    b.writeln(' 10');
    b.writeln('0.0');
    b.writeln(' 20');
    b.writeln('0.0');
    b.writeln(' 30');
    b.writeln('0.0');
    b.writeln('210');
    b.writeln('0.0');
    b.writeln('220');
    b.writeln('0.0');
    b.writeln('230');
    b.writeln('1.0');
    b.writeln('  2');
    b.writeln(h.patternName);
    b.writeln(' 70');
    b.writeln('0');
    b.writeln(' 71');
    b.writeln('0');
    b.writeln(' 91');
    b.writeln('${h.boundaries.length}');
    for (final boundary in h.boundaries) {
      b.writeln(' 92');
      b.writeln(boundary.closed ? '1' : '0');
      b.writeln(' 93');
      b.writeln('${boundary.points.length}');
      for (final pt in boundary.points) {
        _pair(b, 10, pt.x);
        _pair(b, 20, pt.y);
      }
      b.writeln(' 97');
      b.writeln('0');
    }
    b.writeln(' 75');
    b.writeln('1');
    b.writeln(' 76');
    b.writeln('1');
    b.writeln(' 98');
    b.writeln('1');
    b.writeln(' 52');
    b.writeln('0.0');
    b.writeln(' 41');
    b.writeln('1.0');
  }

  void _common(StringBuffer b, CadEntity e, bool r12, String subclass) {
    if (!r12) {
      b.writeln('  5');
      b.writeln(e.handle.isEmpty ? _hexHandle(e.hashCode) : e.handle);
      b.writeln('100');
      b.writeln('AcDbEntity');
    }
    b.writeln('  8');
    b.writeln(e.layer);
    if (e.color != null) {
      b.writeln(' 62');
      b.writeln('${e.color}');
    }
    if (!r12 && e.lineType != null) {
      b.writeln('  6');
      b.writeln(e.lineType!);
    }
    if (!r12) {
      b.writeln('100');
      b.writeln(subclass);
    }
  }

  void _commonR12(StringBuffer b, CadEntity e) {
    b.writeln('  8');
    b.writeln(e.layer);
    if (e.color != null) {
      b.writeln(' 62');
      b.writeln('${e.color}');
    }
  }

  void _marker(StringBuffer b, String marker) {
    b.writeln('100');
    b.writeln(marker);
  }

  void _var9(StringBuffer b, String name, String value) {
    b.writeln('  9');
    b.writeln(name);
    b.writeln('  1');
    b.writeln(value);
  }

  void _var70(StringBuffer b, String name, num value) {
    b.writeln('  9');
    b.writeln(name);
    b.writeln(' 70');
    b.writeln('$value');
  }

  void _varPoint(StringBuffer b, String name, double x, double y) {
    b.writeln('  9');
    b.writeln(name);
    _pair(b, 10, x);
    _pair(b, 20, y);
    _pair(b, 30, 0);
  }

  void _pair(StringBuffer b, int code, double value) {
    b.writeln('$code'.padLeft(3));
    b.writeln(_formatDouble(value));
  }

  String _formatDouble(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return '${v.round()}';
    }
    return v.toStringAsFixed(6);
  }

  double _radToDeg(double rad) => rad * 180 / math.pi;

  String _hexHandle(int h) => (h.abs() % 0xFFFFFF).toRadixString(16).padLeft(4, '0');
}
