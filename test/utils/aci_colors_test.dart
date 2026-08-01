import 'package:cad_viewer/utils/aci_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativeLuminance / contrastRatio (WCAG)', () {
    test('blanco vs negro = contraste máximo (21)', () {
      expect(relativeLuminance(0xFFFFFFFF), closeTo(1.0, 1e-3));
      expect(relativeLuminance(0xFF000000), closeTo(0.0, 1e-3));
      expect(contrastRatio(0xFFFFFFFF, 0xFF000000), closeTo(21, 0.2));
    });

    test('blanco sobre blanco = contraste mínimo (1)', () {
      expect(contrastRatio(0xFFFFFFFF, 0xFFFFFFFF), closeTo(1.0, 1e-3));
    });
  });

  group('ensureContrast (fix capas invisibles en tema claro)', () {
    const whiteBg = 0xFFFFFFFF; // lienzo del tema "Claro"
    const darkBg = 0xFF1E2128; // lienzo del tema "Oscuro"

    test('ACI 7 (blanco) sobre fondo claro se oscurece (era invisible)', () {
      final result = ensureContrast(0xFFFFFFFF, whiteBg);
      expect(result, isNot(0xFFFFFFFF));
      expect(contrastRatio(result, whiteBg), greaterThanOrEqualTo(3.0));
      // Debe quedar claramente más oscuro que el blanco puro.
      expect(relativeLuminance(result), lessThan(0.6));
    });

    test('blanco sobre fondo oscuro se mantiene (ya tiene contraste)', () {
      expect(ensureContrast(0xFFFFFFFF, darkBg), 0xFFFFFFFF);
    });

    test('amarillo (ACI 2) sobre fondo claro se oscurece lo necesario', () {
      final result = ensureContrast(0xFFFFFF00, whiteBg);
      expect(contrastRatio(result, whiteBg), greaterThanOrEqualTo(3.0));
    });

    test('rojo (ACI 1) sobre fondo claro se mantiene (ya tiene contraste)', () {
      // Rojo puro ≈ contraste 4 sobre blanco.
      final result = ensureContrast(0xFFFF0000, whiteBg);
      expect(contrastRatio(result, whiteBg), greaterThanOrEqualTo(3.0));
    });

    test('color oscuro sobre fondo claro no se toca (ya visible)', () {
      expect(ensureContrast(0xFF1A202C, whiteBg), 0xFF1A202C);
    });

    test('color muy oscuro sobre fondo oscuro se aclara', () {
      // 0xFF3A3F4A (outline del tema) sobre 0xFF1E2128: contraste ≈ 1.5 < 3.
      final low = ensureContrast(0xFF3A3F4A, darkBg);
      expect(contrastRatio(low, darkBg), greaterThanOrEqualTo(3.0));
      // Debe quedar más claro que el original.
      expect(relativeLuminance(low), greaterThan(relativeLuminance(0xFF3A3F4A)));
    });

    test('gris medio (ACI 8) sobre fondo oscuro ya cumple contraste', () {
      // 0xFF808080 sobre 0xFF1E2128 ≈ 4.1: no debe tocarse.
      expect(ensureContrast(0xFF808080, darkBg), 0xFF808080);
    });
  });
}
