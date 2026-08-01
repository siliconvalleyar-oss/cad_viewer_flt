# TODO — CAD Viewer & Editor

**Proyecto:** cad_viewer
**Versión actual docs:** 0.3.1
**Versión objetivo:** 1.0.0
**Fecha:** 2026-07-31
**Fuentes:** `docs/REQUIREMENTS.md` (requisitos), `docs/EDITING.md` (edición), `docs/ROADMAP.md` (roadmap)

---

> Numeración de fases 0–16 (sin saltos). Cada fase tiene Definition of Done. El roadmap versionado está en `docs/ROADMAP.md`.
>
> Nota: la versión de documentación (0.2.0) lidera a la versión de código (0.1.0) durante el desarrollo; `VERSION` se crea con `0.1.0` y se incrementa al completar hitos.

---

## Fase 0 — Configuración del proyecto

- [x] Leer `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md` y `docs/EDITING.md`
- [x] Definir estructura de carpetas (ver `docs/ARCHITECTURE.md`)
- [ ] Crear `pubspec.yaml` con dependencias fijadas:
  - `dxf: ^1.3.0`
  - `provider: ^6.1.1`
  - `file_picker: ^8.1.2`
  - `shared_preferences: ^2.2.3`
  - `path_provider: ^2.1.4`
  - `screenshot: ^3.0.0`
  - `share_plus: ^10.0.0`
  - `flutter_svg: ^2.0.17`
  - `path: ^1.9.0`, `collection: ^1.18.0`
- [ ] Crear `analysis_options.yaml` con reglas estrictas (`flutter_lints`)
- [ ] Crear `VERSION` con `0.1.0`
- [ ] Configurar Android (minSdk 21, SAF)
- [ ] Configurar iOS (Info.plist: file sharing, fotos)
- [ ] Configurar Windows/macOS/Linux
- [ ] Preparar `assets/` (fonts, logo, previews) según `docs/AESTHETICS.md`

**DoD:** `flutter pub get` + `flutter analyze --fatal-infos` sin errores.

---

## Fase 1 — Modelos

- [ ] `lib/models/cad_entity.dart` — base + 14 subtipos con `copyWith`
- [ ] `lib/models/cad_layer.dart` — visible, locked, frozen, displayColor, isCurrent
- [ ] `lib/models/cad_block.dart`
- [ ] `lib/models/cad_file.dart` — CadFile + CadHeader + `getBounds()`
- [ ] `lib/models/cad_document.dart` — sesión editable (fromCadFile, exportCadFile, dirty)
- [ ] `lib/models/cad_enums.dart` — CadEntityType, DimType, UnitsType, SnapMode, GridType
- [ ] Tests: igualdad, copyWith, getBounds, exportCadFile

**DoD:** Modelos Dart puro compilan; tests unitarios verdes.

---

## Fase 2 — Parsers y Writers

- [ ] `lib/parsers/dxf_parser.dart` — wrapper paquete `dxf`, mapeo de entidades/capas/bloques, normalización (ByLayer, bulge, MTEXT strip)
- [ ] `lib/parsers/dxf_writer.dart` — serialización R2000/R12, LWPOLYLINE→POLYLINE en R12, precisión 6 decimales
- [ ] `lib/parsers/dwg_parser.dart` — MVP: mensaje de no soporte; interfaz lista para ODA
- [ ] `lib/utils/file_helper.dart` — detectFormat (ext + magic bytes), lectura segura
- [ ] Archivos de muestra en `test/files/` (R12 LibreCAD, R12 AutoCAD, R2000, R2010, corrupto, binario)
- [ ] Tests: parse por entidad, round-trip parse→write→parse, errores

**DoD:** Parsear los 4 DXF de muestra → CadFile correcto; round-trip sin pérdida.

---

## Fase 3 — Renderizado básico

- [ ] `lib/renderers/cad_painter.dart` — fondo, grid, ejes, entidades visibles, selección
- [ ] `lib/utils/coordinate_transform.dart` — mundo↔canvas, bounds, fit-to-screen
- [ ] `lib/renderers/layer_manager.dart` — filtrado visible/!frozen, color por capa
- [ ] `lib/utils/aci_colors.dart` — ACI → Color
- [ ] `lib/utils/geometry.dart` — dist punto-segmento, bulge→arco
- [ ] `RepaintBoundary` + `shouldRepaint` por version counters

**DoD:** DXF de prueba renderiza líneas/círculos; zoom/pan/fit funcionan.

---

## Fase 4 — Gestión de capas

- [ ] `lib/screens/layer_panel.dart` — checkbox, color ACI, show/hide all, locked, contador
- [ ] Conectar a CadViewModel (`layersVersion` + `context.select`)
- [ ] Override de `displayColor` por capa

**DoD:** Toggle en tiempo real sin lag; presets OK.

---

## Fase 5 — Interacción y selección

- [ ] Hit-testing por tipo en `viewer_screen.dart` (orden inverso, top-most)
- [ ] `lib/widgets/property_panel.dart` — props por tipo
- [ ] `lib/widgets/zoom_controls.dart` — +, −, fit
- [ ] Halo de selección + animación "respiración"
- [ ] Haptics (light impact)

**DoD:** Tap selecciona y muestra propiedades; zoom/fit OK.

---

## Fase 6 — Pantallas principales

- [ ] `lib/screens/home_screen.dart` — abrir archivo, recientes, settings
- [ ] `lib/screens/viewer_screen.dart` — AppBar, canvas, paneles
- [ ] `lib/widgets/recent_files_list.dart` — horizontales con miniatura
- [ ] Persistencia historial (10 últimos) en shared_preferences

**DoD:** Home→abrir→Viewer funciona; ajustes persisten.

---

