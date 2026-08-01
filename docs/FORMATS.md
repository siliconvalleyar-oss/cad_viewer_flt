# Formatos CAD — Referencia DXF / DWG / DGN

**Versión:** 0.3.3 · **Estado:** Aprobado (arquitectura técnica)
**Fecha:** 2026-07-31
**Propósito:** Referencia técnica de los formatos CAD que maneja la aplicación: estructura DXF, versiones, entidades con group codes, DWG, DGN y compatibilidad LibreCAD. Base para parsers y writer (ver `docs/ARCHITECTURE.md`).

## Índice

1. [Resumen de formatos](#1-resumen-de-formatos)
2. [Estructura DXF](#2-estructura-del-formato-dxf)
3. [Versiones DXF](#3-versiones-de-dxf-header-acadver)
4. [Entidades y group codes](#4-entidades-dxf-y-sus-group-codes-mapeo-interno)
5. [DWG](#5-dwg--formato-binario-propietario)
6. [DGN](#6-dgn--formato-microstation-fuera-de-alcance)
7. [LibreCAD](#7-compatibilidad-librecad-caso-de-uso-principal-de-prueba)
8. [Detección de formato](#8-detección-de-formato-file_helper)
9. [Escritura DXF](#9-estrategia-de-escritura-dxf-dxfwriter)
10. [Matriz de compatibilidad](#10-matriz-de-compatibilidad-formato--versión--operación)
11. [Archivos de muestra](#11-matriz-de-pruebas-con-archivos-de-muestra)

---

## 1. Resumen de formatos

| Formato | Tipo | Soporte v1.0 | Lectura | Escritura |
|---------|------|--------------|---------|-----------|
| **DXF ASCII** | Texto abierto | ✅ Primario | Sí (paquete `dxf` + wrapper) | Sí (`DxfWriter` propio) |
| **DXF binario** | Binario | ⚠️ Advertir | No | No |
| **DWG** | Binario propietario Autodesk | ⚠️ MVP guía / v0.3+ ODA | Sí (vía conversión) | No |
| **DGN** | Binario propietario Bentley | ❌ Fuera de alcance | No | No |

---

## 2. Estructura del formato DXF

El DXF es un formato de **texto ASCII** basado en pares **código de grupo / valor**. Cada par ocupa dos líneas: el código (entero) y el valor.

```
0            ← código 0 = tipo de sección/entidad
SECTION
2
HEADER
9
$ACADVER
1
AC1015       ← R2000
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
MyLayer      ← código 8 = capa
10
0.0          ← código 10 = X inicio
20
0.0          ← código 20 = Y inicio
11
100.0        ← código 11 = X fin
21
50.0         ← código 21 = Y fin
0
ENDSEC
0
EOF
```

### 2.1 Secciones principales

| Sección | Contenido |
|---------|-----------|
| `HEADER` | Variables del dibujo: `$ACADVER`, `$INSUNITS`, `$EXTMIN`, `$EXTMAX`, `$LIMMIN/MAX` |
| `CLASSES` | Definiciones de clases (R2000+) |
| `TABLES` | Tablas: `LAYER`, `LTYPE`, `STYLE`, `BLOCK_RECORD`, `DIMSTYLE`, `VIEW`, `UCS`, `APPID` |
| `BLOCKS` | Definiciones de bloques (`BLOCK` ... `ENDBLK`) |
| `ENTITIES` | Entidades del model space |
| `OBJECTS` | Diccionarios y objetos no gráficos (R2000+) |

### 2.2 Códigos de grupo comunes

| Código | Significado |
|--------|-------------|
| `0` | Tipo de elemento (SECTION, ENTITY, ENDSEC, EOF...) |
| `1` | Texto primario (contenido TEXT/MTEXT) |
| `2` | Nombre (bloque, estilo, capa...) |
| `5` | Handle de la entidad |
| `6` | Tipo de línea |
| `7` | Estilo de texto |
| `8` | Nombre de capa |
| `10/20/30` | X/Y/Z punto de inicio o de definición |
| `11/21/31` | X/Y/Z segundo punto (o dirección) |
| `38` | Elevación |
| `39` | Grosor (thickness) |
| `40` | Radio / altura de texto / escala |
| `41/42` | Escalas X/Y, o bulge (42 en vértice de LWPOLYLINE) |
| `43` | Ancho (MTEXT) |
| `50/51` | Ángulos (grados) |
| `62` | Color ACI (0 = ByBlock, 256 = ByLayer) |
| `67` | 1 = espacio papel, 0 = modelo |
| `70` | Flags (estado, closed...) |
| `100` | Subclass marker (R2000+) |
| `210/220/230` | Vector de extrusión |
| `330` | Handle de referencia (owner) |

> Referencia completa: especificación DXF de Autodesk (pública). El paquete `dxf` de Dart implementa un subconjunto orientado a las primitivas 2D más comunes.

---

## 3. Versiones de DXF (header `$ACADVER`)

| Código | Versión | Notas |
|--------|---------|-------|
| `AC1009` | R12 | Compatible LibreCAD; sin LWPOLYLINE (usa POLYLINE pesada), sin SPLINE nativa, sin MTEXT nativa |
| `AC1012` | R13 | Rara |
| `AC1014` | R14 | Introduce LWPOLYLINE |
| `AC1015` | R2000 | Estándar moderno; subclass markers, SPLINE, MTEXT, HATCH enriquecido |
| `AC1018` | R2004 | Compresión de objetos |
| `AC1021` | R2007 | |
| `AC1024` | R2010 | |
| `AC1027` | R2013 | |
| `AC1032` | R2018 | |

**Estrategia de la app:**
- Lectura: cualquier versión ASCII (el paquete `dxf` es tolerante).
- Escritura: **R12 (`AC1009`)** o **R2000 (`AC1015`)** — las dos más compatibles. Por defecto R2000; opción R12 para máxima compatibilidad con LibreCAD/AutoCAD antiguos.

---

## 4. Entidades DXF y sus group codes (mapeo interno)

| Entidad | Códigos clave | Modelo interno |
|---------|---------------|----------------|
| `LINE` | 10/20/30, 11/21/31 | CadLine |
| `CIRCLE` | 10/20/30 (centro), 40 (radio) | CadCircle |
| `ARC` | 10/20/30, 40, 50 (start), 51 (end) | CadArc |
| `ELLIPSE` | 10/20/30 (centro), 11/21 (eje mayor), 40 (relación ejes), 41/42 (ángulos) | CadEllipse |
| `LWPOLYLINE` | 90 (num vértices), 70 (closed), 10/20 repetidos, 42 (bulge) | CadLwPolyline |
| `POLYLINE` | 66 (verts follow), 70 (flags) + `VERTEX`/`SEQEND` | CadPolyline |
| `TEXT` | 10/20, 40 (altura), 1 (texto), 50 (rotación), 7 (estilo), 72/73 (alineación) | CadText |
| `MTEXT` | 10/20, 40, 1 (texto con códigos), 71 (attachment), 41 (ancho), 50 | CadMText |
| `INSERT` | 2 (bloque), 10/20, 41/42 (escala), 50 (rotación) | CadInsert |
| `POINT` | 10/20/30 | CadPoint |
| `HATCH` | 2 (patrón), 91 (num boundaries), paths `POLYLINE`/`EDGE` | CadHatch |
| `SPLINE` | 70 (flags), 71/72 (grados), 10/20 (control points), 40 (knots) | CadSpline |
| `DIMENSION` | 2 (bloque), 10/11/13/14 (def points), 1 (texto), 70 (tipo) | CadDim |
| `3DFACE` | 10..13/20..23/30..33 (4 esquinas) | Cad3dFace |

### 4.1 Reglas de parseo

1. **Color:** `62` ausente = ByLayer (heredar de la capa). `62=0` = ByBlock. `62=256` = ByLayer. Normalizar a `null` (heredar) en el modelo interno.
2. **LWPOLYLINE con bulge:** el bulge = `tan(θ/4)`, donde θ es el ángulo incluido del arco. Al renderizar se convierte a arcos; al escribir se recalcula.
3. **MTEXT con códigos de formato:** texto contiene secuencias `\A`, `\H`, `\f`, `{...}`. En v1.0 se extrae el texto plano (strip de códigos).
4. **Extrusión:** entidades con `210/220/230` ≠ (0,0,1) se proyectan ortogonalmente al plano XY (advertencia si el usuario intenta editarlas).
5. **Elevación `38`:** se aplica como desplazamiento en Z; ignorada en render 2D.

---

## 5. DWG — formato binario propietario

### 5.1 Características

- Formato binario cerrado de Autodesk (spec no pública; versiones `AC1015`–`AC1032` y anteriores).
- **No existe parser puro en Dart/Flutter** (confirmado en investigación, julio 2026).
- Estrategias documentadas en `docs/ADR.md` ADR-0005:
  - **MVP (v0.1–v0.2):** mensaje de no soporte + guía para convertir a DXF.
  - **v0.3+:** integración con **ODA File Converter** (CLI local, gratuito, multiplataforma) que convierte DWG → DXF; luego se parsea con el pipeline DXF.

### 5.2 ODA File Converter (referencia CLI)

| Aspecto | Detalle |
|---------|---------|
| Proveedor | Open Design Alliance (gratuito) |
| Plataformas | Windows 10+ (x64), macOS 13+ (ARM64 y x64), Linux (rpm/deb/AppImage) |
| Entrada | DWG AC9 → AC1032 (todas las versiones) |
| Salida | DXF (todas las versiones), entre otros |
| Modo | GUI y **CLI batch** (directorio origen → destino, filtros `*.dwg`, versión de salida, recursividad, flag audit) |

**Ejemplo CLI (v0.3+):**
```
ODAFileConverter <inputDir> <outputDir> <outputVersion> <outputType> <recurse> <audit> <filter>
ODAFileConverter ./in ./out AC1015 1 1 1 "*.dwg"
```

### 5.3 Servicios cloud (alternativa)

| Servicio | Notas |
|----------|-------|
| Apryse (PDFTron) | SDK corporativo de alta fidelidad (DWG/DXF/DGN) — costo |
| CloudConvert | API REST DWG→DXF |
| Online-Convert | Web simple |

> Decisión: **primero CLI local (ODA)** por privacidad (no subir planos a la nube); cloud como opción premium futura. Ver ADR-0005.

---

## 6. DGN — formato MicroStation (fuera de alcance)

- Formato binario de Bentley Systems (`DGN v7`/`v8`).
- Sin soporte en v1.0 (ADR-0008). En roadmap v2.0: evaluar conversión vía ODA o Apryse.

---

## 7. Compatibilidad LibreCAD (caso de uso principal de prueba)

| Aspecto | Detalle |
|---------|---------|
| Exportación por defecto | **DXF R12 (AC1009)** |
| Otras versiones | R14, 2000, 2004, 2007 (seleccionables en exportación) |
| Entidades típicas | LINE, CIRCLE, ARC, ELLIPSE, POINT, TEXT, POLYLINE (pesada, no LWPOLYLINE en R12), bloques y capas |
| Splines a R12 | Descompuestas en segmentos de línea / POLYLINE por LibreCAD |
| Metadatos | Sin diccionarios propietarios de AutoCAD; estructura más limpia |
| Unidades | `$INSUNITS` según configuración (frecuentemente ausente → asumir mm) |

**Implicaciones para la app:**
1. Nuestro parser **debe** soportar POLYLINE pesada (vertientes `VERTEX` + `SEQEND`) — es lo que produce LibreCAD en R12.
2. Los DXF de LibreCAD son un excelente set de prueba: en `test/files/` debe haber al menos un dibujo exportado por LibreCAD real.
3. Al escribir, R12 debe **convertir LWPOLYLINE → POLYLINE pesada** (o advertir) para máxima compatibilidad con LibreCAD.

---

## 8. Detección de formato (file_helper)

| Señal | Formato |
|-------|---------|
| Extensión `.dxf` | DXF |
| Extensión `.dwg` | DWG |
| Extensión `.dgn` | DGN (advertir no soportado) |
| Magic bytes `AC10xx` en bytes 0–5 | DWG (independiente de extensión) |
| Primer par de líneas `0\nSECTION` | DXF ASCII |
| Bytes binarios (`0x00` frecuente en primeros 64 bytes) | DXF binario (advertir) |

---

## 9. Estrategia de escritura DXF (DxfWriter)

| Aspecto | Detalle |
|---------|---------|
| Versión por defecto | R2000 (`AC1015`) |
| Opción R12 | Convierte LWPOLYLINE → POLYLINE; omite SPLINE/MTEXT (o las aproxima) con advertencia |
| Secciones emitidas | HEADER (mínimo: `$ACADVER`, `$INSUNITS`, `$EXTMIN/MAX`), TABLES (LAYER, LTYPE, STYLE mínimos), BLOCKS (si hay), ENTITIES, EOF |
| Handles | Regenerar secuenciales si el archivo no los tiene |
| Precisión | 6 decimales (suficiente para coordenadas CAD) |
| Rendimiento | Serialización en Isolate; `flush: true` al escribir |

> ✅ **Especificación detallada (v0.3.3):** group codes de salida por sección y por entidad (R12 y R2000), precisión, conversiones y contrato de round-trip en **`docs/DXF_WRITER_SPEC.md`**.

---

## 10. Matriz de compatibilidad formato × versión × operación

Leyenda: ✅ soportado · ⚠️ parcial/advertencia · ❌ no soportado · — no aplica

| Entidad | R12 leído | R12 escrito | R2000+ leído | R2000+ escrito | Render | Editar v1.0 |
|---------|:--------:|:-----------:|:------------:|:--------------:|:------:|:-----------:|
| LINE | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CIRCLE | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ARC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ELLIPSE | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| LWPOLYLINE | ⚠️ (como POLYLINE) | ⚠️ → POLYLINE | ✅ | ✅ | ✅ | ✅ |
| POLYLINE | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| TEXT | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| MTEXT | ⚠️ (no nativa R12) | ⚠️ omitida con aviso | ✅ | ✅ | ✅ | ⚠️ básico |
| INSERT | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ instancia |
| POINT | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| HATCH | ⚠️ básico | ⚠️ simplificado | ⚠️ básico | ⚠️ simplificado | ✅ | ❌ |
| SPLINE | ⚠️ (aprox. polilínea) | ⚠️ omitida con aviso | ✅ | ✅ | ✅ | ⚠️ mover |
| DIMENSION | ⚠️ | ⚠️ | ✅ | ✅ | ⚠️ básico | ⚠️ mover |
| 3DFACE | ✅ (proyección) | ✅ | ✅ | ✅ | ⚠️ proyección 2D | ❌ |
| Sólidos 3D / MESH | ⚠️ detectar y advertir | ❌ | ⚠️ detectar y advertir | ❌ | ❌ | ❌ |

**Reglas:**
1. El **escritor** nunca emite entidades que la versión destino no soporta: R12 convierte LWPOLYLINE→POLYLINE y omite SPLINE/MTEXT/HATCH complejos con `warnings`.
2. El **lector** tolera cualquier versión ASCII; las entidades fuera del catálogo se conservan con handle y se advierten (RF-ENT-16).
3. El round-trip esperado por versión está documentado en `docs/SERIALIZATION.md` §5.

---

## 11. Matriz de pruebas con archivos de muestra

| Archivo | Formato | Valida |
|---------|---------|--------|
| `sample_r12_librecad.dxf` | R12 (LibreCAD) | POLYLINE pesada, capas, textos |
| `sample_r12_autocad.dxf` | R12 | Arc, círculos, bloques R12 |
| `sample_r2000.dxf` | R2000 | LWPOLYLINE, SPLINE, MTEXT, HATCH |
| `sample_r2010.dxf` | R2010 | DIMENSION, bloques anidados |
| `sample_dwg.dwg` | DWG R2018 | Flujo ODA (v0.3+) |
| `sample_binary.dxf` | DXF binario | Advertencia correcta |
| `sample_corrupt.dxf` | — | Manejo de errores sin crash |
