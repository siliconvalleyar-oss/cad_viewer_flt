/// Detección de formato y lectura segura de archivos (docs/FORMATS.md §8).
///
/// - Detecta formato por extensión y por magic bytes (DWG empieza con
///   `AC10xx`, RF-CARGA-03).
/// - Detecta DXF binario (primer byte 0x41 = 'A' ASCII es DXF de texto; el
///   binario empieza con 'AutoCAD Binary DXF').
/// - Lectura con try-catch y feedback (RULES.md B1).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/cad_enums.dart';

/// Resultado de detección de formato.
class DetectedFile {
  const DetectedFile({required this.format, this.isBinary = false});

  /// Formato detectado.
  final FileFormat format;

  /// `true` si es DXF binario (no soportado en v1.0).
  final bool isBinary;
}

/// Detecta el formato de un archivo por extensión y contenido.
DetectedFile detectFormat(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.dwg')) {
    // Magic bytes DWG: "AC10xx" en los primeros bytes (RF-CARGA-03).
    final text = _firstAscii(bytes);
    if (text.startsWith('AC10') || text.startsWith('AC1')) {
      return const DetectedFile(format: FileFormat.dwg);
    }
    return const DetectedFile(format: FileFormat.dwg);
  }
  if (lower.endsWith('.dgn')) {
    return const DetectedFile(format: FileFormat.dgn);
  }
  if (lower.endsWith('.dxf')) {
    final text = _firstAscii(bytes);
    if (text.startsWith('AutoCAD Binary DXF')) {
      return const DetectedFile(format: FileFormat.dxf, isBinary: true);
    }
    return const DetectedFile(format: FileFormat.dxf);
  }
  // Sin extensión: inspeccionar contenido.
  final text = _firstAscii(bytes);
  if (text.startsWith('AutoCAD Binary DXF')) {
    return const DetectedFile(format: FileFormat.dxf, isBinary: true);
  }
  if (text.startsWith('AC10') || text.startsWith('AC1')) {
    return const DetectedFile(format: FileFormat.dwg);
  }
  return const DetectedFile(format: FileFormat.unknown);
}

/// Lee un archivo con manejo de errores. Devuelve `null` si falla.
Future<Uint8List?> readFileSafe(File file) async {
  try {
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  } catch (e) {
    return null;
  }
}

/// Escribe contenido a un archivo con `flush: true` (RULES.md B1).
Future<bool> writeFileSafe(File file, String content) async {
  try {
    await file.parent.create(recursive: true);
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeString(content);
      await raf.flush();
    } finally {
      await raf.close();
    }
    return true;
  } catch (e) {
    return false;
  }
}

/// Primeros bytes como ASCII (tolera caracteres no ASCII).
String _firstAscii(Uint8List bytes) {
  final length = bytes.length < 32 ? bytes.length : 32;
  return latin1.decode(bytes.sublist(0, length), allowInvalid: true);
}
