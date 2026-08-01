import 'dart:io';
import 'package:cad_viewer/models/cad_entity.dart';
import 'package:cad_viewer/parsers/dxf_parser.dart';

void main() {
  final bytes = File('files_cad/banera.dxf').readAsBytesSync();
  final result = DxfParserWrapper().parseBytes(bytes, fileName: 'banera.dxf');
  final file = result.cadFile!;
  print('error: ${result.error}');
  print('warnings: ${result.warnings}');
  for (final b in file.blocks) {
    print('bloque "${b.name}": ${b.entities.length} entidades');
    for (final e in b.entities.take(3)) print('  ${e.runtimeType}');
  }
  final inserts = file.entities.whereType<CadInsert>().toList();
  print('INSERTS: ${inserts.length}');
  for (final i in inserts) {
    final blk = file.blockByName(i.blockName);
    print('  insert "${i.blockName}" -> bloque ${blk == null ? 'NO EXISTE' : '${blk.entities.length} entidades'}');
  }
}
