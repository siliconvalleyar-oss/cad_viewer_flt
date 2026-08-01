/// Toolbar contextual de edición (docs/UX_FLOWS.md, RF-PANT-07).
///
/// - Sin selección: toolbar de dibujo + medición.
/// - Con selección: transformación (mover, rotar, escalar, copiar, borrar).
/// Con BackdropFilter blur 20px (RF-UX-03).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';

/// Toolbar contextual flotante.
class ToolbarEdit extends StatelessWidget {
  const ToolbarEdit({super.key, this.onTool});

  /// Callback opcional cuando se pulsa una herramienta.
  final void Function(ToolMode mode)? onTool;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final hasSelection = vm.selection.count > 0;
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );

    final bg = palette.surfaceElevated.withValues(alpha: 0.9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: AppElevation.z3,
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: hasSelection
                  ? _transformTools(context, vm)
                  : _drawTools(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _drawTools(BuildContext context, CadViewModel vm) {
    final items = <(ToolMode, IconData, String)>[
      (ToolMode.line, Icons.timeline, 'Línea'),
      (ToolMode.circle, Icons.circle_outlined, 'Círculo'),
      (ToolMode.arc, Icons.radio_button_unchecked, 'Arco'),
      (ToolMode.ellipse, Icons.filter_tilt_shift, 'Elipse'),
      (ToolMode.polyline, Icons.polyline_outlined, 'Polilínea'),
      (ToolMode.text, Icons.text_fields, 'Texto'),
      (ToolMode.point, Icons.adjust, 'Punto'),
    ];
    final measure = <(ToolMode, IconData, String)>[
      (ToolMode.measureDistance, Icons.straighten, 'Distancia'),
      (ToolMode.measureAngle, Icons.architecture, 'Ángulo'),
      (ToolMode.measureArea, Icons.square_foot, 'Área'),
    ];
    return [
      for (final (mode, icon, label) in items)
        _ToolButton(
          icon: icon,
          tooltip: label,
          active: vm.toolMode == mode,
          onTap: () => onTool?.call(mode),
        ),
      const SizedBox(width: AppSpacing.sm),
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
      for (final (mode, icon, label) in measure)
        _ToolButton(
          icon: icon,
          tooltip: label,
          active: vm.toolMode == mode,
          onTap: () => onTool?.call(mode),
        ),
    ];
  }

  List<Widget> _transformTools(BuildContext context, CadViewModel vm) {
    final items = <(ToolMode, IconData, String)>[
      (ToolMode.move, Icons.open_with, 'Mover'),
      (ToolMode.rotate, Icons.rotate_right, 'Rotar'),
      (ToolMode.scale, Icons.zoom_out_map, 'Escalar'),
      (ToolMode.copy, Icons.copy, 'Copiar'),
    ];
    return [
      for (final (mode, icon, label) in items)
        _ToolButton(
          icon: icon,
          tooltip: label,
          active: vm.toolMode == mode,
          onTap: () => onTool?.call(mode),
        ),
      const SizedBox(width: AppSpacing.sm),
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Borrar (Supr)',
        onPressed: vm.deleteSelection,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
      IconButton(
        icon: const Icon(Icons.content_copy),
        tooltip: 'Duplicar',
        onPressed: () {
          final dx = 10 / vm.scale;
          vm.duplicateSelection(dx, 0);
        },
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    ];
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    return IconButton(
      icon: Icon(
        icon,
        color: active ? palette.accent : palette.textPrimary,
        size: 21,
      ),
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: active
          ? IconButton.styleFrom(
              backgroundColor: palette.accent.withValues(alpha: 0.18),
            )
          : null,
    );
  }
}
