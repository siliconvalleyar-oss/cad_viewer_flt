/// Pantalla de inicio (docs/UX_FLOWS.md, RF-PANT-01).
///
/// Logo, botón "Abrir archivo" destacado, lista de recientes y ajustes.
/// La carga usa `file_picker` (RF-CARGA-01) con detección de formato.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/cad_enums.dart';
import '../parsers/dwg_parser.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/recent_files_list.dart';
import 'settings_sheet.dart';
import 'viewer_screen.dart';

/// Pantalla de inicio.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openFile(BuildContext context) async {
    final vm = context.read<CadViewModel>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['dxf', 'dwg'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return; // Usuario canceló (flujo de error: volver a Home).
    }
    final file = result.files.single;
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    final name = file.name;
    final path = file.path;

    if (name.toLowerCase().endsWith('.dwg')) {
      // MVP DWG: guía de conversión (ADR-0005).
      final head = String.fromCharCodes(
        Uint8List.fromList(bytes.length < 6 ? bytes : bytes.sublist(0, 6)),
      );
      final info = const DwgParser().detect(head);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.info_outline),
          title: const Text('Archivo DWG'),
          content: Text(info.guide),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    await vm.loadBytes(Uint8List.fromList(bytes), name);
    if (vm.error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!)),
      );
      return;
    }
    if (context.mounted && vm.hasDocument) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: AppMotion.medium,
          pageBuilder: (_, __, ___) => const ViewerScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
      vm.error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            // Logo minimalista: círculo + rombo inscrito (misma marca del icono).
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
              ),
              child: CustomPaint(
                painter: _MinimalMarkPainter(
                  color: palette.accent,
                  strokeWidth: 3,
                ),
                size: const Size.square(88),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('CAD Viewer & Editor', style: AppType.display),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'DXF · DWG — visualiza y edita planos',
              style: AppType.body.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Botón principal.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _openFile(context),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir archivo', style: AppType.subtitle),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Recientes.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        Text('Recientes', style: AppType.subtitle),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Ajustes',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const SettingsSheet(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RecentFilesList(
                      onOpen: (path) async {
                        await vm.loadFromPath(path);
                        if (context.mounted && vm.hasDocument) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ViewerScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca minimalista: círculo + rombo inscrito (icono del launcher).
class _MinimalMarkPainter extends CustomPainter {
  const _MinimalMarkPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;
    // Media diagonal del rombo inscrito (misma proporción que el icono del
    // launcher: esquinas a ~0.8·r del centro, dentro del círculo).
    final d = r * 0.80;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, paint);
    final path = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MinimalMarkPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
