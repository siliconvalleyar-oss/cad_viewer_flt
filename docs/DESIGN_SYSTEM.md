# Design System — CAD Viewer & Editor

**Versión:** 0.3.0
**Estado:** Aprobado (equipo de diseño)
**Equipo responsable:** Design Lead · UX · Motion
**Propósito:** Sistema de diseño formal de la aplicación. **Fuente única de verdad de los tokens** y especificaciones de componentes. `docs/DESIGN.md` define la visión de alto nivel y delega aquí los valores concretos. `docs/AESTHETICS.md` define las paletas temáticas; este documento las formaliza en roles semánticos.

---

## Índice

1. [Principios de diseño](#1-principios-de-diseño)
2. [Design tokens](#2-design-tokens)
3. [Componentes y estados](#3-componentes-y-estados)
4. [Motion design](#4-motion-design)
5. [Iconografía](#5-iconografía)
6. [Accesibilidad visual](#6-accesibilidad-visual)
7. [Layout y stacking](#7-layout-y-stacking)
8. [Checklist de conformidad](#8-checklist-de-conformidad)

---

## 1. Principios de diseño

Reglas de decisión para cualquier elemento nuevo. Cada principio incluye su aplicación concreta en la app.

| # | Principio | Aplicación en CAD Viewer & Editor |
|---|-----------|-----------------------------------|
| P1 | **Menos es más** | El canvas es el protagonista: cero decoración que compita con el dibujo. Controles discretos y auto-ocultables |
| P2 | **Jerarquía por contraste, no por decoración** | Fondo (menor contraste) → canvas → selección (mayor). Un solo elemento resaltado a la vez |
| P3 | **Consistencia de tokens** | Nunca valores literales en el código: siempre `ThemeExtension`/constantes nombradas (`spacing.md`, `radius.lg`) |
| P4 | **Feedback inmediato y proporcional** | Cada acción tiene respuesta en < 100 ms (visual o háptica); la intensidad escala con la importancia |
| P5 | **Affordance clara** | Lo táctil se ve táctil: botones con elevación sutil, filas con hover, grips con forma de agarre |
| P6 | **Progressive disclosure** | La edición avanzada (CommandBar, snaps) se revela solo cuando se necesita; nunca abruma al nuevo usuario |
| P7 | **Precisión como valor estético** | Tipografía mono para medidas, alineación a grid 4dp, coordenadas siempre visibles: la exactitud se *ve* |
| P8 | **Inmersión sin trampas** | El dibujo siempre legible: blur solo en controles, nunca sobre entidades; overlays con opacidad controlada |
| P9 | **Ergonomía primero** | Acciones frecuentes en zona de pulgar (móvil); teclado completo en desktop; pen en tablet |
| P10 | **Inclusividad** | WCAG AA, dynamic type, modo contraste reducido y estrategia color-blind para capas ACI |

---

## 2. Design tokens

> Convención de nombres: `categoría.variante` (ej: `spacing.md`, `radius.lg`, `elevation.z2`, `motion.standard`, `color.surface`). En código: constantes Dart en `lib/theme/app_tokens.dart` y `ThemeExtension` para los roles de color.

### 2.1 Espaciado (grid de 4dp)

| Token | Valor | Uso |
|-------|-------|-----|
| `spacing.xs` | 4 dp | Espaciado entre icono y etiqueta, inner padding chips |
| `spacing.sm` | 8 dp | Padding de iconos, gap entre elementos de toolbar |
| `spacing.md` | 12 dp | Padding de controles flotantes, listas densas |
| `spacing.lg` | 16 dp | Padding estándar de paneles y sheets |
| `spacing.xl` | 24 dp | Márgenes de pantalla, gaps de secciones |
| `spacing.xxl` | 32 dp | Separación de bloques grandes (Home) |
| `spacing.xxxl` | 48 dp | Áreas de respiración (canvas edge padding) |

**Regla:** nunca usar valores fuera de la escala (prohibido 5, 7, 11... dp). El grid se aplica a posiciones, sizes y offsets de alineación.

### 2.2 Radios

| Token | Valor | Uso |
|-------|-------|-----|
| `radius.sm` | 4 dp | Chips, checkboxes, mini-indicadores |
| `radius.md` | 8 dp | List items, tooltips, snap indicator |
| `radius.lg` | 12 dp | Controles flotantes (zoom, toolbar, command bar) |
| `radius.xl` | 16 dp | Bottom sheets, diálogos |
| `radius.full` | 999 dp | FABs, toggles circulares |

### 2.3 Elevación

| Token | Sombra | Uso |
|-------|--------|-----|
| `elevation.z0` | Ninguna | Superficies planas (paneles de fondo) |
| `elevation.z1` | `0,1,2,0` α0.12 + `0,1,1,0` α0.08 | List items, filas de capa |
| `elevation.z2` | `0,2,4,0` α0.12 + `0,1,2,0` α0.08 | Controles flotantes, toolbar contextual |
| `elevation.z3` | `0,4,8,0` α0.16 + `0,2,4,0` α0.12 | Bottom sheets, panels deslizantes |
| `elevation.z4` | `0,6,12,0` α0.18 + `0,3,6,0` α0.12 | Diálogos modales |
| `elevation.z5` | `0,10,20,0` α0.20 + `0,4,8,0` α0.14 | Snackbars, loading overlay |

**Dark mode:** aplicar tinte de elevación (Material): superficie oscura se aclara +4% luminosidad por nivel.

### 2.4 Opacidad

| Token | Valor | Uso |
|-------|-------|-----|
| `opacity.scrim` | 0.5 | Scrim de sheets/diálogos |
| `opacity.overlay` | 0.15 | Ventanas de selección window/crossing |
| `opacity.ghost` | 0.30 | Elementos decorativos, grid en dark |
| `opacity.disabled` | 0.38 | Controles deshabilitados |
| `opacity.muted` | 0.60 | Iconos secundarios, texto secundario en canvas |
| `opacity.highlight` | 0.85 | Halo de selección en estado alto |

### 2.5 Color semántico (roles por tema)

Cada tema (6 en total, ver `docs/AESTHETICS.md`) mapea estos roles. Tabla para los dos temas base:

| Rol | Claro | Oscuro | Uso |
|-----|-------|--------|-----|
| `color.background` | `#F5F7FA` | `#1A1D23` | Fondo de app |
| `color.surface` | `#FFFFFF` | `#1E2128` | Canvas, paneles |
| `color.surfaceElevated` | `#FFFFFF` | `#232731` | Sheets, controles flotantes |
| `color.onBackground` | `#1A202C` | `#EDF2F7` | Texto principal |
| `color.onSurfaceMuted` | `#4A5568` | `#A0AEC0` | Texto secundario |
| `color.primary` | `#3182CE` | `#63B3ED` | Acentos, botones primarios |
| `color.onPrimary` | `#FFFFFF` | `#0B1B2B` | Texto sobre primary |
| `color.outline` | `#CBD5E0` | `#3A3F4A` | Bordes, separadores |
| `color.error` | `#E53E3E` | `#FC8181` | Errores |
| `color.success` | `#38A169` | `#68D391` | Confirmaciones |
| `color.grid` | `#D0D5DD` | `#3A3F4A` | Rejilla del canvas |
| `color.snap` | `#D69E2E` | `#F6E05E` | Indicador de snap (amarillo) |
| `color.axisX` | `#E53E3E` | `#FC8181` | Eje X |
| `color.axisY` | `#2B6CB0` | `#63B3ED` | Eje Y |
| `color.selection` | `#3182CE` | `#63B3ED` | Halo de selección, grips inactivos |
| `color.gripActive` | `#E53E3E` | `#FC8181` | Grip activo |

**Regla de capas ACI:** los colores ACI del dibujo **nunca** se reemplazan por tokens de UI; se mapean con `aci_colors.dart` y el override temático de AESTHETICS.md §5.

### 2.6 Tipografía

| Token | Fuente | Tamaño/Weight | Uso |
|-------|--------|---------------|-----|
| `type.display` | Inter | 28 sp / 700 | Título de Home, números grandes |
| `type.title` | Inter | 20 sp / 600 | Títulos de panel y pantalla |
| `type.subtitle` | Inter | 16 sp / 500 | Subtítulos, nombres de archivo |
| `type.body` | Inter | 14 sp / 400 | Texto general |
| `type.bodyMedium` | Inter | 14 sp / 500 | Nombres de capa, filas de lista |
| `type.label` | Inter | 12 sp / 500 | Etiquetas de UI, chips, botones |
| `type.property` | Inter | 12 sp / 400 | Valores de propiedades, textos auxiliares |
| `type.caption` | Inter | 11 sp / 400 | Textos auxiliares, versiones |
| `type.mono` | JetBrains Mono | 10–12 sp / 400 | Coordenadas, medidas, valores de propiedad |

**Detalles:**
- Interlineado: 1.5x (títulos 1.2x).
- Letter-spacing: +0.5% en `label` y `caption`; 0 en el resto.
- Mayúsculas: solo en `label` para etiquetas de control (UI text), nunca en contenido del dibujo.
- Texto CAD (entidades TEXT/MTEXT): usar la fuente del estilo DXF si está disponible; fallback Inter.
- Dynamic type: toda la escala escala ×1.0–1.3 según configuración del sistema (ver §6).

### 2.7 Breakpoints

| Breakpoint | Rango | Comportamiento |
|------------|-------|----------------|
| `bp.xs` | < 360 dp | Controles compactos, toolbar simplificada (solo 4 acciones) |
| `bp.sm` | 360–600 dp | Móvil estándar: bottom sheets, thumb-first |
| `bp.md` | 600–840 dp | Tablet portrait: paneles laterales opcionales |
| `bp.lg` | 840–1200 dp | Tablet landscape / desktop: paneles laterales fijos |
| `bp.xl` | > 1200 dp | Desktop: ventanas flotantes para propiedades, CommandBar ancha |

Implementación: `LayoutBuilder` + constantes en `app_tokens.dart`. Complementa a `OrientationBuilder` (DISEÑO.md §5).

---

## 3. Componentes y estados

Matriz de estados común: **normal · hover · pressed · disabled · focus · selected · loading**.

### 3.1 Botones (FAB / icon buttons / tool buttons)

| Estado | Especificación |
|--------|----------------|
| normal | Fondo `surfaceElevated`, elevación z2, icono `onSurface` |
| hover (pointer) | Fondo +6% luminosidad, sin elevación extra |
| pressed | Elevación z1, escala 0.96, 100 ms |
| disabled | Opacidad 0.38, sin sombra, cursor no-permitido (pointer) |
| focus (teclado) | Focus ring 2px `color.primary`, offset 2px |
| selected (toggle) | Fondo `primary` α0.15 + borde `primary` 1.5px |
| loading | Icono reemplazado por spinner 16 dp; deshabilitado |

**Aplicación:** ZoomControls (+, −, fit), ToolbarEdit (mover, rotar, escalar, borrar, crear), FAB "Abrir", botones de CommandBar. Los botones undo/redo reflejan `canUndo/canRedo` → disabled.

### 3.2 Filas de lista (LayerPanel, recientes, historial de comandos)

| Estado | Especificación |
|--------|----------------|
| normal | Padding `md`, radius `md`, fondo transparente |
| hover | Fondo `onSurface` α0.04 |
| pressed | Fondo `onSurface` α0.08 |
| disabled | Opacidad 0.38 (capa frozen) |
| focus | Focus ring 2px |
| selected | Fondo `primary` α0.12 + indicador lateral 3px `primary` |
| leading icon | Color ACI de la capa (chip 8 dp) |

### 3.3 Checkbox / switch de capa

- Checkbox: `radius.sm`, color `primary` cuando activo.
- Switch: track 32×20 dp, thumb 16 dp, `primary`.
- Estados: normal/hover/pressed/disabled (capa frozen)/focus.
- **A11y:** `Semantics(label: 'Capa X visible')`.

### 3.4 Bottom sheets y paneles

| Elemento | Spec |
|----------|------|
| Sheet | radius `xl` superior, elevación z3, scrim `opacity.scrim`, drag handle 32×4 dp `outline` |
| Panel lateral (landscape/desktop) | width: 280 dp (`bp.lg`) / 320 dp (`bp.xl`), separador `outline` |
| Entrada | slide easeOutCubic 300 ms (`motion.medium`) |
| Salida | slide inverso 200 ms (`motion.fast`) |

### 3.5 Snackbar / dialog / banner

| Elemento | Spec |
|----------|------|
| Snackbar | elevación z5, radius `lg`, fondo `onBackground` invertido, acción con `primary` |
| Dialog | radius `xl`, elevación z4, padding `lg`, botones alineados derecha |
| Error banner | Fondo `error` α0.10, borde 1px `error`, icono de error, texto `onSurface` |
| Duración | snackbar 4 s (acciones destructivas con undo: 6 s) |

### 3.6 Estado vacío (empty state)

```
┌──────────────────────────────┐
│      [icono 48 dp, muted]    │
│    Título (type.subtitle)    │
│  Descripción (type.body)     │
│      [CTA si aplica]         │
└──────────────────────────────┘
```
- Copy y CTA por pantalla: ver `docs/UX_FLOWS.md` §5 (matriz de estados).
- Iconografía: ver §5 de este documento.

---

## 4. Motion design

### 4.1 Tokens de easing

| Token | Curva | Uso |
|-------|-------|-----|
| `motion.standard` | `Cubic(0.2, 0.0, 0.0, 1.0)` | Transiciones de UI generales |
| `motion.emphasized` | `Cubic(0.2, 0.0, 0.0, 1.4)` | Entradas destacadas, sheets |
| `motion.decelerate` | `Cubic(0.0, 0.0, 0.2, 1.0)` | Salidas y desapariciones |
| `motion.fastOutSlowIn` | `Cubic(0.4, 0.0, 0.2, 1.0)` | Zoom, feedback de control |

### 4.2 Escala de duración

| Token | Valor | Uso |
|-------|-------|-----|
| `motion.instant` | 0 ms | Feedback de pressed (escala) |
| `motion.fast` | 100 ms | Hover, pressed, micro-feedback |
| `motion.medium` | 200 ms | Zoom, tooltips, undo/redo feedback |
| `motion.slow` | 300 ms | Sheets, paneles, fade-through |
| `motion.hero` | 500 ms | Splash, onbording, transiciones de pantalla |

### 4.3 Mapa de animaciones (componente → token)

| Animación | Easing | Duración | Referencia |
|-----------|--------|----------|------------|
| Fade-through Home→Viewer | standard | 300 ms | DESIGN.md §6 |
| Sheet/panel entrada | emphasized | 300 ms | §3.4 |
| Sheet/panel salida | decelerate | 200 ms | §3.4 |
| Halo de selección "respiración" | linear (loop) | 1000 ms | DESIGN.md §6 |
| Zoom con botones | fastOutSlowIn | 200 ms | DESIGN.md §6 |
| Botón pressed | standard | 100 ms | §3.1 |
| Splash stroke-dash + fade | emphasized | 1500 ms | DESIGN.md §6 |
| Snap indicator aparición | fast | 100 ms | — |
| Grip hover | fast | 100 ms | — |
| Rubber band (preview) | linear | por frame | — |
| Undo/redo SnackBar | standard | 200 ms + 6 s | — |
| Toolbar contextual entrada/salida | standard | 200 ms | — |

### 4.4 Reduced motion

- Leer `MediaQuery.of(context).disableAnimations` (o `accessibleNavigation`).
- Política: deshabilitar loop del halo (estado estático), duraciones ≥ 2x en las demás, sin motion de entrada (aparición directa), scroll suave estándar.
- El splash respeta la preferencia: mostrar logo estático sin stroke-dash.

---

## 5. Iconografía

### 5.1 Estilo

- Fuente: Feather Icons (trazo 1.5 px) + Material Icons para acciones de sistema.
- Grid: 24 dp (botones) / 16 dp (listas, chips) / 48 dp (empty states).
- Alineación óptica al 1/2 px del grid.

### 5.2 Registro de iconos (feature → icono)

| Feature | Icono (Feather) | Estado |
|---------|-----------------|--------|
| Abrir archivo | folder-open | — |
| Ajustes | settings | — |
| Zoom in / out | plus / minus | — |
| Fit to screen | maximize | — |
| Capas | layers | activo cuando panel abierto |
| Zoom indicador | — | % en `type.mono` |
| Mover | move | selected si modo activo |
| Rotar | refresh-cw | — |
| Escalar | maximize-2 | — |
| Copiar | copy | — |
| Borrar | trash-2 | disabled sin selección |
| Deshacer / Rehacer | rotate-ccw / rotate-cw | disabled si `!canUndo/canRedo` |
| Propiedades | info | — |
| Crear línea | trending-up (45°) | — |
| Crear círculo | circle | — |
| Crear arco | compass | — |
| Crear elipse | sun (oval) | — |
| Crear polilínea | hexagon | — |
| Crear texto | type | — |
| Crear punto | crosshair | — |
| Medir distancia | ruler | — |
| Medir ángulo | edit-3 (protractor) | — |
| Medir área | square | — |
| Compartir | share-2 | — |
| Captura | camera | — |
| Guardar | save | disabled si `!dirty` |
| Línea de comandos | terminal | — |
| Snap (toggle) | magnet | selected si activo |

---

## 6. Accesibilidad visual

### 6.1 Contraste (WCAG AA, 4.5:1 texto / 3:1 UI)

Tabla de verificación por par (temas base):

| Par | Claro | Ratio | Oscuro | Ratio |
|-----|-------|-------|--------|-------|
| onBackground / background | `#1A202C` / `#F5F7FA` | 15.3:1 ✅ | `#EDF2F7` / `#1A1D23` | 13.9:1 ✅ |
| onSurfaceMuted / background | `#4A5568` / `#F5F7FA` | 7.1:1 ✅ | `#A0AEC0` / `#1A1D23` | 7.0:1 ✅ |
| primary / background (texto) | `#3182CE` / `#F5F7FA` | 4.6:1 ✅ | `#63B3ED` / `#1A1D23` | 7.2:1 ✅ |
| onSurfaceMuted / surface | `#4A5568` / `#FFFFFF` | 7.3:1 ✅ | `#A0AEC0` / `#1E2128` | 6.4:1 ✅ |
| error / background | `#E53E3E` / `#F5F7FA` | 4.6:1 ✅ | `#FC8181` / `#1A1D23` | 7.1:1 ✅ |

> Verificación automatizada en CI: test de contraste por token/tema (golden + análisis).

### 6.2 Estrategia color-blind para capas ACI (crítico en CAD)

| Percepción | Problema | Mitigación |
|------------|----------|------------|
| Deuteranopia (rojo/verde) | ACI 1 (rojo) ≈ ACI 3 (verde) | Tema **Blueprint** (monocromático) por defecto en accesibilidad; patrón de línea + grosor + etiqueta de capa como canal redundante |
| Tritanopia (azul/amarillo) | ACI 5 (azul) ≈ ACI 2 (amarillo) | Override de `displayColor` por capa; tema de alto contraste |
| Saturación baja | Colores pastel ACI | `displayColor` con saturación mínima; opción "forzar colores saturados" |

**Regla de diseño:** la selección nunca depende solo del color (halo + grosor + grips). Los indicadores de estado usan forma + color (snap: forma según modo).

### 6.3 Dynamic type

- Escala tipográfica ×1.0–1.3 (pasos 0.1) según `textScaler` del sistema.
- Verificar que paneles de propiedades y CommandBar no rompan layout en ×1.3 (prueba golden).
- Medidas mono (`type.mono`) pueden quedar fijas en 10 sp para no perder legibilidad de columnas.

### 6.4 Semántica del canvas (lectores de pantalla)

- `Semantics` en el canvas describe: nombre de archivo, número de entidades visibles, entidad seleccionada (tipo + capa + medidas clave).
- Al seleccionar una entidad: `SemanticsService.announce('Seleccionado: Línea en capa Muros, longitud 5.00 m')`.
- Comandos: cada acción de CommandBar/toolbar con `tooltip` + `Semantics(label)`.

### 6.5 Focus visible

- Todo foco por teclado muestra focus ring 2 px `color.primary`, offset 2 px, `radius` del componente.
- Tab order: canvas → AppBar → toolbar → paneles (configurable por plataforma).

---

## 7. Layout y stacking

### 7.1 Orden de apilamiento (z-index)

| Nivel | Capa | Elementos |
|-------|------|-----------|
| 0 | Canvas fondo | `canvasColor` |
| 1 | Dibujo | grid, ejes, entidades (orden de archivo) |
| 2 | Overlay de edición | selección, grips, snap indicator, rubber band |
| 3 | Controles | ZoomControls, ToolbarEdit, CommandBar |
| 4 | Paneles | LayerPanel, PropertyPanel, panel lateral |
| 5 | Superficies | sheets, dialogs, snackbars, scrim |

### 7.2 Densidad

| Modo | Uso | Cambios |
|------|-----|---------|
| `compact` | Móvil, canvas ocupando todo | Controles 40 dp, toolbar colapsada |
| `comfortable` | Tablet/desktop | Controles 44 dp+, paneles con `spacing.lg` |
| `spacious` | Desktop + pen | Paneles anchos, targets 48 dp |

---

## 8. Checklist de conformidad

- [ ] Todos los valores de UI usan tokens (prohibido literales)
- [ ] Todos los componentes tienen los 7 estados especificados
- [ ] Focus visible en todos los elementos enfocables
- [ ] Contraste AA verificado por par/tema (test automático en CI)
- [ ] Reduced-motion implementado para todas las animaciones
- [ ] Iconografía del registro usada (sin iconos ad-hoc)
- [ ] Stacking respetado en todos los overlays
- [ ] Estrategia color-blind para ACI implementada
- [ ] Dynamic type ×1.3 no rompe layout (golden)
- [ ] Semántica del canvas implementada
