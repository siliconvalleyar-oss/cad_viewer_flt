/// Parser DXF propio (docs/FORMATS.md, SERIALIZATION.md).
///
/// El paquete `dxf` (v3.x) solo soporta un subconjunto de entidades, por lo
/// que `DxfParserWrapper` implementa un parseo ASCII directo por pares
/// (código de grupo, valor) que cubre: LINE, CIRCLE, ARC, ELLIPSE,
/// LWPOLYLINE, POLYLINE pesada (R12/LibreCAD, con VERTEX/SEQEND), TEXT,
/// MTEXT, INSERT (bloques), POINT, HATCH básico, SPLINE, DIMENSION, 3DFACE
/// y SOLID/TRACE (áreas rellenas), más HEADER, TABLES (LAYER), BLOCKS y
/// ENTITIES.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/cad_block.dart';
import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../models/cad_file.dart';
import '../models/cad_layer.dart';

/// Resultado del parseo (contrato para Isolates, SERIALIZATION §4):
/// nunca lanza; devuelve el archivo o una descripción de error/warnings.
class ParseResult {
  const ParseResult({this.cadFile, this.error, this.warnings = const []});

  /// Archivo parseado; `null` si hubo error.
  final CadFile? cadFile;

  /// Mensaje de error (si falló).
  final String? error;

  /// Avisos de parseo (entidades no soportadas, etc.).
  final List<String> warnings;
}

/// Wrapper de parseo DXF (ADR-0002).
class DxfParserWrapper {
  const DxfParserWrapper();

  /// Parsea contenido DXF ASCII a [CadFile].
  ParseResult parse(String content, {String fileName = 'dibujo.dxf'}) {
    final warnings = <String>[];
    try {
      final pairs = _readPairs(content);
      final file = _buildFile(pairs, fileName, warnings);
      return ParseResult(cadFile: file, warnings: warnings);
    } on FormatException catch (e) {
      return ParseResult(error: 'Formato DXF inválido: ${e.message}');
    } catch (e) {
      return ParseResult(error: 'No se pudo leer el archivo: $e');
    }
  }

  /// Parsea bytes (UTF-8/ASCII). Detecta DXF binario y devuelve error claro.
  ParseResult parseBytes(Uint8List bytes, {String fileName = 'dibujo.dxf'}) {
    try {
      final head = latin1.decode(
        bytes.sublist(0, bytes.length < 64 ? bytes.length : 64),
        allowInvalid: true,
      );
      if (head.startsWith('AutoCAD Binary DXF')) {
        return const ParseResult(
          error: 'DXF binario no soportado en v1.0. Convierta el archivo a DXF ASCII.',
        );
      }
      return parse(utf8.decode(bytes, allowMalformed: true), fileName: fileName);
    } catch (e) {
      return ParseResult(error: 'No se pudo leer el archivo: $e');
    }
  }

  /// Lee pares (código, valor). Cada par ocupa dos líneas (FORMATS §2).
  List<DxfPair> _readPairs(String content) {
    final pairs = <DxfPair>[];
    final lines = const LineSplitter().convert(content);
    for (var i = 0; i + 1 < lines.length; i += 2) {
      final code = int.tryParse(lines[i].trim());
      if (code == null) {
        continue;
      }
      pairs.add(DxfPair(code, lines[i + 1].trim()));
    }
    return pairs;
  }

