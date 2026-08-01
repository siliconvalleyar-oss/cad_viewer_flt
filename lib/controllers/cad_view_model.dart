/// Estado central de la sesión (docs/ARCHITECTURE.md §5, ADR-0001).
///
/// `CadViewModel` (ChangeNotifier + Provider) es la única fuente de verdad:
/// documento editable, selección, capas, transformación de vista, unidades,
/// tema, snapping y comandos. Usa version counters para rebuild selectivo
/// (`context.select`) y delega la lógica en CommandStack/SnapEngine/
/// SelectionManager.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bounds.dart';
import '../models/cad_document.dart';
import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../models/cad_file.dart';
import '../models/cad_layer.dart';
import '../parsers/dxf_parser.dart';
import '../parsers/dxf_writer.dart';
import '../parsers/dwg_parser.dart';
import '../utils/coordinate_transform.dart';
import '../utils/file_helper.dart';
import '../utils/geometry.dart';
import '../utils/units.dart';
import 'command_stack.dart';
import 'commands.dart';
import 'selection_manager.dart';
import 'snap_engine.dart';

/// Modo de herramienta activo.
enum ToolMode {
  none,
  select,
  line,
  circle,
  arc,
  ellipse,
  polyline,
  text,
  point,
  move,
  rotate,
  scale,
  copy,
  measureDistance,
  measureAngle,
  measureArea,
  grip,
}

/// Modo de medición activo (para la overlay temporal).
enum MeasureMode { none, distance, angle, area }

/// Registro de archivo reciente.
class RecentFile {
  const RecentFile({required this.path, required this.name, required this.date});

  final String path;
  final String name;
  final int date;

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        date: (json['date'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'date': date};
}

/// ViewModel central.
class CadViewModel extends ChangeNotifier {
  CadViewModel() {
    _restorePreferences();
  }

  // -------------------------------------------------------------------------
  // Estado del documento.
  // -------------------------------------------------------------------------
  CadDocument? _document;
  CadDocument? get document => _document;

  /// Entidades visibles (capa renderizable).
  List<CadEntity> get visibleEntities =>
      _document?.getVisibleEntities() ?? const [];

  bool get hasDocument => _document != null;

  bool get dirty => _document?.dirty ?? false;

  /// Capa activa para entidades nuevas.
  String get currentLayerName => _document?.currentLayer ?? '0';

  List<CadLayer> get layers => _document?.layers ?? const [];

  /// Versión estructural del documento (rebuild de painter/panels).
  int documentVersion = 0;

  /// Versión de capas.
  int layersVersion = 0;

  /// Versión de selección.
  int selectionVersion = 0;

  /// Versión de transformación de vista (status bar).
  int transformVersion = 0;

  /// Versión de comandos (botones undo/redo, command bar).
  int commandVersion = 0;

  /// Estado de carga.
  bool isLoading = false;

  /// Mensaje de error actual (o `null`).
  String? error;

  /// Avisos del último parseo.
  List<String> warnings = const [];

  // -------------------------------------------------------------------------
  // Sub-sistemas.
  // -------------------------------------------------------------------------
  final CommandStack commandStack = CommandStack();
  final SnapEngine snapEngine = SnapEngine(const SnapSettings());
  final SelectionManager selection = SelectionManager();

  // -------------------------------------------------------------------------
  // Vista (transformación).
  // -------------------------------------------------------------------------
  double scale = 1;
  double offsetX = 0;
  double offsetY = 0;

  /// Posición del cursor en mundo (status bar).
  double cursorX = 0;
  double cursorY = 0;

  /// Resultado de snap activo (para el indicador visual).
  SnapResult? activeSnap;

  CoordinateTransform get transform =>
      CoordinateTransform(scale: scale, offsetX: offsetX, offsetY: offsetY);

  // -------------------------------------------------------------------------
  // Preferencias.
  // -------------------------------------------------------------------------
  UnitsType units = UnitsType.mm;
  AppThemeMode themeMode = AppThemeMode.dark;
  GridType gridType = GridType.lines;
  bool showAxes = true;
  bool showCrosshair = true;

  /// Lista de archivos recientes (máx. 10).
  List<RecentFile> recentFiles = const [];

  /// Ruta del archivo actual (para guardar sobre él).
  String? currentPath;

  /// Versión DXF de guardado.
  DxfWriteVersion saveVersion = DxfWriteVersion.r2000;

  // -------------------------------------------------------------------------
  // Herramientas / interacción.
  // -------------------------------------------------------------------------
  ToolMode toolMode = ToolMode.select;
  MeasureMode measureMode = MeasureMode.none;
  final List<CadPoint3> draftPoints = <CadPoint3>[];

  /// Punto actual del cursor en mundo durante la creación (rubber band).
  CadPoint3? previewPoint;

  /// Punto de ancla para coordenadas relativas/ortho/polar.
  CadPoint3? anchor;

  /// Puntos de medición.
  final List<CadPoint3> measurePoints = <CadPoint3>[];

  /// Vista previa de transformación (mover/rotar/escalar): desplazamiento.
  double previewDx = 0;
  double previewDy = 0;
  double previewAngle = 0;
  double previewFactor = 1;
  CadPoint3? transformBase;

  /// Grips: puntos de control de la entidad seleccionada.
  List<CadPoint3> grips = const [];
  int? activeGripIndex;

  /// Autoguardado (cada 5 min).
  Timer? _autosaveTimer;

  /// `true` si hay un autoguardado pendiente de restaurar.
  bool hasAutosave = false;

  // -------------------------------------------------------------------------
  // Carga de archivos.
  // -------------------------------------------------------------------------

