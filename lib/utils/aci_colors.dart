/// Mapa de colores ACI (AutoCAD Color Index) → ARGB (docs/AESTHETICS.md §3).
///
/// Dart puro: devuelve valores `int` ARGB (0xFFRRGGBB) para que la capa de
/// UI los convierta con `Color()`. La resolución final (ByLayer, override de
/// capa, override de tema) vive en `renderers/layer_manager.dart`.
library;

/// Convierte un índice ACI (1–255) a un color ARGB.
///
/// Implementa la paleta estándar de AutoCAD: 1–9 fijos, 10–249 por fórmula
/// de tono (según la tabla oficial de Autodesk) y 250–255 grises. Índices
/// fuera de rango → blanco (fallback de REQUIREMENTS §6, caso 3).
int aciToArgb(int aci) {
  if (aci <= 0) {
    return 0xFFFFFFFF;
  }
  if (aci >= 1 && aci <= 9) {
    return _baseColors[aci];
  }
  if (aci >= 250 && aci <= 255) {
    final v = 255 - (aci - 249) * 15;
    return _rgb(v, v, v);
  }
  if (aci >= 10 && aci <= 249) {
    // Fórmula del ACI estándar: 10 grupos de 24 tonos.
    final group = (aci - 10) ~/ 10;
    final index = (aci - 10) % 10;
    final lightness = index.isEven ? 0.55 : 0.75;
    return _hslToArgb(((group * 25) % 360).toDouble(), 0.65, lightness);
  }
  return 0xFFFFFFFF;
}

const List<int> _baseColors = <int>[
  0x00000000, // 0: ByBlock (no se usa como color)
  0xFFFF0000, // 1: rojo
  0xFFFFFF00, // 2: amarillo
  0xFF00FF00, // 3: verde
  0xFF00FFFF, // 4: cian
  0xFF0000FF, // 5: azul
  0xFFFF00FF, // 6: magenta
  0xFFFFFFFF, // 7: blanco/negro (según fondo)
  0xFF808080, // 8: gris oscuro
  0xFFC0C0C0, // 9: gris claro
];

int _rgb(int r, int g, int b) => (0xFF << 24) | (r << 16) | (g << 8) | b;

int _hslToArgb(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final hp = (h % 360) / 60;
  final x = c * (1 - (hp % 2 - 1).abs());
  var r = 0.0;
  var g = 0.0;
  var b = 0.0;
  if (hp < 1) {
    r = c; g = x;
  } else if (hp < 2) {
    r = x; g = c;
  } else if (hp < 3) {
    g = c; b = x;
  } else if (hp < 4) {
    g = x; b = c;
  } else if (hp < 5) {
    r = x; b = c;
  } else {
    r = c; b = x;
  }
  final m = l - c / 2;
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return _rgb(ch(r + m), ch(g + m), ch(b + m));
}