  CadFile _buildFile(
    List<DxfPair> pairs,
    String fileName,
    List<String> warnings,
  ) {
    var version = 'AC1015';
    var insUnits = 4;
    var extMin = const CadPoint3(0, 0, 0);
    var extMax = const CadPoint3(0, 0, 0);
    final layers = <CadLayer>[];
    final blocks = <CadBlock>[];
    final dimStyles = <String, ({double textHeight, double arrowSize})>{};
    final lineTypes = <String, List<double>>{};
    var entities = <CadEntity>[];
    CadBlock? currentBlock;

    var section = '';
    var i = 0;
    while (i < pairs.length) {
      final pair = pairs[i];
      if (pair.code == 0) {
        if (pair.value == 'SECTION') {
          if (i + 1 < pairs.length) {
            section = pairs[i + 1].value;
          }
          i += 2;
          continue;
        }
        if (pair.value == 'ENDSEC') {
          section = '';
          i += 1;
          continue;
        }
        if (section == 'HEADER') {
          final varName = pair.value;
          if (i + 1 < pairs.length) {
            final next = pairs[i + 1];
            switch (varName) {
              case r'$ACADVER':
                version = next.value;
                i += 2;
                continue;
              case r'$INSUNITS':
                insUnits = int.tryParse(next.value) ?? 4;
                i += 2;
                continue;
              case r'$EXTMIN':
                extMin = _readPoint(pairs, i + 1) ?? extMin;
                i = _skipPoint(pairs, i + 1);
                continue;
              case r'$EXTMAX':
                extMax = _readPoint(pairs, i + 1) ?? extMax;
                i = _skipPoint(pairs, i + 1);
                continue;
            }
          }
          i += 2;
          continue;
        }
        if (section == 'TABLES' && pair.value == 'LTYPE') {
          i += 1;
          final lt = _parseLtype(pairs, i);
          if (lt != null) {
            lineTypes[lt.$1] = lt.$2;
          }
          continue;
        }
        if (section == 'TABLES' && pair.value == 'LAYER') {
          i += 1;
          final layer = _parseLayer(pairs, i);
          if (layer != null) {
            layers.add(layer);
          }
          continue;
        }
        if (section == 'TABLES' && pair.value == 'DIMSTYLE') {
          i += 1;
          final style = _parseDimStyle(pairs, i);
          if (style != null) {
            dimStyles[style.name] = (
              textHeight: style.textHeight,
              arrowSize: style.arrowSize,
            );
          }
          continue;
        }
        if (section == 'BLOCKS' && pair.value == 'BLOCK') {
          i += 1;
          final block = _parseBlockHeader(pairs, i);
          if (block != null) {
            blocks.add(block);
            currentBlock = block;
          }
          continue;
        }
        if (pair.value == 'ENDBLK') {
          currentBlock = null;
          i += 1;
          continue;
        }
        if (section == 'ENTITIES' || currentBlock != null) {
          if (pair.value == 'POLYLINE') {
            final poly = _parseHeavyPolylineFull(pairs, i);
            if (poly != null) {
              if (currentBlock != null) {
                currentBlock = currentBlock.copyWith(
                  entities: [...currentBlock.entities, poly.entity],
                );
              } else {
                entities = [...entities, poly.entity];
              }
              i = poly.nextIndex;
            } else {
              i += 1;
            }
            continue;
          }
          final parsed = _parseEntity(pairs, i, warnings, dimStyles);
          if (parsed != null) {
            if (currentBlock != null) {
              currentBlock = currentBlock.copyWith(
                entities: [...currentBlock.entities, parsed],
              );
            } else {
              entities = [...entities, parsed];
            }
          }
          i = _nextEntityStart(pairs, i + 1);
          continue;
        }
      }
      i += 1;
    }

    // Normaliza el bloque *Model_Space: sus entidades son el espacio modelo.
    final modelBlocks = blocks.where((b) => b.name == '*Model_Space').toList();
    if (modelBlocks.isNotEmpty && entities.isEmpty) {
      for (final b in modelBlocks) {
        entities = [...entities, ...b.entities];
      }
    }

    final header = CadHeader(
      units: UnitsType.fromInsUnits(insUnits),
      extMin: extMin,
      extMax: extMax,
      insUnits: insUnits,
    );
    return CadFile(
      fileName: fileName,
      version: version,
      header: header,
      layers: layers.isEmpty ? const [CadLayer(name: '0')] : layers,
      lineTypes: lineTypes,
      entities: entities,
      blocks: blocks.where((b) => !b.name.startsWith('*')).toList(),
    );
  }

