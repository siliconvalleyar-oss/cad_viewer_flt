# Prompt — Generación de app CAD Viewer & Editor Flutter

Copia y pega este bloque completo como solicitud a otra IA para generar la aplicación desde cero. La documentación fuente está en `docs/` (ver `README.md` para el índice).

---

Desarrolla una aplicación multiplataforma en Flutter para **visualizar y editar** archivos CAD en formatos DXF, DWG y opcionalmente DGN, compatible con archivos de **AutoCAD y LibreCAD**. La app debe permitir abrir archivos locales, navegar con zoom y desplazamiento, gestionar capas, consultar propiedades de entidades, **crear y modificar entidades con undo/redo**, usar snapping para precisión y guardar como DXF.

## Requisitos funcionales — Visor

- **Carga de archivos:** usar `file_picker` para seleccionar `.dxf` y `.dwg`. Guardar historial de últimos 10 archivos con `shared_preferences`. Mostrar recientes en Home con nombre y miniatura. Detectar formato por extensión y magic bytes (DWG empieza con `AC10xx`).
- **Renderizado:** `CustomPainter` + `Canvas` envuelto en `InteractiveViewer`. Soportar: LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, POLYLINE (pesada, R12/LibreCAD), TEXT, MTEXT, POINT, INSERT (bloques, recursivo), HATCH (básico), SPLINE, DIMENSION, 3DFACE. Ajuste a pantalla inicial (fit, 80% del viewport).
- **Gestión de capas:** panel con nombre, color ACI y visibilidad; presets mostrar/ocultar todas; override de color de visualización; capa bloqueada (visible, no editable).
- **Interacción:** pinch zoom, drag pan, doble toque zoom en área, botones +/−/fit. Hit-testing por tipo de entidad para selección y hoja de propiedades (tipo, capa, color, geometría, grosor).
- **Exportación:** screenshot a PNG respetando el tema; compartir archivo original con `share_plus`.

## Requisitos funcionales — Editor

- **Selección múltiple:** tap, shift+tap (toggle), ventana (arrastrar, window verde / crossing azul), Ctrl+A, ESC deselecciona. Entidades en capa bloqueada no seleccionables.
- **Creación:** LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, TEXT, POINT con preview en vivo (rubber band). Se crean en la capa actual, con color ByLayer.
- **Transformación:** mover, rotar, escalar, copiar y borrar la selección con atajos (Ctrl+C/V/X, DEL).
- **Undo/Redo:** patrón Command (CadCommand.execute/undo) con `CommandStack` de límite 100. Toda operación de edición es deshacible. Atajos Ctrl+Z/Ctrl+Y y botones.
- **Snapping:** SnapEngine con modos endpoint, midpoint, center, intersection, quadrant, nearest, grid, polar; ortho (F8) y toggle (F3); tolerancia configurable en px; indicador visual del snap.
- **Grips:** al seleccionar, puntos de control editables por tipo de entidad (extremos de línea, centro/radio de círculo, vértices de polilínea...). Arrastrar grip genera el comando correspondiente.
- **Línea de comandos:** barra colapsable con catálogo de comandos (LINE, CIRCLE, ERASE, MOVE, ROTATE, SCALE, COPY, DIST, AREA, SAVE, UNDO, REDO...), autocompletado, historial y entrada de coordenadas absolutas (`10,20`, `#10,20`), relativas (`@10,20`) y polares (`10<45`).
- **Capas editables:** crear, renombrar, cambiar color, borrar capa vacía, establecer capa actual.
- **Medición:** distancia, ángulo y área (overlay temporal, sin crear entidades).
- **Guardado:** SAVE/SAVE AS como DXF (R2000 por defecto; R12 convierte LWPOLYLINE→POLYLINE y advierte sobre SPLINE/MTEXT). Autoguardado cada 5 min. Diálogo de cambios sin guardar.

## Arquitectura técnica

