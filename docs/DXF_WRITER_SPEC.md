# Especificación del Escritor DXF (DxfWriter) — Group Codes de Salida

**Versión:** 0.3.3 · **Estado:** Aprobado (arquitectura técnica)
**Fecha:** 2026-07-31
**Equipo responsable:** Arquitecto Técnico · Data
**Propósito:** Especificación normativa del `DxfWriter` (`lib/parsers/dxf_writer.dart`): group codes exactos de salida para **R12 (`AC1009`)** y **R2000 (`AC1015`)**, por sección y por entidad, con convenciones de precisión, conversiones y contrato de round-trip. Complementa `docs/FORMATS.md` §9 y §4.

---

## Índice

1. [Objetivo y garantías](#1-objetivo-y-garantías)
2. [Estructura general de salida](#2-estructura-general-de-salida)
3. [Convenciones globales](#3-convenciones-globales)
4. [Sección HEADER](#4-sección-header)
5. [Sección TABLES](#5-sección-tables)
6. [Sección BLOCKS](#6-sección-blocks)
7. [Sección ENTITIES — group codes por entidad](#7-sección-entities--group-codes-por-entidad)
8. [Diferencias R12 vs R2000](#8-diferencias-r12-vs-r2000)
9. [Warnings y pérdidas documentadas](#9-warnings-y-pérdidas-documentadas)
10. [Ejemplos completos de salida](#10-ejemplos-completos-de-salida)
11. [Round-trip y pruebas](#11-round-trip-y-pruebas)
12. [Checklist del escritor](#12-checklist-del-escritor)

---

## 1. Objetivo y garantías

| Garantía | Descripción |
|----------|-------------|
| **Round-trip** | `parse → write → parse` produce un modelo equivalente (salvo pérdidas documentadas en §9) |
| **Compatibilidad** | R2000 = formato moderno estándar; R12 = máxima compatibilidad con LibreCAD/AutoCAD antiguos |
| **Determinismo** | El mismo `CadFile` produce siempre el mismo String (orden estable, precisión fija) |
| **No destructivo** | El escritor nunca emite entidades que la versión destino no soporta: convierte u omite con `warnings` (FORMATS.md §10 regla 1) |
| **Eficiencia** | Serialización en Isolate (SERIALIZATION.md §7.2); `flush: true` al escribir archivo |

**Regla de oro:** el escritor recibe un `CadFile` (o `CadDocument.exportCadFile()`) **limpio** — nunca emite estado de sesión (`displayColor`, `isCurrent`, selección, dirty).

---

## 2. Estructura general de salida

Orden fijo de secciones (FORMATS.md §9):

```
0\nSECTION\n2\nHEADER        → §4
0\nENDSEC
0\nSECTION\n2\nTABLES         → §5 (LAYER, LTYPE, STYLE)
0\nENDSEC
0\nSECTION\n2\nBLOCKS         → §6 (*Model_Space + bloques del modelo)
0\nENDSEC
0\nSECTION\n2\nENTITIES       → §7 (todas las entidades de model space)
0\nENDSEC
0\nEOF
```

- **Encoding:** ASCII/UTF-8 sin BOM. Fin de línea `\n` (LF).
- **API:** `write(CadFile, {version = R2000}) → String` · `writeToFile(CadFile, path, {version}) → Future<void>`.
- **Isolate:** el String completo se construye en el worker; la UI solo recibe `{content, warnings}`.

---

## 3. Convenciones globales

### 3.1 Precisión numérica (SERIALIZATION.md §3)

| Tipo | Decimales | Ejemplo de salida |
|------|-----------|-------------------|
| Coordenadas (`10/20/30`…) | 6 | `10\n12.500000` |
| Ángulos en grados (`50/51`, TEXT, ARC, DIMENSION) | 8 (rad→deg) | `50\n45.00000000` |
| Ángulos en radianes (ELLIPSE `41/42`) | 8 | `41\n0.00000000` |
| Bulge (`42` en vértice) | 6 | `42\n0.414200` |
| Radio / altura / grosor (`40`…) | 4 | `40\n2.5000` |
| Grosor de línea (`370`, centésimas de mm) | entero | `370\n50` (0.5 mm) |

- Formato numérico: punto decimal, **sin notación científica**, sin `+` explícito, ceros finales según precisión.
- `-0.000000` se normaliza a `0.000000`.

### 3.2 Capa, color y line type

| Campo del modelo | Emisión | Regla |
|------------------|---------|-------|
| `entity.layer` | `8` | Siempre. Si la capa no existe en `layers`, se crea implícitamente como `"0"` (DATA_MODEL §11) |
| `entity.color == null` | — | **Se omite `62`** (ByLayer) |
| `entity.color == 0` | `62\n0` | ByBlock |
| `entity.color == 256` | — | Normalizado a `null` al parsear; se omite (ByLayer) |
| `entity.color` 1–255 | `62\n<n>` | Override ACI |
| `entity.lineType == null` | — | Se omite `6` |
| `entity.lineType` | `6\n<nombre>` | Override |
| `entity.lineWeight` | `370\n<centésimas>` | mm → centésimas (redondeo); **cap a 211** (rango DXF 0–211); omitir si `null` |

### 3.3 Handles

- Si el modelo trae handles únicos (hex), se reutilizan (`5\n<handle>`).
- Si faltan o están duplicados: **regenerar secuenciales** `1, 2, 3…` en hexadecimal (`1`, `2`, `A`, `10`…), asignados en orden de emisión (FORMATS.md §9).
- R12: los handles **no se emiten** (formato R12 no los usa en las entidades).
- La capa `"0"` **siempre se emite primero** en la tabla LAYER.

### 3.4 Ángulos

- Internamente el modelo almacena ángulos en **radianes**; el DXF exige grados en `50/51` (ARC, TEXT, DIMENSION) → conversión `deg = rad × 180/π`.
- Excepción: ELLIPSE usa radianes en `41/42` (spec DXF) → se emite tal cual.

---

## 4. Sección HEADER

Emisión mínima (siempre, en este orden):

| Group code | Valor R2000 | Valor R12 | Notas |
|-----------|-------------|-----------|-------|
| `9` + `1` | `$ACADVER` / `AC1015` | `$ACADVER` / `AC1009` | Obligatorio |
| `9` + `70` | `$INSUNITS` / `insUnits` | `$INSUNITS` / `insUnits` | Del `CadHeader`; si `0`/ausente → `4` (mm) |
| `9` + `10/20/30` | `$EXTMIN` | `$EXTMIN` | De `header.extMin`; si ausente, calculado de `getBounds()` |
| `9` + `10/20/30` | `$EXTMAX` | `$EXTMAX` | Idem |

Ejemplo (R2000):

```
0
SECTION
2
HEADER
9
$ACADVER
1
AC1015
9
$INSUNITS
70
4
9
$EXTMIN
10
0.000000
20
0.000000
30
0.000000
9
$EXTMAX
10
100.000000
20
60.000000
30
0.000000
0
ENDSEC
```

> R12: `$EXTMIN/MAX` pueden emitirse en 2D (solo `10/20`, como hacen los fixtures de `test/files/`); se emiten 3D (con `30`) por coherencia con el resto de secciones, que usan coordenadas 3D — tolerado por LibreCAD/AutoCAD.
> Nota: `$INSUNITS` es formalmente R13+, pero LibreCAD lo escribe en R12 (FORMATS.md §7); se emite en ambas versiones.

---

## 5. Sección TABLES

Se emiten 3 tablas mínimas, en orden: **LAYER**, **LTYPE**, **STYLE**.

### 5.1 Tabla LAYER

Cabecera de tabla:

```
0
TABLE
2
LAYER
70
<count>
```

Cada capa (la `"0"` primero):

| Group code | R2000 | R12 | Notas |
|-----------|-------|-----|-------|
| `0` | `LAYER` | `LAYER` | |
| `5` | handle | — | Solo R2000 |
| `100` | `AcDbSymbolTableRecord` | — | Solo R2000 |
| `100` | `AcDbLayerTableRecord` | — | Solo R2000 |
| `2` | nombre | nombre | |
| `70` | `0` | `0` | v1.0 emite 0; frozen/locked son de sesión y no se persisten (DATA_MODEL §11.5) |
| `62` | ACI | ACI | `7` = blanco |
| `6` | `CONTINUOUS` | `CONTINUOUS` | |

```
0
ENDTAB
```

### 5.2 Tabla LTYPE

Mínimo: registro `CONTINUOUS`.

| Group code | R2000 | R12 |
|-----------|-------|-----|
| `0` | `LTYPE` | `LTYPE` |
| `5` + `100`×2 (subclass) | Sí | — |
| `2` | `CONTINUOUS` | `CONTINUOUS` |
| `70` | `0` | `0` |
| `3` | `Solid line` | `Solid line` |
| `72` | `65` | `65` |
| `73` | `0` | `0` |
| `40` | `0.0000` | `0.0000` |

### 5.3 Tabla STYLE

Mínimo: registro `Standard`.

| Group code | R2000 | R12 |
|-----------|-------|-----|
| `0` | `STYLE` | `STYLE` |
| `5` + `100`×2 | Sí | — |
| `2` | `Standard` | `Standard` |
| `70` | `0` | `0` |
| `40` | `0.0000` | `0.0000` |
| `41` | `1.0000` | `1.0000` |
| `50` | `0.00000000` | `0.00000000` |
| `71` | `0` | `0` |
| `42` | `2.5000` | `2.5000` |
| `3` | `txt` | `txt` |
| `4` | *(vacío)* | *(vacío)* |

---

## 6. Sección BLOCKS

1. **`*Model_Space`** — bloque interno requerido por AutoCAD/LibreCAD. Se emite vacío (las entidades del model space viven en ENTITIES).

2. **Bloques del modelo** (`CadFile.blocks`) — cada `CadBlock`:

| Group code | R2000 | R12 |
|-----------|-------|-----|
| `0` | `BLOCK` | `BLOCK` |
| `8` | `0` | `0` |
| `2` | nombre | nombre |
| `70` | `0` | `0` |
| `10/20/30` | basePoint | basePoint |
| `3` | nombre (rep.) | nombre (rep.) |
| `1` | *(vacío)* | *(vacío)* |
| … | entidades internas (formato §7) | idem |
| `0` | `ENDBLK` | `ENDBLK` |
| `8` | `0` | — *(R12 no emite la capa tras ENDBLK)* |

> Los bloques se emiten en el orden del modelo. Los bloques **anónimos** (`*D*` de DIMENSION) se regeneran en orden de aparición de las dimensiones (`*D1`, `*D2`…).

---

## 7. Sección ENTITIES — group codes por entidad

Convención de columnas: **R2000** = secuencia con subclass markers; **R12** = secuencia sin subclass markers. La columna *Subclass R2000* indica el `100\nAcDbXxx` propio de cada entidad (tras el común `AcDbEntity`).

**Base común (R2000):**
```
0\n<TYPE>
5\n<handle>
100\nAcDbEntity
8\n<layer>
[62\n<aci>] [6\n<linetype>] [370\n<weight>]
100\n<AcDbXxx>
```

**Base común (R12):**
```
0\n<TYPE>
8\n<layer>
[62\n<aci>] [6\n<linetype>]
```

### 7.1 `CadLine` (x1,y1,x2,y2) — Subclass `AcDbLine`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Inicio | `10/20/30` | `10/20` (30 opcional) |
| Fin | `11/21/31` | `11/21` (31 opcional) |

### 7.2 `CadCircle` (cx,cy,radius) — Subclass `AcDbCircle`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Centro | `10/20/30` | `10/20` |
| Radio | `40` | `40` |

### 7.3 `CadArc` (cx,cy,radius,startAngle,endAngle rad) — Subclass `AcDbCircle`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Centro | `10/20/30` | `10/20` |
| Radio | `40` | `40` |
| Ángulo inicial | `50` (deg, 8 dec) | `50` |
| Ángulo final | `51` (deg, 8 dec) | `51` |

### 7.4 `CadEllipse` (cx,cy,majorRadius,minorRadius,rotation) — Subclass `AcDbEllipse`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Centro | `10/20/30` | `10/20/30` |
| Extremo del eje mayor | `11/21/31` = `majorRadius·cos(rot)`, `majorRadius·sin(rot)`, 0 | idem |
| Extrusión | `210/220/230` = `0,0,1` | — (omitir; R12) |
| Relación menor/mayor | `40` = `minorRadius/majorRadius` | `40` |
| Ángulo inicial | `41` (rad, 8 dec) = `0.0` | `41` |
| Ángulo final | `42` (rad) = `2π` (elipse completa) | `42` |

> Nota: ELLIPSE es formalmente R13+; se emite igualmente en R12 (tolerado por nuestro lector; visores R12 estrictos pueden ignorarla). Matriz FORMATS §10: ✅.

### 7.5 `CadLwPolyline` (points, closed, bulge) — Subclass `AcDbPolyline`

**R2000:**
```
0\nLWPOLYLINE
5\n<handle>
100\nAcDbEntity
8\n<layer>
100\nAcDbPolyline
90\n<n vértices>
70\n<1|0>          ← 1 cerrada, 0 abierta
10\n<x0> 20\n<y0>
10\n<x1> 20\n<y1> [42\n<bulge1>]   ← bulge del segmento 1→2
… (por vértice)
```

- `42` bulge: 6 decimales; **se omite** si el vértice no tiene bulge (o si `0.0`).
- `70`: `closed ? 1 : 0` (LWPOLYLINE usa bit 0 = cerrada).

**R12 — conversión a POLYLINE pesada** (obligatoria, warning W-001):
```
0\nPOLYLINE
8\n<layer>
66\n1              ← "vertices follow"
70\n<closed?1:0>
0\nVERTEX
8\n<layer>
10\n<x> 20\n<y> [30\n<z>] [42\n<bulge>]
0\nVERTEX
…
0\nSEQEND
8\n<layer>
```

### 7.6 `CadPolyline` (points 3D, closed) — Subclass `AcDbPolyline` (R2000) / pesada (R12)

Ambas versiones usan **POLYLINE pesada** (mismo esquema que §7.5 R12, con `VERTEX`/`SEQEND`).

- R2000: añadir subclass markers `100 AcDbEntity` en POLYLINE y en cada VERTEX; `70` bit 0 = cerrada; VERTEX con `100 AcDbVertex` + `100 AcDb2dVertex`.
- R12: sin subclass markers.

### 7.7 `CadText` (text,x,y,height,rotation,style,horizontalAlign) — Subclass `AcDbText`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Inserción | `10/20/30` | `10/20` |
| Altura | `40` (4 dec) | `40` |
| Texto | `1` | `1` |
| Rotación | `50` (deg, 8 dec) | `50` |
| Estilo | `7` (solo si `style != null` y ≠ `Standard`) | `7` |
| Alineación H | `72` (solo si ≠ 0) | `72` |
| Punto de alineación | `11/21` (solo si alineado) | `11/21` |

### 7.8 `CadMText` (text,x,y,height,rotation,attachmentPoint,width) — Subclass `AcDbMText`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Inserción | `10/20/30` | — |
| Altura | `40` | — |
| Ancho | `41` | — |
| Attachment | `71` | — |
| Dirección | `72` = `5` (left-to-right) | — |
| Texto | `1` (texto plano tras strip de códigos) | — |
| Rotación | `50` | — |

**R12:** **omitida con warning W-002** (no nativa R12; FORMATS §10 ⚠️).

### 7.9 `CadInsert` (blockName,x,y,scaleX,scaleY,rotation) — Subclass `AcDbBlockReference`

| Campo | R2000 | R12 |
|-------|-------|-----|
| Bloque | `2` | `2` |
| Inserción | `10/20/30` | `10/20` |
| Escala X | `41` | `41` |
| Escala Y | `42` | `42` |
| Escala Z | `43` = `1.0` | `43` |
| Rotación | `50` (deg) | `50` |

> Si `blockName` no existe en `blocks`: se emite igualmente y se conserva warning de parseo al releer (DATA_MODEL §11.3).

### 7.10 `CadPoint` (x,y) — Subclass `AcDbPoint`

`10/20/30` (R2000) · `10/20` (R12).

### 7.11 `CadHatch` (patternName,boundaries,scale,rotation) — Subclass `AcDbHatch`

**R2000:**
```
0\nHATCH
5\n<handle>
100\nAcDbEntity
8\n<layer>
100\nAcDbHatch
10/20/30\n0,0,0
210/220/230\n0,0,1
2\n<patternName>
70\n<0=patrón|1=sólido>
71\n0
91\n<n boundaries>
92\n7                    ← path type: external|polyline|derived
72\n<closed?1:0>
73\n<n vértices>
10/20 … (por vértice)
97\n0
75\n1
76\n1
52\n<rotation deg>
41\n<scale>
98\n0
```

**R12:** **omitida con warning W-004** (no nativa R12; la simplificación de FORMATS §10 ⚠️ queda como mejora futura, v1.0 omite con aviso).

### 7.12 `CadSpline` (degree,controlPoints,knots,fitPoints) — Subclass `AcDbSpline`

**R2000:**
```
0\nSPLINE
5\n<handle>
100\nAcDbEntity
8\n<layer>
100\nAcDbSpline
70\n8              ← planar
71\n<degree>
72\n<n knots>
73\n<n control points>
40\n<knot 0> … (repetido por knot)
10/20/30\n<cp 0> … (repetido por control point)
```

**R12:** **omitida con warning W-003** (LibreCAD la descompone en polilínea; v1.0 omite con aviso — FORMATS §10 ⚠️).

### 7.13 `CadDim` (dimType,x1..y3,text,style) — Subclass `AcDbDimension` + variante

**R2000:**
```
0\nDIMENSION
5\n<handle>
100\nAcDbEntity
8\n<layer>
100\nAcDbDimension
2\n*D<n>               ← bloque anónimo regenerado
10/20/30\n<punto def 1>
11/21/31\n<punto medio texto>
70\n<dimType | 32>     ← bit 32 = block reference
1\n<texto>            (vacío = medida automática)
71\n5
42\n<medida real>
100\n<AcDbAlignedDimension | AcDbRotatedDimension | …>  ← según dimType
13/23/33\n<def 3>
14/24/34\n<def 4>
```

- El bloque anónimo `*D<n>` con la geometría gráfica de la dimensión se emite en BLOCKS (§6).
- **R12:** se emite sin subclass markers (`70` = dimType, bit 32 según soporte); soporte básico (⚠️ FORMATS §10).

### 7.14 `Cad3dFace` (corners 4) — Subclass `AcDbFace`

| Esquina | R2000 | R12 |
|---------|-------|-----|
| 1 | `10/20/30` | `10/20/30` |
| 2 | `11/21/31` | `11/21/31` |
| 3 | `12/22/32` | `12/22/32` |
| 4 | `13/23/33` | `13/23/33` |

---

## 8. Diferencias R12 vs R2000

| Aspecto | R12 (`AC1009`) | R2000 (`AC1015`) |
|---------|----------------|------------------|
| `$ACADVER` | `AC1009` | `AC1015` |
| Subclass markers `100` | ❌ | ✅ (`AcDbEntity` + subtipo) |
| Handles `5` | ❌ | ✅ (regenerados si faltan) |
| `LWPOLYLINE` | ❌ → **POLYLINE pesada** (W-001) | ✅ nativa |
| `MTEXT` | ❌ omitida (W-002) | ✅ |
| `SPLINE` | ❌ omitida (W-003) | ✅ |
| `HATCH` | ❌ omitida (W-004) | ✅ |
| `ELLIPSE` | ✅ (no nativa, tolerada) | ✅ |
| `ENDBLK` con `8/0` | ❌ | ✅ |
| `$EXTMIN/MAX` 3D | ✅ (tolerado) | ✅ |
| `370` line weight | ❌ (omitir) | ✅ |

---

## 9. Warnings y pérdidas documentadas

El escritor **nunca falla silenciosamente**: devuelve `warnings` (contrato Isolate §7.2 de SERIALIZATION.md). Catálogo:

| Código | Condición | Acción |
|--------|-----------|--------|
| `W-001` | LWPOLYLINE → versión R12 | Convertida a POLYLINE pesada |
| `W-002` | MTEXT → versión R12 | Entidad omitida |
| `W-003` | SPLINE → versión R12 | Entidad omitida |
| `W-004` | HATCH → versión R12 | Entidad omitida |
| `W-005` | Entidad fuera del catálogo | Conservada con handle + warning (RF-ENT-16). *Aplicable solo si el modelo incorpora un tipo `CadUnknownEntity`; hoy el parser descarta las desconocidas, así que el writer nunca las recibe (especulativo)* |
| `W-006` | Capa de entidad inexistente | Entidad reasignada a `"0"` |

**Pérdidas esperadas en round-trip R12** (SERIALIZATION.md §5.1): SPLINE/MTEXT/HATCH perdidas con warning; POLYLINE pesada releída como LWPOLYLINE (esperado); handles regenerados.

---

## 10. Ejemplos completos de salida

### 10.1 R2000 — LINE + CIRCLE + LWPOLYLINE (cerrada, bulge)

```
0
SECTION
2
HEADER
9
$ACADVER
1
AC1015
9
$INSUNITS
70
4
9
$EXTMIN
10
0.000000
20
0.000000
30
0.000000
9
$EXTMAX
10
100.000000
20
60.000000
30
0.000000
0
ENDSEC
0
SECTION
2
TABLES
0
TABLE
2
LAYER
70
1
0
LAYER
5
1
100
AcDbSymbolTableRecord
100
AcDbLayerTableRecord
2
0
70
0
62
7
6
CONTINUOUS
0
ENDTAB
0
TABLE
2
LTYPE
70
1
0
LTYPE
5
2
100
AcDbSymbolTableRecord
100
AcDbLinetypeTableRecord
2
CONTINUOUS
70
0
3
Solid line
72
65
73
0
40
0.0000
0
ENDTAB
0
TABLE
2
STYLE
70
1
0
STYLE
5
3
100
AcDbSymbolTableRecord
100
AcDbTextStyleTableRecord
2
Standard
70
0
40
0.0000
41
1.0000
50
0.00000000
71
0
42
2.5000
3
txt
4

0
ENDTAB
0
ENDSEC
0
SECTION
2
BLOCKS
0
BLOCK
8
0
2
*Model_Space
70
0
10
0.000000
20
0.000000
30
0.000000
3
*Model_Space
1

0
ENDBLK
8
0
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
5
4
100
AcDbEntity
8
0
100
AcDbLine
10
0.000000
20
0.000000
30
0.000000
11
100.000000
21
0.000000
31
0.000000
0
CIRCLE
5
5
100
AcDbEntity
8
0
100
AcDbCircle
10
50.000000
20
30.000000
30
0.000000
40
10.0000
0
LWPOLYLINE
5
6
100
AcDbEntity
8
0
100
AcDbPolyline
90
4
70
1
10
0.000000
20
0.000000
10
20.000000
20
0.000000
42
0.414200
10
20.000000
20
15.000000
10
0.000000
20
15.000000
0
ENDSEC
0
EOF
```

### 10.2 R12 — misma LWPOLYLINE convertida a POLYLINE pesada

```
0
SECTION
2
HEADER
9
$ACADVER
1
AC1009
9
$INSUNITS
70
4
0
ENDSEC
0
SECTION
2
TABLES
0
TABLE
2
LAYER
70
1
0
LAYER
2
0
70
0
62
7
6
CONTINUOUS
0
ENDTAB
0
ENDSEC
0
SECTION
2
BLOCKS
0
BLOCK
8
0
2
*Model_Space
70
0
10
0.0
20
0.0
30
0.0
3
*Model_Space
0
ENDBLK
0
ENDSEC
0
SECTION
2
ENTITIES
0
POLYLINE
8
0
66
1
70
1
0
VERTEX
8
0
10
0.0
20
0.0
0
VERTEX
8
0
10
20.0
20
0.0
42
0.4142
0
VERTEX
8
0
10
20.0
20
15.0
0
VERTEX
8
0
10
0.0
20
15.0
0
SEQEND
8
0
0
ENDSEC
0
EOF
```

> El R12 usa las mismas convenciones de los fixtures de `test/files/` (`sample_r12_*.dxf`).
>
> **Nota sobre fixtures vs spec:** los fixtures sintéticos de `test/files/` se escribieron **mínimos** (sin tabla STYLE, LAYER sin subclass markers en R12); el writer emite siempre la tabla STYLE (`Standard`) y subclass markers en R2000, según FORMATS.md §9. Al comparar salida del writer con un fixture, esperar esas secciones adicionales.

---

## 11. Round-trip y pruebas

### 11.1 Matriz de round-trip (SERIALIZATION.md §5.1)

| Ruta | Garantía |
|------|----------|
| `CadFile → write R2000 → parse` | Igualdad salvo handles regenerados y MTEXT strip |
| `CadFile → write R12 → parse` | POLYLINE releída como LWPOLYLINE (esperado); SPLINE/MTEXT/HATCH perdidas con warning |
| Mismo modelo → 2 escrituras | String idéntico (determinismo) |

### 11.2 Casos de `dxf_writer_test.dart` (TESTING.md §3.2)

| Caso | Archivo de muestra |
|------|--------------------|
| Round-trip R2000 (parse→write→parse = mismo modelo) | `test/files/sample_r2000.dxf` |
| Round-trip R12 | `test/files/sample_r12_librecad.dxf` |
| R12 convierte LWPOLYLINE→POLYLINE (W-001) | `sample_r2000.dxf` guardado como R12 |
| R12 omite SPLINE/MTEXT/HATCH (W-002/3/4) | `sample_r2000.dxf` → R12 |
| Precisión 6 decimales en coordenadas | cualquier fixture |
| ByLayer (sin `62`) vs override (`62`) | `sample_selection.dxf` |
| Handles regenerados si ausentes | modelo sintético |
| `$INSUNITS` se conserva | `sample_units_inch.dxf` (1 = inch) |

### 11.3 Verificación con tool/benchmark.dart

`tool/benchmark.dart` (TESTING.md §6) mide escritura sobre los 6+ fixtures y verifica determinismo.

---

## 12. Checklist del escritor

- [ ] Orden fijo de secciones: HEADER → TABLES → BLOCKS → ENTITIES → EOF
- [ ] Precisión 6/8/8/6/4 según tabla §3.1; sin notación científica
- [ ] Capa `"0"` primera; entidad con capa inexistente → `"0"` + W-006
- [ ] Color: `null`→omite `62`; 0→ByBlock; 256→omite (ByLayer)
- [ ] Handles: reutilizar o regenerar secuenciales (solo R2000)
- [ ] R12: LWPOLYLINE→POLYLINE (W-001); MTEXT/SPLINE/HATCH omitidas (W-002/3/4)
- [ ] R12: sin subclass markers, sin handles, `ENDBLK` sin `8/0`
- [ ] Ángulos: rad→deg en `50/51`; radianes en ELLIPSE `41/42`
- [ ] `exportCadFile()` limpio: sin estado de sesión
- [ ] Isolate: retorna `{content, warnings}`, nunca lanza
- [ ] Tests: §11.2 en verde; determinismo verificado
