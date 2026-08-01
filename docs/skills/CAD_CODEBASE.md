# 🎯 Skill: cad_codebase — CAD Viewer & Editor Project

**Fecha:** 31 Julio 2026
**Versión:** 0.3.1
**Propósito:** Skill principal del proyecto cad_viewer — app Flutter para **visualizar y editar** archivos CAD (DXF, DWG). Compatible con AutoCAD y LibreCAD.

---

## 1. Project Overview

Aplicación Flutter profesional para visualizar y editar archivos **CAD**:
- **`.dxf`** — DXF texto plano (AutoCAD/LibreCAD); parser con paquete `dxf ^1.3.0` + wrapper propio; escritura con `DxfWriter` propio
- **`.dwg`** — DWG binario propietario; MVP mensaje + guía; v0.3+ conversión local con **ODA File Converter** (CLI)
- **`.dgn`** — Opcional; fuera de v1.0 (ADR-0008)

**Stack:**
| Componente | Tecnología |
|------------|-----------|
| Framework | Flutter 3.x / Dart 3.x |
| State management | Provider + ChangeNotifier |
| Renderizado | CustomPainter + InteractiveViewer |
| Parsing DXF | Paquete `dxf ^1.3.0` + `DxfParserWrapper` |
| Escritura DXF | `DxfWriter` propio |
| Parsing DWG | ODA File Converter (v0.3+, local) |
| Edición | Patrón Command + `CommandStack` propio |
| File picking | file_picker |
| Storage | path_provider + shared_preferences |
| Screenshot / Share | screenshot / share_plus |

**Documentación:** Ver `docs/README` índice en `README.md`. Base de requisitos: `docs/REQUIREMENTS.md`. Edición: `docs/EDITING.md`.

---

## 2. Directory Structure

```
cad_viewer/
├── lib/
│   ├── main.dart                    # Entry point, theme, Provider setup
│   ├── controllers/
│   │   ├── cad_view_model.dart       # ViewModel / ChangeNotifier central
│   │   ├── command_stack.dart        # Undo/redo (patrón Command)
│   │   ├── snap_engine.dart          # Snapping
│   │   └── selection_manager.dart    # Selección múltiple
│   ├── models/                       # Dart puro (sin Flutter)
│   │   ├── cad_file.dart             # CadFile, CadHeader
│   │   ├── cad_entity.dart           # CadEntity base + 14 tipos
│   │   ├── cad_layer.dart            # CadLayer (visible, locked, frozen...)
│   │   ├── cad_block.dart            # CadBlock
│   │   ├── cad_document.dart         # Sesión editable (dirty, selection)
│   │   └── cad_enums.dart            # Enums (entity type, units, snap...)
│   ├── parsers/
│   │   ├── dxf_parser.dart           # Wrapper dxf package → modelos internos
│   │   ├── dxf_writer.dart           # Serialización DXF (R2000/R12)
│   │   └── dwg_parser.dart           # ODA bridge (v0.3+)
│   ├── renderers/
│   │   ├── cad_painter.dart          # CustomPainter principal
│   │   ├── layer_manager.dart        # Visibilidad y color de capas
│   │   ├── grid_renderer.dart        # Rejilla
│   │   ├── axis_renderer.dart        # Ejes X/Y
│   │   ├── grip_renderer.dart        # Grips de edición
│   │   └── snap_renderer.dart        # Indicador de snap
│   ├── screens/
│   │   ├── home_screen.dart          # Inicio + recientes
│   │   ├── viewer_screen.dart        # Canvas + gestos + paneles
│   │   └── layer_panel.dart          # Panel de capas
│   ├── widgets/
│   │   ├── zoom_controls.dart        # Zoom +, -, fit
│   │   ├── property_panel.dart       # Propiedades de entidad
│   │   ├── command_bar.dart          # Línea de comandos
│   │   ├── toolbar_edit.dart         # Toolbar de edición contextual
│   │   └── recent_files_list.dart    # Recientes horizontales
│   └── utils/
│       ├── coordinate_transform.dart # Transformación mundo↔canvas
│       ├── geometry.dart             # Geometría analítica
│       ├── units.dart                # Unidades (mm base)
│       ├── aci_colors.dart           # ACI → Color
│       └── file_helper.dart          # Detección y lectura segura
├── test/                             # Unit, widget, golden + test/files/
├── tool/benchmark.dart               # Benchmark de rendimiento
├── pubspec.yaml
├── README.md
└── docs/                             # Ver README.md índice
```

---

## 3. Architecture & State Management

### Patrón: Provider + ChangeNotifier

