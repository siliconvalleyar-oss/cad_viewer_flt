# Changelog

## [0.4.0] - 2026-08-01 — Código implementado + fix de cotas
### Added
- **Código fuente completo implementado** (lib/): parser DXF propio (R12/R2000, LWPOLYLINE con bulges, POLYLINE pesada VERTEX/SEQEND, TEXT/MTEXT, INSERT, HATCH, SPLINE, DIMENSION, 3DFACE), writer DXF R2000/R12, editor con CommandStack (undo/redo, 100), SnapEngine (endpoint/midpoint/center/intersección/cuadrante/nearest/grid/polar + ortho), SelectionManager, CadViewModel (Provider), renderers (CadPainter, grid/axis/grip/snap/layer), 6 temas, pantallas Home/Viewer/LayerPanel/Settings, file_picker 10.3.10 (compat AGP 9), guardado SAF Android, autoguardado con path_provider, icono minimalista (círculo + rombo) y splash animado
- **Fix cotas gigantes (bug 1000x)**: `_paintDimension` usaba altura de texto FIJA de 20 unidades de mundo → en planos de ~100 m las cotas se veían ~1000x más grandes. Ahora: texto con altura real del DIMSTYLE (dimtxt=140) o 4% de la longitud medida, flechas rellenas reales (dimasz=41), puntos de extensión 2 (14/24), medición real (42), etiqueta formateada con `formatLength` en la unidad de visualización y mínimo legible de 12 px
- **CadDim extendido**: `x4/y4` (ext 2), `textHeight`, `arrowSize`, `measurement` + actualización de bounds (painter/cad_file/cad_block/selection_manager), transforms (move/rotate/scale), hit-testing, snap y writer
### Changed
- `docs/skills/` — Estado del proyecto: código fuente ✅ implementado (antes ❌); parcer DXF ✅, writer ✅, edición ✅, tests ✅
- `README.md` — Versión 0.4.0; código implementado

## [0.3.4] - 2026-07-31 — Pendientes v0.3.1 completados
### Added
- `docs/PERFORMANCE.md` §1.1 — **Presupuestos de rendimiento por plataforma**: tabla con Android (gama baja/media/alta por núcleos/RAM), iOS, Windows, macOS, Linux y Web con métricas de parseo 5 MB, apertura < 1 MB, FPS pan/zoom 10 k, memoria, escritura y jank; criterios de aplicación (heap Android, blob Web, jank por tier, clasificación de tier)
- `docs/TESTING.md` §5 — **YAML de GitHub Actions ejecutable** (`.github/workflows/ci.yml`): jobs analyze (`--fatal-infos`), format (`dart format`), unit (cobertura ≥ 70% con lcov), golden (comparación) y bench (tool/benchmark.dart contra PERFORMANCE.md §1/§1.1); `subosito/flutter-action@v2` con `channel: stable` y `cache: true`; notas de fijación de versión y builds iOS/macOS
### Changed
- `docs/PERFORMANCE.md` — Versión 0.3.1; §1 referencia §1.1; checklist §7 con verificación por plataforma; §6 benchmark contra `test/files/`
- `docs/TESTING.md` — Versión 0.3.3; §5 esquema → YAML completo; §6 benchmark actualizado
- `docs/CORRECTIONS.md` — Versión 0.3.4; §2.10 y §6: los dos pendientes v0.3.1 marcados como resueltos
- `README.md` — Versión 0.3.4

## [0.3.3] - 2026-07-31 — Especificación del escritor DXF
### Added
- **`docs/DXF_WRITER_SPEC.md`** — Especificación normativa del `DxfWriter` (group codes de salida R12/R2000): estructura general de salida (HEADER → TABLES → BLOCKS → ENTITIES → EOF), convenciones de precisión (6/8/8/6/4 decimales, sin notación científica), reglas de capa/color/handles, cabeceras de TABLES (LAYER/LTYPE/STYLE mínimos), emisión de bloques y `*Model_Space`, y **spec por entidad** (LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, POLYLINE, TEXT, MTEXT, INSERT, POINT, HATCH, SPLINE, DIMENSION, 3DFACE) con tablas R2000 vs R12, catálogo de warnings W-001…W-006, ejemplos completos (R2000 y R12), matriz de round-trip y casos de `dxf_writer_test.dart`
### Changed
- `docs/FORMATS.md` — §9: referencia a DXF_WRITER_SPEC.md como creada (ya no "pendiente"); versión 0.3.3
- `docs/CORRECTIONS.md` — §6: DXF_WRITER_SPEC.md movido a creados; lista de pendientes renumerada; versión 0.3.3
- `README.md` — Versión 0.3.3; fila `docs/DXF_WRITER_SPEC.md` en el índice de documentación

