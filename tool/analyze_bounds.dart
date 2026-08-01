import 'dart:io';
import 'dart:math' as math;

import 'package:cad_viewer/parsers/dxf_parser.dart';
import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/models/cad_file.dart';
import 'package:cad_viewer/models/bounds.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'files_cad/original.dxf';
  final content = File(path).readAsStringSync();
  final res = const DxfParserWrapper().parse(content, fileName: path);
  if (res.error != null) {
    print('ERROR: ${res.error}');
    return;
  }
  final file = res.cadFile!;
  print('entidades modelo: ${file.entities.length}');
  print('bloques: ${file.blocks.length}');
  final b = file.getBounds();
  print('bounds app: min=(${b.minX}, ${b.minY}) max=(${b.maxX}, ${b.maxY})');

  // Encontrar las entidades que alcanzan los extremos.
  var maxX = -1e300, maxY = -1e300, minX = 1e300, minY = 1e300;
  CadEntity? worstX, worstY;
  for (final e in file.entities) {
    final eb = entityBoundsInFile(e, file);
    if (!eb.isEmpty) {
      if (eb.maxX > maxX) { maxX = eb.maxX; worstX = e; }
      if (eb.maxY > maxY) { maxY = eb.maxY; worstY = e; }
      if (eb.minX < minX) minX = eb.minX;
      if (eb.minY < minY) minY = eb.minY;
    }
  }
  String desc(CadEntity e) {
    if (e is CadInsert) return 'INSERT bloque=${e.blockName} @(${e.x}, ${e.y}) escala=${e.scaleX},${e.scaleY} rot=${e.rotation}';
    return '${e.type}';
  }
  print('extremos por entidad: maxX=$maxX (${worstX != null ? desc(worstX!) : '-'})');
  print('                      maxY=$maxY (${worstY != null ? desc(worstY!) : '-'})');
  print('                      minX=$minX minY=$minY');

  // Revisar los bloques con bounds grandes.
  for (final blk in file.blocks) {
    final bb = blk.getBounds();
    if (bb.maxX > 1800 || bb.maxY > 2000 || bb.minX < -1000 || bb.minY < -1000) {
      print('BLOQUE ${blk.name} entities=${blk.entities.length} bounds=(${bb.minX},${bb.minY})-(${bb.maxX},${bb.maxY})');
    }
  }
}