  /// Carga bytes de un archivo (desde FilePicker).
  Future<void> loadBytes(Uint8List bytes, String fileName) async {
    final detected = detectFormat(fileName, bytes);
    if (detected.format == FileFormat.dwg) {
      final header = String.fromCharCodes(bytes.take(6));
      final info = const DwgParser().detect(header);
      error = info.guide;
      isLoading = false;
      notifyListeners();
      return;
    }
    if (detected.isBinary) {
      error = 'DXF binario no soportado en v1.0. Convierta el archivo a DXF ASCII.';
      isLoading = false;
      notifyListeners();
      return;
    }
    await _parseAndSet(bytes, fileName);
  }

  /// Carga un archivo desde ruta.
  Future<void> loadFromPath(String path) async {
    isLoading = true;
    error = null;
    notifyListeners();
    final file = File(path);
    final bytes = await readFileSafe(file);
    if (bytes == null) {
      error = 'No se pudo leer el archivo.';
      isLoading = false;
      notifyListeners();
      return;
    }
    await _parseAndSet(bytes, p.basename(path), path: path);
  }

  Future<void> _parseAndSet(
    Uint8List bytes,
    String fileName, {
    String? path,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    // Parseo pesado fuera del hilo de UI (archivos > 1 MB).
    final result = bytes.length > 1 << 20
        ? await compute(_parseWorker, _ParseJob(bytes: bytes, fileName: fileName))
        : const DxfParserWrapper().parseBytes(bytes, fileName: fileName);
    isLoading = false;
    if (result.error != null) {
      error = result.error;
      notifyListeners();
      return;
    }
    final file = result.cadFile!;
    _document = CadDocument.fromCadFile(file);
    currentPath = path ?? file.fileName;
    units = file.header.units == UnitsType.unitless ? UnitsType.mm : file.header.units;
    warnings = result.warnings;
    commandStack.clear();
    selection.clear();
    grips = const [];
    toolMode = ToolMode.select;
    measureMode = MeasureMode.none;
    measurePoints.clear();
    draftPoints.clear();
    documentVersion++;
    layersVersion++;
    selectionVersion++;
    commandVersion++;
    _addRecent(file.fileName);
    _startAutosave();
    notifyListeners();
  }

  /// Parsea en un Isolate (contrato JSON, SERIALIZATION §4).
  static ParseResult _parseWorker(_ParseJob job) =>
      const DxfParserWrapper().parseBytes(job.bytes, fileName: job.fileName);

  // -------------------------------------------------------------------------
  // Guardado.
  // -------------------------------------------------------------------------

  /// Guarda el documento como DXF (sobreescribe [currentPath] o devuelve
  /// el contenido para guardar con FilePicker).
  Future<String?> exportDxf({DxfWriteVersion? version}) async {
    final doc = _document;
    if (doc == null) {
      return null;
    }
    final file = doc.exportCadFile();
    final v = version ?? saveVersion;
    final result = file.entities.length > 2000
        ? await compute(_writeWorker, _WriteJob(file: file, r12: v == DxfWriteVersion.r12))
        : const DxfWriter().write(file, version: v);
    if (result.error != null) {
      error = result.error;
      notifyListeners();
      return null;
    }
    warnings = result.warnings;
    return result.content;
  }

  static WriteResult _writeWorker(_WriteJob job) =>
      const DxfWriter().write(job.file, version: job.r12 ? DxfWriteVersion.r12 : DxfWriteVersion.r2000);

  /// Guarda el contenido en [path] y marca guardado.
  Future<bool> saveToPath(String path, String content) async {
    final ok = await writeFileSafe(File(path), content);
    if (ok) {
      _document = _document?.markSaved();
      currentPath = path;
      _addRecent(p.basename(path));
      commandVersion++;
      notifyListeners();
    }
    return ok;
  }

  /// Registra un guardado ya realizado por el sistema (SAF Android,
  /// `content://` no escribible con dart:io) sin reescribir el archivo.
  /// No se añade a recientes: las URIs `content://` no se pueden reabrir
  /// con dart:io (el SnackBar de la UI confirma el guardado).
  Future<bool> recordSaved(String uri) async {
    _document = _document?.markSaved();
    currentPath = uri;
    commandVersion++;
    notifyListeners();
    return true;
  }

  /// Autoguardado cada 5 minutos en el directorio de documentos.
  void _startAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await autosave();
    });
  }

  Future<void> autosave() async {
    final doc = _document;
    if (doc == null || !doc.dirty) {
      return;
    }
    final content = await exportDxf();
    if (content == null) {
      return;
    }
    try {
      // Directorio privado de la app (path_provider) — la raíz '/' no es
      // escribible en Android.
      final dir = Directory(p.join((await getAppDir()).path, 'autosave'));
      await dir.create(recursive: true);
      final name = p.basenameWithoutExtension(doc.cadFile.fileName);
      final ok = await writeFileSafe(
        File(p.join(dir.path, '$name.autosave.dxf')),
        content,
      );
      hasAutosave = ok;
    } catch (_) {
      hasAutosave = false;
    }
  }

  /// Restaura el autoguardado de un archivo (si existe).
  Future<bool> restoreAutosave(String originalPath) async {
    final dir = Directory(p.join((await getAppDir()).path, 'autosave'));
    final name = p.basenameWithoutExtension(originalPath);
    final file = File(p.join(dir.path, '$name.autosave.dxf'));
    if (!await file.exists()) {
      return false;
    }
    await loadFromPath(file.path);
    return true;
  }

  /// Directorio base de la app: override opcional o documentos privados.
  Future<Directory> getAppDir() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString('appDir');
    if (override != null && override.isNotEmpty) {
      return Directory(override);
    }
    return getApplicationDocumentsDirectory();
  }

  // -------------------------------------------------------------------------
  // Vista.
  // -------------------------------------------------------------------------

  /// Ajusta a pantalla (fit, 80% del viewport, RF-RENDER-04).
  void fitToScreen(double viewportW, double viewportH) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    final bounds = _documentBounds();
    final t = CoordinateTransform.fitToScreen(bounds, viewportW, viewportH);
    scale = t.scale;
    offsetX = t.offsetX;
    offsetY = t.offsetY;
    transformVersion++;
    notifyListeners();
  }

  Bounds _documentBounds() {
    final doc = _document!;
    var b = const Bounds.empty();
    for (final e in doc.entities) {
      b = b.expandToInclude(selectionBoundsFor(e, doc));
    }
    if (b.isEmpty) {
      return const Bounds(minX: -100, minY: -100, maxX: 100, maxY: 100);
    }
    // Margen del 5%.
    final w = b.width * 0.05;
    final h = b.height * 0.05;
    return Bounds(minX: b.minX - w, minY: b.minY - h, maxX: b.maxX + w, maxY: b.maxY + h);
  }

  /// Zoom en un punto de pantalla (factor > 1 acerca).
  void zoomAt(double factor, double screenX, double screenY) {
    final newScale = (scale * factor).clamp(0.0001, 1000000.0);
    // Mantiene el punto de mundo bajo el cursor fijo.
    final wx = (screenX - offsetX) / scale;
    final wy = (screenY - offsetY) / scale;
    scale = newScale;
    offsetX = screenX - wx * newScale;
    offsetY = screenY - wy * newScale;
    transformVersion++;
    notifyListeners();
  }

  /// Zoom de botones centrado en el viewport.
  void zoomIn(double viewportW, double viewportH) =>
      zoomAt(1.25, viewportW / 2, viewportH / 2);

  void zoomOut(double viewportW, double viewportH) =>
      zoomAt(0.8, viewportW / 2, viewportH / 2);

  /// Pan por delta de píxeles.
  void panBy(double dx, double dy) {
    offsetX += dx;
    offsetY += dy;
    transformVersion++;
    notifyListeners();
  }

  /// Actualiza la posición del cursor (status bar + snap + preview).
  void updateCursor(double screenX, double screenY) {
    final wx = (screenX - offsetX) / scale;
    final wy = (screenY - offsetY) / scale;
    cursorX = wx;
    cursorY = wy;
    previewPoint = CadPoint3(wx, wy);
    if (toolMode != ToolMode.none &&
        toolMode != ToolMode.select &&
        toolMode != ToolMode.move &&
        toolMode != ToolMode.rotate &&
        toolMode != ToolMode.scale &&
        toolMode != ToolMode.copy &&
        toolMode != ToolMode.grip) {
      activeSnap = snapEngine.snap(
        px: wx,
        py: wy,
        entities: visibleEntities,
        scalePxPerMm: scale,
      );
    }
    transformVersion++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Selección (delegada a SelectionManager).
  // -------------------------------------------------------------------------

  /// Devuelve la entidad bajo el cursor (hit-testing por tipo, RF-SEL-01).
  CadEntity? hitTest(double wx, double wy, {double tolerancePx = 10}) {
    final doc = _document;
    if (doc == null) {
      return null;
    }
    final tol = tolerancePx / scale;
    CadEntity? best;
    var bestDist = double.infinity;
    for (final e in doc.entities) {
      final layer = doc.layerByName(e.layer);
      if (layer != null && !layer.isRenderable) {
        continue;
      }
      final d = distanceToEntity(e, wx, wy);
      if (d <= tol && d < bestDist) {
        best = e;
        bestDist = d;
      }
    }
    return best;
  }

  /// Tap en una entidad: selecciona (o toggle si shift).
  void tapSelect(double wx, double wy, {bool shift = false}) {
    final e = hitTest(wx, wy);
    if (e == null) {
      selection.clear();
      grips = const [];
      activeGripIndex = null;
    } else {
      final layer = _document?.layerByName(e.layer);
      if (layer != null && (layer.locked || layer.frozen)) {
        return; // Capa bloqueada: no seleccionable (RF-SEL-09).
      }
      if (shift) {
        selection.toggle(e.handle);
      } else if (selection.contains(e.handle) && selection.count > 1) {
        selection.clear();
        selection.add(e.handle);
      } else {
        selection.selectOne(e.handle);
      }
      _updateGrips();
    }
    selectionVersion++;
    notifyListeners();
  }

  void selectAll() {
    final doc = _document;
    if (doc == null) {
      return;
    }
    selection.selectAll(doc);
    _updateGrips();
    selectionVersion++;
    notifyListeners();
  }

  void clearSelection() {
    selection.clear();
    grips = const [];
    activeGripIndex = null;
    selectionVersion++;
    notifyListeners();
  }

  /// Selección por ventana (window verde / crossing azul).
  void selectWindow(Bounds window, {required bool crossing}) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    selection.selectWindow(doc, window, crossing: crossing);
    _updateGrips();
    selectionVersion++;
    notifyListeners();
  }

  Set<String> get selectedHandles => selection.handles;

  /// Entidades seleccionadas.
  List<CadEntity> get selectedEntities {
    final doc = _document;
    if (doc == null) {
      return const [];
    }
    return selection.handles
        .map(doc.getEntity)
        .whereType<CadEntity>()
        .toList();
  }

  // -------------------------------------------------------------------------
  // Herramientas.
  // -------------------------------------------------------------------------

  /// Activa una herramienta de creación/transformación.
  void setTool(ToolMode mode) {
    toolMode = mode;
    draftPoints.clear();
    measurePoints.clear();
    measureMode = MeasureMode.none;
    anchor = null;
    previewDx = 0;
    previewDy = 0;
    previewAngle = 0;
    previewFactor = 1;
    transformBase = null;
    if (mode == ToolMode.measureDistance) {
      measureMode = MeasureMode.distance;
    } else if (mode == ToolMode.measureAngle) {
      measureMode = MeasureMode.angle;
    } else if (mode == ToolMode.measureArea) {
      measureMode = MeasureMode.area;
    }
    commandVersion++;
    transformVersion++;
    notifyListeners();
  }

  bool get isDrawingTool =>
      toolMode == ToolMode.line ||
      toolMode == ToolMode.circle ||
      toolMode == ToolMode.arc ||
      toolMode == ToolMode.ellipse ||
      toolMode == ToolMode.polyline ||
      toolMode == ToolMode.point;

  /// Tap principal en el canvas según la herramienta activa.
  void canvasTap(double wx, double wy, {bool shift = false}) {
    if (toolMode == ToolMode.select) {
      tapSelect(wx, wy, shift: shift);
      return;
    }
    if (measureMode != MeasureMode.none) {
      _measureTap(wx, wy);
      return;
    }
    final snapped = _snapPoint(wx, wy);
    switch (toolMode) {
      case ToolMode.line:
        _draftLine(snapped);
      case ToolMode.circle:
        _draftCircle(snapped);
      case ToolMode.arc:
        _draftArc(snapped);
      case ToolMode.ellipse:
        _draftEllipse(snapped);
      case ToolMode.polyline:
        _draftPolyline(snapped);
      case ToolMode.point:
        _commitPoint(snapped);
      case ToolMode.text:
        _promptText(snapped);
      default:
        break;
    }
  }

  /// Tap secundario / confirmar (doble tap o enter).
  void confirmDraft() {
    if (toolMode == ToolMode.polyline && draftPoints.isNotEmpty) {
      _commitPolyline(closed: false);
    } else if (toolMode == ToolMode.line && draftPoints.isNotEmpty) {
      setTool(ToolMode.select);
    }
  }

  /// ESC: cancela la herramienta o la selección.
  void cancelTool() {
    if (draftPoints.isNotEmpty) {
      draftPoints.clear();
      transformVersion++;
      notifyListeners();
      return;
    }
    if (measureMode != MeasureMode.none) {
      measurePoints.clear();
      measureMode = MeasureMode.none;
      toolMode = ToolMode.select;
      commandVersion++;
      notifyListeners();
      return;
    }
    setTool(ToolMode.select);
    clearSelection();
  }

  // -- Creación -------------------------------------------------------------

  void _draftLine(CadPoint3 p) {
    draftPoints.add(p);
    anchor = p;
    if (draftPoints.length == 2) {
      final start = draftPoints[0];
      final end = draftPoints[1];
      _commitCommand(
        CommandCreate([
          CadLine(
            handle: nextHandle(),
            layer: currentLayerName,
            x1: start.x, y1: start.y, x2: end.x, y2: end.y,
          ),
        ]),
      );
      draftPoints.clear();
      anchor = null;
      setTool(ToolMode.select);
    }
  }

  void _draftCircle(CadPoint3 p) {
    if (draftPoints.isEmpty) {
      draftPoints.add(p);
      anchor = p;
    } else {
      final c = draftPoints.first;
      final r = distance(c.x, c.y, p.x, p.y);
      _commitCommand(
        CommandCreate([
          CadCircle(
            handle: nextHandle(), layer: currentLayerName,
            cx: c.x, cy: c.y, radius: r,
          ),
        ]),
      );
      draftPoints.clear();
      anchor = null;
      setTool(ToolMode.select);
    }
  }

  void _draftArc(CadPoint3 p) {
    draftPoints.add(p);
    anchor = draftPoints.isEmpty ? null : draftPoints.last;
    if (draftPoints.length == 3) {
      final a = draftPoints[0];
      final b = draftPoints[1];
      final c = draftPoints[2];
      final arc = _arcThrough3Points(a, b, c);
      if (arc != null) {
        _commitCommand(
          CommandCreate([
            CadArc(
              handle: nextHandle(), layer: currentLayerName,
              cx: arc.$1.x, cy: arc.$1.y, radius: arc.$2,
              startAngle: arc.$3, endAngle: arc.$4,
            ),
          ]),
        );
      }
      draftPoints.clear();
      anchor = null;
      setTool(ToolMode.select);
    }
  }

  (CadPoint3, double, double, double)? _arcThrough3Points(
    CadPoint3 a, CadPoint3 b, CadPoint3 c,
  ) {
    // Circuncentro de 3 puntos.
    final ax = a.x; final ay = a.y;
    final bx = b.x; final by = b.y;
    final cx = c.x; final cy = c.y;
    final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    if (d.abs() < 1e-9) {
      return null;
    }
    final ux = ((ax * ax + ay * ay) * (by - cy) +
            (bx * bx + by * by) * (cy - ay) +
            (cx * cx + cy * cy) * (ay - by)) /
        d;
    final uy = ((ax * ax + ay * ay) * (cx - bx) +
            (bx * bx + by * by) * (ax - cx) +
            (cx * cx + cy * cy) * (bx - ax)) /
        d;
    final r = distance(ax, ay, ux, uy);
    var s = math.atan2(ay - uy, ax - ux);
    var e = math.atan2(cy - uy, cx - ux);
    final mid = math.atan2(by - uy, bx - ux);
    // Asegura el sentido (CCW o CW según la posición del punto medio).
    if (_isClockwise(s, mid, e)) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    if (e < s) {
      e += 2 * math.pi;
    }
    return (CadPoint3(ux, uy), r, s, e);
  }

  bool _isClockwise(double a1, double a2, double a3) {
    final d1 = (a2 - a1 + 2 * math.pi) % (2 * math.pi);
    final d2 = (a3 - a2 + 2 * math.pi) % (2 * math.pi);
    return d1 + d2 > 2 * math.pi;
  }

  void _draftEllipse(CadPoint3 p) {
    draftPoints.add(p);
    anchor = draftPoints.isEmpty ? null : draftPoints.last;
    if (draftPoints.length == 3) {
      final center = draftPoints[0];
      final major = draftPoints[1];
      final minor = draftPoints[2];
      final majorR = distance(center.x, center.y, major.x, major.y);
      final minorR = distance(center.x, center.y, minor.x, minor.y);
      final rot = math.atan2(major.y - center.y, major.x - center.x);
      _commitCommand(
        CommandCreate([
          CadEllipse(
            handle: nextHandle(), layer: currentLayerName,
            cx: center.x, cy: center.y,
            majorRadius: majorR, minorRadius: minorR, rotation: rot,
          ),
        ]),
      );
      draftPoints.clear();
      anchor = null;
      setTool(ToolMode.select);
    }
  }

  void _draftPolyline(CadPoint3 p) {
    if (draftPoints.isEmpty) {
      draftPoints.add(p);
      anchor = p;
    } else {
      // Cerrar si toca el primer punto.
      final first = draftPoints.first;
      if (draftPoints.length > 2 &&
          distance(first.x, first.y, p.x, p.y) < 10 / scale) {
        _commitPolyline(closed: true);
        return;
      }
      draftPoints.add(p);
      anchor = p;
    }
  }

  void _commitPolyline({required bool closed}) {
    if (draftPoints.length < 2) {
      return;
    }
    _commitCommand(
      CommandCreate([
        CadLwPolyline(
          handle: nextHandle(), layer: currentLayerName,
          points: draftPoints.map((p) => LwVertex(p.x, p.y)).toList(),
          closed: closed,
        ),
      ]),
    );
    draftPoints.clear();
    anchor = null;
    setTool(ToolMode.select);
  }

  void _commitPoint(CadPoint3 p) {
    _commitCommand(
      CommandCreate([
        CadPoint(handle: nextHandle(), layer: currentLayerName, x: p.x, y: p.y),
      ]),
    );
    setTool(ToolMode.select);
  }

  Future<void> _promptText(CadPoint3 p) async {
    draftPoints.add(p);
    anchor = p;
    notifyListeners();
  }

  /// Confirma un texto con contenido (desde el diálogo).
  void commitText(String text) {
    if (draftPoints.isEmpty) {
      return;
    }
    final p = draftPoints.first;
    _commitCommand(
      CommandCreate([
        CadText(
          handle: nextHandle(), layer: currentLayerName,
          text: text, x: p.x, y: p.y, height: 10 / scale,
        ),
      ]),
    );
    draftPoints.clear();
    anchor = null;
    setTool(ToolMode.select);
  }

  // -- Medición -------------------------------------------------------------

  void _measureTap(double wx, double wy) {
    measurePoints.add(CadPoint3(wx, wy));
    anchor = measurePoints.isEmpty ? null : measurePoints.last;
    switch (measureMode) {
      case MeasureMode.distance:
        if (measurePoints.length == 2) {
          final a = measurePoints[0];
          final b = measurePoints[1];
          final d = distance(a.x, a.y, b.x, b.y);
          message = 'Distancia: ${_fmtLength(d)}';
          measurePoints.clear();
        }
      case MeasureMode.angle:
        if (measurePoints.length == 3) {
          final a = measurePoints[0];
          final b = measurePoints[1];
          final c = measurePoints[2];
          final ang1 = math.atan2(a.y - b.y, a.x - b.x);
          final ang2 = math.atan2(c.y - b.y, c.x - b.x);
          final deg = (ang2 - ang1).abs() * 180 / math.pi % 360;
          message = 'Ángulo: ${deg.toStringAsFixed(2)}°';
          measurePoints.clear();
        }
      case MeasureMode.area:
        break; // se cierra con doble tap
      default:
        break;
    }
    transformVersion++;
    notifyListeners();
  }

  void finishMeasureArea() {
    if (measureMode == MeasureMode.area && measurePoints.length >= 3) {
      final area = polygonArea(measurePoints);
      message = 'Área: ${_fmtArea(area)}';
      measurePoints.clear();
      measureMode = MeasureMode.none;
      toolMode = ToolMode.select;
      commandVersion++;
      notifyListeners();
    }
  }

  String _fmtLength(double mm) {
    final v = mmToUnit(mm, units);
    return '${v.toStringAsFixed(2)} ${units.symbol}';
  }

  String _fmtArea(double mm2) {
    if (units == UnitsType.mm) {
      return '${mm2.toStringAsFixed(0)} mm²';
    }
    if (units == UnitsType.cm) {
      return '${(mm2 / 100).toStringAsFixed(2)} cm²';
    }
    if (units == UnitsType.m) {
      return '${(mm2 / 1e6).toStringAsFixed(3)} m²';
    }
    return '${(mm2 / 645.16).toStringAsFixed(2)} in²';
  }

  /// Mensaje transitorio (status bar / snackbar).
  String? message;

  /// Publica un mensaje transitorio y notifica (línea de comandos).
  void postMessage(String msg) {
    message = msg;
    notifyListeners();
  }

  /// Elimina un archivo del historial de recientes.
  void removeRecent(String path) {
    recentFiles = recentFiles.where((r) => r.path != path).toList();
    _persist();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Transformación de la selección.
  // -------------------------------------------------------------------------

  /// Inicia una transformación (move/rotate/scale/copy) con punto base.
  void beginTransform(double wx, double wy) {
    if (selection.isEmpty) {
      return;
    }
    transformBase = CadPoint3(wx, wy);
    previewDx = 0;
    previewDy = 0;
    previewAngle = 0;
    previewFactor = 1;
    commandVersion++;
    transformVersion++;
    notifyListeners();
  }

  void updateTransform(double wx, double wy) {
    final base = transformBase;
    if (base == null || selection.isEmpty) {
      return;
    }
    switch (toolMode) {
      case ToolMode.move:
      case ToolMode.copy:
        previewDx = wx - base.x;
        previewDy = wy - base.y;
      case ToolMode.rotate:
        previewAngle = math.atan2(wy - base.y, wx - base.x);
      case ToolMode.scale:
        final d0 = distance(base.x, base.y, _selectionCenter().x, _selectionCenter().y);
        final d1 = distance(base.x, base.y, wx, wy);
        previewFactor = d0 <= 1e-6 ? 1 : d1 / d0;
      default:
        break;
    }
    transformVersion++;
    notifyListeners();
  }

  /// Confirma la transformación en curso (Command).
  void commitTransform(double wx, double wy) {
    final base = transformBase;
    if (base == null || selection.isEmpty) {
      return;
    }
    final handles = Set<String>.from(selection.handles);
    switch (toolMode) {
      case ToolMode.move:
        _commitCommand(CommandMove(handles, previewDx, previewDy));
        _clearTransform();
        setTool(ToolMode.select);
      case ToolMode.copy:
        _commitCommand(CommandCopy(_entitiesOf(handles), previewDx, previewDy));
        _clearTransform();
        setTool(ToolMode.select);
      case ToolMode.rotate:
        _commitCommand(
          CommandRotate(handles, previewAngle, base.x, base.y),
        );
        _clearTransform();
        setTool(ToolMode.select);
      case ToolMode.scale:
        _commitCommand(
          CommandScale(handles, previewFactor, base.x, base.y),
        );
        _clearTransform();
        setTool(ToolMode.select);
      default:
        break;
    }
  }

  void _clearTransform() {
    transformBase = null;
    previewDx = 0;
    previewDy = 0;
    previewAngle = 0;
    previewFactor = 1;
  }

  /// Elimina la selección (DEL).
  void deleteSelection() {
    final sel = selectedEntities;
    if (sel.isEmpty) {
      return;
    }
    _commitCommand(CommandDelete(sel));
    selection.clear();
    grips = const [];
    selectionVersion++;
    notifyListeners();
  }

  /// Duplica la selección con un offset (botón copiar).
  void duplicateSelection(double dx, double dy) {
    final sel = selectedEntities;
    if (sel.isEmpty) {
      return;
    }
    _commitCommand(CommandCopy(sel, dx, dy));
  }

  // -------------------------------------------------------------------------
  // Undo / Redo.
  // -------------------------------------------------------------------------

  void undo() {
    final doc = _document;
    if (doc == null || !commandStack.canUndo) {
      return;
    }
    _document = commandStack.undo(doc);
    _afterCommand();
  }

  void redo() {
    final doc = _document;
    if (doc == null || !commandStack.canRedo) {
      return;
    }
    _document = commandStack.redo(doc);
    _afterCommand();
  }

  void _commitCommand(CadCommand command) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = commandStack.push(command, doc);
    _afterCommand();
  }

  void _afterCommand() {
    selection.clear();
    grips = const [];
    documentVersion++;
    commandVersion++;
    selectionVersion++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Capas.
  // -------------------------------------------------------------------------

  CadLayer? layerByName(String name) => _document?.layerByName(name);

  /// Alterna la visibilidad de una capa (sesión, no es comando).
  void toggleLayerVisible(String name) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    final layer = doc.layerByName(name);
    if (layer == null) {
      return;
    }
    _document = doc.copyWith(
      layers: doc.layers
          .map((l) => l.name == name ? l.copyWith(visible: !l.visible) : l)
          .toList(),
    );
    layersVersion++;
    documentVersion++;
    notifyListeners();
  }

  void setLayerDisplayColor(String name, Color color) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = doc.copyWith(
      layers: doc.layers
          .map(
            (l) => l.name == name
                ? l.copyWith(displayColor: color.toARGB32())
                : l,
          )
          .toList(),
    );
    layersVersion++;
    documentVersion++;
    notifyListeners();
  }

  void toggleLayerLock(String name) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = doc.copyWith(
      layers: doc.layers
          .map((l) => l.name == name ? l.copyWith(locked: !l.locked) : l)
          .toList(),
    );
    layersVersion++;
    notifyListeners();
  }

  void setCurrentLayer(String name) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = doc
        .withCurrentLayer(name)
        .copyWith(
          layers: doc.layers
              .map((l) => l.copyWith(isCurrent: l.name == name))
              .toList(),
        );
    layersVersion++;
    commandVersion++;
    notifyListeners();
  }

  void createLayer(String name, int aci) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    if (doc.layerByName(name) != null) {
      error = 'La capa $name ya existe.';
      notifyListeners();
      return;
    }
    _commitCommand(CommandLayerCreate(CadLayer(name: name, color: aci)));
    layersVersion++;
    notifyListeners();
  }

  void deleteLayer(String name) {
    final doc = _document;
    if (doc == null) {
      return;
    }
    final layer = doc.layerByName(name);
    if (layer == null) {
      return;
    }
    // Solo capas vacías (RF-CAPA-08).
    final used = doc.entities.any((e) => e.layer == name);
    if (used) {
      error = 'La capa $name no está vacía.';
      notifyListeners();
      return;
    }
    _commitCommand(CommandLayerDelete(layer));
    if (currentLayerName == name) {
      _document = _document?.withCurrentLayer('0');
    }
    layersVersion++;
    notifyListeners();
  }

  void renameLayer(String oldName, String newName) {
    if (oldName == newName) {
      return;
    }
    _commitCommand(CommandLayerRename(oldName, newName));
    if (currentLayerName == oldName) {
      _document = _document?.withCurrentLayer(newName);
    }
    layersVersion++;
    notifyListeners();
  }

  void showAllLayers() {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = doc.copyWith(
      layers: doc.layers.map((l) => l.copyWith(visible: true)).toList(),
    );
    layersVersion++;
    documentVersion++;
    notifyListeners();
  }

  void hideAllLayers() {
    final doc = _document;
    if (doc == null) {
      return;
    }
    _document = doc.copyWith(
      layers: doc.layers.map((l) => l.copyWith(visible: false)).toList(),
    );
    layersVersion++;
    documentVersion++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Propiedades de entidad.
  // -------------------------------------------------------------------------

  void modifyEntity(String handle, CadEntity updated) {
    final doc = _document;
    final before = doc?.getEntity(handle);
    if (doc == null || before == null) {
      return;
    }
    _commitCommand(CommandModifyProps(handle, before, updated));
  }

  // -------------------------------------------------------------------------
  // Grips.
  // -------------------------------------------------------------------------

  void _updateGrips() {
    final sel = selectedEntities;
    if (sel.length != 1) {
      grips = const [];
      activeGripIndex = null;
      return;
    }
    grips = gripsFor(sel.first);
  }

  /// Puntos de control por tipo de entidad (RF-EDI-11).
  static List<CadPoint3> gripsFor(CadEntity e) {
    switch (e) {
      case final CadLine l:
        return [CadPoint3(l.x1, l.y1), CadPoint3(l.x2, l.y2)];
      case final CadCircle c:
        return [
          CadPoint3(c.cx, c.cy),
          CadPoint3(c.cx + c.radius, c.cy),
          CadPoint3(c.cx - c.radius, c.cy),
          CadPoint3(c.cx, c.cy + c.radius),
          CadPoint3(c.cx, c.cy - c.radius),
        ];
      case final CadArc a:
        return [
          CadPoint3(a.cx, a.cy),
          CadPoint3(
            a.cx + a.radius * math.cos(a.startAngle),
            a.cy + a.radius * math.sin(a.startAngle),
          ),
          CadPoint3(
            a.cx + a.radius * math.cos(a.endAngle),
            a.cy + a.radius * math.sin(a.endAngle),
          ),
        ];
      case final CadLwPolyline p:
        return p.points.map((v) => CadPoint3(v.x, v.y)).toList();
      case final CadPolyline p:
        return List.of(p.points);
      case final CadText t:
        return [CadPoint3(t.x, t.y)];
      case final CadMText m:
        return [CadPoint3(m.x, m.y)];
      case final CadInsert i:
        return [CadPoint3(i.x, i.y)];
      case final CadPoint pt:
        return [CadPoint3(pt.x, pt.y)];
      case final CadEllipse el:
        return [
          CadPoint3(el.cx, el.cy),
          pointOnEllipse(el.cx, el.cy, el.majorRadius, el.minorRadius, el.rotation, 0),
        ];
      default:
        return const [];
    }
  }

  /// Mueve el grip [index] a la nueva posición y confirma el comando.
  void moveGrip(int index, double wx, double wy) {
    final doc = _document;
    if (doc == null || selection.count != 1) {
      return;
    }
    final handle = selection.handles.first;
    final e = doc.getEntity(handle);
    if (e == null || index >= grips.length) {
      return;
    }
    final target = CadPoint3(wx, wy);
    CadEntity updated;
    switch (e) {
      case final CadLine l:
        updated = index == 0
            ? l.copyWith(x1: wx, y1: wy)
            : l.copyWith(x2: wx, y2: wy);
      case final CadCircle c:
        updated = switch (index) {
          0 => c.copyWith(cx: wx, cy: wy),
          1 || 3 => c.copyWith(radius: distance(c.cx, c.cy, wx, wy)),
          _ => c.copyWith(radius: distance(c.cx, c.cy, wx, wy)),
        };
      case final CadArc a:
        updated = switch (index) {
          0 => a.copyWith(cx: wx, cy: wy),
          1 => a.copyWith(
                radius: distance(a.cx, a.cy, wx, wy),
                startAngle: math.atan2(wy - a.cy, wx - a.cx),
              ),
          _ => a.copyWith(
                radius: distance(a.cx, a.cy, wx, wy),
                endAngle: math.atan2(wy - a.cy, wx - a.cx),
              ),
        };
      case final CadLwPolyline p:
        final pts = List<LwVertex>.of(p.points);
        final v = pts[index];
        pts[index] = v.copyWith(x: wx, y: wy);
        updated = p.copyWith(points: pts);
      case final CadPolyline p:
        final pts = List<CadPoint3>.of(p.points);
        pts[index] = CadPoint3(wx, wy);
        updated = p.copyWith(points: pts);
      default:
        return;
    }
    _commitCommand(CommandModifyProps(handle, e, updated));
    _updateGrips();
    selectionVersion++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Utilidades.
  // -------------------------------------------------------------------------

  /// Punto de snap (o crudo si no hay snap).
  CadPoint3 _snapPoint(double wx, double wy) {
    final result = snapEngine.snap(
      px: wx,
      py: wy,
      entities: visibleEntities,
      scalePxPerMm: scale,
    );
    if (result != null) {
      activeSnap = result;
      return result.point;
    }
    return CadPoint3(wx, wy);
  }

  CadPoint3 _selectionCenter() {
    final sel = selectedEntities;
    if (sel.isEmpty) {
      return const CadPoint3(0, 0);
    }
    var b = const Bounds.empty();
    for (final e in sel) {
      b = b.expandToInclude(selectionBoundsFor(e, _document!));
    }
    return CadPoint3(b.centerX, b.centerY);
  }

  List<CadEntity> _entitiesOf(Set<String> handles) {
    final doc = _document;
    if (doc == null) {
      return const [];
    }
    return handles.map(doc.getEntity).whereType<CadEntity>().toList();
  }

  // -------------------------------------------------------------------------
  // Preferencias (shared_preferences).
  // -------------------------------------------------------------------------

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme');
    if (themeIndex != null && themeIndex < AppThemeMode.values.length) {
      themeMode = AppThemeMode.values[themeIndex];
    }
    final unitsIndex = prefs.getInt('units');
    if (unitsIndex != null && unitsIndex < UnitsType.values.length) {
      units = UnitsType.values[unitsIndex];
    }
    final gridIndex = prefs.getInt('gridType');
    if (gridIndex != null && gridIndex < GridType.values.length) {
      gridType = GridType.values[gridIndex];
    }
    showAxes = prefs.getBool('showAxes') ?? true;
    showCrosshair = prefs.getBool('showCrosshair') ?? true;
    final snap = _loadSnapSettings(prefs);
    if (snap != null) {
      snapEngine.settings = snap;
    }
    final recent = prefs.getStringList('recentFiles');
    if (recent != null) {
      recentFiles = recent
          .map((s) => RecentFile.fromJson(_jsonDecode(s)))
          .toList();
    }
    final ver = prefs.getInt('saveVersion');
    if (ver != null) {
      saveVersion = ver == 0 ? DxfWriteVersion.r2000 : DxfWriteVersion.r12;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', themeMode.index);
    await prefs.setInt('units', units.index);
    await prefs.setInt('gridType', gridType.index);
    await prefs.setBool('showAxes', showAxes);
    await prefs.setBool('showCrosshair', showCrosshair);
    await prefs.setStringList(
      'recentFiles',
      recentFiles.map((r) => _jsonEncode(r.toJson())).toList(),
    );
    await prefs.setInt('saveVersion', saveVersion == DxfWriteVersion.r2000 ? 0 : 1);
    await prefs.setStringList(
      'snapModes',
      snapEngine.settings.toJson().map((k, v) => MapEntry('$k', '$v')).entries.map((e) => '${e.key}=${e.value}').toList(),
    );
  }

  void setThemeMode(AppThemeMode mode) {
    themeMode = mode;
    _persist();
    notifyListeners();
  }

  void setUnits(UnitsType u) {
    units = u;
    _persist();
    notifyListeners();
  }

  void setGridType(GridType g) {
    gridType = g;
    _persist();
    transformVersion++;
    notifyListeners();
  }

  void setShowAxes(bool v) {
    showAxes = v;
    _persist();
    transformVersion++;
    notifyListeners();
  }

  void setShowCrosshair(bool v) {
    showCrosshair = v;
    _persist();
    transformVersion++;
    notifyListeners();
  }

  void setSnapSettings(SnapSettings s) {
    snapEngine.settings = s;
    _persist();
    transformVersion++;
    notifyListeners();
  }

  void setSaveVersion(DxfWriteVersion v) {
    saveVersion = v;
    _persist();
    notifyListeners();
  }

  SnapSettings? _loadSnapSettings(SharedPreferences prefs) {
    final list = prefs.getStringList('snapModes');
    if (list == null || list.isEmpty) {
      return null;
    }
    final map = <String, String>{};
    for (final entry in list) {
      final i = entry.indexOf('=');
      if (i > 0) {
        map[entry.substring(0, i)] = entry.substring(i + 1);
      }
    }
    bool b(String k) => map[k] == 'true';
    return SnapSettings(
      enabled: b('enabled'),
      ortho: b('ortho'),
      endpoint: b('endpoint'),
      midpoint: b('midpoint'),
      center: b('center'),
      intersection: b('intersection'),
      quadrant: b('quadrant'),
      nearest: b('nearest'),
      grid: b('grid'),
      polar: b('polar'),
      tolerancePx: double.tryParse(map['tolerancePx'] ?? '') ?? 12,
    );
  }

  void _addRecent(String name) {
    final path = currentPath ?? name;
    recentFiles = [
      RecentFile(path: path, name: name, date: DateTime.now().millisecondsSinceEpoch),
      ...recentFiles.where((r) => r.path != path),
    ];
    if (recentFiles.length > 10) {
      recentFiles = recentFiles.sublist(0, 10);
    }
    _persist();
  }

  Map<String, dynamic> _jsonDecode(String s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _jsonEncode(Map<String, dynamic> m) => jsonEncode(m);

  // -------------------------------------------------------------------------
  // Bounds de entidades (reutilizado de SelectionManager).
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}

/// Bounds de una entidad con resolución de bloques (para fit/zoom).
Bounds selectionBoundsFor(CadEntity e, CadDocument doc) {
  return entityBounds(e);
}

// Trabajadores para Isolates (objetos serializables, SERIALIZATION §4).
class _ParseJob {
  const _ParseJob({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class _WriteJob {
  const _WriteJob({required this.file, required this.r12});

  final CadFile file;
  final bool r12;
}
