# Modelo de Datos — CAD Viewer & Editor

**Versión:** 0.3.0 · **Estado:** Aprobado (arquitectura técnica)
**Fecha:** 2026-07-31
**Propósito:** Definición completa del modelo de datos de la aplicación: estructuras de dominio, entidades CAD, sesión editable, selección y pila de comandos. Complementa `docs/API.md` y `docs/SERIALIZATION.md`.

## Índice

1. [Filosofía](#1-filosofía-del-modelo)
2. [Diagrama de clases](#2-diagrama-de-clases)
3. [CadFile](#3-cadfile)
4. [CadLayer](#4-cadlayer)
5. [CadEntity](#5-cadentity-base-y-subtipos)
6. [CadBlock](#6-cadblock)
7. [CadDocument](#7-caddocument-sesión-editable)
8. [Selección](#8-selección-selectionmanager)
9. [CommandStack](#9-pila-de-comandos-commandstack)
10. [Unidades](#10-unidades-unitstype)
11. [Integridad](#11-consistencia-y-reglas-de-integridad)
12. [Tests](#12-tests-sugeridos-para-el-modelo)

---

## 1. Filosofía del modelo

- **`models/` es Dart puro** (sin dependencias de Flutter): testeable y reutilizable.
- **Separación archivo ↔ sesión:** `CadFile` representa el contenido del archivo (inmutable por convención). `CadDocument` representa la sesión de trabajo editable.
- **Edición segura:** las mutaciones ocurren solo vía `CadCommand` aplicado por `CommandStack` (ver `docs/EDITING.md`), que mantiene undo/redo.
- **Valores por referencia:** las entidades usan `copyWith` para derivar versiones modificadas sin mutar el original.

---

## 2. Diagrama de clases

```
CadFile (contenido del archivo)
├── fileName: String
├── format: FileFormat (dxf|dwg)
├── version: String (R12, R2000...)
├── header: CadHeader
│   ├── units: UnitsType (mm, inch, m, ...)
│   ├── extMin/extMax: Point3 (límites del dibujo)
│   ├── baseAngle: double
│   └── insUnits: int ($INSUNITS)
├── layers: List<CadLayer>
├── entities: List<CadEntity>
└── blocks: List<CadBlock>

CadDocument (sesión editable)
├── cadFile: CadFile            (referencia al archivo base)
├── entities: List<CadEntity>   (entidades de trabajo — pueden diferir del archivo)
├── layers: List<CadLayer>      (capas de trabajo, pueden diferir)
├── blocks: List<CadBlock>
├── selection: Set<String>      (handles seleccionados)
├── currentLayer: String        (capa activa)
├── dirty: bool                 (cambios sin guardar)
└── exportCadFile() → CadFile   (convierte sesión → archivo limpio)

CadCommand (patrón Command)
├── execute(doc) → void
├── undo(doc) → void
├── description: String
└── (subtipos: CommandMove, CommandCreate, CommandDelete, CommandModifyProps...)
```

---

## 3. CadFile

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `fileName` | `String` | Nombre del archivo de origen |
| `format` | `FileFormat` | `dxf`, `dwg` (o `unknown`) |
| `version` | `String` | Versión DXF leída de `$ACADVER` (AC1009, AC1015, AC1032...) o inferida |
| `header` | `CadHeader` | Variables de encabezado |
| `layers` | `List<CadLayer>` | Definiciones de capas |
| `entities` | `List<CadEntity>` | Entidades del dibujo (model space) |
| `blocks` | `List<CadBlock>` | Definiciones de bloques |
| `getBounds()` | `Rect` | Bounding box del dibujo (todas las entidades) |

### CadHeader

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `units` | `UnitsType` | Unidad del dibujo (normalizada a mm internamente) |
| `extMin` / `extMax` | `Point3` | Límites del dibujo |
| `baseAngle` | `double` | Ángulo base (rad) |
| `insUnits` | `int` | Valor crudo de `$INSUNITS` |

---

## 4. CadLayer

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | `String` | Nombre de capa (único) |
| `color` | `int` | Índice ACI (1–255); 7 = blanco |
| `lineType` | `String` | Nombre de tipo de línea (`Continuous`, `DASHED`...) |
| `lineWeight` | `double?` | Grosor en mm (override) |
| `visible` | `bool` | Visible en pantalla |
| `locked` | `bool` | Bloqueada (visible pero no editable/seleccionable) |
| `frozen` | `bool` | Congelada (no renderizada ni editable) |
| `displayColor` | `Color?` | Override de color de visualización (no afecta al archivo) |
| `isCurrent` | `bool` | Es la capa activa (entidades nuevas) |

**Reglas:**
- `frozen=true` ⇒ no se renderiza (prevalece sobre `visible`).
- `locked=true` ⇒ se renderiza pero no se selecciona ni edita.
- `displayColor != null` ⇒ reemplaza al ACI solo en pantalla.

---

## 5. CadEntity (base) y subtipos

### 5.1 Base

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `handle` | `String` | Identificador único (handle DXF o generado) |
| `layer` | `String` | Nombre de capa |
| `color` | `int?` | ACI override (null = heredar de capa) |
| `lineType` | `String?` | Tipo de línea override (null = heredar) |
| `lineWeight` | `double?` | Grosor override (mm) |
| `type` | `CadEntityType` | Tipo polimórfico |
| `copyWith()` | `CadEntity` | Copia inmutable con campos modificados |

### 5.2 Tabla de subtipos

| Tipo | Campos geométricos | Notas de edición |
|------|--------------------|------------------|
| `CadLine` | `x1,y1,x2,y2` | Grips en ambos extremos |
| `CadCircle` | `cx,cy,radius` | Grip centro + grip de radio |
| `CadArc` | `cx,cy,radius,startAngle,endAngle` | Grips: centro, extremos, punto medio |
| `CadEllipse` | `cx,cy,majorRadius,minorRadius,rotation` | Grips: centro, ejes |
| `CadLwPolyline` | `points:List<LwVertex>`, `closed`, `bulge:List<double>` | Grips en vértices |
| `CadPolyline` | `points:List<Point3>`, `closed` | Grips en vértices |
| `CadText` | `text,x,y,height,rotation,style,horizontalAlign` | Grip de inserción |
| `CadMText` | `text,x,y,height,rotation,attachmentPoint,width` | Grip de inserción |
| `CadInsert` | `blockName,x,y,scaleX,scaleY,rotation` | Grips: inserción, escala |
| `CadPoint` | `x,y` | Grip único |
| `CadHatch` | `patternName,boundaries,scale,rotation` | Solo lectura en v1.0 |
| `CadSpline` | `degree,controlPoints,knots,fitPoints` | Mover; no editar CP v1.0 |
| `CadDim` | `dimType,x1..y3,text,style` | Mover; texto auto |
| `Cad3dFace` | `corners:List<Point3>(4)` | Solo lectura v1.0 |

> Detalle de cada entidad con group codes de DXF en `docs/FORMATS.md`.

---

## 6. CadBlock

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | `String` | Nombre del bloque |
| `basePoint` | `Point3` | Punto base de inserción |
| `entities` | `List<CadEntity>` | Entidades internas (recursivas) |
| `getBounds()` | `Rect` | Bounds locales (antes de transformación) |

---

## 7. CadDocument (sesión editable)

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `cadFile` | `CadFile` | Archivo base (inmutable) |
| `entities` | `List<CadEntity>` | Entidades de trabajo |
| `layers` | `List<CadLayer>` | Capas de trabajo |
| `blocks` | `List<CadBlock>` | Bloques de trabajo |
| `selection` | `Set<String>` | Handles seleccionados |
| `currentLayer` | `String` | Capa activa |
| `dirty` | `bool` | Cambios sin guardar |
| `documentVersion` | `int` | Incrementa en cada cambio estructural |

### Métodos principales

| Método | Descripción |
|--------|-------------|
| `static fromCadFile(CadFile)` | Crea sesión limpia |
| `exportCadFile()` | Convierte sesión → CadFile (para escritura) |
| `getVisibleEntities(layers)` | Filtra por visibilidad/descongeladas |
| `getEntity(handle)` | Búsqueda por handle |
| `addEntity(e)` / `removeEntity(handle)` | Mutación controlada |
| `setEntityProps(handle, props)` | Actualización controlada (usa copyWith) |
| `markDirty()` / `markSaved()` | Flag de cambios |

> Todas las mutaciones de `CadDocument` **deben** pasar por un `CadCommand` (ver `docs/EDITING.md` §3). El documento no expone mutadores públicos excepto a través del `CommandStack`.

---

## 8. Selección (SelectionManager)

```
SelectionManager
├── selected: Set<String>
├── add(handle), remove(handle), toggle(handle), clear()
├── addRange(List<String>)
├── selectByWindow(rect, mode: crossing|window, visibleEntities)
└── isLockedLayer(handle, doc) → bloquea selección en capa locked
```

- La selección vive en el ViewModel (no en el painter).
- `selectionVersion` notifica a UI (toolbar, property panel, grips).
- Regla: entidad en capa `locked`/`frozen` no es seleccionable.

---

## 9. Pila de comandos (CommandStack)

```
CommandStack
├── undoStack: List<CadCommand>   (límite 100)
├── redoStack: List<CadCommand>
├── canUndo / canRedo: bool
├── push(cmd) → ejecuta y apila
├── undo() → deshace
├── redo() → rehace
└── clear() (al abrir archivo nuevo)
```

### Contratos de CadCommand

```dart
abstract class CadCommand {
  String get description;
  void execute(CadDocument doc);
  void undo(CadDocument doc);
  bool get changesDocument => true;
}
```

**Reglas:**
1. `execute()` muta `doc` y NO notifica (lo hace el CommandStack vía ViewModel).
2. `undo()` debe revertir exactamente lo hecho por `execute()`.
3. Comandos idempotentes: aplicar `execute` dos veces = efecto neto uno (para redo se re-ejecuta `execute`, no se re-aplica el estado capturado).
4. Comandos con geometría compleja pueden capturar estado anterior (Memento) en lugar de recomputar.

---

## 10. Unidades (UnitsType)

| Enum | Factor a mm | Uso |
|------|-------------|-----|
| `mm` | 1.0 | Por defecto |
| `cm` | 10.0 | Visualización/entrada |
| `m` | 1000.0 | Visualización/entrada |
| `inch` | 25.4 | Visualización/entrada |
| `unitless` | 1.0 | DXF sin `$INSUNITS` |

- **Internamente todo se almacena en mm.** La conversión ocurre solo en la capa de entrada/salida (UI, parser, writer). Ver ADR-0007.

---

## 11. Consistencia y reglas de integridad

1. Un handle es único dentro del documento (el writer genera `H`+counter si el DXF no trae).
2. Al parsear, entidades con capa inexistente se asignan a la capa `"0"` (creada implícitamente).
3. `INSERT` con bloque inexistente: se conserva pero se advierte y no se renderiza su contenido.
4. Al eliminar una capa con entidades: se pregunta; las entidades se mueven a la capa actual o se eliminan (decisión del usuario).
5. `exportCadFile()` nunca exporta estado de sesión (`displayColor`, `isCurrent`, selection, dirty).
6. El bounding box (`getBounds`) ignora entidades en capas descongeladas si se pide `visibleOnly`.

---

## 12. Tests sugeridos para el modelo

Ver `docs/TESTING.md`. Resumen:

| Archivo de test | Cubre |
|-----------------|-------|
| `test/models/cad_file_test.dart` | `getBounds`, header, normalización de capas |
| `test/models/cad_entity_test.dart` | Igualdad, copyWith, subtipos |
| `test/models/cad_document_test.dart` | fromCadFile, exportCadFile, dirty flag |
| `test/models/command_stack_test.dart` | Push/undo/redo, límite 100, idempotencia |
| `test/controllers/selection_manager_test.dart` | Window/crossing, capa bloqueada |
