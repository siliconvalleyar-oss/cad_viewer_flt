/// Punto de entrada de CAD Viewer & Editor (docs/ARCHITECTURE.md §2).
///
/// - `CadViewModel` (ChangeNotifier) expuesto con `provider`.
/// - Tema dinámico según `AppThemeMode` (6 temas, AESTHETICS.md).
/// - Splash animado (stroke-dashoffset 1.5s) → Home.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/cad_view_model.dart';
import 'models/cad_enums.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CadViewModel(),
      child: const CadViewerApp(),
    ),
  );
}

/// Raíz de la aplicación.
class CadViewerApp extends StatelessWidget {
  const CadViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<CadViewModel, AppThemeMode>((v) => v.themeMode);
    final palette = AppThemes.byMode(themeMode);
    return MaterialApp(
      title: 'CAD Viewer & Editor',
      debugShowCheckedModeBanner: false,
      theme: palette.toThemeData(),
      darkTheme: palette.toThemeData(),
      themeMode: ThemeMode.light, // los 6 temas definen su propio fondo
      home: const SplashGate(child: HomeScreen()),
    );
  }
}

/// Splash animado (1.5 s) antes del Home.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.hero,
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHome = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      child: _showHome
          ? widget.child
          : Container(
              key: const ValueKey('splash'),
              color: palette.canvasBackground,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LogoStroke(
                      progress: _controller,
                      color: palette.accent,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FadeTransition(
                      opacity: _fade,
                      child: Text(
                        'CAD Viewer & Editor',
                        style: AppType.subtitle.copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Logotipo dibujado con animación de trazado.
class _LogoStroke extends StatelessWidget {
  const _LogoStroke({required this.progress, required this.color});

  final Animation<double> progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => CustomPaint(
        size: const Size(96, 96),
        painter: _LogoPainter(
          t: progress.value.clamp(0.0, 1.0),
          color: color,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    // Media diagonal del rombo inscrito (misma marca que el icono del launcher).
    final d = r * 0.80;

    // Trazado animado: círculo + rombo inscrito (marca minimalista).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5707963267948966,
      2 * 3.141592653589793 * t,
      false,
      paint,
    );

    // Rombo: 4 lados (cada uno de longitud d·√2) dibujados secuencialmente.
    const edge = 1.4142135623730951; // √2
    final total = 4 * (d * edge);
    var consumed = 0.0;
    void segment(double length, void Function(double p) draw) {
      if (consumed + length < total * t) {
        draw(1);
        consumed += length;
      } else if (consumed < total * t) {
        draw((total * t - consumed) / length);
        consumed = total * t;
      }
    }

    final top = Offset(c.dx, c.dy - d);
    final right = Offset(c.dx + d, c.dy);
    final bottom = Offset(c.dx, c.dy + d);
    final left = Offset(c.dx - d, c.dy);

    void line(Offset a, Offset b, double p) {
      canvas.drawLine(
        a,
        Offset(a.dx + (b.dx - a.dx) * p, a.dy + (b.dy - a.dy) * p),
        paint,
      );
    }

    segment(d * edge, (p) => line(top, right, p));
    segment(d * edge, (p) => line(right, bottom, p));
    segment(d * edge, (p) => line(bottom, left, p));
    segment(d * edge, (p) => line(left, top, p));
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.t != t || old.color != color;
}
