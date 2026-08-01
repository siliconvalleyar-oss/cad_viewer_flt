# 🎯 Skill: cad_ui_components — UI Components

**Propósito:** Documentación de widgets y pantallas. Diseño visual: `docs/DESIGN.md`; estéticas: `docs/AESTHETICS.md`.

---

## 1. HomeScreen

**Archivo:** `lib/screens/home_screen.dart`

### Layout

```
┌────────────────────────────────────────┐
│  CAD Viewer & Editor               ⚙️ │
├────────────────────────────────────────┤
│                                        │
│     [📁 Abrir archivo]                 │
│                                        │
│  Recientes                             │
│  ┌──────┐ ┌──────┐ ┌──────┐           │
│  │ 📄   │ │ 📄   │ │ 📄   │           │
│  │file1 │ │file2 │ │file3 │           │
│  └──────┘ └──────┘ └──────┘           │
│                                        │
└────────────────────────────────────────┘
```

### Widgets

| Widget | Descripción |
|--------|-------------|
| OpenFileButton | Botón destacado para abrir archivo |
| RecentFilesList | Lista horizontal de recientes con miniatura |
| SettingsIcon | Abre hoja de ajustes (tema, unidades, snap, grid) |

---

## 2. ViewerScreen

**Archivo:** `lib/screens/viewer_screen.dart`

### Layout

```
┌────────────────────────────────────────┐
│ ← file.dxf        [Fit] [Info] [⋯]     │
├────────────────────────────────────────┤
│                                        │
│            Canvas CAD                  │
│         (InteractiveViewer)            │
│         + overlays (grips/snap)        │
│                                        │
│  [ToolbarEdit contextual]              │
│    [+] [-]                    [Layers] │
├────────────────────────────────────────┤
│ CommandBar (colapsable)                │
│ (X: 123.45, Y: 678.90) — Snap: END     │
└────────────────────────────────────────┘
```

### Componentes

| Componente | Descripción |
|------------|-------------|
| AppBar | Nombre archivo, back, fit-to-screen, info; translúcida con blur |
| CadView | Canvas con InteractiveViewer + CadPainter + overlays |
| ZoomControls | Botones +, −, fit-to-screen (bottom-right) |
| ToolbarEdit | Toolbar contextual de edición (bottom-center) |
| CommandBar | Línea de comandos (bottom, colapsable) |
| LayerPanel | Panel de capas (sweep abajo / lateral en landscape) |
| PropertyPanel | Bottom sheet con propiedades de entidad |
| StatusBar | Coordenadas + snap activo + medidas en vivo |

### Gestos

- Un dedo: pan
- Dos dedos: pinch zoom
- Un toque: seleccionar / punto de entrada en modo edición
- Doble toque: zoom en área
- Drag con snap: crear/mover en modo edición
- ESC: cancelar comando / deseleccionar

---

## 3. LayerPanel

**Archivo:** `lib/screens/layer_panel.dart`

### Features
- Lista de capas con checkbox de visibilidad + indicador de color ACI
- Botones Show All / Hide All
- Toggle de color de visualización (displayColor)
- Icono de candado (locked)
- Menú de capa: renombrar, borrar (vacía), hacer actual, cambiar color
- Contador de entidades por capa
- Rebuild selectivo: `context.select((vm) => vm.layersVersion)`

---

## 4. PropertyPanel

**Archivo:** `lib/widgets/property_panel.dart`

### Features
- Bottom sheet modal (40% altura móvil; ventana flotante desktop)
- Propiedades por tipo de entidad
- Formato: label + value por línea
- Cerrar al tocar fuera o botón close
- v0.3+: campos editables (capa, color, grosor, texto, radio...)

### Propiedades por tipo

| Tipo | Propiedades |
|------|-------------|
| CadLine | Layer, Color, Start, End, Length |
| CadCircle | Layer, Color, Center, Radius |
| CadArc | Layer, Color, Center, Radius, Angles |
| CadEllipse | Layer, Color, Center, Major/Minor, Rotation |
| CadLwPolyline | Layer, Color, Closed, Vertices, Length |
| CadText | Layer, Text, Height, Rotation, Style |
| CadInsert | Layer, Block, Position, Scale, Rotation |
| CadDim | Layer, Type, Measurement Text |

---

## 5. ZoomControls

**Archivo:** `lib/widgets/zoom_controls.dart`

- Botones flotantes: +, −, fit-to-screen
- Indicador de porcentaje entre botones
- Posición bottom-right, BackdropFilter blur, auto-ocultar 3s
- Mantener presionado → zoom acelerado
- Iconos Material: add, remove, fit_screen

---

## 6. CommandBar

**Archivo:** `lib/widgets/command_bar.dart`

- Campo de entrada + historial + autocompletado
- Catálogo de comandos: ver `docs/EDITING.md` §7.2
- Coordenadas: absolutas/relativas/polares
- Estado activo: borde resaltado con acento del tema
- Atajos hardware keyboard en desktop/tablet

---

## 7. ToolbarEdit

**Archivo:** `lib/widgets/toolbar_edit.dart`

- Contextual: aparece con selección activa (Mover, Rotar, Escalar, Copiar, Borrar, Propiedades)
- Modo creación: Line, Circle, Arc, Ellipse, Polyline, Text, Point
- Bottom-center flotante, blur 20px, radius 12dp, auto-ocultar
- Botones undo/redo siempre visibles (habilitados según canUndo/canRedo)

---

## 8. SettingsSheet

**Archivo:** modal bottom sheet desde HomeScreen

### Opciones
- Tema: Claro / Oscuro / Blueprint / Poster / Infografía / AutoCAD Dark (con previews)
- Unidades: mm / cm / m / pulgadas
- Grid: tipo (cartesiano/polar/isométrico), mostrar/ocultar
- Ejes: mostrar/ocultar
- Snap: modos activos, tolerancia, polar step, ortho
- Versión de la app
- Política de privacidad (enlace)

---

## 9. Checklist AI para UI

- [ ] ¿Todos los controles usan BackdropFilter blur 20px y radius 12dp?
- [ ] ¿Los touch targets son ≥ 44dp?
- [ ] ¿Los widgets usan context.select (no watch innecesario)?
- [ ] ¿La toolbar de edición aparece solo con selección/creación?
- [ ] ¿El CommandBar es colapsable y tiene autocompletado?
- [ ] ¿Landscape adapta paneles a lateral con OrientationBuilder?
- [ ] ¿Los textos respetan la escala tipográfica de DESIGN.md?
- [ ] ¿Los 6 temas se aplican correctamente en todos los paneles?
