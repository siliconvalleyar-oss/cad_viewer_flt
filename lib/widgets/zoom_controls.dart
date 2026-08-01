/// Controles flotantes de zoom (docs/DESIGN.md, RF-RENDER-02).
///
/// Botones +/−/fit con BackdropFilter blur 20px y radio 12dp (RF-UX-03).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';

/// Botones flotantes de zoom (+/−/fit).
class ZoomControls extends StatelessWidget {
  const ZoomControls({super.key, this.onFit, this.onZoomIn, this.onZoomOut});

  final VoidCallback? onFit;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    final bg = palette.surfaceElevated.withValues(alpha: 0.85);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: AppElevation.z3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomButton(
                icon: Icons.add,
                tooltip: 'Acercar',
                onPressed: onZoomIn,
              ),
              const Divider(height: 1, thickness: 1),
              _ZoomButton(
                icon: Icons.remove,
                tooltip: 'Alejar',
                onPressed: onZoomOut,
              ),
              const Divider(height: 1, thickness: 1),
              _ZoomButton(
                icon: Icons.fit_screen,
                tooltip: 'Ajustar a pantalla',
                onPressed: onFit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 22,
      constraints: const BoxConstraints.tightFor(width: 48, height: 44),
    );
  }
}