## Fase 7 — Diseño y UX (docs/DESIGN.md + AESTHETICS.md)

- [ ] Tema Material 3 + paleta DESIGN.md (claro/oscuro)
- [ ] Tipografías Inter + JetBrains Mono
- [ ] Splash animado (stroke-dashoffset 1.5s)
- [ ] Controles BackdropFilter blur 20px, radius 12dp, auto-ocultar 3s
- [ ] Grid y ejes con colores por tema
- [ ] Status bar de coordenadas
- [ ] Landscape (OrientationBuilder)
- [ ] Animaciones y haptics
- [ ] 6 temas: claro, oscuro, Blueprint, Poster, Infografía, AutoCAD Dark
- [ ] ACI color mapping por tema
- [ ] Onboarding 3 pasos
- [ ] Icono launcher + previews de temas

**DoD:** Cumple DESIGN.md y AESTHETICS.md; temas seleccionables y persistidos.

---

## Fase 8 — Exportación y compartición

- [ ] Screenshot PNG a galería (respetando tema)
- [ ] Compartir archivo original (share_plus)
- [ ] Permisos Android/iOS correctos

**DoD:** PNG guarda; share abre sheet nativo.

---

## Fase 9 — Editor: Command y undo/redo

- [ ] `lib/models/cad_document.dart` — mutaciones controladas
- [ ] `lib/controllers/command_stack.dart` — push/undo/redo, límite 100
- [ ] Comandos base: `CommandCreate`, `CommandDelete`, `CommandMove`, `CommandRotate`, `CommandScale`, `CommandCopy`, `CommandModifyProps`
- [ ] Botones undo/redo + atajos Ctrl+Z/Ctrl+Y
- [ ] Tests: cada comando execute+undo = original; límite de pila

**DoD:** Toda operación es deshacible; pila límite 100 funciona.

---

## Fase 10 — Editor: creación y transformación

- [ ] Creación por gestos: LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, TEXT, POINT (preview en vivo)
- [ ] Mover/rotar/escalar/copiar/borrar selección
- [ ] Atajos Ctrl+C/V/X, DEL
- [ ] `lib/widgets/toolbar_edit.dart` — toolbar contextual
- [ ] Capa actual para entidades nuevas

**DoD:** Crear y transformar entidades con undo; toolbar contextual funcional.

---

## Fase 11 — Editor: snapping y selección múltiple

- [ ] `lib/controllers/snap_engine.dart` — endpoint, midpoint, center, intersection, grid, polar + ortho + tolerancia
- [ ] `lib/renderers/snap_renderer.dart` — indicador visual
- [ ] `lib/controllers/selection_manager.dart` — shift toggle, window/crossing, Ctrl+A
- [ ] Ajustes de snap en Settings
- [ ] Tests: cada modo, prioridades, tolerancia, capa bloqueada

**DoD:** Snap preciso con indicador; selección múltiple completa.

---

## Fase 12 — Editor: capas editables y medición

- [ ] Crear/renombrar/borrar capa (vacía), color, actual
- [ ] Medición: distancia, ángulo, área (overlay temporal)
- [ ] Tests

**DoD:** Capas editables; mediciones correctas con snap.

---

## Fase 13 — Editor: guardado y persistencia

- [ ] `DxfWriter` integrado en ViewModel: SAVE/SAVE AS (R2000/R12)
- [ ] Autoguardado cada 5 min (`*.autosave.dxf`)
- [ ] Diálogo "cambios sin guardar"
- [ ] Round-trip tests

**DoD:** Guardar→reabrir→mismo dibujo; autosave recupera sesión.

---

## Fase 14 — Editor avanzado: línea de comandos y grips

- [ ] `lib/widgets/command_bar.dart` — catálogo de comandos, autocompletado, historial
- [ ] Coordenadas absolutas/relativas/polares (`#`, `@`, `<`)
- [ ] `lib/renderers/grip_renderer.dart` + grips por tipo de entidad
- [ ] Atajos de teclado desktop (F3 snap, F8 ortho, ESC)
- [ ] Tests

**DoD:** Comandos y coordenadas funcionan; grips editan directamente.

---

## Fase 15 — Editor avanzado: DWG, TRIM/OFFSET, PDF

- [ ] Integración ODA File Converter (setup guiado, CLI local)
- [ ] `CommandTrim`, `CommandOffset`, `CommandMirror`
- [ ] Edición de propiedades desde PropertyPanel
- [ ] Exportar PDF básico; exportar selección a DXF
- [ ] LOD/perf de edición
- [ ] Tests E2E (apertura→edición→guardado) + benchmark

**DoD:** DWG local funciona; TRIM/OFFSET con undo; benchmark dentro de presupuesto.

---

## Fase 16 — Release v1.0

- [ ] Cobertura ≥ 70% (parsers/models/controllers)
- [ ] i18n es/en (ARB)
- [ ] QA manual por plataforma (matriz TESTING.md)
- [ ] Política de privacidad (`docs/PRIVACY.md`)
- [ ] Manual de usuario en README
- [ ] Capturas + icono launcher + screenshots de temas
- [ ] APK/IPA firmados; publicación
- [ ] CHANGELOG.md completo

**DoD:** App publicada y estable; documentación al día.

---

## Notas

- **DWG:** MVP = guía de conversión; v0.3+ = ODA local (ADR-0005). Cloud con consentimiento.
- **DGN:** Fuera de v1.0 (ADR-0008).
- **Entidades avanzadas (HATCH complejo, SPLINE edit, 3D):** v1.0 solo lectura/mover (RF-ENT).
- **Límite de archivo:** recomendar < 10 MB; advertencia si mayor.
- **Undo/redo:** obligatorio para toda operación de edición (RULES.md B.13).
