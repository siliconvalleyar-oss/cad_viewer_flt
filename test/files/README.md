# Archivos de muestra para pruebas — CAD Viewer & Editor

**Versión:** 0.3.2
**Fecha:** 2026-07-31
**Propósito:** Conjunto de archivos CAD de prueba para parsers, writers, round-trip, render, selección y manejo de errores. Referencia: `docs/TESTING.md` §2 y `docs/FORMATS.md` §11.

---

## Matriz de archivos

| Archivo | Formato / Versión | Propósito | Resultado esperado |
|---------|-------------------|-----------|--------------------|
| `sample_r12_librecad.dxf` | DXF R12 (`AC1009`) | Estilo LibreCAD | POLYLINE pesada (`VERTEX`/`SEQEND`), capas `WALLS`/`TEXT-L`, 2 TEXT (rotación 0°/90°), 1 LINE |
| `sample_r12_autocad.dxf` | DXF R12 (`AC1009`) | Estilo AutoCAD R12 | ARC (0°→180°), CIRCLE, POINT, bloque `BOLT` con INSERT (rotación 45°), LINE |
| `sample_r2000.dxf` | DXF R2000 (`AC1015`) | Estándar moderno | LWPOLYLINE cerrada con bulge 0.4142, SPLINE (grado 3, 4 puntos de control), MTEXT con códigos `{\\f...}` (strip → "Floor plan note"), HATCH SOLID, ELLIPSE, LINE, CIRCLE |
| `sample_r2010.dxf` | DXF R2010 (`AC1024`) | R2010 | DIMENSION alineada (dimtype 33) con bloque anónimo `*D1`, bloques anidados (`B` dentro de `A`, INSERT de `A` en model space), LINE |
| `sample_units_inch.dxf` | DXF R2000 (`AC1015`) | Conversión de unidades | `$INSUNITS=1` (pulgadas) → al cargar se convierte a mm según `docs/EDITING.md` §3 / ADR-0007 |
| `sample_selection.dxf` | DXF R2000 (`AC1015`) | Hit-testing denso | Líneas paralelas a 0.1 de separación, 3 círculos superpuestos (centros casi coincidentes), rejilla de puntos — para probar prioridades y tolerancias de selección |
| `sample_empty.dxf` | DXF R2000 (`AC1015`) | Archivo vacío | Sin entidades; capas `0`; carga sin error y bounds vacíos |
| `sample_binary.dxf` | DXF **binario** (`AC1015`) | Detección de formato | Debe detectarse como binario (sentinel `AutoCAD Binary DXF\r\n\x1a\x00`) y mostrar **advertencia** de no soporte (FORMATS.md §8), sin crash |
| `sample_corrupt.dxf` | — (truncado) | Manejo de errores | Empieza como DXF ASCII válido pero se corta a mitad de entidad (sin `ENDSEC` ni `EOF`) → error limpio `ERR-PARSE-UNEXPECTED_EOF` sin crash (ERROR_HANDLING.md) |
| `sample_dwg.dwg` | DWG (`AC1032`) **stub** | Flujo ODA (v0.3+) | Magic bytes `AC1032` detectables por `file_helper`; contenido **no es un DWG real** — placeholder hasta reemplazarlo con un DWG convertido por ODA File Converter |

---

## Convenciones aplicadas a los DXF ASCII

- Pares `group code` (entero) / `valor` en líneas alternas, terminados con `0\nEOF`.
- Cabecera mínima: `$ACADVER`, `$INSUNITS` (4 = mm salvo `sample_units_inch` = 1), `$EXTMIN`/`$EXTMAX`.
- Tablas: `LAYER` (con capa `0` obligatoria) y `LTYPE` (CONTINUOUS).
- Sección `BLOCKS` con `*Model_Space` (requerido por AutoCAD).
- Handles (`5`) únicos por entidad; en R12 se omiten los subclass markers `100` (no existen en esa versión).
- Coordenadas con 6 decimales (máximo), consistente con la precisión del `DxfWriter` (SERIALIZATION.md §3).
- Ángulos en **grados** (group codes 50/51), como exige el formato DXF.
- Los DXF R12 incluyen `$INSUNITS` aunque ese código apareció en R13: LibreCAD lo escribe en sus exportaciones R12 (FORMATS.md §7 lo contempla: "frecuentemente ausente → asumir mm").

## Regeneración y reemplazo

- Los archivos **sintéticos** de esta carpeta fueron escritos a mano siguiendo la especificación DXF (R12 de Autodesk y R2000+ con subclass markers).
- Antes del release, **reemplazar por archivos reales exportados** desde LibreCAD (R12) y AutoCAD (R2000/R2010) para validar tolerancia a archivos reales (TESTING.md §2).
- El DWG debe generarse con **ODA File Converter** (CLI local, FORMATS.md §5.2) a partir de un dibujo de prueba, reemplazando el stub `sample_dwg.dwg`.
- Verificar con `docs/TESTING.md` §3.2 (`dxf_parser_test`, `dxf_writer_test` round-trip) y §6 (`tool/benchmark.dart`).