  /// Lee un registro LTYPE: nombre (2) y elementos de patrón (49).
  ///
  /// En DXF los elementos 49 son positivos = trazo, negativos = espacio y
  /// 0 = punto. Devuelve `(nombre, patrón)` o `null` si no es válido.
  (String, List<double>)? _parseLtype(List<DxfPair> pairs, int start) {
    String? name;
    final pattern = <double>[];
    var i = start;
    while (i < pairs.length && pairs[i].code != 0) {
      final p = pairs[i];
      switch (p.code) {
        case 2:
          name = p.value;
        case 49:
          final v = double.tryParse(p.value);
          if (v != null) {
            pattern.add(v);
          }
      }
      i += 1;
    }
    if (name == null || pattern.isEmpty) {
      return null;
    }
    return (name, List<double>.unmodifiable(pattern));
  }

  /// Lee un registro DIMSTYLE: nombre (2), altura de texto dimtxt (140) y
  /// tamaño de flecha dimasz (41).
  ({String name, double textHeight, double arrowSize})? _parseDimStyle(
    List<DxfPair> pairs,
    int start,
  ) {
    String? name;
    var textHeight = 0.0;
    var arrowSize = 0.0;
    var i = start;
    while (i < pairs.length && pairs[i].code != 0) {
      final p = pairs[i];
      switch (p.code) {
        case 2:
          name = p.value;
        case 140:
          textHeight = double.tryParse(p.value) ?? 0;
        case 41:
          arrowSize = double.tryParse(p.value) ?? 0;
      }
      i += 1;
    }
    if (name == null) {
      return null;
    }
    return (name: name, textHeight: textHeight, arrowSize: arrowSize);
  }

  CadLayer? _parseLayer(List<DxfPair> pairs, int start) {
    String? name;
    var color = 7;
    var lineType = 'Continuous';
    var i = start;
    while (i < pairs.length && pairs[i].code != 0) {
      final p = pairs[i];
      switch (p.code) {
        case 2:
          name = p.value;
        case 62:
          color = int.tryParse(p.value) ?? 7;
        case 6:
          lineType = p.value;
      }
      i += 1;
    }
    if (name == null) {
      return null;
    }
    return CadLayer(
      name: name,
      color: color.abs().clamp(1, 255),
      lineType: lineType,
      isCurrent: name == '0',
    );
  }

  CadBlock? _parseBlockHeader(List<DxfPair> pairs, int start) {
    String? name;
    var base = const CadPoint3(0, 0, 0);
    var i = start;
    while (i < pairs.length && pairs[i].code != 0) {
      final p = pairs[i];
      switch (p.code) {
        case 2:
          name = p.value;
        case 10:
          base = base.copyWith(x: double.tryParse(p.value) ?? 0);
        case 20:
          base = base.copyWith(y: double.tryParse(p.value) ?? 0);
        case 30:
          base = base.copyWith(z: double.tryParse(p.value) ?? 0);
      }
      i += 1;
    }
    if (name == null) {
      return null;
    }
    return CadBlock(name: name, basePoint: base);
  }

