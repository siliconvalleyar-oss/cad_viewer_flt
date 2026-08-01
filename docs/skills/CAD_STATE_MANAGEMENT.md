# 🎯 Skill: cad_state_management — State Management

**Propósito:** Documentación del estado con Provider + ChangeNotifier. Base: `docs/ARCHITECTURE.md` y `docs/DATA_MODEL.md`.

---

## 1. Provider Setup

**Archivo:** `lib/main.dart`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CadViewModel(prefs),
      child: const CadViewerApp(),
    ),
  );
}
```

---

## 2. CadViewModel Overview

**Archivo:** `lib/controllers/cad_view_model.dart`

### Properties

| Categoría | Propiedades |
|-----------|-------------|
| **Data** | `document` (CadDocument?), `_recentFiles` |
| **View** | `_selectedHandles` (Set<String>) |
| **UI** | `_visibleLayers`, `_showLayerPanel`, `_showToolbar` |
| **Transform** | `_scale`, `_offset` |
| **Edit** | `commandStack`, `snapSettings`, `currentLayer`, `dirty` |
| **Theme/Units** | `themeMode` (AppThemeMode), `units` |
| **Loading** | `_isLoading`, `_error` |

### Métodos

| Método | Descripción |
|--------|-------------|
| `loadFile(content, {fileName, format})` | Carga, parsea (Isolate) y crea CadDocument |
| `loadFromPath(path)` | Carga desde ruta |
| `save()` / `saveAs(path)` | Exporta y escribe DXF (Isolate) |
| `undo()` / `redo()` | Delega en commandStack |
| `selectEntity(handle)` / `selectEntities(Set)` / `clearSelection()` | Selección |
| `beginCommand(type)` / `cancelCommand()` | Modos de edición |
| `setLayerVisibility(name, visible)` | Alterna capa |
| `createLayer/deleteLayer/renameLayer/setCurrentLayer` | Capas editables |
| `setSnapSettings(settings)` | Configura snaps |
| `fitToScreen()` | Ajusta vista |
| `setTransform(offset, scale)` | Actualiza vista |
| `getRecentFiles()` / `addRecentFile(path, thumbnail)` | Historial |
| `toggleTheme(mode)` / `setUnits(units)` | Preferencias |

---

## 3. Sub-sistemas (delegación)

### CommandStack (`lib/controllers/command_stack.dart`)
- push/undo/redo/clear; límite 100.
- Todas las mutaciones de `CadDocument` pasan por aquí (ADR-0004).

### SnapEngine (`lib/controllers/snap_engine.dart`)
- `snap(cursor, candidates)` → SnapResult? con tolerancia px→mundo.
- Cache por entidad; prioridad de modos.

### SelectionManager (`lib/controllers/selection_manager.dart`)
- Set de handles; window/crossing; reglas de capa bloqueada/frozen.

---

## 4. Version Counters

```dart
int _documentVersion = 0;    // cadFile estructural (entidades/capas/bloques)
int _layersVersion = 0;      // visibilidad/lock/frozen
int _selectionVersion = 0;   // selección
int _transformVersion = 0;   // zoom/pan
int _commandVersion = 0;     // undo/redo

void setLayerVisibility(String name, bool visible) {
  if (visible) _visibleLayers.add(name);
  else _visibleLayers.remove(name);
  _layersVersion++;
  notifyListeners();
}
```

---

## 5. Widget → ViewModel Mapping

| Widget | Lee de ViewModel | Selector |
|--------|-----------------|----------|
| HomeScreen | recentFiles | `context.watch` |
| ViewerScreen | document, selectedHandles, scale, offset | `context.watch` |
| LayerPanel | layersVersion | `context.select((vm) => vm.layersVersion)` |
| PropertyPanel | selectedHandles + documentVersion | `context.select((vm) => vm.documentVersion)` |
| ToolbarEdit | selectionVersion + commandVersion | `context.select(...)` |
| CommandBar | commandVersion, currentCommand | `context.select(...)` |
| ZoomControls | scale | `context.watch` |
| StatusBar | transformVersion, snapResult | `context.select(...)` |

---

## 6. State Flow

### File Open

```
User taps Open → FilePicker → FileHelper.detectFormat()
    ↓
Isolate: DxfParserWrapper.parse(content) → CadFile
    ↓
CadDocument.fromCadFile(cadFile) → viewModel.document
    ↓
notifyListeners() → ViewerScreen loader → CadPainter renderiza
    ↓
addRecentFile(path, thumbnail)
```

### Edit Commit (MOVE)

```
User drags selected entity → preview en vivo (sin mutar)
    ↓
Al soltar: CommandMove(handles, delta).execute(doc)
    ↓
commandStack.push(cmd) → doc.markDirty() → documentVersion++
    ↓
notifyListeners() → painter repinta; CommandBar muestra "MOVE OK"
    ↓
Ctrl+Z → commandStack.undo() → documentVersion++ → repinta
```

### Layer Toggle

```
User toggles layer → viewModel.setLayerVisibility()
    ↓
_layersVersion++
    ↓
notifyListeners()
    ↓
Solo LayerPanel rebuilds (context.select)
CadPainter se repinta (visibleLayers cambió)
```

### Selection

```
User taps entity → _selectNearestEntity() → viewModel.selectEntity(handle)
    ↓
_selectionVersion++
    ↓
notifyListeners()
    ↓
CadPainter resalta (halo + grips); ToolbarEdit/PropertyPanel muestran info
```

---

## 7. Reglas de estado

1. `CadDocument` no se muta fuera de CommandStack.
2. La UI lee versiones de estado; nunca mantiene copias locales del documento.
3. `dirty` se pone true en todo comando y false al guardar.
4. Al abrir un archivo nuevo: `commandStack.clear()`, selección vacía, `dirty=false`.
5. Undo/redo notifican vía `commandVersion` + `documentVersion`.
6. Los comandos de vista (zoom/pan) no entran en la pila.
