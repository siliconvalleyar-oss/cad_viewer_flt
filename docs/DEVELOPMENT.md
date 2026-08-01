# Development Guide — CAD Viewer & Editor

**Versión:** 0.3.0 · **Estado:** Aprobado (arquitectura técnica)

## Índice

1. [Environment Setup](#environment-setup)
2. [Architecture](#architecture)
3. [DXF Format](#dxf-format)
4. [DWG Support](#dwg-support)
5. [Project Structure](#project-structure)
6. [Key Packages](#key-packages)
7. [Extending the App](#extending-the-app)
8. [Design Reference](#design-reference)
9. [Performance](#performance)
10. [Phases](#phases-alto-nivel)

## Environment Setup

```bash
flutter doctor
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter run
flutter build apk --debug
```

## Architecture

Ver `docs/ARCHITECTURE.md` para el detalle completo. Resumen:

### State Management
Provider + ChangeNotifier. `CadViewModel` es la única fuente de verdad de la sesión. Paneles usan `context.select` con version counters para rebuild selectivo. La edición delega en `CommandStack`, `SnapEngine` y `SelectionManager`.

### Rendering Pipeline
1. **File Loading** — FilePicker obtiene bytes/ruta; `FileHelper.detectFormat()`
2. **Parsing** — `DxfParserWrapper` convierte la salida del paquete `dxf` a CadFile (en Isolate)
3. **Model Construction** — `CadDocument.fromCadFile()` crea sesión editable
4. **Rendering** — CadPainter pinta entidades visibles, grid, ejes, selección, grips, snap
5. **Interaction** — InteractiveViewer (zoom/pan) + GestureDetector (tap-to-select, drag-to-edit)

### Editing Pipeline
1. **Command** — cada operación crea un `CadCommand` (execute/undo)
2. **Commit** — `CommandStack.push(cmd)` ejecuta y apila; `doc.markDirty()`
3. **Undo/Redo** — `CommandStack.undo()/redo()`; botones y atajos Ctrl+Z/Y
4. **Snap** — `SnapEngine.snap()` resuelve el punto más cercano según modos activos
5. **Save** — `CadDocument.exportCadFile()` → `DxfWriter` (Isolate) → `writeFile(flush: true)`

## DXF Format

Formato texto con pares código/valor. Ejemplo (ver `docs/FORMATS.md` para el detalle):
```
0
SECTION
2
HEADER
9
$ACADVER
1
AC1015
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
MyLayer
10
0.0
20
0.0
11
100.0
21
50.0
0
CIRCLE
8
MyLayer
10
50.0
20
50.0
40
25.0
0
ENDSEC
0
EOF
```

## DWG Support

DWG es binario propietario; **no existe parser Dart puro** (investigación 2026-07).
- MVP: mensaje de no soporte + guía de conversión
- v0.3+: **ODA File Converter** (CLI local, gratuito, multiplataforma) → DXF temporal → parse
- Cloud (Apryse/CloudConvert) solo como opción futura con consentimiento (ADR-0005)

## Project Structure

```
cad_viewer/
├── lib/
│   ├── main.dart
│   ├── controllers/   (cad_view_model, command_stack, snap_engine, selection_manager)
│   ├── models/        (cad_file, cad_entity, cad_layer, cad_block, cad_document, cad_enums)
│   ├── parsers/       (dxf_parser, dxf_writer, dwg_parser)
│   ├── renderers/     (cad_painter, layer_manager, grid_renderer, axis_renderer, grip_renderer, snap_renderer)
│   ├── screens/       (home_screen, viewer_screen, layer_panel)
│   ├── widgets/       (zoom_controls, property_panel, command_bar, toolbar_edit, recent_files_list)
│   └── utils/         (coordinate_transform, geometry, units, aci_colors, file_helper)
├── test/              (unit, widget, golden, sample files)
├── tool/              (benchmark.dart)
├── pubspec.yaml
├── README.md
└── docs/              (ver README.md para índice)
```

## Key Packages

| Package        | Usage                                    |
|----------------|------------------------------------------|
| dxf ^1.3.0     | Parse DXF files to internal model        |
| provider       | State management                         |
| file_picker    | Browse device storage for CAD files      |
| shared_preferences | Recent files history and settings    |
| path_provider  | App documents directory                  |
| screenshot     | Capture current view as PNG              |
| share_plus     | Share original CAD file                  |
| flutter_svg    | SVG icons/previews                       |
| path, collection | Path utils, collection helpers          |

Sin dependencias externas de undo/redo ni geometría: se implementan como código propio (ADR-0004).

## Extending the App

### Adding a New Entity Type
1. Add class in `models/cad_entity.dart` (+ copyWith)
2. Add parsing logic in `parsers/dxf_parser.dart`
3. Add serialization in `parsers/dxf_writer.dart`
4. Add rendering logic in `renderers/cad_painter.dart`
5. Add hit-testing logic in `screens/viewer_screen.dart`
6. Add snap points in `controllers/snap_engine.dart`
7. Add grips in `renderers/grip_renderer.dart`
8. Add tests (parser, writer, painter, snap)

### Adding a New Edit Command
1. Create `CadCommand` subclass in `controllers/commands/`
2. Implement `execute()` and `undo()`
3. Wire it in the appropriate UI (toolbar/command bar)
4. Add tests: execute+undo = original state

### Adding a New Panel
1. Create widget in `widgets/`
2. Connect state in `controllers/cad_view_model.dart`
3. Add button in toolbar if needed
4. Use `context.select` for selective rebuild

## Design Reference

See `docs/DESIGN.md` (visual design, UX, animations, theming, accessibility).
See `docs/AESTHETICS.md` (6 themes: Light, Dark, Blueprint, Poster, Infographic, AutoCAD Dark).
See `docs/EDITING.md` (editing system: commands, undo/redo, snapping, grips, command bar).

**Key design tokens:**
- Background light: `#F5F7FA`, dark: `#1A1D23`
- Canvas light: `#FFFFFF`, dark: `#1E2128`
- Grid opacity: 0.3 (light), 0.2 (dark)
- Axis X: `#E53E3E` / `#FC8181`, Axis Y: `#2B6CB0` / `#63B3ED`
- Control blur: 20px, radius: 12dp
- Touch target minimum: 44dp
- Auto-hide controls: 3s inactivity

## Performance

Ver `docs/PERFORMANCE.md`. Resumen:
- `RepaintBoundary` around canvas
- Entity culling + spatial index
- Parseo y escritura en Isolates
- Version counters para rebuild selectivo
- Cache de TextPainter y Picture
- LOD a zoom lejano

## Phases (alto nivel)

Ver `docs/TODO.md` para tareas detalladas y `docs/ROADMAP.md` para el roadmap versionado.

1. **Fases 0–8 (v0.1.x)** — Config, modelos, parser/writer, renderizado, capas, selección, pantallas, diseño UX, exportación, tests → **Visor**
2. **Fases 9–13 (v0.2.x)** — CadDocument, comandos, undo/redo, creación, transformaciones, snap, selección múltiple, capas editables, medición, guardado → **Editor básico**
3. **Fases 14–15 (v0.3.x)** — Línea de comandos, coordenadas, grips, propiedades, DWG ODA, TRIM/OFFSET, PDF → **Editor avanzado**
4. **Fase 16 (v1.0.0)** — Estable, i18n, publicación
