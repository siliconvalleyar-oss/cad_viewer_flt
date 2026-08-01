# 🎯 Skill: cad_renderers — Canvas Rendering

**Propósito:** Documentación del sistema de renderizado CAD con CustomPainter. Complementa `docs/DESIGN.md` y `docs/AESTHETICS.md`.

---

## 1. Rendering Pipeline

```
ViewerScreen
└── InteractiveViewer
    └── RepaintBoundary
        └── CustomPaint
            └── painter: CadPainter
                ├── 1. Background
                ├── 2. Grid (GridRenderer)
                ├── 3. Axes (AxisRenderer)
                ├── 4. Entities visibles (culling + spatial index)
                ├── 5. Selection halo + ventanas window/crossing
                ├── 6. Grips (GripRenderer, con selección activa)
                └── 7. Snap indicator (SnapRenderer)
```

### InteractiveViewer config

```dart
InteractiveViewer(
  transformationController: _transformController,
  boundaryMargin: EdgeInsets.all(double.infinity),
  minScale: 0.01,
  maxScale: 100.0,
  onInteractionEnd: (details) {
    viewModel.setTransform(offset, scale);
  },
)
```

---

## 2. CadPainter

**Archivo:** `lib/renderers/cad_painter.dart`

### paint() — Orden de pintado

1. **Background** — color de fondo según tema
2. **Grid** — adaptado a escala (paso mínimo 8px), cache de Path
3. **Axes** — X rojo / Y azul con flechas (ocultables)
4. **Entidades visibles** — con culling (viewport +20%) y por orden de archivo
5. **Selection overlay** — halo azul discontinuo + "respiración"
6. **Grips** — solo si hay selección activa
7. **Snap indicator** — marcador según modo activo

### Métodos de dibujo

| Método | Entidad |
|--------|---------|
| _drawLine | CadLine |
| _drawCircle | CadCircle |
| _drawArc | CadArc |
| _drawEllipse | CadEllipse |
| _drawPolyline / _drawLwPolyline | CadPolyline / CadLwPolyline |
| _drawText / _drawMText | CadText / CadMText (TextPainter con cache LRU) |
| _drawInsert | CadInsert (recursivo con transformación completa) |
| _drawHatch | CadHatch (básico) |
| _drawPoint / _drawSpline / _drawDim / _draw3dFace | Resto del catálogo |

### ACI Color Mapping

```dart
Color _getAciColor(int aci, AppThemeMode themeMode) {
  // theme-aware: Blueprint monocromático, AutoCAD paleta estándar, etc.
  // Ver docs/AESTHETICS.md §5
}
```

### shouldRepaint (por version counters, no listas)

```dart
@override
bool shouldRepaint(CadPainter oldDelegate) {
  return oldDelegate.documentVersion != documentVersion ||
      oldDelegate.selectionVersion != selectionVersion ||
      oldDelegate.themeMode != themeMode ||
      oldDelegate.transformVersion != transformVersion ||
      oldDelegate.layersVersion != layersVersion;
}
```

---

## 3. LayerManager

**Archivo:** `lib/renderers/layer_manager.dart`

```dart
class LayerManager {
  final CadDocument document;
  List<CadEntity> getVisibleEntities();      // visible && !frozen
  bool isLayerVisible(String name);
  void toggleLayer(String name);
  void showAllLayers();
  void hideAllLayers();
  Color getLayerColor(CadLayer layer, AppThemeMode theme);  // displayColor ?? aci
  bool isLayerLocked(String name);
  bool isLayerFrozen(String name);
}
```

---

## 4. Coordinate Transform

**Archivo:** `lib/utils/coordinate_transform.dart`

```dart
class CoordinateTransform {
  final Size viewportSize;
  final CadDocument document;
  final double scale;
  final Offset offset;

  Offset toCanvas(Point3 pt);
  Point3 toWorld(Offset px);
  Rect getEntityBounds(CadEntity entity);   // con cache por handle
  Rect getDrawingBounds({bool visibleOnly});
  Matrix4 fitToScreenMatrix();              // escala al 80%, centrado
}
```

Fit to screen:
```dart
Matrix4 fitToScreenMatrix() {
  final bounds = getDrawingBounds();
  final scale = min(vw.width / bounds.width, vw.height / bounds.height) * 0.8;
  final center = bounds.center;
  return Matrix4.identity()
    ..translate(vw.width / 2, vw.height / 2)
    ..scale(scale)
    ..translate(-center.dx, -center.dy);
}
```

---

## 5. Overlays de edición

### GripRenderer (`lib/renderers/grip_renderer.dart`)
- Grips por tipo de entidad (ver `docs/EDITING.md` §6.2).
- Activo: relleno rojo; inactivo: azul hueco. Tamaño 8dp.

### SnapRenderer (`lib/renderers/snap_renderer.dart`)
- Marcador según modo: endpoint (cuadrado), midpoint (triángulo), center (círculo), intersection (X), nearest (rombo).
- Color amarillo, 12dp, contrastado en todos los temas.

### GridRenderer (`lib/renderers/grid_renderer.dart`)
- Cartesiano (paso adaptativo, mínimo 8px), polar e isométrico (30°/150°).
- Opacidad por tema: 0.3 claro / 0.2 oscuro (AESTHETICS.md §7).

### AxisRenderer (`lib/renderers/axis_renderer.dart`)
- Eje X `#E53E3E`/`#FC8181`, Y `#2B6CB0`/`#63B3ED`; flecha + etiqueta; oculto si origen fuera de vista.

---

## 6. Rendimiento

- **Culling:** solo entidades cuyo bounds intersecta viewport +20%.
- **Spatial index:** grid hash/R-tree sobre bounds; reconstruido tras `documentVersion++` (Isolate si > 5 k entidades).
- **Cache de Picture:** capas estáticas renderizadas a `ui.Picture` reutilizable.
- **LOD:** a zoom lejano, omitir textos < 4px y simplificar hatches/splines.
- **TextPainter LRU:** reusar por (texto, altura, rotación).

---

## 7. Checklist AI para renderizado

- [ ] ¿shouldRepaint usa version counters (no compara listas)?
- [ ] ¿El culling y spatial index están activos?
- [ ] ¿Los textos usan cache y LOD?
- [ ] ¿Grips y snap indicator respetan el tema?
- [ ] ¿El painter no muta el documento (solo lee)?
- [ ] ¿El grid se simplifica si el paso es < 8px?
- [ ] ¿Los colores ACI son theme-aware?
