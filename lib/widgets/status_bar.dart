/// Barra de estado inferior del visor (docs/UX_FLOWS.md, RF-UX-04).
///
/// Muestra coordenadas del cursor en la unidad de visualización, el snap
/// activo, el modo de herramienta y el estado de ortho.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';

/// Barra de estado con coordenadas del cursor.
class CadStatusBar extends StatelessWidget {
  const CadStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'X: ${_fmt(vm.cursorX)}  Y: ${_fmt(vm.cursorY)}',
            style: AppType.mono,
          ),
          const SizedBox(width: AppSpacing.lg),
          if (vm.activeSnap != null)
            Text(
              'Snap: ${vm.activeSnap!.mode.name}',
              style: AppType.mono.copyWith(color: palette.snap),
            ),
          const Spacer(),
          if (vm.snapEngine.settings.ortho)
            const Text('ORTHO', style: AppType.mono),
          if (vm.toolMode != ToolMode.select)
            Text(
              vm.toolMode.name.toUpperCase(),
              style: AppType.mono.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.abs() < 0.005 ? '0' : v.toStringAsFixed(2);
}
