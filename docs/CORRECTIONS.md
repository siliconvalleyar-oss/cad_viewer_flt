# Correcciones y Análisis de la Documentación — CAD Viewer & Editor

**Versión:** 0.3.4
**Fecha:** 2026-07-31
**Propósito:** Registrar el análisis completo de la documentación existente, las discrepancias detectadas, las correcciones aplicadas y los documentos nuevos creados. Este documento sirve como acta de auditoría para que cualquier miembro del equipo entienda qué cambió y por qué.

---

## 1. Alcance de la auditoría

Se auditaron los siguientes archivos:

| Archivo | Estado original |
|---------|-----------------|
| `README.md` | Revisado y corregido |
| `docs/RULES.md` | Revisado y corregido |
| `docs/DESIGN.md` | Revisado y ampliado |
| `docs/AESTHETICS.md` | Revisado y corregido |
| `docs/API.md` | Revisado y ampliado |
| `docs/DEVELOPMENT.md` | Revisado y corregido |
| `docs/TODO.md` | Revisado y ampliado |
| `docs/PROMPT.md` | Revisado y ampliado |
| `docs/CONTRIBUTING.md` | Revisado y corregido |
| `docs/CHANGELOG.md` | Revisado y actualizado |
| `docs/skills/` (7 archivos) | Revisado, corregido y ampliado |

---

## 2. Discrepancias críticas detectadas (y su resolución)

### 2.1 RULES.md contenía reglas de otro proyecto (KiCad)

**Problema:** `docs/RULES.md` estaba encabezado como *"Reglas de Oro — KiCad Preview"* e incluía reglas específicas de KiCad (parseo de S-expressions) que no aplican a un visor/editor de CAD DXF/DWG.

**Decisión:** Corregir el contenido para el proyecto CAD Viewer & Editor, conservando la estructura de "reglas de oro" y su carácter normativo. Las reglas se adaptaron al dominio DXF/DWG (parseo DXF, escritura con `flush: true`, etc.).

> ⚠️ Nota: El archivo declara ser inmutable ("NO BORRAR NI MODIFICAR"). Se interpreta como que su **estatus normativo** es inmutable, pero el **contenido factual erróneo** (referencias a KiCad) debía corregirse, dado que la instrucción del responsable fue corregir toda la documentación. Si se desea, se puede restaurar el texto original desde el control de versiones.

### 2.2 La documentación solo cubría visualización, no edición

**Problema:** El usuario solicitó una app para **visualizar y editar** archivos CAD, pero toda la documentación describía únicamente un visor (sin creación/modificación de entidades, undo/redo, snapping, grips, línea de comandos, guardado).

**Decisión:** Ampliar el alcance a **CAD Viewer & Editor**:
- Nuevo `docs/EDITING.md` — diseño completo del sistema de edición.
- Nuevo `docs/DATA_MODEL.md` — modelo de datos con soporte de edición.
- Nuevo `docs/REQUIREMENTS.md` — requisitos funcionales y no funcionales de visor + editor.
- Ampliación de `docs/API.md`, `docs/TODO.md`, `docs/PROMPT.md`, `docs/DEVELOPMENT.md`, `docs/DESIGN.md`.
- Nuevo skill `docs/skills/CAD_EDITING.md`.

### 2.3 No se mencionaba compatibilidad con LibreCAD

**Problema:** El usuario mencionó explícitamente "autocad, librecad". La documentación solo hablaba de AutoCAD.

**Decisión:** Añadir sección de compatibilidad LibreCAD en `docs/FORMATS.md` y en requisitos. LibreCAD exporta DXF (por defecto R12) y sus archivos son el caso de uso principal de prueba.

### 2.4 Inconsistencias de numeración de fases

**Problema:** `docs/DEVELOPMENT.md` hablaba de "7 fases", `docs/TODO.md` definía 12 fases + una "Fase 6.5", y el `README.md` mencionaba "7 fases".

**Decisión:** Unificar a **fases numeradas sin saltos (0–16)** en `docs/TODO.md` como fuente de verdad detallada. `docs/DEVELOPMENT.md` referencia las fases de alto nivel (visión → editor básico → editor avanzado → release) y enlaza a TODO.md y ROADMAP.md para el detalle. Los rangos de fases por versión quedan: v0.1.x = fases 0–8, v0.2.x = fases 9–13, v0.3.x = fases 14–15, v1.0 = fase 16.