## [0.3.2] - 2026-07-31 — Archivos de muestra DXF (test/files/)
### Added
- **`test/files/`** — Conjunto de archivos de prueba que desbloquea parsers, writers y round-trip (TESTING.md §2 / FORMATS.md §11):
  - `sample_r12_librecad.dxf` (R12, POLYLINE pesada VERTEX/SEQEND, capas, TEXT)
  - `sample_r12_autocad.dxf` (R12, ARC, CIRCLE, POINT, bloque BOLT + INSERT rotado)
  - `sample_r2000.dxf` (R2000, LWPOLYLINE con bulge, SPLINE, MTEXT con códigos, HATCH SOLID, ELLIPSE)
  - `sample_r2010.dxf` (R2010, DIMENSION alineada + bloque anónimo `*D1`, bloques anidados A→B)
  - `sample_units_inch.dxf` (R2000, `$INSUNITS=1` conversión de unidades)
  - `sample_selection.dxf` (R2000, hit-testing denso: paralelas 0.1, círculos superpuestos, rejilla)
  - `sample_empty.dxf` (R2000, sin entidades)
  - `sample_binary.dxf` (DXF binario real R2000 con sentinel, 17 grupos, termina en EOF)
  - `sample_corrupt.dxf` (truncado a mitad de entidad, sin ENDSEC/EOF → ERR-PARSE-UNEXPECTED_EOF)
  - `sample_dwg.dwg` (stub con magic bytes `AC1032` para detección; placeholder hasta conversión ODA)
  - `test/files/README.md` — Manifest: matriz, convenciones de group codes, regeneración y reemplazo por archivos reales
### Changed
- `docs/TESTING.md` — Nota §2 actualizada: archivos creados (sintéticos validados) + recordatorio de reemplazo por exportaciones reales antes del release; añadido `sample_empty.dxf` a la matriz
- `docs/CORRECTIONS.md` — §6: "Muestras de archivos" movido a creados; versión 0.3.2
- `README.md` — Versión 0.3.2

## [0.3.1] - 2026-07-31 — Documentos críticos de publicación
### Added
- `docs/PRIVACY.md` — Política de privacidad completa para Google Play / App Store: datos recopilados (ninguno de contenido de planos), permisos, procesamiento local, conversión DWG local-first, formulario de datos de Google Play, Privacy Nutrition Labels de App Store, cumplimiento GDPR/CCPA/LGPD
- `LICENSE.md` — Licencia **MIT** (titular por defecto: "CAD Viewer & Editor contributors"; editable según decisión del titular)
- **Manual de usuario** en `README.md` — instalación, primeros pasos, navegación, capas, selección, edición (crear/transformar/snap/grips/undo), guardado y exportación, formatos soportados, temas, FAQ
### Changed
- `docs/SECURITY.md` — Referencia a PRIVACY.md como redactada; checklist de política de privacidad completado
- `docs/CORRECTIONS.md` — Sección 6 actualizada: PRIVACY.md, LICENSE.md, manual de usuario y UX_FLOWS.md marcados como creados; pendientes reordenados (LOCALIZATION, RELEASE, DXF_WRITER_SPEC, QA_MANUAL, etc.); sección "Archivos ajenos detectados" documentando `docs/LEARNINGS.md` (de otro proyecto, decisión pendiente del titular)
- `docs/RULES.md` — Nota §A: la línea "Current version:" de README incluye versión de documentación y de código; la regla de igualdad con VERSION aplica a la versión de código
- `docs/EDITING.md` — Atajo Ctrl+S (Guardar) añadido a la tabla de atajos §7.4
- `README.md` — Añadido al índice de documentación; sección manual de usuario; header con enlace a LICENSE.md; capas marcadas "según versión (v0.2+)"