  CadEntity? _parseEntity(
    List<DxfPair> pairs,
    int start,
    List<String> warnings,
    Map<String, ({double textHeight, double arrowSize})> dimStyles,
  ) {
    final type = pairs[start].value;
    var end = start + 1;
    while (end < pairs.length && pairs[end].code != 0) {
      end += 1;
    }
    final entityPairs = pairs.sublist(start + 1, end);
    final byCode = <int, List<String>>{};
    for (final p in entityPairs) {
      byCode.putIfAbsent(p.code, () => <String>[]).add(p.value);
    }

    String first(int code, [String fallback = '']) {
      final list = byCode[code];
      return list == null || list.isEmpty ? fallback : list.first;
    }

    String? lastOrNull(int code) {
      final list = byCode[code];
      return list == null || list.isEmpty ? null : list.last;
    }

    double d(int code, [double fallback = 0]) =>
        double.tryParse(first(code, '')) ?? fallback;

    int ix(int code, [int fallback = 0]) =>
        int.tryParse(first(code, '')) ?? fallback;

    String handle = first(5, '');
    final layer = first(8, '0');
    final color = ix(62, 256);
    final lineType = lastOrNull(6);
    // El grupo 370 está en centésimas de mm (30 = 0.30 mm); valores ≤ 0
    // (BYLAYER/BYBLOCK/DEFAULT) se normalizan a null (heredar).
    final lineWeight = _lineWeightFrom370(double.tryParse(first(370, '')));

    if (handle.isEmpty) {
      handle = 'h${start.toRadixString(16)}';
    }
    final effColor = (color == 256 || color <= 0) ? null : color;

    switch (type) {
      case 'LINE':
        return CadLine(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          x1: d(10), y1: d(20), x2: d(11), y2: d(21),
        );
      case 'CIRCLE':
        return CadCircle(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          cx: d(10), cy: d(20), radius: d(40),
        );
      case 'ARC':
        return CadArc(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          cx: d(10), cy: d(20), radius: d(40),
          startAngle: _degToRad(d(50)), endAngle: _degToRad(d(51)),
        );
      case 'ELLIPSE':
        final majorX = d(11);
        final majorY = d(21);
        final major = math.sqrt(majorX * majorX + majorY * majorY);
        return CadEllipse(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          cx: d(10), cy: d(20),
          majorRadius: major,
          minorRadius: major * d(40),
          rotation: math.atan2(majorY, majorX),
        );
      case 'LWPOLYLINE':
        return _parseLwPolyline(byCode, handle, layer, effColor, lineType, lineWeight);
      case 'VERTEX':
      case 'SEQEND':
        return null;
      case 'TEXT':
        return CadText(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          text: first(1), x: d(10), y: d(20), height: d(40),
          rotation: _degToRad(d(50)), horizontalAlign: ix(72),
        );
      case 'MTEXT':
        final text = (byCode[1] ?? <String>[]).join() + (byCode[3] ?? <String>[]).join();
        return CadMText(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          text: _stripMtextFormatting(text),
          x: d(10), y: d(20), height: d(40),
          rotation: _degToRad(d(50)), width: d(41),
        );
      case 'INSERT':
        return CadInsert(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          blockName: first(2), x: d(10), y: d(20),
          scaleX: byCode.containsKey(41) ? d(41) : 1,
          scaleY: byCode.containsKey(42) ? d(42) : 1,
          rotation: _degToRad(d(50)),
        );
      case 'POINT':
        return CadPoint(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          x: d(10), y: d(20),
        );
      case 'HATCH':
        final hatch = _parseHatch(entityPairs, handle, layer, effColor, lineType, lineWeight);
        if (hatch != null) {
          return hatch;
        }
        warnings.add('HATCH omitido (sin contornos válidos)');
        return null;
      case 'SPLINE':
        return _parseSpline(byCode, handle, layer, effColor, lineType, lineWeight);
      case 'DIMENSION':
        final styleName = first(3, '');
        final style = dimStyles[styleName];
        final entityTextH = d(140);
        final entityArrow = d(41);
        return CadDim(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          dimType: DimType.fromDxfCode(ix(70)),
          x1: d(10), y1: d(20), x2: d(11), y2: d(21),
          x3: d(13), y3: d(23), x4: d(14), y4: d(24),
          text: lastOrNull(1), style: styleName.isEmpty ? null : styleName,
          textHeight: entityTextH != 0
              ? entityTextH
              : (style?.textHeight ?? 0),
          arrowSize: entityArrow != 0
              ? entityArrow
              : (style?.arrowSize ?? 0),
          measurement: byCode.containsKey(42) ? d(42) : null,
        );
      case '3DFACE':
        return Cad3dFace(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          corners: [
            CadPoint3(d(10), d(20), d(30)),
            CadPoint3(d(11), d(21), d(31)),
            CadPoint3(d(12), d(22), d(32)),
            CadPoint3(d(13), d(23), d(33)),
          ],
        );
      case 'SOLID':
      case 'TRACE':
        // SOLID/TRACE: 4 esquinas (10-13/20-23) como 3DFACE; si la 3ª y 4ª
        // coinciden es un triángulo. Se rellena con el color de la entidad.
        return CadSolid(
          handle: handle, layer: layer, color: effColor,
          lineType: lineType, lineWeight: lineWeight,
          corners: [
            CadPoint3(d(10), d(20), d(30)),
            CadPoint3(d(11), d(21), d(31)),
            CadPoint3(d(12), d(22), d(32)),
            CadPoint3(d(13), d(23), d(33)),
          ],
        );
      default:
        warnings.add('Entidad $type no soportada (handle $handle omitido)');
        return null;
    }
  }

