# Estrategia de Pruebas — CAD Viewer & Editor

**Versión:** 0.3.3
**Fecha:** 2026-07-31
**Propósito:** Estrategia de pruebas de la aplicación: tipos de test, archivos de muestra, cobertura objetivo, herramientas y pipeline CI.

---

## 1. Pirámide de pruebas

```
        ┌──────────┐
        │ Widget / │   ← pocas pero críticas (flujos completos)
        │ Golden   │
      ┌─┴──────────┴─┐
      │ Unitaria     │   ← muchas: parsers, modelos, comandos, snap
    ┌─┴──────────────┴─┐
    │ Modelo puro Dart │   ← base sólida (sin Flutter)
    └──────────────────┘
```

| Nivel | Qué cubre | Objetivo |
|-------|-----------|----------|
| Modelo puro | Models, geometry, units, commands | ≥ 90% |
| Unitaria | Parsers, writers, viewmodel, snap, selection | ≥ 70% global |
| Widget | HomeScreen, LayerPanel, PropertyPanel, CommandBar, Toolbar | Flujos clave |
| Golden | CadPainter con archivos de muestra | Regresión visual |
| Integración | Apertura → edición → guardado → reapertura | Flujo E2E |
| Manual | QA por plataforma (matriz) | Cubre gestos reales |

---

## 2. Archivos de muestra (`test/files/`)

| Archivo | Formato | Propósito |
|---------|---------|-----------|
| `sample_r12_librecad.dxf` | R12 (LibreCAD) | POLYLINE pesada, capas, textos |
| `sample_r12_autocad.dxf` | R12 | Arcos, círculos, bloques |
| `sample_r2000.dxf` | R2000 | LWPOLYLINE, SPLINE, MTEXT, HATCH |
| `sample_r2010.dxf` | R2010 | DIMENSION, bloques anidados |
| `sample_dwg.dwg` | DWG R2018 | Flujo ODA (v0.3+) |
| `sample_binary.dxf` | DXF binario | Advertencia |
| `sample_corrupt.dxf` | — | Error handling |
| `sample_units_inch.dxf` | R2000 | `$INSUNITS=1` conversión |
| `sample_selection.dxf` | R2000 | Hit-testing denso |
| `sample_empty.dxf` | R2000 | Carga de archivo vacío (QA §7) |

> ✅ **Estado (v0.3.2):** los archivos existen en `test/files/` como **sintéticos escritos a mano** siguiendo la especificación DXF (validados: pares group code/valor, EOF, `$ACADVER`, sentinel binario, magic bytes DWG). Ver el manifest `test/files/README.md` (matriz, convenciones, resultados esperados).
>
> ⚠️ **Antes del release:** reemplazar los sintéticos por **archivos reales exportados** desde LibreCAD (R12) y AutoCAD (R2000/R2010), y el DWG stub por uno convertido con ODA File Converter, para validar tolerancia a archivos reales.

---

## 3. Suites de tests (mapeo a código)

### 3.1 `test/models/`

| Archivo | Cubre |
|---------|-------|
| `cad_entity_test.dart` | Igualdad, copyWith, subtipos, defaults |
| `cad_file_test.dart` | getBounds (todas las entidades), header, capas implícitas |
| `cad_document_test.dart` | fromCadFile, exportCadFile (no exporta estado de sesión), dirty |
| `cad_layer_test.dart` | frozen > visible, locked, displayColor |

### 3.2 `test/parsers/`

| Archivo | Cubre |
|---------|-------|
| `dxf_parser_test.dart` | Cada entidad del catálogo; versiones R12/R2000/R2010; ByLayer vs override; bulge; MTEXT strip; INSERT inexistente; capa inexistente → "0" |
| `dxf_writer_test.dart` | Round-trip (parse→write→parse = mismo modelo); R12 convierte LWPOLYLINE→POLYLINE; precisión 6 decimales |
| `dwg_parser_test.dart` | MVP: mensaje correcto; v0.3+: stub del CLI ODA |

### 3.3 `test/controllers/`

| Archivo | Cubre |
|---------|-------|
| `command_stack_test.dart` | Push/undo/redo, límite 100, clear, comandos de vista excluidos |
| `commands_test.dart` | Cada comando: execute + undo = estado original |
| `selection_manager_test.dart` | Tap, shift toggle, window vs crossing, capa bloqueada |
| `snap_engine_test.dart` | Cada modo, tolerancia, prioridades, ortho, polar |
| `cad_view_model_test.dart` | Carga, error, unidades, dirty, notificaciones |

### 3.4 `test/utils/`

| Archivo | Cubre |
|---------|-------|
| `geometry_test.dart` | dist punto-segmento, intersección, área, ángulo, bulge→arco |
| `coordinate_transform_test.dart` | mundo↔canvas, fit-to-screen, bounds |
| `units_test.dart` | Conversiones mm↔cm/m/inch, formateo |