```
MaterialApp
└── ChangeNotifierProvider<CadViewModel>
    ├── HomeScreen (recientes, abrir, ajustes)
    └── ViewerScreen
        ├── AppBar (file name, back, fit, info)
        ├── CadView (InteractiveViewer + CadPainter + overlays)
        ├── ZoomControls / ToolbarEdit / CommandBar
        ├── LayerPanel / PropertyPanel
        └── StatusBar (coordenadas + snap + medidas)
```

### CadViewModel (ChangeNotifier central)

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `document` | `CadDocument?` | Sesión editable actual |
| `selectedHandles` | `Set<String>` | Selección |
| `visibleLayers` | `Set<String>` | Capas visibles |
| `currentLayer` | `String` | Capa activa |
| `scale` / `offset` | `double` / `Offset` | Vista |
| `units` | `UnitsType` | Unidades de visualización |
| `snapSettings` | `SnapSettings` | Modos de snap |
| `themeMode` | `AppThemeMode` | Tema (6) |
| `commandStack` | `CommandStack` | Undo/redo |
| `dirty` | `bool` | Cambios sin guardar |
| `isLoading` / `error` | `bool` / `String?` | Carga/errores |

**Version counters:** `documentVersion`, `layersVersion`, `selectionVersion`, `transformVersion`, `commandVersion`.

---

## 4. Critical Notes & Refactoring Needed

### 🔴 4.1 — Soporte DWG/DGN
No hay parser nativo en Dart. ODA File Converter (CLI local, v0.3+). DGN fuera de alcance. Ver ADR-0005/0008.

### 🟡 4.2 — `utils/` pendiente
Implementar coordinate_transform, geometry, units, aci_colors, file_helper.

### 🟡 4.3 — `cad_painter.dart` puede crecer
Separar dibujo por tipo de entidad en métodos privados o clases helper; overlays en renderers separados (grid, axis, grip, snap).

### 🟡 4.4 — Sin tests unitarios
Implementar tests para parsers, writer, modelos, comandos, snap, selection (ver `docs/TESTING.md`).

### 🟡 4.5 — Performance con dibujos grandes
Culling + spatial index + Isolates + cache de Picture/TextPainter (ver `docs/PERFORMANCE.md`).

### 🟡 4.6 — ViewModel puede crecer
Delegar en CommandStack/SnapEngine/SelectionManager; no mutar el doc desde la UI.

---

## 5. AI Verification Checklist

Cuando una AI visite este proyecto, debe verificar:

- [ ] **5.1** — ¿El wrapper dxf convierte correctamente todas las entidades requeridas?
- [ ] **5.2** — ¿CadPainter tiene shouldRepaint basado en version counters (no listas)?
- [ ] **5.3** — ¿LayerPanel usa context.select apropiadamente?
- [ ] **5.4** — ¿El hit-testing soporta todos los tipos de entidad?
- [ ] **5.5** — ¿Las dependencias en pubspec están fijadas?
- [ ] **5.6** — ¿Los archivos están formateados con dart format y analyze limpio?
- [ ] **5.7** — ¿Hay tests para parsers, modelos y comandos?
- [ ] **5.8** — ¿El canvas se calcula dinámicamente según bounds?
- [ ] **5.9** — ¿Toda mutación de CadDocument pasa por CommandStack?
- [ ] **5.10** — ¿Undo/redo funcionan para todas las operaciones de edición?
- [ ] **5.11** — ¿El snap usa tolerancia en px adaptada al zoom?
- [ ] **5.12** — ¿El writer produce DXF R2000/R12 válido (round-trip)? (ver FORMATS.md)
- [ ] **5.13** — ¿Unidades internas en mm en todo el modelo?
- [ ] **5.14** — ¿El guardado usa flush:true y verifica errores?

---

## 6. Common Tasks

### 🔧 Agregar entidad DXF nueva
1. Clase en `models/cad_entity.dart` (+ copyWith)
2. Parseo en `parsers/dxf_parser.dart`
3. Serialización en `parsers/dxf_writer.dart`
4. Render en `renderers/cad_painter.dart`
5. Hit-testing en `screens/viewer_screen.dart`
6. Snap points en `controllers/snap_engine.dart`
7. Grips en `renderers/grip_renderer.dart`
8. Tests (parser, writer, painter, snap)

### 🔧 Agregar comando de edición nuevo
1. Subclase de `CadCommand` (execute + undo)
2. Conectar en toolbar/command bar
3. Test: execute + undo = original

### 🔧 Cambiar color de capa en visualización
1. Modificar `CadLayer.displayColor`
2. `layer_manager.dart` usa displayColor si existe

### 🔧 Agregar pantalla de ajustes
1. Widget en `widgets/` o modal en `home_screen.dart`
2. Persistir en shared_preferences vía `cad_view_model.dart`
