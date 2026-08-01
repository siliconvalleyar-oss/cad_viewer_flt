/// Joystick transparente de paneo del lienzo.
///
/// Arrastre circular: mover el pomo panear la vista (misma dirección que el
/// desplazamiento del dedo). Al soltar vuelve al centro. Es translúcido para
/// no tapar el dibujo y se oculta/muestra desde Ajustes (BUG-28).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../theme/app_theme.dart';

/// Joystick transparente que llama a [CadViewModel.panBy].
class Joystick extends StatefulWidget {
  const Joystick({super.key});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _radius = 42;
  static const double _knobRadius = 20;
  static const double _maxOffset = _radius - _knobRadius;

  Offset _knob = Offset.zero;

  void _onPanUpdate(DragUpdateDetails d, CadViewModel vm) {
    final next = _knob + d.delta;
    if (next.distance > _maxOffset) {
      _knob = next / next.distance * _maxOffset;
    } else {
      _knob = next;
    }
    vm.panBy(d.delta.dx, d.delta.dy);
    setState(() {});
  }

  void _onPanEnd() {
    setState(() => _knob = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    final knobCenter = Offset.zero + _knob;

    return SizedBox(
      width: _radius * 2,
      height: _radius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _onPanUpdate(d, context.read<CadViewModel>()),
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        child: CustomPaint(
          painter: _JoystickPainter(
            knobCenter: knobCenter,
            color: palette.textPrimary,
            accent: palette.accent,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobCenter,
    required this.color,
    required this.accent,
  });

  final Offset knobCenter;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Base circular translúcida (borde fino, sin relleno para ver el dibujo).
    canvas.drawCircle(
      center,
      _JoystickState._radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      center,
      _JoystickState._radius,
      Paint()..color = color.withValues(alpha: 0.05),
    );
    // Cruz de referencia central.
    final cross = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      center - const Offset(_JoystickState._radius, 0),
      center + const Offset(_JoystickState._radius, 0),
      cross,
    );
    canvas.drawLine(
      center - const Offset(0, _JoystickState._radius),
      center + const Offset(0, _JoystickState._radius),
      cross,
    );
    // Pomos: exterior translúcido + núcleo de acento.
    final knob = center + knobCenter;
    canvas.drawCircle(
      knob,
      _JoystickState._knobRadius,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      knob,
      8,
      Paint()..color = accent.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.knobCenter != knobCenter ||
      old.color != color ||
      old.accent != accent;
}
