/// Panel de capas (docs/UX_FLOWS.md, RF-PANT-03).
///
/// Bottom sheet (móvil) / lateral (landscape) con: visibilidad, bloqueo,
/// color de visualización, presets mostrar/ocultar todas, capa actual,
/// crear/renombrar/borrar capas.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/cad_enums.dart';
import '../models/cad_file.dart';
import '../models/cad_layer.dart';
import '../renderers/layer_manager.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Panel de capas.
class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, this.onClose});

  /// Callback para cerrar el panel.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );
    final manager = LayerManager(
      vm.document?.cadFile ?? const CadFile(fileName: ''),
      canvasBackground: palette.canvasBackground.toARGB32(),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.only(top: 70, right: 0, bottom: 40),
          decoration: BoxDecoration(
            color: palette.surfaceElevated.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              bottomLeft: Radius.circular(AppRadius.xl),
            ),
            boxShadow: AppElevation.z4,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Text('Capas', style: AppType.title),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: 'Mostrar todas',
                      onPressed: vm.showAllLayers,
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_off_outlined),
                      tooltip: 'Ocultar todas',
                      onPressed: vm.hideAllLayers,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Nueva capa',
                      onPressed: () => _createLayer(context, vm),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: vm.layers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final layer = vm.layers[index];
                    return _layerTile(context, vm, manager, layer);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layerTile(
    BuildContext context,
    CadViewModel vm,
    LayerManager manager,
    CadLayer layer,
  ) {
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );
    return ListTile(
      dense: true,
      leading: GestureDetector(
        onTap: () => _pickColor(context, vm, layer, manager),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: manager.layerColor(layer),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              layer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyMedium.copyWith(
                fontWeight: layer.isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (layer.isCurrent)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(Icons.touch_app, size: 14, color: palette.accent),
            ),
        ],
      ),
      subtitle: Text(
        'ACI ${layer.color} · ${layer.lineType}',
        style: AppType.caption.copyWith(color: palette.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              layer.visible ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            tooltip: layer.visible ? 'Ocultar' : 'Mostrar',
            onPressed: () => vm.toggleLayerVisible(layer.name),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          IconButton(
            icon: Icon(
              layer.locked ? Icons.lock : Icons.lock_open,
              size: 18,
            ),
            tooltip: layer.locked ? 'Desbloquear' : 'Bloquear',
            onPressed: () => vm.toggleLayerLock(layer.name),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          PopupMenuButton<String>(
            iconSize: 18,
            onSelected: (action) => _layerAction(context, vm, layer, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'current', child: Text('Hacer actual')),
              PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem(value: 'delete', child: Text('Borrar')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createLayer(BuildContext context, CadViewModel vm) async {
    final name = await _promptText(context, 'Nueva capa', 'Nombre');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    vm.createLayer(name.trim(), 7);
  }

  Future<void> _layerAction(
    BuildContext context,
    CadViewModel vm,
    CadLayer layer,
    String action,
  ) async {
    switch (action) {
      case 'current':
        vm.setCurrentLayer(layer.name);
      case 'rename':
        final name = await _promptText(context, 'Renombrar capa', layer.name);
        if (name != null && name.trim().isNotEmpty) {
          vm.renameLayer(layer.name, name.trim());
        }
      case 'delete':
        vm.deleteLayer(layer.name);
        if (vm.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.error!)),
          );
          vm.error = null;
        }
    }
  }

  Future<void> _pickColor(
    BuildContext context,
    CadViewModel vm,
    CadLayer layer,
    LayerManager manager,
  ) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color de visualización'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var aci = 1; aci <= 9; aci++)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(Color(0xFF000000 | _aciArgb(aci))),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | _aciArgb(aci)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (color != null) {
      vm.setLayerDisplayColor(layer.name, color);
    }
  }

  int _aciArgb(int aci) {
    // Paleta base (1-9) para el selector rápido.
    const base = <int, int>{
      1: 0xFFFF0000, 2: 0xFFFFFF00, 3: 0xFF00FF00, 4: 0xFF00FFFF,
      5: 0xFF0000FF, 6: 0xFFFF00FF, 7: 0xFFFFFFFF, 8: 0xFF808080,
      9: 0xFFC0C0C0,
    };
    return base[aci] ?? 0xFFFFFFFF;
  }

  Future<String?> _promptText(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
