/// Hoja de ajustes (docs/UX_FLOWS.md, RF-PANT-05).
///
/// Tema (6 con preview), unidades, grid, ejes, crosshair, snap (modos,
/// tolerancia, ortho), versión DXF de guardado y acerca de / privacidad.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/cad_enums.dart';
import '../parsers/dxf_writer.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Hoja de ajustes deslizable.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Text('Ajustes', style: AppType.title),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),

              // Tema.
              Text('Tema', style: AppType.subtitle),
              const SizedBox(height: AppSpacing.sm),
              _themeGrid(context, vm),

              const Divider(),

              // Unidades.
              Text('Unidades', style: AppType.subtitle),
              DropdownButton<UnitsType>(
                value: vm.units,
                isExpanded: true,
                items: [
                  for (final u in UnitsType.values)
                    DropdownMenuItem(value: u, child: Text(u.label)),
                ],
                onChanged: (u) {
                  if (u != null) {
                    vm.setUnits(u);
                  }
                },
              ),

              const Divider(),

              // Grid y ejes.
              Text('Canvas', style: AppType.subtitle),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rejilla'),
                value: vm.gridType != GridType.none,
                onChanged: (v) => vm.setGridType(v ? GridType.lines : GridType.none),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ejes X/Y'),
                value: vm.showAxes,
                onChanged: vm.setShowAxes,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Crosshair'),
                value: vm.showCrosshair,
                onChanged: vm.setShowCrosshair,
              ),

              const Divider(),

              // Cotas y texto.
              Text('Cotas y texto', style: AppType.subtitle),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tamaño del texto de cota'),
                subtitle: Text(
                  '×${vm.dimTextScale.toStringAsFixed(2)}'
                  '${vm.dimTextScale == 1.0 ? ' (auto)' : ''}',
                  style: AppType.label,
                ),
              ),
              Slider(
                value: vm.dimTextScale.clamp(0.2, 5.0).toDouble(),
                min: 0.2,
                max: 5.0,
                divisions: 24,
                label: '×${vm.dimTextScale.toStringAsFixed(2)}',
                onChanged: vm.setDimTextScale,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tamaño de las flechas'),
                subtitle: Text(
                  '×${vm.dimArrowScale.toStringAsFixed(2)}'
                  '${vm.dimArrowScale == 1.0 ? ' (auto)' : ''}',
                  style: AppType.label,
                ),
              ),
              Slider(
                value: vm.dimArrowScale.clamp(0.2, 5.0).toDouble(),
                min: 0.2,
                max: 5.0,
                divisions: 24,
                label: '×${vm.dimArrowScale.toStringAsFixed(2)}',
                onChanged: vm.setDimArrowScale,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fuente de la vista'),
                subtitle: Text(
                  _fontLabel(vm.dimFontFamily),
                  style: AppType.label,
                ),
                trailing: DropdownButton<String>(
                  value: _fontOptions.contains(vm.dimFontFamily)
                      ? vm.dimFontFamily
                      : '',
                  items: [
                    for (final f in _fontOptions)
                      DropdownMenuItem(value: f, child: Text(_fontLabel(f))),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      vm.setDimFontFamily(v);
                    }
                  },
                ),
              ),

              const Divider(),

              // Snap.
              Text('Snapping', style: AppType.subtitle),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Snap activo (F3)'),
                value: vm.snapEngine.settings.enabled,
                onChanged: (v) =>
                    vm.setSnapSettings(vm.snapEngine.settings.copyWith(enabled: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ortho (F8)'),
                value: vm.snapEngine.settings.ortho,
                onChanged: (v) =>
                    vm.setSnapSettings(vm.snapEngine.settings.copyWith(ortho: v)),
              ),
              ..._snapModeTiles(context, vm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tolerancia de snap'),
                subtitle: Slider(
                  value: vm.snapEngine.settings.tolerancePx.clamp(4, 24),
                  min: 4,
                  max: 24,
                  divisions: 10,
                  label: '${vm.snapEngine.settings.tolerancePx.toStringAsFixed(0)} px',
                  onChanged: (v) => vm.setSnapSettings(
                    vm.snapEngine.settings.copyWith(tolerancePx: v),
                  ),
                ),
              ),

              const Divider(),

              // Versión de guardado.
              Text('Guardado', style: AppType.subtitle),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Formato DXF'),
                subtitle: Text(
                  vm.saveVersion == DxfWriteVersion.r2000
                      ? 'R2000 (AC1015) — recomendado'
                      : 'R12 (AC1009) — máxima compatibilidad LibreCAD',
                ),
                trailing: DropdownButton<DxfWriteVersion>(
                  value: vm.saveVersion,
                  items: const [
                    DropdownMenuItem(value: DxfWriteVersion.r2000, child: Text('R2000')),
                    DropdownMenuItem(value: DxfWriteVersion.r12, child: Text('R12')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      vm.setSaveVersion(v);
                    }
                  },
                ),
              ),

              const Divider(),

              // Acerca de.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.architecture),
                title: const Text('CAD Viewer & Editor v0.1.0'),
                subtitle: const Text(
                  'Procesamiento 100% local. Tus planos nunca salen del dispositivo.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeGrid(BuildContext context, CadViewModel vm) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: [
        for (final t in AppThemes.all)
          _themePreview(context, vm, t),
      ],
    );
  }

  Widget _themePreview(BuildContext context, CadViewModel vm, AppThemePalette t) {
    final selected = AppThemes.byMode(vm.themeMode).id == t.id;
    return GestureDetector(
      onTap: () => vm.setThemeMode(
        AppThemeMode.values[AppThemes.all.indexOf(t)],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? t.accent : t.outline.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: t.axisX),
                const SizedBox(width: 4),
                Icon(Icons.circle, size: 10, color: t.axisY),
                const SizedBox(width: 4),
                Icon(Icons.circle, size: 10, color: t.accent),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: t.accent),
              ],
            ),
            const Spacer(),
            Text(t.name, style: AppType.label.copyWith(color: t.textPrimary)),
          ],
        ),
      ),
    );
  }

  /// Fuentes disponibles para el texto del lienzo (vacío = sistema).
  static const List<String> _fontOptions = [
    '',
    'monospace',
    'serif',
    'sans-serif',
    'sans-serif-condensed',
    'sans-serif-medium',
    'cursive',
  ];

  static String _fontLabel(String family) => switch (family) {
        '' => 'Predeterminada',
        'monospace' => 'Monoespaciada',
        'serif' => 'Serif',
        'sans-serif' => 'Sans-serif',
        'sans-serif-condensed' => 'Sans-serif condensada',
        'sans-serif-medium' => 'Sans-serif media',
        'cursive' => 'Cursiva',
        _ => family,
      };

  List<Widget> _snapModeTiles(BuildContext context, CadViewModel vm) {
    final s = vm.snapEngine.settings;
    final modes = <(String, bool, void Function(bool))>[
      ('Endpoint', s.endpoint, (v) => vm.setSnapSettings(s.copyWith(endpoint: v))),
      ('Midpoint', s.midpoint, (v) => vm.setSnapSettings(s.copyWith(midpoint: v))),
      ('Centro', s.center, (v) => vm.setSnapSettings(s.copyWith(center: v))),
      ('Cuadrante', s.quadrant, (v) => vm.setSnapSettings(s.copyWith(quadrant: v))),
      ('Intersección', s.intersection, (v) => vm.setSnapSettings(s.copyWith(intersection: v))),
      ('Nearest', s.nearest, (v) => vm.setSnapSettings(s.copyWith(nearest: v))),
      ('Grid', s.grid, (v) => vm.setSnapSettings(s.copyWith(grid: v))),
      ('Polar', s.polar, (v) => vm.setSnapSettings(s.copyWith(polar: v))),
    ];
    return [
      for (final (label, value, onChanged) in modes)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label),
          value: value,
          onChanged: onChanged,
        ),
    ];
  }
}
