# Serialización y Contratos de Datos — CAD Viewer & Editor

**Versión:** 0.3.0
**Estado:** Aprobado (arquitectura técnica)
**Equipo responsable:** Arquitecto Técnico · Data
**Propósito:** Contrato de serialización entre el modelo en memoria, los Isolates (parseo/escritura) y la persistencia. Garantiza round-trip exacto y migraciones seguras. Complementa `docs/DATA_MODEL.md`.

---

## Índice

1. [Objetivos y garantías](#1-objetivos-y-garantías)
2. [DTOs de transferencia](#2-dtos-de-transferencia)
3. [Precisión numérica](#3-precisión-numérica)
4. [Esquema de versiones (schemaVersion)](#4-esquema-de-versiones-schemaversion)
5. [Round-trip y pruebas](#5-round-trip-y-pruebas)
6. [Persistencia local](#6-persistencia-local)
7. [Contratos de Isolate](#7-contratos-de-isolate)

---

## 1. Objetivos y garantías

| Garantía | Descripción |
|----------|-------------|
| **Exactitud de round-trip** | `CadFile → JSON → CadFile` y `parse → write → parse` producen modelos equivalentes (salvo pérdida documentada de entidades no soportadas) |
| **Transferibilidad** | Todo objeto cruzando un `Isolate` debe ser serializable a JSON plano (Dart `sendable`) |
| **Migrabilidad** | `schemaVersion` permite migrar datos guardados entre versiones de la app |
| **Traza** | Pérdidas (entidades no soportadas, R12) se registran como `warnings` en el modelo, no silenciosamente |

**Regla de oro:** los objetos de dominio (`CadEntity`, `CadLayer`, ...) **no** se pasan a Isolates directamente; se pasa su DTO JSON. Los DTOs viven en `lib/models/dto/`.

---

## 2. DTOs de transferencia

### 2.1 CadFileJson

```json
{
  "schemaVersion": 1,
  "fileName": "plano.dxf",
  "format": "dxf",
  "version": "AC1015",
  "header": {
    "units": "mm",
    "insUnits": 4,
    "extMin": [0.0, 0.0, 0.0],
    "extMax": [10000.0, 7000.0, 0.0],
    "baseAngle": 0.0
  },
  "layers": [ { "name": "MUROS", "aci": 1, "lineType": "Continuous",
                "lineWeight": 0.5, "visible": true, "locked": false,
                "frozen": false } ],
  "entities": [ CadEntityJson... ],
  "blocks": [ { "name": "PUERTA", "basePoint": [0,0,0], "entities": [...] } ],
  "warnings": [ "2 entidades desconocidas omitidas" ]
}
```

### 2.2 CadEntityJson (polimórfico)

Cada tipo serializa `type` + campos propios + campos comunes:

```json
{
  "type": "line",
  "handle": "1A2B",
  "layer": "MUROS",
  "color": null,
  "lineType": null,
  "lineWeight": null,
  "x1": 0.0, "y1": 0.0, "x2": 100.0, "y2": 50.0
}
```

| type | Campos |
|------|--------|
| `line` | x1,y1,x2,y2 |
| `circle` | cx,cy,radius |
| `arc` | cx,cy,radius,startAngle,endAngle (rad) |
| `ellipse` | cx,cy,majorRadius,minorRadius,rotation |
| `lwPolyline` | points:[[x,y,startWidth,endWidth,bulge]], closed |
| `polyline` | points:[[x,y,z]], closed |
| `text` | text,x,y,height,rotation,style,horizontalAlign |
| `mtext` | text,x,y,height,rotation,attachmentPoint,width |
| `insert` | blockName,x,y,scaleX,scaleY,rotation |
| `point` | x,y |
| `hatch` | patternName,scale,rotation,boundaries |
| `spline` | degree,controlPoints:[[x,y,z]],knots:[...],fitPoints |
| `dim` | dimType,x1,y1,x2,y2,x3,y3,text,style |
| `3dFace` | corners:[[x,y,z]×4] |

**Ser/deser:** `fromJson`/`toJson` por subtipo, centralizadas en `cad_entity_json.dart`. Campos desconocidos se ignoran con warning (forward-compatibility).

---

## 3. Precisión numérica

| Tipo | Precisión interna | Serialización |
|------|-------------------|---------------|
| Coordenadas | `double` (Dart, IEEE-754) | 6 decimales (redondeo half-even) |
| Ángulos | `double` en **radianes** | 8 decimales (evitar drift en round-trip) |
| Bulges | `double` | 6 decimales |
| Grosor/radio | `double` | 4 decimales |

**Regla:** al escribir DXF (DxfWriter) se usan 6 decimales para coordenadas (FORMATS.md §9). Al serializar JSON para Isolate se usan las mismas precisiones para que `parse→write→parse` sea estable.

> Los ángulos en JSON/Isolates siempre en radianes; la conversión a grados ocurre solo en la frontera DXF (group codes 50/51).

---

## 4. Esquema de versiones (schemaVersion)

- `schemaVersion` = versión del contrato JSON (entero, actual: **1**).
- Reglas:
  1. Cambio **aditivo** (nuevo campo opcional): mismo `schemaVersion`, campo con default.
  2. Cambio **rupturista** (renombrado, eliminado, semántica nueva): `schemaVersion++` + migrador `migrate(json, from, to)`.
  3. Los migradores viven en `lib/models/dto/migrations.dart` y se prueban con fixtures.
- La app rechaza JSON con `schemaVersion > actual` (más nuevo que la app) con mensaje "actualiza la app".

---

## 5. Round-trip y pruebas

### 5.1 Matriz de round-trip

| Ruta | Garantía |
|------|----------|
| DXF R12 → parse → CadFile → JSON → CadFile | Igualdad de modelo |
| CadFile → DxfWriter R2000 → parse | Igualdad salvo warnings documentados (handles regenerados, MTEXT strip) |
| CadFile → DxfWriter R12 → parse | POLYLINE convertida a LWPOLYLINE al releer (esperado); SPLINE/MTEXT perdidas con warning |
| JSON → Isolate → JSON | Byte-identical (precisiones fijas) |

### 5.2 Tests

`test/models/serialization_test.dart`:
- Cada tipo: `toJson → fromJson` = original (deep equality).
- Precisión: coordenadas 6 decimales, ángulos 8.
- Migración: fixture v1 → v2 (cuando exista).
- Round-trip con los archivos de `test/files/`.
- Warning: entidades desconocidas registradas en `CadFile.warnings`.

---

## 6. Persistencia local

### 6.1 Claves de shared_preferences (canonical)

| Clave | Tipo | Contenido |
|-------|------|-----------|
| `recent_files.v1` | `List<String>` | Últimos 10 paths (nunca contenido) |
| `recent_thumbnails.v1` | `List<String>` | Miniaturas base64 (≤ 100 KB c/u) |
| `settings.theme.v1` | `String` | `AppThemeMode.name` |
| `settings.units.v1` | `String` | `UnitsType.name` |
| `settings.snap.v1` | `String` | JSON de `SnapSettings` |
| `settings.grid.v1` | `String` | JSON de grid config |
| `session.last_file.v1` | `String?` | Último archivo (para restaurar) |
| `session.autosave.v1` | `String?` | Path del autosave (si existe) |

- Prefijo `.v1` = versionado de clave. Nueva versión = clave nueva (sin migración destructiva).
- Nunca almacenar contenido de planos (SECURITY.md §5).

### 6.2 Autosave (formato de archivo)

```
<nombre>.autosave.json
{
  "schemaVersion": 1,
  "savedAt": "2026-07-31T12:00:00Z",
  "sourcePath": "/ruta/original.dxf",
  "cadFile": { CadFileJson },
  "viewState": { "scale": 1.25, "offset": [10,20], "selectedHandles": ["1A2B"] }
}
```

- Se escribe cada 5 min si `dirty` (EDITING.md §10.2).
- Al abrir: si autosave existe y es más reciente que el archivo fuente → preguntar restaurar.
- Se elimina al guardar manualmente correctamente.

---

## 7. Contratos de Isolate

### 7.1 Parseo

```
Entrada (sendable):  { "content": "<dxf string>", "fileName": "x.dxf" }
Salida (sendable):   { "cadFileJson": {...}, "error": null | "msg" }
```

- Uso: `compute(_parseWorker, payload)` con `_parseWorker` top-level (requisito de `compute`).
- El DXF crudo viaja como String (transferencia eficiente); el resultado como `CadFileJson`.

### 7.2 Escritura

```
Entrada (sendable):  { "cadFileJson": {...}, "version": "r2000" | "r12" }
Salida (sendable):   { "content": "<dxf string>", "warnings": ["..."] }
```

### 7.3 Errores

- Los Isolates **nunca lanzan**: siempre retornan `{ error }` que la UI traduce a mensajes de usuario (ERROR_HANDLING.md).
- Timeout de escritura/parseo: 60 s; el usuario puede cancelar (aislado vía `Isolate.kill` con port).

---

## Checklist de serialización

- [ ] Todo objeto que cruza un Isolate es DTO JSON (schemaVersion)
- [ ] Precisiones fijas (6/8/4 decimales) y probadas
- [ ] Migradores con fixtures y rechazo de schemaVersion futuro
- [ ] Round-trip probado con los archivos de muestra
- [ ] Claves de prefs versionadas con `.v1`
- [ ] Autosave con schemaVersion + viewState
- [ ] Sin contenido de planos en prefs
- [ ] Isolates no lanzan (contrato `{error}`)