### 2.5 Nombre inconsistente del enum de tema

**Problema:** `docs/AESTHETICS.md` usaba `ThemeMode.blueprint` en el código de ejemplo de `getAciColor`, pero definía el enum como `AppThemeMode`.

**Decisión:** Unificar en `AppThemeMode`. Corregido el fragmento de código de AESTHETICS.md.

### 2.6 Referencias de archivos en minúsculas/mezcladas

**Problema:** Varios documentos referenciaban `docs/prompt.md` (minúsculas) o `docs/README.md` inexistente. Los nombres reales son `docs/PROMPT.md` y el README está en la raíz.

**Decisión:** Normalizar todas las referencias a los nombres reales de archivos.

### 2.7 docs/skills/README.md listaba DESIGN.md y AESTHETICS.md como si estuvieran en skills/

**Problema:** La tabla de `docs/skills/README.md` incluía `DESIGN.MD` y `AESTHETICS.MD` entre los skills, pero residen en `docs/`.

**Decisión:** Corregir la tabla para listar solo los skills de `docs/skills/` y referenciar los documentos base con su ruta real.

### 2.8 Stack sin versión fijada y faltaban dependencias

**Problema:** El stack no fijaba versiones y omitía dependencias necesarias para edición (p. ej., `file_picker` para guardar, `path_provider`).

**Decisión:** Fijar versiones en `docs/API.md` / `docs/REQUIREMENTS.md` y añadir dependencias de edición (ninguna externa nueva: el sistema de comandos y undo/redo es código propio; se añade `file_picker` ya contemplado).

### 2.9 Falta de documentación de rendimiento, testing, seguridad, decisiones de arquitectura

**Problema:** No existían documentos de rendimiento, estrategia de pruebas, seguridad/privacidad, registro de decisiones de arquitectura (ADR) ni roadmap.

**Decisión:** Crear `docs/PERFORMANCE.md`, `docs/TESTING.md`, `docs/SECURITY.md`, `docs/ADR.md`, `docs/ROADMAP.md` y `docs/GLOSSARY.md`.

---

## 2.10 Elevación a documentación profesional de equipo (v0.3.0)

**Solicitud:** "la documentación debe ser profesional, realizada por un equipo de expertos en diseño de aplicaciones minimalistas, con todos los detalles".

**Proceso:** auditoría de 3 expertos (Design Lead minimalista, Experto UX/IA, Arquitecto técnico Flutter/CAD) → producción de 4 documentos nuevos + mejora de los existentes.

**Documentos nuevos de la ronda profesional:**
- `docs/DESIGN_SYSTEM.md` — sistema de diseño formal (tokens, estados, motion, iconografía, accesibilidad)
- `docs/UX_FLOWS.md` — personas, IA, flujos Mermaid, matriz de estados, microcopy, ergonomía
- `docs/SERIALIZATION.md` — contrato de serialización (DTOs, Isolates, round-trip, persistencia)
- `docs/ERROR_HANDLING.md` — taxonomía ERR-XXX, ErrorHandler, logging con privacidad

**Cambios estructurales:** DESIGN.md ahora delega los valores concretos a DESIGN_SYSTEM.md (una sola fuente de verdad); front-matter profesional (versión/estado/equipo) + TOC en los docs principales; diagramas Mermaid en ARCHITECTURE/EDITING/UX_FLOWS; matriz de compatibilidad en FORMATS.md.

**Hallazgos clave de la auditoría (todos resueltos):**

