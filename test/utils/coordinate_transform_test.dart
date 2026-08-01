import 'package:cad_viewer/models/bounds.dart';
import 'package:cad_viewer/utils/coordinate_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoordinateTransform (Y invertida, fix volteo 180°)', () {
    test('worldToScreenY invierte Y: mundo arriba → pantalla arriba', () {
      const t = CoordinateTransform(scale: 2, offsetX: 0, offsetY: 100);
      // En mundo, +Y es arriba; en pantalla, y=0 es arriba.
      // wy=50 (arriba en mundo) debe quedar por encima de wy=-50 (abajo).
      expect(t.worldToScreenY(50), lessThan(t.worldToScreenY(-50)));
      // round-trip exacto.
      expect(t.screenToWorldY(t.worldToScreenY(50)), closeTo(50, 1e-9));
      expect(t.worldToScreenY(t.screenToWorldY(37)), closeTo(37, 1e-9));
    });

    test('fitToScreen centra el bounds y mantiene la orientación', () {
      final b = Bounds(minX: 0, minY: 0, maxX: 100, maxY: 50);
      final t = CoordinateTransform.fitToScreen(b, 400, 300);
      // El centro del mundo (50, 25) debe quedar en el centro del viewport.
      expect(t.worldToScreenX(50), closeTo(200, 0.5));
      expect(t.worldToScreenY(25), closeTo(150, 0.5));
      // maxY del mundo (arriba) → pantalla arriba (menor que el centro).
      expect(t.worldToScreenY(50), lessThan(t.worldToScreenY(25)));
      expect(t.worldToScreenY(0), greaterThan(t.worldToScreenY(50)));
    });

    test('zoomAt mantiene el punto del mundo bajo el cursor (Y invertida)', () {
      // Simula la operación del ViewModel con la Y invertida.
      const t0 = CoordinateTransform(scale: 2, offsetX: 10, offsetY: 100);
      const factor = 2.0;
      const screenX = 200.0;
      const screenY = 150.0;
      final wx = (screenX - t0.offsetX) / t0.scale;
      final wy = (t0.offsetY - screenY) / t0.scale;
      final newScale = (t0.scale * factor).clamp(0.0001, 1000000.0);
      final t1 = CoordinateTransform(
        scale: newScale,
        offsetX: screenX - wx * newScale,
        offsetY: screenY + wy * newScale,
      );
      expect(t1.worldToScreenX(wx), closeTo(screenX, 1e-6));
      expect(t1.worldToScreenY(wy), closeTo(screenY, 1e-6));
    });

    test('screenToWorldX sin cambios (solo Y se invierte)', () {
      const t = CoordinateTransform(scale: 3, offsetX: 5, offsetY: 0);
      expect(t.screenToWorldX(35), closeTo(10, 1e-9));
    });
  });

  group('CoordinateTransform (rotate180, fix UCS rotado)', () {
    test('worldToScreenX/Y niegan ambos ejes (rotación 180° en plano)', () {
      const t = CoordinateTransform(
        scale: 2,
        offsetX: 100,
        offsetY: 50,
        rotate180: true,
      );
      // Con rotate180: sx = -wx*s + ox ; sy = wy*s + oy.
      expect(t.worldToScreenX(10), closeTo(80, 1e-9)); // -20 + 100
      expect(t.worldToScreenY(10), closeTo(70, 1e-9)); // 20 + 50
      // Round-trip exacto.
      expect(t.screenToWorldX(t.worldToScreenX(33)), closeTo(33, 1e-9));
      expect(t.screenToWorldY(t.worldToScreenY(-21)), closeTo(-21, 1e-9));
    });

    test('fitToScreen con rotate180 centra el bounds', () {
      final b = Bounds(minX: 0, minY: 0, maxX: 100, maxY: 50);
      final t = CoordinateTransform.fitToScreen(b, 400, 300, rotate180: true);
      expect(t.rotate180, isTrue);
      // El centro del mundo (50, 25) debe quedar en el centro del viewport.
      expect(t.worldToScreenX(50), closeTo(200, 0.5));
      expect(t.worldToScreenY(25), closeTo(150, 0.5));
      // maxY del mundo (arriba) → pantalla ABAJO (rotación 180°).
      expect(t.worldToScreenY(50), greaterThan(t.worldToScreenY(25)));
      expect(t.worldToScreenX(0), greaterThan(t.worldToScreenX(100)));
    });

    test('zoomAt mantiene el punto del mundo bajo el cursor (rotate180)', () {
      const t0 = CoordinateTransform(
        scale: 2,
        offsetX: 10,
        offsetY: 20,
        rotate180: true,
      );
      const screenX = 200.0;
      const screenY = 150.0;
      final wx = t0.screenToWorldX(screenX);
      final wy = t0.screenToWorldY(screenY);
      final t1 = t0.zoomAt(2.0, screenX, screenY);
      expect(t1.rotate180, isTrue);
      expect(t1.worldToScreenX(wx), closeTo(screenX, 1e-6));
      expect(t1.worldToScreenY(wy), closeTo(screenY, 1e-6));
    });

    test('isVisible robusto con el orden de esquinas invertido', () {
      final b = Bounds(minX: 0, minY: 0, maxX: 10, maxY: 10);
      const t = CoordinateTransform(
        scale: 2,
        offsetX: 100,
        offsetY: 50,
        rotate180: true,
      );
      // sx = -2x+100 → rango [80, 100]; sy = 2y+50 → [50, 70]: visible.
      expect(t.isVisible(b, 400, 300), isTrue);
      // Fuera del viewport (lejos a la derecha en mundo → pantalla izquierda).
      const far = Bounds(minX: 1000, minY: 1000, maxX: 1010, maxY: 1010);
      expect(t.isVisible(far, 400, 300), isFalse);
    });
  });

  group('CoordinateTransform (flipX/flipY, fix archivos espejados)', () {
    test('flipX niega X en pantalla (espejo horizontal); round-trip', () {
      const t = CoordinateTransform(
        scale: 2,
        offsetX: 100,
        offsetY: 50,
        flipX: true,
      );
      // sx = -2x + 100
      expect(t.worldToScreenX(10), closeTo(80, 1e-9)); // -20 + 100
      expect(t.worldToScreenX(-10), closeTo(120, 1e-9)); // 20 + 100
      // Y sigue invertida como la vista normal.
      expect(t.worldToScreenY(10), closeTo(30, 1e-9)); // -20 + 50
      expect(t.screenToWorldX(t.worldToScreenX(33)), closeTo(33, 1e-9));
      expect(t.screenToWorldY(t.worldToScreenY(-21)), closeTo(-21, 1e-9));
    });

    test('flipY no invierte Y (espejo vertical); round-trip', () {
      const t = CoordinateTransform(
        scale: 2,
        offsetX: 100,
        offsetY: 50,
        flipY: true,
      );
      // sy = +2y + 50 (Y NO invertida)
      expect(t.worldToScreenY(10), closeTo(70, 1e-9)); // 20 + 50
      expect(t.worldToScreenY(-10), closeTo(30, 1e-9)); // -20 + 50
      // X sin cambios.
      expect(t.worldToScreenX(10), closeTo(120, 1e-9)); // 20 + 100
      expect(t.screenToWorldX(t.worldToScreenX(33)), closeTo(33, 1e-9));
      expect(t.screenToWorldY(t.worldToScreenY(-21)), closeTo(-21, 1e-9));
    });

    test('flipX + rotate180 equivale a flipY (XOR de signos)', () {
      // Offsets no nulos: con offset 0 el signo se enmascara y la
      // comparación pasaría aunque los signos estuvieran mal.
      const a = CoordinateTransform(
        scale: 2, offsetX: 37, offsetY: 19, flipY: true,
      );
      const b = CoordinateTransform(
        scale: 2, offsetX: 37, offsetY: 19, rotate180: true, flipX: true,
      );
      expect(b.signX, a.signX); // +1
      expect(b.signY, a.signY); // +1
      expect(b.worldToScreenX(5), a.worldToScreenX(5));
      expect(b.worldToScreenY(5), a.worldToScreenY(5));
      expect(b.worldToScreenX(-5), a.worldToScreenX(-5));
      expect(b.worldToScreenY(-5), a.worldToScreenY(-5));
    });

    test('fitToScreen con flipX/flipY centra el bounds', () {
      final b = Bounds(minX: 0, minY: 0, maxX: 100, maxY: 50);
      final tx = CoordinateTransform.fitToScreen(b, 400, 300, flipX: true);
      expect(tx.flipX, isTrue);
      expect(tx.worldToScreenX(50), closeTo(200, 0.5));
      expect(tx.worldToScreenY(25), closeTo(150, 0.5));
      final ty = CoordinateTransform.fitToScreen(b, 400, 300, flipY: true);
      expect(ty.flipY, isTrue);
      expect(ty.worldToScreenX(50), closeTo(200, 0.5));
      expect(ty.worldToScreenY(25), closeTo(150, 0.5));
    });

    test('zoomAt mantiene el punto bajo el cursor con flipX y flipY', () {
      const t0 = CoordinateTransform(
        scale: 2, offsetX: 10, offsetY: 20, flipX: true, flipY: true,
      );
      const screenX = 200.0;
      const screenY = 150.0;
      final wx = t0.screenToWorldX(screenX);
      final wy = t0.screenToWorldY(screenY);
      final t1 = t0.zoomAt(2.0, screenX, screenY);
      expect(t1.flipX, isTrue);
      expect(t1.flipY, isTrue);
      expect(t1.worldToScreenX(wx), closeTo(screenX, 1e-6));
      expect(t1.worldToScreenY(wy), closeTo(screenY, 1e-6));
    });

    test('screenAngle refleja según espejo (no suma π como el giro)', () {
      // Los ángulos de screenAngle pueden quedar fuera de (-π, π] (p. ej.
      // espejo X devuelve θ+π); se comparan módulo 2π porque representan
      // el mismo ángulo en pantalla (canvas.rotate es periódico).
      double norm(double a) {
        // En Dart, % con divisor positivo siempre devuelve ≥ 0.
        const twoPi = 6.283185307179586;
        return a % twoPi;
      }

      // Base (Y invertida): -θ.
      const base = CoordinateTransform(scale: 1, offsetX: 0, offsetY: 0);
      expect(norm(base.screenAngle(0.5)), closeTo(norm(-0.5), 1e-9));
      expect(base.sweepSign, -1);
      // Giro 180°: -θ + π.
      const rot = CoordinateTransform(scale: 1, offsetX: 0, offsetY: 0, rotate180: true);
      expect(norm(rot.screenAngle(0.5)), closeTo(norm(-0.5 + 3.141592653589793), 1e-9));
      // Espejo X: θ + π ≡ θ - π (refleja, no rota).
      const fx = CoordinateTransform(scale: 1, offsetX: 0, offsetY: 0, flipX: true);
      expect(norm(fx.screenAngle(0.5)), closeTo(norm(0.5 + 3.141592653589793), 1e-9));
      expect(fx.sweepSign, 1);
      // Espejo Y: θ (no invierte Y).
      const fy = CoordinateTransform(scale: 1, offsetX: 0, offsetY: 0, flipY: true);
      expect(norm(fy.screenAngle(0.5)), closeTo(norm(0.5), 1e-9));
      expect(fy.sweepSign, 1);
      // screenVectorAngle (atan2): espejo X refleja la dirección a -x, que
      // es π o -π según el signo del cero (atan2(-0.0, -1.0) = -π); se
      // compara módulo 2π.
      expect(norm(fx.screenVectorAngle(1, 0)), closeTo(norm(3.141592653589793), 1e-9));
      expect(norm(base.screenVectorAngle(1, 0)), closeTo(0, 1e-9));
      expect(norm(fy.screenVectorAngle(1, 0)), closeTo(0, 1e-9));
      // flipX: el vector mundo (0,1) (arriba) se refleja a (0,-1) → -π/2.
      expect(norm(fx.screenVectorAngle(0, 1)), closeTo(norm(-1.5707963267948966), 1e-9));
    });
  });
}
