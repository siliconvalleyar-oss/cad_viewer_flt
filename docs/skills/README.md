# 📚 CAD Viewer & Editor — Skills Documentation

**Ubicación:** `docs/skills/`
**Versión:** 0.4.0
**Propósito:** Documentación estructurada del proyecto cad_viewer para que cualquier AI (o desarrollador) pueda entender y modificar el código de forma eficiente.

---

## Archivos

| Archivo | Contenido |
|---------|-----------|
| `CAD_CODEBASE.md` | **Skill principal** — estructura, stack, módulos, checklist AI |
| `CAD_PARSERS.md` | **Parsers/Writers** — DxfParser propio (R12/R2000), DxfWriter, DwgParser (ODA), pipeline, errores |
| `CAD_RENDERERS.md` | **Renderizado** — CadPainter, LayerManager, grid/axis/grip/snap renderers, coordinate transform, ACI colors |
| `CAD_EDITING.md` | **Edición** — CommandStack, comandos, SnapEngine, grips, CommandBar, medición, guardado |
| `CAD_FEATURES.md` | **Features** — File loading, recientes, visor, capas, selección, export/share, DWG, edición |
| `CAD_UI_COMPONENTS.md` | **UI Components** — HomeScreen, ViewerScreen, LayerPanel, PropertyPanel, ZoomControls, CommandBar, ToolbarEdit, SettingsSheet |
| `CAD_STATE_MANAGEMENT.md` | **State Management** — CadViewModel, Provider, version counters, CommandStack/SnapEngine/SelectionManager |

> Los documentos base (`docs/DESIGN.md`, `docs/DESIGN_SYSTEM.md`, `docs/UX_FLOWS.md`, `docs/AESTHETICS.md`, `docs/REQUIREMENTS.md`, `docs/EDITING.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/FORMATS.md`, `docs/SERIALIZATION.md`, `docs/ERROR_HANDLING.md`) residen en `docs/` y son referenciados desde aquí.

---

## Cómo usar estos skills

### Para una AI que visita por primera vez:

1. **`CAD_CODEBASE.md`** — Primero. Estructura general, stack, módulos.
2. **`docs/DESIGN.md`** — Estética base, paleta, tipografía, pantallas, animaciones.
3. **`docs/AESTHETICS.md`** — Los 6 temas (claro/oscuro + 4 estéticas) y su implementación.
4. **`CAD_STATE_MANAGEMENT.md`** — Cómo se maneja el estado.
5. **`CAD_PARSERS.md`** + **`CAD_RENDERERS.md`** — El corazón de la app (lectura y dibujo).
6. **`CAD_EDITING.md`** — El sistema de edición (comandos, undo/redo, snap).
7. **`CAD_FEATURES.md`** + **`CAD_UI_COMPONENTS.md`** — Features específicas y UI.

### Para modificar el código:

1. Leer el skill relevante al área de cambio
2. Verificar la checklist AI en `CAD_CODEBASE.md` (sección 5) y en el skill correspondiente
3. Hacer cambios siguiendo `docs/RULES.md`
4. Correr `dart format` + `flutter analyze --fatal-infos` antes de commit
5. Añadir tests (ver `docs/TESTING.md`)

### Para generar la app desde cero:

1. Leer `docs/PROMPT.md` (prompt completo para IA generadora)
2. Seguir las fases de `docs/TODO.md` y el roadmap de `docs/ROADMAP.md`

### Para reportar bugs:

Incluir la sección del skill afectado y el comportamiento esperado vs actual.

---

## Estado del proyecto

| Aspecto | Estado |
|---------|--------|
| Documentación completa (visor + editor) | ✅ (v0.4.0) |
| **Código fuente (visor + editor)** | ✅ **implementado** |
| **Parser DXF propio** (R12/R2000, LWPOLYLINE, POLYLINE pesada) | ✅ |
| **Writer DXF** (R2000/R12) | ✅ |
| **Renderizado / capas / selección** | ✅ |
| **Edición** (Command, snap, grips, undo/redo) | ✅ |
| **Tests unitarios** | ✅ 50 tests (modelos) |
| Bridge DWG (ODA) | 📋 (v0.3+; MVP = guía de conversión) |
| Requisitos (FRD/NFR) | ✅ (`docs/REQUIREMENTS.md`) |
| Arquitectura | ✅ (`docs/ARCHITECTURE.md`) |
| Modelo de datos | ✅ (`docs/DATA_MODEL.md`) |
| Formatos CAD | ✅ (`docs/FORMATS.md`) |
| Diseño visual y UX | ✅ (`docs/DESIGN.md`) |
| Estéticas CAD | ✅ (`docs/AESTHETICS.md`) |
| Sistema de edición | ✅ (`docs/EDITING.md` + `CAD_EDITING.md`) |
| Design system (tokens, motion, a11y) | ✅ (`docs/DESIGN_SYSTEM.md`) |
| UX (personas, flujos, estados, microcopy) | ✅ (`docs/UX_FLOWS.md`) |
| Serialización / Errores | ✅ (`docs/SERIALIZATION.md`, `docs/ERROR_HANDLING.md`) |
| Rendimiento / Tests / Seguridad | ✅ (`docs/PERFORMANCE.md`, `docs/TESTING.md`, `docs/SECURITY.md`) |
| ADR / Roadmap / Glosario | ✅ (`docs/ADR.md`, `docs/ROADMAP.md`, `docs/GLOSSARY.md`) |
| Prompt para generación | ✅ (`docs/PROMPT.md`) |
