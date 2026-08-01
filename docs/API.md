# API Documentation — CAD Viewer & Editor

**Versión:** 0.3.0 · **Estado:** Aprobado (arquitectura técnica)
**Propósito:** Referencia de la API pública de modelos, parsers, writers, state management, edición y renderers. Detalle de implementación en `docs/DATA_MODEL.md`, `docs/SERIALIZATION.md` y `docs/ARCHITECTURE.md`.

## Índice

1. [Core Models](#1-core-models)
2. [Parsers & Writers](#2-parsers--writers)
3. [State Management](#3-state-management)
4. [Widgets](#4-widgets)
5. [Renderers](#5-renderers)
6. [Utils](#6-utils)

---

## 1. Core Models

### CadFile
Modelo interno resultado del parsing de DXF/DWG.

| Property       | Type                   | Description                          |
|----------------|------------------------|--------------------------------------|
| fileName       | String                 | Source file name                     |
| format         | FileFormat             | `dxf`, `dwg` or `unknown`            |
| version        | String                 | DXF version (AC1009, AC1015, AC1032...) |
| header         | CadHeader              | Header vars: units, extMin, extMax   |
| layers         | List<CadLayer>         | Layer definitions                    |
| entities       | List<CadEntity>        | All drawing entities                 |
| blocks         | List<CadBlock>         | Block definitions                    |
| getBounds()    | Rect                   | Drawing bounding box                 |

### CadHeader
| Property       | Type       | Description                          |
|----------------|------------|--------------------------------------|
| units          | UnitsType  | Drawing units (normalized to mm)     |
| extMin / extMax| Point3     | Drawing limits                       |
| baseAngle      | double     | Base angle (radians)                 |
| insUnits       | int        | Raw `$INSUNITS` value                |

### CadLayer
| Property       | Type       | Description                          |
|----------------|------------|--------------------------------------|
| name           | String     | Layer name                           |
| color          | int        | AutoCAD color index (ACI) 1-255      |
| lineType       | String     | Linetype name ('Continuous', etc.)   |
| lineWeight     | double?    | Line weight override (mm)            |
| visible        | bool       | Layer visibility                     |
| locked         | bool       | Visible but not editable/selectable  |
| frozen         | bool       | Not rendered nor editable            |
| displayColor   | Color?     | Override visualization color         |
| isCurrent      | bool       | Active layer for new entities        |

### CadEntity (base)
| Property       | Type       | Description                          |
|----------------|------------|--------------------------------------|
| handle         | String     | Entity handle (unique ID)            |
| layer          | String     | Layer name                           |
| color          | int?       | Entity color (override; null = ByLayer) |
| lineType       | String?    | Entity linetype (override)           |
| lineWeight     | double?    | Line weight in mm (override)         |
| type           | CadEntityType | Polymorphic type                   |
| copyWith()     | CadEntity  | Immutable copy with changes          |

### Entity Types

| Type         | Fields                                        | Description               |
|--------------|-----------------------------------------------|---------------------------|
| CadLine      | x1, y1, x2, y2                                | Line segment              |
| CadCircle    | cx, cy, radius                                | Circle                    |
| CadArc       | cx, cy, radius, startAngle, endAngle          | Arc (partial circle)      |
| CadEllipse   | cx, cy, majorRadius, minorRadius, rotation    | Ellipse                   |
| CadLwPolyline| points, closed, bulge                         | Lightweight polyline (DXF R14+) |
| CadPolyline  | points, closed                                | Heavy polyline (DXF R12, VERTEX+SEQEND) |
| CadText      | text, x, y, height, rotation, style, horizontalAlign | Single-line text   |
| CadMText     | text, x, y, height, rotation, attachmentPoint, width | Multi-line text   |
| CadInsert    | blockName, x, y, scaleX, scaleY, rotation     | Block reference (INSERT)  |
| CadPoint     | x, y                                         | Point entity              |
| CadHatch     | patternName, boundaries, scale, rotation      | Hatch pattern (read-only v1.0) |
| CadSpline    | degree, controlPoints, knots, fitPoints       | Spline curve (move only)  |
| CadDim       | dimType, x1, y1, x2, y2, x3, y3, text, style  | Dimension (move only)     |
| Cad3dFace    | corners (4x3)                                 | 3D face (read-only v1.0)  |

### CadBlock
| Property       | Type              | Description                          |
|----------------|-------------------|--------------------------------------|
| name           | String            | Block name                           |
| basePoint      | Point3            | Insertion point                      |
| entities       | List<CadEntity>   | Entities within the block            |
| getBounds()    | Rect              | Local bounds                         |

### CadDocument (editable session)
| Property       | Type              | Description                          |
|----------------|-------------------|--------------------------------------|
| cadFile        | CadFile           | Base file (immutable reference)      |
| entities       | List<CadEntity>   | Working entities                     |
| layers         | List<CadLayer>    | Working layers                       |
| blocks         | List<CadBlock>    | Working blocks                       |
| selection      | Set<String>       | Selected handles                     |
| currentLayer   | String            | Active layer                         |
| dirty          | bool              | Unsaved changes                      |
| documentVersion| int               | Increments on structural change      |
| fromCadFile()  | CadDocument       | Create clean session                 |
| exportCadFile()| CadFile           | Session → clean file (no session state) |

---

## 2. Parsers & Writers

### DxfParserWrapper (`lib/parsers/dxf_parser.dart`)
Wrapper sobre el paquete `dxf ^1.3.0` que convierte su salida a modelos internos.

- `parse(String content, {String fileName})` → CadFile (correr en Isolate)
- `parseFile(String path)` → CadFile
- `fromDxfDocument(dxfDoc, {fileName})` → CadFile

### DxfWriter (`lib/parsers/dxf_writer.dart`)
Serializa CadFile/CadDocument a DXF ASCII.

- `write(CadFile file, {DxfVersion version = R2000})` → String
- `writeToFile(CadFile file, String path, {DxfVersion version})` → Future<void> (flush: true)
- Convierte LWPOLYLINE → POLYLINE en R12; omite/advierte SPLINE/MTEXT en R12.

### DwgParser (`lib/parsers/dwg_parser.dart`)
- MVP: `parseFile(path)` lanza/retorna mensaje "convierta a DXF"
- v0.3+: `convertDwgToDxf(inputPath, {odacPath})` → DXF temporal (CLI ODA), luego delega en DxfParserWrapper

---

## 3. State Management

### CadViewModel (`lib/controllers/cad_view_model.dart`)

**Properties:**
- `document` — CadDocument? (working session)
- `selectedHandles` — Set<String>
- `visibleLayers` — Set<String>
- `currentLayer` — String
- `scale` — double, `offset` — Offset
- `units` — UnitsType
- `snapSettings` — SnapSettings
- `themeMode` — AppThemeMode
- `commandStack` — CommandStack
- `dirty` — bool
- `isLoading`, `error`

**Methods:**
- `loadFile(content, {fileName, format})` — Load and parse
- `loadFromPath(path)` — Load from device path
- `save()` / `saveAs(path)` — Save via DxfWriter
- `undo()` / `redo()` — CommandStack delegation
- `setLayerVisibility(name, visible)`
- `showAllLayers()` / `hideAllLayers()`
- `createLayer(name, color)` / `deleteLayer(name)` / `renameLayer(old, new)`
- `setCurrentLayer(name)`
- `selectEntity(handle)` / `selectEntities(Set)` / `clearSelection()`
- `beginCommand(commandType)` — Enter edit mode
- `applySnapResult(point)` — Use snapped point
- `fitToScreen()`
- `setTransform(offset, scale)`
- `getRecentFiles()` / `addRecentFile(path, thumbnail)`
- `toggleTheme(mode)` / `setUnits(units)` / `setSnapSettings(settings)`

**Version counters:** `documentVersion`, `layersVersion`, `selectionVersion`, `transformVersion`, `commandVersion`.

### CommandStack (`lib/controllers/command_stack.dart`)
- `push(CadCommand)` — executes and stacks
- `undo()` / `redo()`
- `canUndo` / `canRedo`
- `clear()`
- Limit: 100

### SnapEngine (`lib/controllers/snap_engine.dart`)
- `snap(Point cursor, {required List<CadEntity> candidates, required SnapSettings settings})` → SnapResult?
- Modes: endpoint, midpoint, center, quadrant, intersection, nearest, grid, polar (+ ortho filter)

### SelectionManager (`lib/controllers/selection_manager.dart`)
- `add`, `remove`, `toggle`, `clear`, `addRange`
- `selectByWindow(Rect, {required WindowMode mode})` — crossing | window
- Blocked layers rule

---

## 4. Widgets

| Widget           | Description                                      |
|------------------|--------------------------------------------------|
| HomeScreen       | Start screen: open button, recent files, settings|
| ViewerScreen     | Main canvas: InteractiveViewer + CadPainter      |
| LayerPanel       | Layer list: visibility, lock, color, presets     |
| PropertyPanel    | Bottom sheet with entity properties              |
| ZoomControls     | Floating zoom +, -, fit to screen                |
| RecentFilesList  | Horizontal recent files with thumbnails          |
| CommandBar       | Command/coordinate input line (collapsible)      |
| ToolbarEdit      | Contextual edit toolbar (move, rotate, scale, erase, create) |
| SettingsSheet    | Theme, units, grid, snap settings, about         |

---

## 5. Renderers

### CadPainter (`lib/renderers/cad_painter.dart`)
- `paint()` — background, grid, axes, visible entities, selection halo, grips, snap indicator
- `_drawLine/_drawCircle/_drawArc/_drawEllipse/_drawPolyline/_drawLwPolyline/_drawText/_drawMText/_drawInsert/_drawPoint/_drawHatch/_drawSpline/_drawDim/_draw3dFace`
- `_getAciColor(aci)` — ACI → Color (theme-aware, see AESTHETICS.md)
- `shouldRepaint()` — compares version counters, not full lists

### LayerManager (`lib/renderers/layer_manager.dart`)
- `getVisibleEntities()` — filter by visible && !frozen
- `isLayerVisible(name)`, `toggleLayer(name)`, `showAll()`, `hideAll()`
- `getLayerColor(layer)` — displayColor ?? aciColor(theme)

### GridRenderer / AxisRenderer / GripRenderer / SnapRenderer
- `GridRenderer.paint(canvas, transform, theme, gridType)` — adaptive spacing
- `AxisRenderer.paint(canvas, transform, theme, showAxes)` — X red / Y blue with arrows
- `GripRenderer.paint(canvas, grips, theme)` — squares/diamonds
- `SnapRenderer.paint(canvas, snapResult, theme)` — snap marker per mode

---

## 6. Utils

| Class | Location | API |
|-------|----------|-----|
| CoordinateTransform | `lib/utils/coordinate_transform.dart` | toCanvas, toWorld, getDrawingBounds, fitToScreenMatrix |
| Geometry | `lib/utils/geometry.dart` | distPointToSegment, intersection, area, angle, bulgeToArc, arcToBulge |
| Units | `lib/utils/units.dart` | toMm, fromMm, format (locale-aware) |
| AciColors | `lib/utils/aci_colors.dart` | standardAciColor, themeAciColor |
| FileHelper | `lib/utils/file_helper.dart` | detectFormat, isDxf, isDwg, readFileAsString (try-catch), getFileExtension |
