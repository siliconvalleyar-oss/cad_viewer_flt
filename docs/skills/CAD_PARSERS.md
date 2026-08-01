# 🎯 Skill: cad_parsers — CAD File Parsing & Writing System

**Propósito:** Documentación del sistema de parseo y escritura DXF/DWG. Base técnica: `docs/FORMATS.md`.

---

## 1. DxfParserWrapper — Wrapper del paquete dxf

**Archivo:** `lib/parsers/dxf_parser.dart`
**Propósito:** Convierte la salida del paquete `dxf ^1.3.0` a modelos internos `CadFile`, `CadLayer`, `CadEntity`

### API

```dart
class DxfParserWrapper {
  static CadFile parse(String content, {String fileName = ''});        // correr en Isolate
  static Future<CadFile> parseFile(String path);
  static CadFile fromDxfDocument(dxf.Document doc, {String fileName = ''});
}
```

### Flujo

1. Usar `dxf.Document.fromString(content)` del paquete `dxf`
2. Recorrer `doc.layers` → `CadLayer`
3. Recorrer `doc.entities` → mapear a `CadEntity` por tipo
4. Recorrer `doc.blocks` → `CadBlock`
5. Retornar `CadFile`

### Entidades mapeadas

| Tipo dxf package | Modelo interno |
|------------------|----------------|
| dxf.Line | CadLine |
| dxf.Circle | CadCircle |
| dxf.Arc | CadArc |
| dxf.Ellipse | CadEllipse |
| dxf.LwPolyline | CadLwPolyline |
| dxf.Polyline | CadPolyline (pesada, R12/LibreCAD: VERTEX + SEQEND) |
| dxf.Text | CadText |
| dxf.MText | CadMText (strip de códigos de formato) |
| dxf.Insert | CadInsert |
| dxf.Point | CadPoint |
| dxf.Hatch | CadHatch (básico) |
| dxf.Spline | CadSpline |
| dxf.Dimension | CadDim |
| dxf.Face3d | Cad3dFace |

### Normalizaciones clave

- **Color:** `62` ausente/256 = ByLayer → `color = null` (heredar). `62=0` = ByBlock.
- **Bulge:** `bulge = tan(θ/4)`; convertir a arco al renderizar y recalcular al escribir.
- **Unidades:** `$INSUNITS` → normalizar a mm (ADR-0007).
- **Capa inexistente:** entidades se asignan a la capa `"0"` implícita.
- **INSERT con bloque inexistente:** conservar, advertir, no renderizar contenido.
- **Extrusión no ortogonal:** proyectar al plano XY con advertencia al editar.

---

## 2. DxfWriter — Escritura DXF propia

**Archivo:** `lib/parsers/dxf_writer.dart`
**Propósito:** Serializa `CadFile` a DXF ASCII. ADR-0003.

```dart
class DxfWriter {
  static String write(CadFile file, {DxfVersion version = DxfVersion.r2000});
  static Future<void> writeToFile(CadFile file, String path, {DxfVersion version});
}
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
  static Future<CadFile> parseFile(String dwgPath, {String? odacPath});
  static Future<String> convertDwgToDxf(String dwgPath, {String? odacPath});
}
```

### Pipeline DWG

```
DWG file → ODA File Converter (CLI: ODAFileConverter in out AC1015 1 1 1 "*.dwg")
    → DXF temporal → DxfParserWrapper.parseFile(dxfPath) → CadFile
    → borrar temporal
```

---

## 4. FileHelper — Detección de formato

**Archivo:** `lib/utils/file_helper.dart`

```dart
FileFormat detectFormat(String path, {Uint8List? bytes});
bool isDxf(String path);  bool isDwg(String path);  bool isDgn(String path);
Future<String> readFileAsString(String path);   // try-catch + feedback
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
