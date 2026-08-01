/// Línea de comandos estilo AutoCAD/LibreCAD (docs/EDITING.md §9, RF-CMD).
///
/// Barra colapsable con catálogo de comandos, autocompletado, historial y
/// entrada de coordenadas absolutas (`10,20` / `#10,20`), relativas
/// (`@10,20`) y polares (`10<45`).
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';

/// Entrada de comandos colapsable.
class CommandBar extends StatefulWidget {
  const CommandBar({super.key});

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _history = <String>[];
  int _historyIndex = -1;
  bool _expanded = false;
  List<String> _suggestions = const [];

  static const List<String> _commands = <String>[
    'LINE', 'CIRCLE', 'ARC', 'ELLIPSE', 'POLYLINE', 'TEXT', 'POINT',
    'ERASE', 'MOVE', 'ROTATE', 'SCALE', 'COPY', 'DIST', 'ANGLE', 'AREA',
    'UNDO', 'REDO', 'SAVE', 'SAVEAS', 'ZOOM', 'FIT', 'LAYER', 'ORTHO',
    'SNAP', 'SELECTALL', 'GRID',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return;
    }
    final vm = context.read<CadViewModel>();
    _history.insert(0, input);
    if (_history.length > 30) {
      _history.removeLast();
    }
    _historyIndex = -1;

    // Coordenadas: se usan como punto para la herramienta activa.
    final coord = _parseCoordinate(input, vm);
    if (coord != null) {
      if (vm.isDrawingTool) {
        vm.canvasTap(coord.x, coord.y);
      } else {
        vm.setTool(ToolMode.line);
        vm.canvasTap(coord.x, coord.y);
      }
      _controller.clear();
      setState(() {});
      return;
    }

    final upper = input.toUpperCase();
    switch (upper) {
      case 'LINE':
        vm.setTool(ToolMode.line);
      case 'CIRCLE':
        vm.setTool(ToolMode.circle);
      case 'ARC':
        vm.setTool(ToolMode.arc);
      case 'ELLIPSE':
        vm.setTool(ToolMode.ellipse);
      case 'POLYLINE':
        vm.setTool(ToolMode.polyline);
      case 'TEXT':
        vm.setTool(ToolMode.text);
      case 'POINT':
        vm.setTool(ToolMode.point);
      case 'ERASE':
      case 'DEL':
        vm.deleteSelection();
      case 'MOVE':
        vm.setTool(ToolMode.move);
      case 'ROTATE':
        vm.setTool(ToolMode.rotate);
      case 'SCALE':
        vm.setTool(ToolMode.scale);
      case 'COPY':
        vm.setTool(ToolMode.copy);
      case 'DIST':
        vm.setTool(ToolMode.measureDistance);
      case 'ANGLE':
        vm.setTool(ToolMode.measureAngle);
      case 'AREA':
        vm.setTool(ToolMode.measureArea);
      case 'UNDO':
        vm.undo();
      case 'REDO':
        vm.redo();
      case 'ORTHO':
        final s = vm.snapEngine.settings;
        vm.setSnapSettings(s.copyWith(ortho: !s.ortho));
      case 'SNAP':
        final s = vm.snapEngine.settings;
        vm.setSnapSettings(s.copyWith(enabled: !s.enabled));
      case 'FIT':
      case 'ZOOM':
      case 'SELECTALL':
        vm.selectAll();
      case 'GRID':
        vm.setGridType(vm.gridType == GridType.lines ? GridType.dots : GridType.lines);
      case 'SAVE':
      case 'SAVEAS':
        vm.postMessage('Usa el botón de guardar (arriba).');
      case 'LAYER':
        vm.postMessage('Usa el panel de capas.');
      default:
        vm.postMessage('Comando desconocido: $input');
    }
    _controller.clear();
    setState(() {});
  }

  CadPoint3? _parseCoordinate(String input, CadViewModel vm) {
    var s = input.trim();
    var relative = false;
    if (s.startsWith('@')) {
      relative = true;
      s = s.substring(1);
    } else if (s.startsWith('#')) {
      s = s.substring(1); // absoluto explícito
    }
    // Polar: 10<45
    if (s.contains('<')) {
      final parts = s.split('<');
      if (parts.length == 2) {
        final dist = double.tryParse(parts[0].trim());
        final deg = double.tryParse(parts[1].trim());
        if (dist != null && deg != null) {
          final rad = deg * math.pi / 180;
          final dx = dist * math.cos(rad);
          final dy = dist * math.sin(rad);
          return _withAnchor(dx, dy, relative, vm);
        }
      }
      return null;
    }
    // Cartesiana: x,y (opcional z)
    if (s.contains(',')) {
      final parts = s.split(',');
      if (parts.length >= 2) {
        final x = double.tryParse(parts[0].trim());
        final y = double.tryParse(parts[1].trim());
        if (x != null && y != null) {
          return _withAnchor(x, y, relative, vm);
        }
      }
    }
    return null;
  }

  CadPoint3 _withAnchor(double dx, double dy, bool relative, CadViewModel vm) {
    if (relative && vm.anchor != null) {
      return CadPoint3(vm.anchor!.x + dx, vm.anchor!.y + dy);
    }
    if (relative) {
      final last = vm.draftPoints.isNotEmpty ? vm.draftPoints.last : null;
      if (last != null) {
        return CadPoint3(last.x + dx, last.y + dy);
      }
    }
    return CadPoint3(dx, dy);
  }

  void _onChanged(String value) {
    final query = value.trim().toUpperCase();
    setState(() {
      if (query.isEmpty) {
        _suggestions = const [];
      } else {
        _suggestions = _commands
            .where((c) => c.startsWith(query))
            .take(5)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    final bg = palette.surfaceElevated.withValues(alpha: 0.92);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_expanded && _suggestions.isNotEmpty)
                ..._suggestions.map(
                  (s) => InkWell(
                    onTap: () {
                      _controller.text = s;
                      _run(s);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(s, style: AppType.mono),
                    ),
                  ),
                ),
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Icon(
                          _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          size: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: _onChanged,
                        onSubmitted: _run,
                        style: AppType.mono,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Comando o coordenada…',
                        ),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, size: 18),
                      tooltip: 'Historial',
                      onPressed: () {
                        if (_history.isEmpty) {
                          return;
                        }
                        _historyIndex = (_historyIndex + 1) % _history.length;
                        _controller.text = _history[_historyIndex];
                        _controller.selection = TextSelection.collapsed(
                          offset: _controller.text.length,
                        );
                      },
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