- **Dependencias:** `dxf ^1.3.0` (parseo), `provider`, `file_picker`, `shared_preferences`, `path_provider`, `screenshot`, `share_plus`, `flutter_svg`, `path`, `collection`. El undo/redo y la geometría son código propio (sin dependencias externas).
- **Estructura:** `models/` (Dart puro: cad_file, cad_entity, cad_layer, cad_block, cad_document, cad_enums), `parsers/` (dxf_parser wrapper, dxf_writer propio, dwg_parser), `renderers/` (cad_painter, layer_manager, grid_renderer, axis_renderer, grip_renderer, snap_renderer), `controllers/` (cad_view_model, command_stack, snap_engine, selection_manager), `screens/`, `widgets/`, `utils/` (coordinate_transform, geometry, units, aci_colors, file_helper).
- **Estado:** Provider + ChangeNotifier. `CadViewModel` con version counters (`documentVersion`, `layersVersion`, `selectionVersion`, `transformVersion`, `commandVersion`) y `context.select` para rebuild selectivo. La edición delega en CommandStack/SnapEngine/SelectionManager.
- **Modelo de sesión:** `CadFile` (archivo, inmutable) ↔ `CadDocument` (sesión editable: entidades, capas, selección, dirty). Toda mutación pasa por comandos. `exportCadFile()` convierte sesión→archivo limpio.
- **Parseo/escritura en Isolates** (`compute`) para archivos > 1 MB. Renderizado con culling + spatial index + `RepaintBoundary`.

## Diseño de UI

- **Home:** botón "Abrir archivo" destacado, recientes horizontales, ajustes (tema, unidades, snap).
- **Viewer:** AppBar translúcida (back, nombre, fit, info), canvas, zoom controls flotantes (+/−/fit), status bar con coordenadas `(X: 123.45, Y: 678.90)`, botón capas.
- **Edición:** toolbar contextual flotante al seleccionar (mover, rotar, escalar, copiar, borrar); al crear, toolbar de dibujo (line, circle, arc, ellipse, polyline, text, point). CommandBar colapsable abajo.
- **Gestos:** un dedo arrastra, dos pellizcan, tap selecciona, drag con snap para crear/mover. ESC cancela.
- **Landscape:** paneles laterales fijos (capas derecha, propiedades izquierda) con `OrientationBuilder`.

## Diseño visual y UX

Leer `docs/DESIGN.md` y `docs/AESTHETICS.md`:
- Filosofía minimalista e inmersiva; paleta, tipografía (Inter + JetBrains Mono), iconografía.
- 6 temas: claro, oscuro, Blueprint Premium, Poster Publicitario, Infografía Educativa, AutoCAD Dark. Selector con previews; ACI color mapping por tema; exportación PNG respeta tema.
- Splash animado (stroke-dashoffset 1.5s), onboarding 3 pasos, BackdropFilter blur 20px en controles, auto-ocultar 3s, haptics, animaciones (fade-through, slide, halo de selección, zoom 200ms), accesibilidad (44dp, WCAG AA).

## Fases de desarrollo

1. Config + modelos + parser DXF + writer (round-trip).
2. CustomPainter básico (líneas/círculos) + InteractiveViewer + fit.
3. Entidades completas (arcos, polilíneas, textos, bloques, hatch básico).
4. Panel de capas + visibilidad.
5. Hit-testing + panel de propiedades + selección.
6. Pantallas Home/Viewer + recientes + temas + PNG/share.
7. Optimización: culling, RepaintBoundary, Isolate, cache, LOD.
8. CadDocument + CommandStack + comandos base (create/delete/move/rotate/scale/copy).
9. Creación por gestos + toolbar de edición + atajos.
10. SnapEngine + selección múltiple + grips.
11. Capas editables + medición + guardado (SAVE/autosave).
12. Línea de comandos + coordenadas relativas/polares + DWG (ODA local) + TRIM/OFFSET.
13. Tests (unit/widget/golden/benchmark) + i18n + release.

## Consideraciones adicionales

- DWG: sin parser Dart puro. MVP = mensaje + guía; luego ODA File Converter (CLI local, gratuito). Nunca subir planos a la nube sin consentimiento (privacidad).
- DGN: fuera de alcance v1.0.
- Unidades internas siempre mm; visualización configurable (mm, cm, m, pulgadas).
- Web: imports condicionales (`dart:io` vs `dart:html`), limitaciones DWG.
- Pruebas con archivos DXF de R12 (LibreCAD y AutoCAD), R2000 y R2010 en `test/files/`.
- Cobertura ≥ 70%; `flutter analyze --fatal-infos` limpio.

## Entregables esperados

Código fuente completo, `pubspec.yaml` con dependencias fijas, README con instrucciones y manual de usuario, conjunto de archivos de prueba, tests con cobertura, y APK/IPA compilados.
