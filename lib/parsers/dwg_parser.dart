/// Soporte DWG (docs/FORMATS.md §6, ADR-0005).
///
/// MVP (v0.1–v0.2): el formato DWG es binario y propietario de Autodesk; no
/// existe un parser Dart puro. `DwgParser` detecta la versión por magic bytes
/// (`AC10xx`) y devuelve la guía de conversión a DXF (ODA File Converter,
/// local y gratuito). v0.3+ invocará el CLI de ODA.
library;

/// Resultado de la detección DWG.
class DwgInfo {
  const DwgInfo({required this.version, required this.guide});

  /// Versión detectada (p. ej. 'AC1015').
  final String version;

  /// Guía de conversión para el usuario.
  final String guide;
}

/// Parser/mensajero DWG.
class DwgParser {
  const DwgParser();

  /// Detecta la versión DWG a partir de los primeros bytes.
  DwgInfo detect(String header) {
    var version = 'desconocida';
    if (header.startsWith('AC1009')) {
      version = 'R12';
    } else if (header.startsWith('AC1012')) {
      version = 'R13';
    } else if (header.startsWith('AC1014')) {
      version = 'R14';
    } else if (header.startsWith('AC1015')) {
      version = 'R2000';
    } else if (header.startsWith('AC1018')) {
      version = 'R2004';
    } else if (header.startsWith('AC1021')) {
      version = 'R2007';
    } else if (header.startsWith('AC1024')) {
      version = 'R2010';
    } else if (header.startsWith('AC1027')) {
      version = 'R2013';
    } else if (header.startsWith('AC1032')) {
      version = 'R2018';
    }
    return DwgInfo(
      version: version,
      guide: 'El formato DWG (versión $version) es binario y propietario. '
          'Para abrirlo, conviértalo a DXF con ODA File Converter '
          '(https://www.opendesign.com/guestfiles/oda_file_converter), '
          'gratuito y 100% local: sus planos nunca salen de este dispositivo.',
    );
  }
}
