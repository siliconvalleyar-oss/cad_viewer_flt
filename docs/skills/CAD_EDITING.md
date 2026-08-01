# 🎯 Skill: cad_editing — Editing System (Command, Undo/Redo, Snap, Grips, CommandBar)

**Propósito:** Documentación del subsistema de edición de CAD Viewer & Editor. Complementa `docs/EDITING.md` (especificación completa).

---

## 1. Arquitectura de edición

```
CadDocument (sesión editable, mutable solo vía comandos)
   ▲
   │ (mutación)
CommandStack ── push/undo/redo ──► CadCommand.execute(doc) / undo(doc)
   ▲
   │ (delegación)
CadViewModel (estado de sesión, notifica a UI)
   ▲
   │ (input)
UI: GestureDetector / CommandBar / ToolbarEdit / Grips
```

**Regla de oro:** ninguna mutación de `CadDocument` ocurre fuera de un `CadCommand` ejecutado por `CommandStack`. Ver `docs/EDITING.md` §3 y ADR-0004.

---

## 2. CommandStack

**Archivo:** `lib/controllers/command_stack.dart`

```dart
class CommandStack {
  final List<CadCommand> _undo = [];
  final List<CadCommand> _redo = [];
  static const int limit = 100;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void push(CadCommand cmd) {
    cmd.execute(_doc);       // muta el documento
    _undo.add(cmd);          // si _undo.length > limit → removeAt(0)
    _redo.clear();           // nueva rama invalida el redo
  }

  void undo() {
    final cmd = _undo.removeLast();
    cmd.undo(_doc);
    _redo.add(cmd);
  }

  void redo() {
    final cmd = _redo.removeLast();
    cmd.execute(_doc);       // re-ejecuta (no re-aplica snapshot)
    _undo.add(cmd);
  }

  void clear() { _undo.clear(); _redo.clear(); }
}
```

---

## 3. Comandos principales

| Comando | execute | undo |
|---------|---------|------|
| `CommandCreate(entity)` | add entity | remove entity |
| `CommandDelete(handles)` | remove + guardar snapshot | restaurar snapshot |
| `CommandMove(handles, delta)` | desplazar +delta | desplazar −delta |
| `CommandRotate(handles, center, angle)` | rotar +angle | rotar −angle |
| `CommandScale(handles, base, factor)` | escalar factor | escalar 1/factor |
| `CommandCopy(handles, delta)` | duplicar + mover | eliminar copias |
| `CommandModifyProps(handle, before, after)` | aplicar after | aplicar before |
| `CommandTrim/Offset/Mirror` | modificar | restaurar snapshot |

**Tests obligatorios:** para cada comando, `execute` luego `undo` = estado original.

---

## 4. SnapEngine

**Archivo:** `lib/controllers/snap_engine.dart`

```dart
class SnapEngine {
  final SnapSettings settings;   // modos activos, tolerancia px, polar step

  SnapResult? snap(Point cursor, List<CadEntity> candidates) {
    final tolerance = settings.tolerancePx * _pxToWorld; // adaptada al zoom
    // 1) recolectar puntos candidatos por modo × entidad (con cache)
    // 2) priorizar: intersection > endpoint > midpoint/center/quadrant > nearest > grid/polar
    // 3) ortho: si activo y hay punto previo → proyectar cursor a eje X o Y
  }
}
```

**Cache:** puntos de snap por entidad se recalculan solo al cambiar `documentVersion` o la visibilidad.

---

## 5. Grips

**Archivo:** `lib/renderers/grip_renderer.dart` + lógica en viewer_screen

- Grips por tipo de entidad (ver `docs/EDITING.md` §6.2).
- Grip activo (tocado): relleno rojo; inactivos: azul hueco.
- Arrastrar grip → preview en vivo → al soltar `CommandModifyProps`.
- Grip central de segmento de polilínea → insertar vértice.

---

## 6. CommandBar

**Archivo:** `lib/widgets/command_bar.dart`

- Catálogo de comandos: ver `docs/EDITING.md` §7.2 (LINE, CIRCLE, ERASE, MOVE, DIST, AREA, SAVE, UNDO, REDO...).
- Coordenadas: absolutas `10,20` / `#10,20`, relativas `@10,20`, polares `10<45`.
- Autocompletado + historial.
- Atajos: Ctrl+Z/Y, Ctrl+C/V/X, DEL, ESC, F3 (snap), F8 (ortho).

---

## 7. Flujo de creación (ejemplo LINE)

```
Toolbar/Comando: LINE
  → estado "Specify first point" → tap (snap) o coordenadas
  → preview rubber band
  → "Specify next point" → tap → segmento
  → ESC/Enter → CommandCreate(entidad final), queda seleccionada
```

---

## 8. Medición

- `DIST`, `ANGLE`, `AREA` — overlay temporal en canvas, sin crear entidades.
- Resultados en status bar + SnackBar.

---

## 9. Guardado

```
SAVE → exportCadFile() → DxfWriter (Isolate) → writeFile(flush:true)
Autosave cada 5 min (path_provider, *.autosave.dxf)
Diálogo de cambios sin guardar al salir
```

---

## 10. Checklist AI para edición

- [ ] ¿Toda mutación pasa por CommandStack? (ningún setState que mute el doc directo)
- [ ] ¿Cada comando tiene execute + undo simétricos y testeados?
- [ ] ¿El límite de 100 funciona (descarta el más antiguo)?
- [ ] ¿El snap usa tolerancia en px adaptada al zoom?
- [ ] ¿El snap consulta la capa (entidades en capa locked no producen snap editable)? (regla: snap sí, edición no)
- [ ] ¿Los grips solo aparecen con selección activa?
- [ ] ¿ESC cancela el comando en curso y deselecciona?
- [ ] ¿Undo/redo notifican la UI correctamente (commandVersion)?
- [ ] ¿`dirty` se actualiza en cada comando y al guardar?
- [ ] ¿El guardado valida R12 (LWPOLYLINE→POLYLINE) y advierte de SPLINE/MTEXT?
