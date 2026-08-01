# 🎯 Skill: cad_parsers — CAD File Parsing & Writing System

**Propósito:** Documentación del sistema de parseo y escritura DXF/DWG. Base técnica: `docs/FORMATS.md`. (v0.4.0 — parser propio, sin dependencias externas)

---

## 1. DxfParserWrapper — Parser DXF propio

**Archivo:** `lib/parsers/dxf_parser.dart`
**Propósito:** Parsea DXF ASCII **directamente por pares (código de grupo, valor)** — sin paquete externo — y devuelve `CadFile`, `CadLayer`, `CadEntity`.

### API

```dart
class DxfParserWrapper {
  ParseResult parse(String content, {String fileName = 'dibujo.dxf'});        // nunca lanza
  ParseResult parseBytes(Uint8List bytes, {String fileName = 'dibujo.dxf'});  // detecta DXF binario
}
// ParseResult { CadFile? cadFile, String? error, List<String> warnings }
```

### Flujo

1. `_readPairs(content)` → lista de `DxfPair(code, value)` (dos líneas por par)
2. `_buildFile(pairs, ...)` recorre secciones HEADER (ACADVER, INSUNITS, EXTMIN/EXTMAX), TABLES (LAYER, DIMSTYLE), BLOCKS y ENTITIES
3. Por entidad, `_parseEntity` agrupa códigos en `byCode` y mapea a `CadEntity`
4. Retornar `ParseResult(cadFile: ...)` o el error/warnings

### Entidades soportadas

| Entidad DXF | Modelo interno |
|-------------|----------------|
| LINE | CadLine |
| CIRCLE | CadCircle |
| ARC | CadArc (ángulos → radianes) |
| ELLIPSE | CadEllipse (eje mayor por 11/21, minorRatio 40, rotación) |
| LWPOLYLINE | CadLwPolyline (códigos repetidos 10/20/42, bulges) |
| POLYLINE pesada | CadPolyline (R12/LibreCAD: VERTEX + SEQEND) |
| TEXT | CadText (1=texto, 40=altura, 50=rotación, 72=halign) |
| MTEXT | CadMText (strip de códigos `\P`/`{}`) |
| INSERT | CadInsert (2=bloque, 41/42=escala, 50=rotación) |
| POINT | CadPoint |
| HATCH | CadHatch (básico, contornos 10/20) |
| SPLINE | CadSpline (puntos de control 10/20, nudos 40) |
| DIMENSION | CadDim (10/20=def, 11/21=texto, 13/23=ext1, 14/24=ext2, 42=medición, 3=estilo) |
| 3DFACE | Cad3dFace |

### DIMSTYLE y cotas (DIMENSION)

- `_parseDimStyle` lee la tabla DIMSTYLE: nombre (2), **dimtxt = 140** (altura de texto) y **dimasz = 41** (tamaño de flecha)
- `_parseEntity` para DIMENSION resuelve el estilo por el grupo **3** y rellena `CadDim.textHeight` / `CadDim.arrowSize` (override con 140/41 de la entidad si existen); la medición real viene del grupo **42**

### Normalizaciones clave

- **Color:** `62` ausente/256 = ByLayer → `color = null` (heredar). `62=0` = ByBlock.
- **Bulge:** `bulge = tan(θ/4)`; convertir a arco al renderizar y recalcular al escribir.
- **Unidades:** `$INSUNITS` → `UnitsType.fromInsUnits` (mm interno, ADR-0007).
- **Capa inexistente:** entidades se asignan a la capa `"0"` implícita.
- **INSERT con bloque inexistente:** conservar, advertir, no renderizar contenido.
- **Extrusión no ortogonal:** proyectar al plano XY con advertencia al editar.
- **Handles ausentes:** generar `h<índice hex>`.

---

## 2. DxfWriter — Escritura DXF propia

**Archivo:** `lib/parsers/dxf_writer.dart`
**Propósito:** Serializa `CadFile` a DXF ASCII. ADR-0003.

```dart
class DxfWriter {
  const DxfWriter();
  WriteResult write(CadFile file, {DxfWriteVersion version = DxfWriteVersion.r2000});
}
// WriteResult { String? content, String? error, List<String> warnings }
// enum DxfWriteVersion { r2000, r12 }
```

| Aspecto | Detalle |
|---------|---------|
| R2000 (AC1015) | Por defecto: LWPOLYLINE, SPLINE, MTEXT, HATCH |
| R12 (AC1009) | Convierte LWPOLYLINE → POLYLINE; omite/advierte SPLINE/MTEXT |
| Secciones | HEADER (mínimo), TABLES (LAYER/LTYPE/STYLE), BLOCKS, ENTITIES, EOF |
| Precisión | 6 decimales |
| Handles | Regenerar secuenciales si faltan |
| Rendimiento | Ejecutar en Isolate; `flush: true` al escribir |

---

## 3. DwgParser — Conversión DWG a DXF

**Archivo:** `lib/parsers/dwg_parser.dart`

### Estrategias (ADR-0005)

| Opción | Descripción |
|--------|-------------|
| MVP | Mensaje: "convierta a DXF" + guía |
| v0.3+ | **ODA File Converter** CLI local (gratuito, multiplataforma) |
| Futuro | Cloud (Apryse/CloudConvert) con consentimiento explícito |

### API

```dart
class DwgParser {
  const DwgParser();
  DwgInfo detect(String header);   // magic bytes AC10xx → info con guía de conversión
}
```

### MVP v1.0

Detección por magic bytes (`AC10xx`) + mensaje/guía de conversión a DXF (el ViewModel lo muestra como `error` informativo). La conversión local con **ODA File Converter** queda para v0.3+.

### Pipeline DWG (futuro, ODA)

```
DWG file → ODA File Converter (CLI: ODAFileConverter in out AC1015 1 1 1 "*.dwg")
    → DXF temporal → DxfParserWrapper.parse(dxfPath) → CadFile
    → borrar temporal
```

---

## 4. FileHelper — Detección de formato

**Archivo:** `lib/utils/file_helper.dart`

```dart
FileFormat detectFormat(String fileName, Uint8List bytes);
bool isDxf(String fileName);  bool isDwg(String fileName);  bool isDgn(String fileName);
Future<Uint8List?> readFileSafe(File file);   // try-catch + feedback (null si falla)
```

| Señal | Formato |
|-------|---------|
| Ext `.dxf` | DXF |
| Ext `.dwg` o magic bytes `AC10xx` | DWG |
| Ext `.dgn` | DGN (advertir no soportado) |
| Primer par `0\nSECTION` | DXF ASCII |
| Bytes binarios | DXF binario (advertir) |

---

## 5. Error Handling

```dart
try {
  final cadFile = await compute(DxfParserWrapper.parse, content);
} on FormatException catch (e) {
  _error = 'Archivo no válido: $e';
} on PathNotFoundException {
  _error = 'Archivo no encontrado';
} catch (e) {
  _error = 'Error inesperado: $e';
}
```

---

## 6. Checklist AI para parsers

- [ ] ¿Se parsean los 4 archivos de muestra (R12 LibreCAD, R12 AutoCAD, R2000, R2010)?
- [ ] ¿Round-trip parse→write→parse preserva el modelo?
- [ ] ¿R12 convierte LWPOLYLINE→POLYLINE al escribir?
- [ ] ¿ByLayer/ByBlock se normalizan a `color=null`?
- [ ] ¿El writer valida entidades no soportadas en R12 con advertencia?
- [ ] ¿El parseo corre en Isolate para archivos > 1 MB?
- [ ] ¿Los temporales de conversión DWG se borran?