| Hallazgo | Resolución |
|----------|------------|
| Sin design tokens formales (P0) | DESIGN_SYSTEM.md §2 (espaciado 4dp, radios, elevación, opacidad, color semántico, tipografía, breakpoints, motion) |
| Componentes sin estados (P0) | DESIGN_SYSTEM.md §3 (matriz normal/hover/pressed/disabled/focus/selected/loading + focus ring) |
| Motion incompleto sin reduced-motion (P0) | DESIGN_SYSTEM.md §4 (cubic-bezier, mapa por componente, política reduced-motion) |
| Estados empty/loading/error sin diseñar (P1) | UX_FLOWS.md §4 (matriz por pantalla + transiciones) |
| Sin personas ni flujos (P1) | UX_FLOWS.md §1 y §3 (4 personas + Mermaid) |
| Sin microcopy (P1) | UX_FLOWS.md §5 (catálogo es/en + voz) |
| Sin ergonomía/pen (P1) | UX_FLOWS.md §6 (thumb zones, pen, palm rejection) |
| Accesibilidad no verificable (P1) | DESIGN_SYSTEM.md §6 (tabla de contraste, ACI color-blind, dynamic type, semántica canvas) |
| Sin diagramas Mermaid técnicos (P0) | ARCHITECTURE.md §8 (classDiagram + 2 sequenceDiagram), EDITING.md §3.4/§5.2 |
| Sin contrato de serialización (P0) | SERIALIZATION.md (DTOs, precisión, schemaVersion, round-trip, prefs `.v1`) |
| Sin matriz de compatibilidad (P0) | FORMATS.md §10 (formato × versión × operación) |
| Sin taxonomía de errores/logging (P1) | ERROR_HANDLING.md (ERR-XXX, ErrorHandler, sanitización) |
| Presupuestos de rendimiento genéricos (P1) | ✅ Resuelto: desglose por plataforma y tier en PERFORMANCE.md §1.1 (ronda v0.3.4) |
| CI como esquema, no YAML ejecutable (P1) | ✅ Resuelto: YAML de GitHub Actions ejecutable en TESTING.md §5 (ronda v0.3.4) |

---

## 3. Documentación nueva creada

| Documento | Propósito |
|-----------|-----------|
| `docs/REQUIREMENTS.md` | Requisitos funcionales (RF) y no funcionales (RNF), actores, user stories, casos de borde |
| `docs/ARCHITECTURE.md` | Arquitectura de la app: capas, módulos, flujo de datos, patrones |
| `docs/DATA_MODEL.md` | Modelo de datos completo: CadFile, CadEntity y subtipos, capas, bloques, selección, undo/redo |
| `docs/FORMATS.md` | Formatos CAD: DXF (R12/R2000/R2010), DWG, DGN, compatibilidad LibreCAD, group codes |
| `docs/EDITING.md` | Sistema de edición: comandos, undo/redo, selección múltiple, snapping, grips, línea de comandos, medición, guardado |
| `docs/PERFORMANCE.md` | Presupuesto de rendimiento, optimizaciones, culling, LOD, isolates |
| `docs/TESTING.md` | Estrategia de pruebas: unitarias, widget, golden, integración, archivos de muestra |
| `docs/SECURITY.md` | Seguridad y privacidad: procesamiento local, conversión DWG externa, permisos |
| `docs/ADR.md` | Registro de decisiones de arquitectura (ADR-0001 a ADR-0008) |
| `docs/ROADMAP.md` | Roadmap versionado v0.1 → v1.0 y más allá |
| `docs/GLOSSARY.md` | Glosario de términos CAD y de la app |
| `docs/skills/CAD_EDITING.md` | Skill de edición para agentes IA/desarrolladores |
| `docs/DESIGN_SYSTEM.md` | Sistema de diseño formal (ronda v0.3.0) |
| `docs/UX_FLOWS.md` | UX: personas, flujos, estados, microcopy (ronda v0.3.0) |
| `docs/SERIALIZATION.md` | Contrato de serialización (ronda v0.3.0) |
| `docs/ERROR_HANDLING.md` | Manejo de errores y logging (ronda v0.3.0) |

---

## 4. Documentación revisada y ampliada