  /// POLYLINE pesada R12: lee la POLYLINE, sus VERTEX y termina en SEQEND.
  ///
  /// Devuelve la entidad y el índice justo después de SEQEND.
  ({CadPolyline entity, int nextIndex})? _parseHeavyPolylineFull(
    List<DxfPair> pairs,
    int start,
  ) {
    String handle = '';
    var layer = '0';
    var color = 256;
    String? lineType;
    double? lineWeight;
    var closed = false;
    final vertices = <CadPoint3>[];

    // Header de la POLYLINE.
    var i = start + 1;
    while (i < pairs.length && pairs[i].code != 0) {
      final p = pairs[i];
      switch (p.code) {
        case 5:
          handle = p.value;
        case 8:
          layer = p.value;
        case 62:
          color = int.tryParse(p.value) ?? 256;
        case 6:
          lineType = p.value;
        case 370:
          lineWeight = _lineWeightFrom370(double.tryParse(p.value));
        case 70:
          closed = (int.tryParse(p.value) ?? 0) & 1 == 1;
      }
      i += 1;
    }
    if (handle.isEmpty) {
      handle = 'h${start.toRadixString(16)}';
    }

    // VERTEX…SEQEND.
    while (i < pairs.length && pairs[i].code == 0) {
      final kind = pairs[i].value;
      if (kind == 'SEQEND') {
        var j = i + 1;
        while (j < pairs.length && pairs[j].code != 0) {
          j += 1;
        }
        final effColor = (color == 256 || color <= 0) ? null : color;
        return (
          entity: CadPolyline(
            handle: handle, layer: layer, color: effColor,
            lineType: lineType, lineWeight: lineWeight,
            points: vertices, closed: closed,
          ),
          nextIndex: j,
        );
      }
      if (kind == 'VERTEX') {
        var x = 0.0;
        var y = 0.0;
        var j = i + 1;
        while (j < pairs.length && pairs[j].code != 0) {
          if (pairs[j].code == 10) {
            x = double.tryParse(pairs[j].value) ?? 0;
          } else if (pairs[j].code == 20) {
            y = double.tryParse(pairs[j].value) ?? 0;
          }
          j += 1;
        }
        vertices.add(CadPoint3(x, y));
        i = j;
        continue;
      }
      break;
    }
    return null;
  }

  CadEntity _parseLwPolyline(
    Map<int, List<String>> byCode,
    String handle,
    String layer,
    int? color,
    String? lineType,
    double? lineWeight,
  ) {
    final xs = byCode[10] ?? const <String>[];
    final ys = byCode[20] ?? const <String>[];
    final bulges = byCode[42] ?? const <String>[];
    final vertices = <LwVertex>[];
    for (var i = 0; i < xs.length; i++) {
      final x = double.tryParse(xs[i]) ?? 0.0;
      final y = i < ys.length ? (double.tryParse(ys[i]) ?? 0.0) : 0.0;
      final b = i < bulges.length ? (double.tryParse(bulges[i]) ?? 0.0) : 0.0;
      vertices.add(LwVertex(x, y, bulge: b));
    }
    final closed = (int.tryParse((byCode[70] ?? const ['0']).first) ?? 0) & 1 == 1;
    return CadLwPolyline(
      handle: handle, layer: layer, color: color,
      lineType: lineType, lineWeight: lineWeight,
      points: vertices, closed: closed,
    );
  }