## [0.3.0] - 2026-07-31 — Documentación profesional de equipo
### Added
- `docs/DESIGN_SYSTEM.md` — Sistema de diseño formal: design tokens nombrados (espaciado 4dp, radios, elevación z0–z5, opacidades, color semántico por tema, tipografía `type.*`, breakpoints xs–xl, motion), matriz de estados de componentes (normal/hover/pressed/disabled/focus/selected/loading), motion design con cubic-bezier y reduced-motion, registro de iconografía, accesibilidad visual (tabla de contraste, estrategia color-blind para capas ACI, dynamic type, semántica del canvas)
- `docs/UX_FLOWS.md` — 4 personas detalladas, arquitectura de información, flujos Mermaid (abrir, seleccionar, crear, mover, guardar), matriz de estados de UI (empty/loading/error/success/offline), microcopy es/en y voz de la app, ergonomía (zonas de pulgar, pen/stylus, palm rejection)
- `docs/SERIALIZATION.md` — Contrato de serialización: DTOs CadFileJson/CadEntityJson, precisión numérica (6/8/4 decimales), schemaVersion y migraciones, round-trip y pruebas, persistencia local (claves prefs `.v1`, autosave), contratos de Isolate
- `docs/ERROR_HANDLING.md` — Taxonomía de errores ERR-XXX (FILE/PARSE/EDIT/STATE/EXPORT), ErrorHandler centralizado, catálogo de mensajes ARB, política de logging con sanitización, reporte de crash local-first
- Diagramas Mermaid (classDiagram y sequenceDiagram) en `docs/ARCHITECTURE.md`, `docs/EDITING.md` y flujos en `docs/UX_FLOWS.md`
- Matriz de compatibilidad formato × versión × operación en `docs/FORMATS.md`
### Changed
- `docs/DESIGN.md` — Reestructurado como visión de alto nivel; delega tokens y especificaciones a DESIGN_SYSTEM.md; TOC y portada profesional
- `docs/REQUIREMENTS.md`, `docs/API.md`, `docs/DEVELOPMENT.md`, `docs/DATA_MODEL.md`, `docs/EDITING.md`, `docs/FORMATS.md`, `docs/ARCHITECTURE.md` — Front-matter profesional (versión, estado, equipo responsable) y TOC
- `README.md` — Índice ampliado con los 4 documentos nuevos; versión 0.3.0
- Auditoría de calidad realizada por equipo de expertos (design lead, UX, arquitecto técnico) con 2 rondas de revisión

## [0.2.0] - 2026-07-31
### Added
- **Alcance ampliado a CAD Viewer & Editor** (visualizar + editar), confirmado por el responsable del proyecto
- `docs/REQUIREMENTS.md` — Requisitos funcionales (RF-*) y no funcionales (RNF-*), actores, user stories, casos de borde, priorización por versión
- `docs/ARCHITECTURE.md` — Arquitectura por capas, módulos, flujos de datos (carga, edición, guardado, snap), Isolates, estado
- `docs/DATA_MODEL.md` — Modelo de datos completo: CadFile, CadDocument (sesión editable), CadLayer extendido (locked/frozen), CommandStack, SelectionManager, unidades en mm
- `docs/FORMATS.md` — Referencia DXF (estructura, group codes, versiones AC1009–AC1032), DWG (ODA File Converter CLI), DGN, compatibilidad LibreCAD (R12, POLYLINE pesada)
- `docs/EDITING.md` — Sistema de edición completo: patrón Command + CommandStack (límite 100), catálogo de comandos, selección múltiple (window/crossing), SnapEngine (9 modos + ortho), grips por tipo de entidad, línea de comandos (catálogo, coordenadas absolutas/relativas/polares), medición, guardado/autoguardado
- `docs/PERFORMANCE.md` — Presupuesto de rendimiento (60 fps / 10 k entidades), culling, spatial index, Isolates, cache, LOD
- `docs/TESTING.md` — Estrategia de pruebas (pirámide), archivos de muestra, cobertura ≥ 70%, CI propuesto, QA manual
- `docs/SECURITY.md` — Seguridad y privacidad: procesamiento local, mínimos permisos, conversión DWG local-first, política de privacidad
- `docs/ADR.md` — 8 decisiones de arquitectura (Provider, paquete dxf, DxfWriter propio, patrón Command, DWG ODA local, CustomPainter, unidades mm, DGN fuera de alcance)
- `docs/ROADMAP.md` — Roadmap versionado v0.1 (visor) → v0.2 (editor básico) → v0.3 (editor avanzado) → v1.0 (release)
- `docs/GLOSSARY.md` — Glosario de términos CAD y de la app
- `docs/CORRECTIONS.md` — Análisis de discrepancias y correcciones aplicadas a toda la documentación
- `docs/skills/CAD_EDITING.md` — Nuevo skill de edición para IA/desarrolladores

