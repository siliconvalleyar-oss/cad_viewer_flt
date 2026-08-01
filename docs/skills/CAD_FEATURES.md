# 🎯 Skill: cad_features — Core Features

**Propósito:** Documentación de funcionalidades principales (visor + editor). Requisitos: `docs/REQUIREMENTS.md`.

---

## 1. File Loading & Recent Files

### File Picker

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['dxf', 'dwg'],
  withData: true,
);
```

### Detección de formato

`FileHelper.detectFormat(path, bytes)`: extensión + magic bytes DWG (`AC10xx`) + DXF ASCII (`0\nSECTION`). DXF binario → advertencia.

### Recent Files

```dart
// Guardar en shared_preferences (máx. 10)
await prefs.setStringList('recent_files', recentPaths);

// Leer
final recentPaths = prefs.getStringList('recent_files') ?? [];
```

### RecentFilesList widget
- Lista horizontal; nombre + miniatura (base64, ≤ 100 KB); tap → cargar; deslizar → eliminar.

---

## 2. Home Screen

**Archivo:** `lib/screens/home_screen.dart`

### Features
- Botón "Abrir archivo" destacado
- Lista horizontal de recientes
- Ajustes: tema (6), unidades (mm/cm/m/inch), grid, snap, versión

### Theme Toggle

```dart
// Guardar preferencia
await prefs.setString('theme_mode', AppThemeMode.blueprint.name);

// Aplicar
MaterialApp(
  theme: lightTheme, darkTheme: darkTheme,
  themeMode: _toMaterial(themeMode),
)
```

---

## 3. Viewer Screen

**Archivo:** `lib/screens/viewer_screen.dart`

### Features
- AppBar con nombre, back, fit-to-screen, info
- CadView: InteractiveViewer + CadPainter + overlays (grips, snap)
- ZoomControls, ToolbarEdit, CommandBar, LayerPanel, PropertyPanel
- StatusBar: coordenadas + snap activo + medidas

### Gestures
- Un dedo: pan; dos: pinch; tap: seleccionar/punto; doble: zoom+; drag: editar en modo edición
- ESC: cancelar/deseleccionar

---

## 4. Layer Panel

**Archivo:** `lib/screens/layer_panel.dart`

### Features
- Checkbox visibilidad + color ACI + candado (locked)
- Show All / Hide All
- DisplayColor override
- Crear/renombrar/borrar (vacía)/actual/color
- Contador de entidades
- Rebuild selectivo: `context.select((vm) => vm.layersVersion)`

---

## 5. Property Panel

**Archivo:** `lib/widgets/property_panel.dart`

- Bottom sheet modal; props por tipo de entidad
- v0.3+: campos editables (CommandModifyProps)

---

## 6. Editing Features (v0.2+)

### CommandStack (undo/redo)

```dart
final cmd = CommandMove(handles, delta);
viewModel.undo();          // CommandStack.undo()
viewModel.redo();          // re-ejecuta execute
```

### Creación

- LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, TEXT, POINT con preview en vivo
- Capa actual; color ByLayer; al terminar queda seleccionada

### Transformación

- Mover, rotar, escalar, copiar, borrar (DEL)
- Atajos: Ctrl+Z/Y, Ctrl+C/V/X, DEL, ESC

### Snap (SnapEngine)

```dart
final result = snapEngine.snap(
  cursorWorld,
  candidates: visibleEntities,
  settings: viewModel.snapSettings,
);
if (result != null) viewModel.useSnappedPoint(result.point);
```

- Modos: endpoint, midpoint, center, quadrant, intersection, nearest, grid, polar; ortho (F8)
- Tolerancia px adaptada al zoom; indicador visual por modo

### Grips (v0.3)

- Por tipo de entidad; activo rojo / inactivo azul; drag → CommandModifyProps

### CommandBar (v0.3)

- Catálogo: LINE, CIRCLE, ERASE, MOVE, ROTATE, SCALE, COPY, DIST, ANGLE, AREA, ZOOM, PAN, FIT, LAYER, SNAP, ORTHO, UNITS, SAVE, UNDO, REDO, CLEAR, HELP
- Coordenadas: `10,20` / `#10,20` / `@10,20` / `10<45`

---

## 7. Export & Share

### Screenshot

```dart
final image = await ScreenshotController()
  .captureFromWidget(RepaintBoundary(...));
await ImageGallerySaver.saveImage(image);   // respeta tema
```

### Share

```dart
await Share.shareXFiles([XFile(filePath)], text: 'CAD file');
```

### Save DXF (DxfWriter)

```dart
final content = await compute(DxfWriter.write, payload);  // R2000 | R12
await File(path).writeAsString(content, flush: true);
```

---

## 8. DWG Support (External)

### Flujo

1. Usuario selecciona `.dwg`
2. MVP: mensaje "convierta a DXF" + guía
3. v0.3+: DwgParser invoca ODA File Converter (CLI local) → DXF temporal → parse
4. Mostrar indicador de carga; borrar temporales

### Privacidad

Nunca subir planos a servicios cloud sin consentimiento explícito (ADR-0005, SECURITY.md).

---

## 9. Measurement

- `DIST`: 2 puntos → distancia + ΔX/ΔY + ángulo
- `ANGLE`: 3 puntos → grados
- `AREA`: polígono/entidad cerrada → unidad²
- Overlay temporal en canvas; sin crear entidades

---

## 10. Checklist AI para features

- [ ] ¿El flujo Home → abrir → ver → editar → guardar → reabrir funciona?
- [ ] ¿Toda edición es deshacible (Ctrl+Z)?
- [ ] ¿El snap respeta la capa (locked no editable pero snap sí)?
- [ ] ¿El guardado R12 convierte LWPOLYLINE y advierte?
- [ ] ¿Los recientes se limitan a 10 y son persistibles?
- [ ] ¿DWG muestra guía en MVP y convierte local en v0.3+?
- [ ] ¿El autosave se limpia al guardar manualmente?
