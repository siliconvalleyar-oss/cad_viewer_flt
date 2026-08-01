/// Visor del canvas (docs/UX_FLOWS.md, RF-PANT-02).
///
/// Canvas + InteractiveViewer (pan/zoom), AppBar translúcida con nombre/fit/
/// info, status bar de coordenadas, zoom controls flotantes, toolbar de
/// edición, panel de capas, panel de propiedades, línea de comandos y
/// gestión de gestos (tap selecciona, drag con snap crea/mueve, ESC cancela).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/bounds.dart';
import '../models/cad_entity.dart';
import '../models/cad_file.dart';
import '../renderers/cad_painter.dart';
import '../renderers/layer_manager.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/command_bar.dart';
import '../widgets/property_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar_edit.dart';
import '../widgets/zoom_controls.dart';
import 'layer_panel.dart';

/// Pantalla principal del visor/editor.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  Size _viewportSize = Size.zero;
  bool _didAutoFit = false;
  Offset? _dragStartScreen;
  bool _selectingWindow = false;
  Offset _windowStart = Offset.zero;
  Offset _windowEnd = Offset.zero;
  double _lastScale = 1;
  int _prevPointerCount = 0;
  bool _showPropertyPanel = false;
  bool _showLayers = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _fit(CadViewModel vm) {
    if (_viewportSize == Size.zero) {
      return;
    }
    vm.fitToScreen(_viewportSize.width, _viewportSize.height);
  }

  void _info(CadViewModel vm, BuildContext context) {
    final doc = vm.document;
    if (doc == null) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del dibujo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Archivo', doc.cadFile.fileName),
            _infoRow('Versión DXF', doc.cadFile.version),
            _infoRow('Entidades', '${doc.entities.length}'),
            _infoRow('Capas', '${doc.layers.length}'),
            _infoRow('Bloques', '${doc.blocks.length}'),
            _infoRow('Unidades', vm.units.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: AppType.label)),
          Expanded(child: Text(value, style: AppType.body)),
        ],
      ),
    );
  }

  Future<void> _save(CadViewModel vm, BuildContext context) async {
    final content = await vm.exportDxf();
    if (content == null) {
      if (context.mounted && vm.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error!)),
        );
      }
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(content));
    // Nombre sugerido: si currentPath es una URI content:// se usa el del
    // documento cargado (no la URI entera).
    final suggestedName = (vm.currentPath != null &&
            !vm.currentPath!.startsWith('content://'))
        ? vm.currentPath!.replaceAll('.dwg', '.dxf')
        : (vm.document?.cadFile.fileName ?? 'dibujo.dxf');
    final picker = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar DXF',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['dxf'],
      // En Android el plugin escribe los bytes vía SAF (ACTION_CREATE_DOCUMENT)
      // y devuelve una URI content:// no escribible con dart:io.
      bytes: bytes,
    );
    if (picker == null) {
      return;
    }
    final ok = picker.startsWith('content://')
        ? await vm.recordSaved(picker)
        : await vm.saveToPath(picker, content);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Guardado en $picker' : 'Error al guardar'),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Gestos.
  // -------------------------------------------------------------------------

  void _onTapUp(TapUpDetails details, CadViewModel vm) {
    final w = _screenToWorld(details.localPosition);
    vm.canvasTap(w.dx, w.dy, shift: _isShiftPressed());
    if (vm.toolMode == ToolMode.text && vm.draftPoints.isNotEmpty) {
      _promptText(context, vm);
    }
    if (vm.selection.count == 1 && vm.toolMode == ToolMode.select) {
      setState(() => _showPropertyPanel = true);
    }
  }

  void _onDoubleTap(CadViewModel vm) {
    vm.zoomAt(2, _viewportSize.width / 2, _viewportSize.height / 2);
  }

  void _onScaleStart(ScaleStartDetails details, CadViewModel vm) {
    final w = _screenToWorld(details.localFocalPoint);
    // Dos dedos: gesto de vista (zoom/pan), el update lo aplica.
    if (details.pointerCount >= 2) {
      _lastScale = 1;
      return;
    }
    if (vm.isDrawingTool || vm.measureMode != MeasureMode.none) {
      vm.canvasTap(w.dx, w.dy);
      _dragStartScreen = details.localFocalPoint;
      return;
    }
    if (vm.toolMode == ToolMode.move ||
        vm.toolMode == ToolMode.rotate ||
        vm.toolMode == ToolMode.scale ||
        vm.toolMode == ToolMode.copy) {
      vm.beginTransform(w.dx, w.dy);
      _dragStartScreen = details.localFocalPoint;
      return;
    }
    // Grips activos (toolMode grip tras long-press): arrastre directo.
    if (vm.toolMode == ToolMode.grip && vm.activeGripIndex != null) {
      _dragStartScreen = details.localFocalPoint;
      return;
    }
    // Selección por ventana si el punto está vacío.
    if (vm.selection.isEmpty || vm.hitTest(w.dx, w.dy) == null) {
      _selectingWindow = true;
      _windowStart = details.localFocalPoint;
      _windowEnd = details.localFocalPoint;
      return;
    }
    // Arrastre de entidad seleccionada → mover.
    vm.beginTransform(w.dx, w.dy);
    vm.setTool(ToolMode.move);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, CadViewModel vm) {
    // Dos dedos: pellizco (zoom) + pan de la vista.
    if (details.pointerCount >= 2) {
      // Transición 1→2 dedos: resetea el factor base para evitar un salto
      // de zoom y descarta una ventana de selección o arrastre en curso
      // (setTool(select) restaura el modo y limpia transformBase/previews).
      if (_lastScale == 1 || _prevPointerCount < 2) {
        _lastScale = details.scale;
        _selectingWindow = false;
        if (vm.transformBase != null) {
          vm.setTool(ToolMode.select);
        }
      }
      final factor = details.scale / _lastScale;
      if (factor != 1) {
        vm.zoomAt(
          factor,
          details.localFocalPoint.dx,
          details.localFocalPoint.dy,
        );
      }
      if (details.focalPointDelta.distance > 0) {
        vm.panBy(details.focalPointDelta.dx, details.focalPointDelta.dy);
      }
      _lastScale = details.scale;
      _prevPointerCount = details.pointerCount;
      return;
    }
    _prevPointerCount = details.pointerCount;
    final w = _screenToWorld(details.localFocalPoint);
    if (vm.isDrawingTool || vm.measureMode != MeasureMode.none) {
      vm.updateCursor(details.localFocalPoint.dx, details.localFocalPoint.dy);
      return;
    }
    if (vm.toolMode == ToolMode.grip && vm.activeGripIndex != null) {
      vm.moveGrip(vm.activeGripIndex!, w.dx, w.dy);
      return;
    }
    if (vm.transformBase != null) {
      vm.updateTransform(w.dx, w.dy);
      return;
    }
    if (_selectingWindow) {
      setState(() => _windowEnd = details.localFocalPoint);
    }
  }

  void _onScaleEnd(ScaleEndDetails details, CadViewModel vm) {
    _lastScale = 1;
    _prevPointerCount = 0;
    if (vm.transformBase != null) {
      final w = _screenToWorld(_dragStartScreen ?? Offset.zero);
      vm.commitTransform(
        w.dx + vm.previewDx,
        w.dy + vm.previewDy,
      );
      vm.setTool(ToolMode.select);
      vm.clearSelection();
      _dragStartScreen = null;
      return;
    }
    if (vm.toolMode == ToolMode.grip) {
      vm.setTool(ToolMode.select);
      _dragStartScreen = null;
      return;
    }
    if (_selectingWindow) {
      _selectingWindow = false;
      final w0 = _screenToWorld(_windowStart);
      final w1 = _screenToWorld(_windowEnd);
      final crossing = _windowEnd.dx < _windowStart.dx;
      vm.selectWindow(
        Bounds(
          minX: w0.dx < w1.dx ? w0.dx : w1.dx,
          minY: w0.dy < w1.dy ? w0.dy : w1.dy,
          maxX: w0.dx > w1.dx ? w0.dx : w1.dx,
          maxY: w0.dy > w1.dy ? w0.dy : w1.dy,
        ),
        crossing: crossing,
      );
      setState(() {});
    }
  }

  void _onLongPress(LongPressStartDetails details, CadViewModel vm) {
    final w = _screenToWorld(details.localPosition);
    vm.tapSelect(w.dx, w.dy);
    if (vm.selection.count == 1 && vm.grips.isNotEmpty) {
      // Activa el grip más cercano.
      var bestIndex = 0;
      var best = double.infinity;
      for (var i = 0; i < vm.grips.length; i++) {
        final g = vm.grips[i];
        final d = (g.x - w.dx) * (g.x - w.dx) + (g.y - w.dy) * (g.y - w.dy);
        if (d < best) {
          best = d;
          bestIndex = i;
        }
      }
      vm.activeGripIndex = bestIndex;
      vm.setTool(ToolMode.grip);
      setState(() {});
    }
  }

  Offset _screenToWorld(Offset screen) {
    final vm = context.read<CadViewModel>();
    return Offset(
      (screen.dx - vm.offsetX) / vm.scale,
      (screen.dy - vm.offsetY) / vm.scale,
    );
  }

  bool _isShiftPressed() {
    // En móvil no hay teclado; en desktop se captura en Focus.
    return _shiftPressed;
  }

  final bool _shiftPressed = false;

  Future<void> _promptText(BuildContext context, CadViewModel vm) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Texto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Contenido del texto'),
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
    if (result != null) {
      vm.commitText(result);
    } else {
      vm.draftPoints.clear();
      vm.setTool(ToolMode.select);
    }
  }

  // -------------------------------------------------------------------------
  // Build.
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<CadViewModel>(),
      child: Consumer<CadViewModel>(
        builder: (context, vm, _) {
          final palette = AppThemes.byMode(vm.themeMode);
          return Scaffold(
            backgroundColor: palette.canvasBackground,
            body: _buildBody(context, vm, palette),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CadViewModel vm, AppThemePalette palette) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _handleKey(event, vm, context);
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          // Canvas.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                // Auto-fit una vez por pantalla (cada archivo abierto crea un
                // ViewerScreen nuevo): sin esto el canvas arranca vacío si el
                // dibujo no está en el origen. No usa documentVersion para no
                // pisar el zoom del usuario al editar o alternar capas.
                if (_viewportSize != Size.zero &&
                    vm.document != null &&
                    !_didAutoFit) {
                  _didAutoFit = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _fit(vm);
                    }
                  });
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTapUp(d, vm),
                  onDoubleTap: () => _onDoubleTap(vm),
                  onLongPressStart: (d) => _onLongPress(d, vm),
                  onScaleStart: (d) => _onScaleStart(d, vm),
                  onScaleUpdate: (d) => _onScaleUpdate(d, vm),
                  onScaleEnd: (d) => _onScaleEnd(d, vm),
                  child: MouseRegion(
                    onHover: (e) {
                      vm.updateCursor(
                        e.localPosition.dx,
                        e.localPosition.dy,
                      );
                    },
                    child: CustomPaint(
                      size: _viewportSize,
                      painter: _buildPainter(vm, palette),
                    ),
                  ),
                );
              },
            ),
          ),

          // Ventana de selección.
          if (_selectingWindow)
            Positioned.fromRect(
              rect: Rect.fromPoints(_windowStart, _windowEnd),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _windowEnd.dx < _windowStart.dx
                        ? Colors.blue.withValues(alpha: 0.8)
                        : Colors.green.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

          // AppBar translúcida.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAppBar(context, vm, palette),
          ),

          // Status bar.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CadStatusBar(),
          ),

          // Zoom controls (derecha, sobre status bar).
          Positioned(
            right: AppSpacing.lg,
            bottom: 60,
            child: ZoomControls(
              onFit: () => _fit(vm),
              onZoomIn: () => vm.zoomIn(_viewportSize.width, _viewportSize.height),
              onZoomOut: () => vm.zoomOut(_viewportSize.width, _viewportSize.height),
            ),
          ),

          // Toolbar de edición (centro inferior).
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: Center(
              child: ToolbarEdit(
                onTool: (mode) {
                  vm.setTool(mode);
                  setState(() {
                    _showPropertyPanel = false;
                  });
                },
              ),
            ),
          ),

          // Línea de comandos (arriba-izquierda flotante).
          Positioned(
            left: AppSpacing.md,
            bottom: 52,
            child: CommandBar(),
          ),

          // Panel de capas.
          if (_showLayers)
            Positioned.fill(
              child: LayerPanel(
                onClose: () => setState(() => _showLayers = false),
              ),
            ),

          // Panel de propiedades (bottom sheet).
          if (_showPropertyPanel && vm.selection.count > 0)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showPropertyPanel = false),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: PropertyPanel(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    CadViewModel vm,
    AppThemePalette palette,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: palette.appBackground.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: () => _back(context, vm),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vm.document?.cadFile.fileName ?? 'Dibujo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subtitle,
                  ),
                  if (vm.dirty)
                    Text(
                      'Sin guardar',
                      style: AppType.caption.copyWith(color: palette.error),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer (Ctrl+Z)',
              onPressed: vm.commandStack.canUndo ? vm.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Rehacer (Ctrl+Y)',
              onPressed: vm.commandStack.canRedo ? vm.redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar como DXF',
              onPressed: () => _save(vm, context),
            ),
            IconButton(
              icon: const Icon(Icons.layers_outlined),
              tooltip: 'Capas',
              onPressed: () => setState(() => _showLayers = !_showLayers),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Información',
              onPressed: () => _info(vm, context),
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Ajustar a pantalla (F)',
              onPressed: () => _fit(vm),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _back(BuildContext context, CadViewModel vm) async {
    if (!vm.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('¿Quieres guardar los cambios antes de salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (save == true) {
      await _save(vm, context);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else if (save == false && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleKey(KeyDownEvent event, CadViewModel vm, BuildContext context) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;
    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      vm.undo();
    } else if (ctrl && key == LogicalKeyboardKey.keyY) {
      vm.redo();
    } else if (ctrl && key == LogicalKeyboardKey.keyS) {
      _save(vm, context);
    } else if (ctrl && key == LogicalKeyboardKey.keyA) {
      vm.selectAll();
    } else if (key == LogicalKeyboardKey.delete) {
      vm.deleteSelection();
    } else if (key == LogicalKeyboardKey.escape) {
      vm.cancelTool();
      setState(() => _showPropertyPanel = false);
    } else if (key == LogicalKeyboardKey.f8) {
      final s = vm.snapEngine.settings;
      vm.setSnapSettings(s.copyWith(ortho: !s.ortho));
    } else if (key == LogicalKeyboardKey.f3) {
      final s = vm.snapEngine.settings;
      vm.setSnapSettings(s.copyWith(enabled: !s.enabled));
    } else if (key == LogicalKeyboardKey.keyF) {
      _fit(vm);
    }
  }

  CadPainter _buildPainter(CadViewModel vm, AppThemePalette palette) {
    final layerManager = LayerManager(vm.document?.cadFile ?? const CadFile(fileName: ''));
    return CadPainter(
      transform: vm.transform,
      entities: vm.visibleEntities,
      layers: vm.layers,
      units: vm.units,
      backgroundColor: palette.canvasBackground,
      gridColor: palette.grid,
      axisXColor: palette.axisX,
      axisYColor: palette.axisY,
      selectionColor: palette.selection,
      snapColor: palette.snap,
      gripColor: palette.grip,
      gripActiveColor: palette.gripActive,
      measureColor: palette.measure,
      entityColorResolver: layerManager.entityColor,
      gridType: vm.gridType,
      showAxes: vm.showAxes,
      showCrosshair: vm.showCrosshair,
      crosshairWorld: CadPoint3(vm.cursorX, vm.cursorY),
      selectedHandles: vm.selectedHandles,
      grips: vm.grips,
      activeGripIndex: vm.activeGripIndex,
      activeSnap: vm.activeSnap,
      draftPoints: vm.draftPoints,
      previewPoint: vm.previewPoint,
      measurePoints: vm.measurePoints,
      measureMode: vm.measureMode,
      previewDx: vm.previewDx,
      previewDy: vm.previewDy,
      previewAngle: vm.previewAngle,
      previewFactor: vm.previewFactor,
      transformBase: vm.transformBase,
      isDrawing: vm.isDrawingTool || vm.measureMode != MeasureMode.none,
      documentVersion: vm.documentVersion,
      selectionVersion: vm.selectionVersion,
      transformVersion: vm.transformVersion,
    )..toolModeFor = vm.toolMode;
  }
}