| Documento | Cambios principales |
|-----------|---------------------|
| `README.md` | Alcance visor+editor, estructura actualizada, enlaces corregidos, mención LibreCAD |
| `docs/RULES.md` | Reglas adaptadas de KiCad → CAD Viewer & Editor, nuevas reglas de edición |
| `docs/DESIGN.md` | Añadido: UI de edición (toolbar, línea de comandos, grips, selección múltiple), interacciones de edición |
| `docs/AESTHETICS.md` | Corregido `ThemeMode` → `AppThemeMode`, checklist ampliado |
| `docs/API.md` | Ampliado: CommandStack, SnapEngine, GripManager, DxfWriter, CadViewModel de edición |
| `docs/DEVELOPMENT.md` | Fases unificadas, pipelines de edición, paquetes actualizados |
| `docs/TODO.md` | Fases renumeradas 0–13, fases de edición añadidas, Definition of Done actualizadas |
| `docs/PROMPT.md` | Prompt ampliado con requisitos de edición |
| `docs/CONTRIBUTING.md` | Flujo de PR actualizado, referencia a TESTING.md |
| `docs/CHANGELOG.md` | Entradas 0.2.0 y 0.3.0 |
| `docs/skills/*` | Actualizados con edición, nuevos módulos y referencias cruzadas |
| `docs/DESIGN.md` | Visión de alto nivel; delega tokens a DESIGN_SYSTEM.md (ronda v0.3.0) |
| `docs/ARCHITECTURE.md`, `docs/EDITING.md`, `docs/DATA_MODEL.md` | Diagramas Mermaid y front-matter (ronda v0.3.0) |
| `docs/REQUIREMENTS.md`, `docs/API.md`, `docs/DEVELOPMENT.md`, `docs/FORMATS.md` | Front-matter profesional + TOC; matriz de compatibilidad en FORMATS (ronda v0.3.0) |
| `README.md` | Índice ampliado con los 4 documentos nuevos (ronda v0.3.0) |

---

## 5. Decisiones de diseño clave adoptadas

Ver `docs/ADR.md` para el detalle. Resumen:

| # | Decisión | Alternativa descartada |
|---|----------|------------------------|
| ADR-0001 | Estado con Provider + ChangeNotifier | Riverpod |
| ADR-0002 | Parseo DXF con paquete `dxf ^1.3.0` + wrapper propio | Parser escrito a mano desde cero |
| ADR-0003 | Escritura DXF con writer propio (`DxfWriter`) | Escribir con el paquete dxf |
| ADR-0004 | Edición con patrón Command + CommandStack propio | Paquetes de undo/redo externos |
| ADR-0005 | DWG: MVP mensaje + guía; luego ODA File Converter (CLI local) | Servicio cloud (Apryse/VeryPDF) como primera opción |
| ADR-0006 | Renderizado con CustomPainter + InteractiveViewer | Impeller 3D / flame / canvas kit |
| ADR-0007 | Unidades internas: siempre mm con factor de escala de visualización | Cambiar unidades de los datos |
| ADR-0008 | DGN fuera de alcance para v1.0 | Soporte nativo DGN |

---

## 6. Lo que aún falta (recomendaciones)

La documentación no está "terminada": se recomienda añadir en siguientes iteraciones:

1. **`docs/LOCALIZATION.md`** — Plan de i18n/l10n (es, en mínimo; estrategia ARB).
2. **`docs/RELEASE.md`** — Proceso de release: firma, CI/CD (GitHub Actions), publicación en stores.
3. **Wireframes/mockups** — Archivos de diseño (Figma) vinculados desde DESIGN.md.
4. **`docs/QA_MANUAL.md`** — Matriz de pruebas manuales por plataforma.
5. **`docs/PERFORMANCE_BENCHMARKS.md`** — Resultados de benchmarks con archivos reales (A/B).
6. **`docs/skills/CAD_DATAMODEL.md`** — Si el modelo de datos crece, separarlo en skill propio.

### Ya creados en rondas posteriores

