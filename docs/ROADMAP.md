# Roadmap — CAD Viewer & Editor

**Versión:** 0.3.0
**Fecha:** 2026-07-31
**Propósito:** Hoja de ruta versionada desde el visor hasta la app completa de edición, con alcance, hitos y dependencias. Fuente detallada de tareas: `docs/TODO.md`.

---

## Visión resumida

```
v0.1.x  Visor            ──►  v0.2.x  Editor básico  ──►  v0.3.x  Editor avanzado  ──►  v1.0.0  Estable
(leer/ver/inspeccionar)        (crear/editar/guardar)       (precisión profesional)       (release stores)
```

---

## v0.1.x — Visor (fases 0–8 de TODO.md)

**Objetivo:** visualizar, navegar e inspeccionar planos DXF de forma profesional.

| Hito | Contenido | DoD |
|------|-----------|-----|
| v0.1.0 | Config proyecto, modelos, parser DXF, render básico (líneas/círculos), zoom/pan/fit | DXF de prueba renderizado |
| v0.1.1 | Entidades completas (arcos, polilíneas, textos, elipses, bloques, hatch básico) | Catálogo RF-ENT renderizado |
| v0.1.2 | Panel de capas + visibilidad + presets + override de color | Toggle en tiempo real |
| v0.1.3 | Hit-testing + PropertyPanel + selección | Tap selecciona y muestra props |
| v0.1.4 | Home, recientes, ajustes (tema/unidades), PNG/share | Flujo completo Home→Viewer |
| v0.1.5 | 4 estéticas profesionales + splash + animaciones + onboarding | Cumple DESIGN/AESTHETICS |
| v0.1.6 | Optimización: culling, RepaintBoundary, Isolate, cache | 60 fps con 10 k entidades |
| v0.1.7 | Tests (modelos, parser, widgets) + QA manual | Cobertura ≥ 70% |

---

## v0.2.x — Editor básico (fases 9–13 de TODO.md)

**Objetivo:** crear, modificar y guardar planos con undo/redo.

| Hito | Contenido | DoD |
|------|-----------|-----|
| v0.2.0 | CadDocument, CommandStack, CommandCreate/Delete/Move | Undo/redo funcional |
| v0.2.1 | Creación: LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, TEXT, POINT con preview | Crear entidades por gestos |
| v0.2.2 | Mover/rotar/escalar/copiar/borrar selección + atajos Ctrl+Z/Y/C/V/X | Transformaciones + undo |
| v0.2.3 | Snap básico: endpoint, midpoint, center, intersection, grid + ortho + indicador | Snap preciso |
| v0.2.4 | Selección múltiple: shift, window, crossing, Ctrl+A | Selección avanzada |
| v0.2.5 | Capas editables: crear, renombrar, color, borrar vacía, actual | Gestión de capas completa |
| v0.2.6 | Guardar: SAVE/SAVE AS DXF (R2000/R12), autoguardado, diálogo cambios | Round-trip parse→write→parse |
| v0.2.7 | Medición básica: distancia, ángulo, área | Herramientas de medida |
| v0.2.8 | Tests de comandos/snap/selection + QA | Cobertura ≥ 70% |

---

## v0.3.x — Editor avanzado (fases 14–15 de TODO.md)

**Objetivo:** precisión profesional estilo AutoCAD/LibreCAD.

| Hito | Contenido | DoD |
|------|-----------|-----|
| v0.3.0 | Línea de comandos: catálogo completo, autocompletado, historial | Comandos por teclado |
| v0.3.1 | Coordenadas absolutas/relativas/polares (`@`, `#`, `<`) | Entrada de precisión |
| v0.3.2 | Grips por tipo de entidad + edición directa | Grips funcionales |
| v0.3.3 | Edición de propiedades (capa, color, grosor, texto, geometría) | PropertyPanel editable |
| v0.3.4 | DWG local: integración ODA File Converter + setup guiado | Abrir DWG → DXF local |
| v0.3.5 | TRIM, OFFSET, MIRROR | Comandos de modificación |
| v0.3.6 | Snap avanzado: quadrant, nearest, polar, tolerancia configurable | Snap completo |
| v0.3.7 | Exportación PDF + selección → DXF + LOD/perf de edición | Exportación profesional |
| v0.3.8 | Tests E2E (apertura→edición→guardado) + benchmark CI | Flujo completo verificado |

---

## v1.0.0 — Release estable

| Área | Requisito |
|------|-----------|
| Calidad | Cobertura ≥ 70%, analyze limpio, benchmark dentro de presupuesto |
| i18n | Español + inglés (ARB) |
| Plataformas | Android, iOS, Windows, macOS, Linux (web con advertencias) |
| Publicación | Google Play + App Store; política de privacidad; capturas |
| Documentación | Manual de usuario en README; CHANGELOG completo |

---

## v1.x — Post-release (candidatos)

- DGN (evaluar conversión)
- Servicio cloud de conversión DWG con consentimiento (premium)
- ViewCube y vista 3D básica (proyección isométrica)
- Edición de bloques (editor de definiciones)
- Dimensiones asociativas
- Multiusuario / sync (fuera de alcance por privacidad)
- Escritura DWG (vía ODA)

---

## Dependencias clave

```
v0.1.x (visión) ──► v0.2.0 (CadDocument/Command) ──► v0.3.0 (CommandBar)
                      │                                │
                      └─► v0.2.3 (Snap) ─────────────► v0.3.2 (Grips) ──► v0.3.5 (TRIM/OFFSET)
```

- La edición (v0.2) **depende** de que el visor tenga selección estable (v0.1.3).
- La línea de comandos (v0.3) **depende** de CommandBar infraestructura básica en v0.2.
- DWG ODA (v0.3.4) **depende** de que el parser DXF sea robusto (v0.1.x).

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Rendimiento con archivos grandes | Culling/LOD desde v0.1.6; presupuesto en PERFORMANCE.md |
| Soporte parcial de HATCH/SPLINE del paquete dxf | Advertencia + simplificación; wrapper aísla el impacto |
| ODA File Converter no disponible en alguna plataforma | Guía de instalación; alternativa cloud futura con consentimiento |
| Complejidad del ViewModel | Delegación a sub-sistemas (CommandStack, SnapEngine, SelectionManager) |
| Alcance de edición creciente | Fases cortas con DoD; features C (Could) fuera de v1.0 |