### 3.5 `test/widgets/`

| Archivo | Cubre |
|---------|-------|
| `home_screen_test.dart` | Render, abrir, recientes, settings |
| `viewer_screen_test.dart` | Load → canvas, toggle layers, tap select, undo/redo buttons |
| `layer_panel_test.dart` | Checkbox, show/hide all, locked display |
| `property_panel_test.dart` | Props por tipo, close |
| `command_bar_test.dart` | Autocompletado, entrada coordenadas |

### 3.6 `test/golden/`

| Archivo | Cubre |
|---------|-------|
| `cad_painter_golden_test.dart` | Snapshot del canvas por tema (light, dark, blueprint, autocad) con `sample_r2000.dxf` |

---

## 4. Objetivos de cobertura

| Área | Objetivo |
|------|----------|
| Parsers + writers | ≥ 80% líneas |
| Models | ≥ 90% |
| Controllers (comandos, snap, selection) | ≥ 75% |
| Widgets | Flujos clave (no cobertura numérica estricta) |
| Global | ≥ 70% |

**Medición:** `flutter test --coverage` + `genhtml` / `lcov`. Umbral en CI: falla si < 70%.

---

## 5. Pipeline CI (GitHub Actions)

YAML **ejecutable** (archivo: `.github/workflows/ci.yml`). Dispara en push/PR, con caché de dependencias y un job por etapa de la pirámide:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze --fatal-infos

  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: dart format --output=none --set-exit-if-changed .

  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter test --coverage
      - name: Cobertura ≥ 70%
        run: |
          sudo apt-get update
          sudo apt-get install -y lcov
          lcov --summary coverage/lcov.info > /tmp/cov.txt
          lines=$(grep -oP 'lines\.*: \K[\d.]+(?=%)' /tmp/cov.txt | head -1)
          echo "Cobertura de líneas: ${lines}%"
          awk -v v="$lines" 'BEGIN { if (v < 70.0) { print "FALLO: cobertura < 70%"; exit 1 } }'

  golden:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter test test/golden --update-goldens=false

  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run tool/benchmark.dart
```

**Notas de ejecución:**
- Para **fijar la versión de Flutter** (recomendado en release), añadir `flutter-version: <X.Y.Z>` coincidiendo con `VERSION` / el constraint de SDK de `pubspec.yaml`; en desarrollo se usa `channel: stable`.
- El job `golden` compara contra los goldens **commiteados**; actualizarlos localmente con `--update-goldens` y subir el cambio en el mismo PR.
- El job `bench` compara contra los umbrales de PERFORMANCE.md §1 y §1.1 (falla si alguna métrica excede el objetivo del runner, que representa un tier desktop medio).
- El job `unit` ejecuta **todos** los tests (incluidos `test/golden/`, que `golden` repite). Si en el futuro los golden llevan tag, acotar con `flutter test --exclude-tags golden` para evitar la redundancia.
- Builds de iOS/macOS/Windows requieren runners específicos y firma; se documentarán en `docs/RELEASE.md` (pendiente).

---

## 6. Tests de rendimiento (benchmark)

- `tool/benchmark.dart`: abre los archivos de `test/files/`, mide parseo/escritura/fit/hit-test, imprime tabla. Umbrales según PERFORMANCE.md §1 y §1.1.
- Ejecución en CI (job `bench` de §5, opcional con cron) y manual antes de release.

---

## 7. Testing manual (QA)

Matriz por plataforma (Android/iOS/Windows/macOS/Linux):

| Área | Caso |
|------|------|
| Carga | DXF R12 LibreCAD, R2000, R2010, DWG (v0.3+), corrupto, binario, vacío, >10 MB |
| Render | Zoom máx/mín, pan, fit, capas ocultas, grid/eje por tema |
| Selección | Tap, shift, window, crossing, capa bloqueada, ESC |
| Edición | Crear cada entidad, mover/rotar/escalar, borrar, undo/redo repetido |
| Snap | Cada modo en entidades cercanas, ortho, polar, tolerancia |
| Guardado | SAVE, SAVE AS, R12 (polilíneas), reapertura del archivo guardado |
| UX | Gestos, auto-ocultar controles, haptics, landscape, accesibilidad (lector) |
| Estados | Cambios sin guardar, autosave, error de permisos |

---

## 8. Definición de "listo" (DoD) por fase

Cada fase de `docs/TODO.md` tiene su Definition of Done. Requisitos comunes:
- `flutter analyze` sin warnings (fatal-infos).
- `dart format` aplicado.
- Tests de la suite afectada en verde.
- Archivos de muestra actualizados si el catálogo cambió.
- CHANGELOG.md actualizado.