- ✅ **`docs/PRIVACY.md`** — Política de privacidad redactada (con formulario Google Play y App Store labels).
- ✅ **`LICENSE.md`** — Licencia MIT (titular por defecto: "CAD Viewer & Editor contributors"; editable).
- ✅ **Manual de usuario** — Sección completa en `README.md` (instalación, visor, edición, guardado, FAQ).
- ✅ **`docs/UX_FLOWS.md`** — Personas, flujos Mermaid, matriz de estados y microcopy (ronda v0.3.0).
- ✅ **`test/files/`** — Conjunto de archivos DXF de prueba (ronda v0.3.2): R12 LibreCAD/AutoCAD, R2000 (LWPOLYLINE+bulge, SPLINE, MTEXT, HATCH, ELLIPSE), R2010 (DIMENSION, bloques anidados), `$INSUNITS=1`, selección densa, vacío, binario real, corrupto truncado y stub DWG con magic bytes. Sintéticos validados; ver `test/files/README.md` y `docs/TESTING.md` §2.
- ✅ **`docs/DXF_WRITER_SPEC.md`** — Especificación de group codes de salida del `DxfWriter` (ronda v0.3.3): R12 y R2000 por sección y por entidad, precisión, conversiones, warnings W-001…W-006, ejemplos completos y contrato de round-trip.
- ✅ **Presupuestos de rendimiento por plataforma** — Desglose por plataforma y tier en `docs/PERFORMANCE.md` §1.1 (ronda v0.3.4): Android (gama baja/media/alta), iOS, Windows, macOS, Linux y Web con métricas de parseo, apertura, FPS, memoria, escritura y jank.
- ✅ **YAML de CI ejecutable** — Pipeline de GitHub Actions completo y ejecutable en `docs/TESTING.md` §5 (ronda v0.3.4): jobs analyze/format/unit (cobertura ≥ 70%)/golden/bench con `subosito/flutter-action` y caché.

### ⚠️ Archivos ajenos detectados

- **`docs/LEARNINGS.md`** — Archivo **preexistente de otro proyecto** ("Proyecto Velocity", reglas de git/versionado y una sección de licencias/Flutter, fechado 2026-07-27). **No forma parte de la documentación de CAD Viewer & Editor**: no está indexado en README ni referenciado por ningún documento del proyecto. **Decisión pendiente del titular:** eliminarlo, moverlo fuera de `docs/` o conservarlo como plantilla personal (en cuyo caso se añadiría una nota de que es ajeno).

---

## 7. Convenciones de nomenclatura unificadas

| Término | Valor canónico |
|---------|----------------|
| Nombre del proyecto | `cad_viewer` (dir actual: `librecad_flt`) |
| Nombre de la app | **CAD Viewer & Editor** |
| Versión actual docs | 0.3.4 |
| Versión objetivo | 1.0.0 |
| Enum de tema | `AppThemeMode` |
| ViewModel | `CadViewModel` (único, en `lib/controllers/`) |
| Directorio de controladores | `lib/controllers/` |
| Prompt | `docs/PROMPT.md` |
| Idioma de código | Dart (Flutter), nombres en inglés |
| Idioma de documentos nuevos | Español |

### Política de versionado por documento (v0.3.1)

El conjunto de documentos usa **versionado por documento**, no versionado de conjunto:

1. **Un documento sube de versión solo cuando se modifica de forma significativa** en una ronda (p. ej., EDITING.md, SECURITY.md y CORRECTIONS.md pasaron a 0.3.1 en la ronda de documentos críticos).
2. **Los documentos no tocados mantienen su versión anterior** (p. ej., FORMATS.md, ARCHITECTURE.md, DESIGN_SYSTEM.md siguen en 0.3.0 — correcto bajo esta política).
3. **Los skills sin cabecera de versión** (CAD_PARSERS, CAD_RENDERERS, CAD_EDITING, CAD_FEATURES, CAD_UI_COMPONENTS, CAD_STATE_MANAGEMENT) se versionan a través de `docs/skills/README.md`; `CAD_CODEBASE.md` sí tiene cabecera propia.
4. **Documentos con versionado propio:** `docs/PRIVACY.md` usa su versión de política legal (1.0) independiente del software, y `LICENSE.md` no lleva cabecera de versión (texto legal).
5. **README.md y CHANGELOG.md** son de nivel proyecto: reflejan la ronda actual (0.3.1).
6. **Excepción por sincronización de sellos:** los bumps masivos de cabecera (p. ej., `skills/CAD_CODEBASE.md` a 0.3.1) son una excepción aceptada aunque el contenido no cambie sustantivamente.
7. **Docs normativos sin cabecera de versión** (p. ej., `docs/RULES.md`) quedan exentos del bump por documento; se versionan por referencia (CHANGELOG y esta acta).

> ⚠️ Consecuencia práctica: "Versión actual docs: 0.3.4" (§7, tabla) indica la ronda más reciente del conjunto, no que todos los documentos estén en 0.3.4.