### Changed
- `docs/RULES.md` — Corregido: referencias de "KiCad Preview" → "CAD Viewer & Editor"; reglas adaptadas al dominio DXF/DWG (Isolates, Command pattern, nunca subir planos sin consentimiento); sección G de documentación
- `README.md` — Alcance visor+editor, estructura actualizada (controllers/command_stack, snap_engine, selection_manager; parsers/dxf_writer), mención LibreCAD, índice de documentación completo
- `docs/API.md` — Ampliado: CadDocument, DxfWriter, CommandStack, SnapEngine, SelectionManager, CadLayer extendido, CommandBar/ToolbarEdit widgets, version counters
- `docs/DEVELOPMENT.md` — Fases unificadas (visión → edición), pipeline de edición, paquetes, extensión con comandos nuevos
- `docs/TODO.md` — Fases renumeradas 0–13 (sin saltos), fases 8–12 de edición añadidas, DoD actualizadas
- `docs/PROMPT.md` — Prompt ampliado con requisitos completos de edición (comandos, snap, grips, línea de comandos, guardado)
- `docs/DESIGN.md` — Añadidas secciones 4.9 (diseño de edición: toolbar, command bar, grips, snap indicator) y 7.5 (preview en vivo); checklist ampliado
- `docs/AESTHETICS.md` — Corregido `ThemeMode` → `AppThemeMode`; 6 temas; checklist de edición ampliado
- `docs/CONTRIBUTING.md` — Requisitos de docs/tests, analyze, cobertura, review con undo/redo y rendimiento
- `docs/skills/*` — Actualizados con edición, nuevos módulos y referencias cruzadas

## [0.1.0] - 2026-07-31
### Added
- Documentación base completa adaptada a requisitos de app CAD Viewer
- Modelos: CadFile, CadLayer, CadEntity (Line, Circle, Arc, Ellipse, Polyline, LwPolyline, Text, MText, Insert, Point, Hatch, Spline, Dim, 3dFace)
- Arquitectura: screens/, widgets/, renderers/, parsers/, models/, utils/
- State management: CadViewModel con Provider + ChangeNotifier
- Dependencias definidas: dxf ^1.3.0, file_picker, shared_preferences, path_provider, screenshot, share_plus
- Pantallas: HomeScreen (recientes + abrir), ViewerScreen (canvas + controles)
- Features: layer panel, property panel, zoom controls, fit-to-screen, hit-testing
- DWG: soporte planeado vía conversión externa (ODA Teigha / Apryse / VeryPDF)
- Fases de desarrollo definidas (7 fases)
- PROMPT.md generado para solicitud a otra IA
- docs/DESIGN.md: documento completo de diseño visual y UX (paleta, tipografía, splash, pantallas, landscape, animaciones, onboarding, accesibilidad)
- docs/AESTHETICS.md: 4 estéticas profesionales CAD con paletas, ThemeData, ACI mapping, assets y checklist
- docs/TODO.md: lista de tareas accionables en 12 fases con Definition of Done