  CadHatch? _parseHatch(
    List<DxfPair> entityPairs,
    String handle,
    String layer,
    int? color,
    String? lineType,
    double? lineWeight,
  ) {
    var pattern = 'SOLID';
    final boundaries = <HatchBoundary>[];
    var current = <CadPoint3>[];
    var vertexCount = 0;
    for (final p in entityPairs) {
      switch (p.code) {
        case 2:
          pattern = p.value;
        case 93:
          vertexCount = int.tryParse(p.value) ?? 0;
          if (current.isNotEmpty) {
            boundaries.add(HatchBoundary(points: List.of(current)));
            current = [];
          }
        case 10:
          if (vertexCount == 0 || current.length < vertexCount) {
            current.add(CadPoint3(double.tryParse(p.value) ?? 0, 0));
          }
        case 20:
          if (current.isNotEmpty) {
            final last = current.removeLast();
            current.add(last.copyWith(y: double.tryParse(p.value) ?? 0));
          }
      }
    }
    if (current.isNotEmpty) {
      boundaries.add(HatchBoundary(points: List.of(current)));
    }
    if (boundaries.isEmpty) {
      return null;
    }
    return CadHatch(
      handle: handle, layer: layer, color: color,
      lineType: lineType, lineWeight: lineWeight,
      patternName: pattern, boundaries: boundaries,
    );
  }

  CadEntity _parseSpline(
    Map<int, List<String>> byCode,
    String handle,
    String layer,
    int? color,
    String? lineType,
    double? lineWeight,
  ) {
    final xs = byCode[10] ?? const <String>[];
    final ys = byCode[20] ?? const <String>[];
    final cps = <CadPoint3>[];
    for (var i = 0; i < xs.length && i < ys.length; i++) {
      cps.add(CadPoint3(double.tryParse(xs[i]) ?? 0, double.tryParse(ys[i]) ?? 0));
    }
    final knots = (byCode[40] ?? const <String>[])
        .map((v) => double.tryParse(v) ?? 0)
        .toList();
    return CadSpline(
      handle: handle, layer: layer, color: color,
      lineType: lineType, lineWeight: lineWeight,
      degree: int.tryParse((byCode[71] ?? const ['3']).first) ?? 3,
      controlPoints: cps, knots: knots,
    );
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  /// Convierte el grupo DXF 370 (centésimas de mm) a mm; ≤ 0 → null.
  double? _lineWeightFrom370(double? raw) {
    if (raw == null || raw <= 0) {
      return null;
    }
    return raw / 100.0;
  }

  CadPoint3? _readPoint(List<DxfPair> pairs, int start) {
    if (start + 2 >= pairs.length) {
      return null;
    }
    final x = double.tryParse(pairs[start].value);
    final y = double.tryParse(pairs[start + 1].value);
    if (x == null || y == null) {
      return null;
    }
    return CadPoint3(x, y, double.tryParse(pairs[start + 2].value) ?? 0);
  }

  int _skipPoint(List<DxfPair> pairs, int start) {
    var i = start;
    while (i < pairs.length &&
        (pairs[i].code == 10 || pairs[i].code == 20 || pairs[i].code == 30)) {
      i += 1;
    }
    return i;
  }

  int _nextEntityStart(List<DxfPair> pairs, int start) {
    var i = start;
    while (i < pairs.length && pairs[i].code != 0) {
      i += 1;
    }
    return i;
  }

  String _stripMtextFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\{[^}]*;'), '')
        .replaceAll('}', '')
        .replaceAll(r'\P', '')
        .trim();
  }
}

/// Par (código de grupo, valor) de un DXF ASCII.
class DxfPair {
  const DxfPair(this.code, this.value);

  /// Código de grupo.
  final int code;

  /// Valor (string).
  final String value;
}
