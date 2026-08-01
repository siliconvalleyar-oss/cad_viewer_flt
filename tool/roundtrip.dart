import 'dart:io';

import 'package:cad_viewer/parsers/dxf_parser.dart';
import 'package:cad_viewer/parsers/dxf_writer.dart';
import 'package:cad_viewer/models/cad_document.dart';
import 'package:cad_viewer/models/cad_file.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'files_cad/original.dxf';
  final ver = args.length > 1 ? args[1] : 'r2000';
  final content = File(path).readAsStringSync();
  final res = const DxfParserWrapper().parse(content, fileName: path);
  if (res.error != null) {
    print('ERROR parse: ${res.error}');
    return;
  }
  final file = res.cadFile!;
  final doc = CadDocument.fromCadFile(file);
  final out = doc.exportCadFile();

  final w = DxfWriter();
  final wr = w.write(out, version: ver == 'r12' ? DxfWriteVersion.r12 : DxfWriteVersion.r2000);
  if (wr.error != null) {
    print('ERROR write: ${wr.error}');
    return;
  }
  print('writer warnings (${ver}): ${wr.warnings.length}');
  for (final ww in wr.warnings.take(5)) {
    print('  warning: $ww');
  }
  final outPath = '/tmp/opencode/roundtrip_$ver.dxf';
  File(outPath).writeAsStringSync(wr.content!);
  print('guardado: $outPath (${wr.content!.length} chars)');

  // Re-parsear el guardado y comparar.
  final res2 = const DxfParserWrapper().parse(wr.content!, fileName: outPath);
  final f2 = res2.cadFile!;
  print('== re-parse del guardado ==');
  print('warnings: ${res2.warnings!.length}');
  for (final ww in res2.warnings!.take(10)) {
    print('  warning: $ww');
  }
  print('entidades modelo: antes=${file.entities.length} despues=${f2.entities.length}');
  print('bloques: antes=${file.blocks.length} despues=${f2.blocks.length}');
  final b0 = file.getBounds();
  final b1 = out.getBounds();
  final b2 = f2.getBounds();
  print('bounds antes:  (${b0.minX},${b0.minY})-(${b0.maxX},${b0.maxY})');
  print('bounds export: (${b1.minX},${b1.minY})-(${b1.maxX},${b1.maxY})');
  print('bounds reparse:(${b2.minX},${b2.minY})-(${b2.maxX},${b2.maxY})');

  // contar entidades por tipo antes/despues
  int count(Iterable e, String type) =>
      e.where((x) => x.type.toString().contains(type)).length;
  print('== entidades por tipo ==');
  final types = ['line', 'circle', 'arc', 'lwpolyline', 'insert', 'text', 'mtext',
                 'hatch', 'dim', 'point', 'solid', 'ellipse', 'spline', 'polyline', '3dface'];
  for (final t in types) {
    final a = count(file.entities, t);
    final c = count(f2.entities, t);
    if (a != c) {
      print('  $t: antes=$a despues=$c   <== DIFERENCIA');
    }
  }
  print('== entidades DENTRO de bloques por tipo ==');
  final typesB = {'line': 0, 'solid': 0, 'mtext': 0, 'lwpolyline': 0, 'arc': 0, 'circle': 0, 'hatch': 0};
  int countB(List blocks, String type) {
    var n = 0;
    for (final blk in blocks) {
      for (final e in blk.entities) {
        if (e.type.toString().contains(type)) n++;
      }
    }
    return n;
  }
  for (final t in typesB.keys) {
    final a = countB(file.blocks, t);
    final c = countB(f2.blocks, t);
    if (a != c) {
      print('  bloque $t: antes=$a despues=$c   <== DIFERENCIA');
    }
  }
}
