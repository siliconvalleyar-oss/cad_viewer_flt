# Registro de Decisiones de Arquitectura (ADR)

**Versión:** 0.3.0
**Fecha:** 2026-07-31
**Propósito:** Documentar las decisiones de arquitectura significativas, el contexto, la alternativa descartada y las consecuencias. Formato MADR (estándar ligero).

---

## ADR-0001 — Gestión de estado con Provider + ChangeNotifier

**Estado:** Aceptado
**Fecha:** 2026-07-31

### Contexto
La app tiene estado de sesión complejo: documento editable, selección, capas, transformación de vista, comandos, temas, unidades. Necesitamos un patrón simple, oficial de Flutter y con bajo acoplamiento.

### Decisión
Usar **Provider + ChangeNotifier** con un único `CadViewModel` y `context.select` para rebuild selectivo. No introducir Riverpod en v1.0.

### Alternativa descartada
- **Riverpod** — más potente y testable, pero agrega curva de aprendizaje y otra dependencia; se puede migrar más adelante si el ViewModel crece sin control.

### Consecuencias
- Rebuild selectivo por version counters (`documentVersion`, `layersVersion`, `selectionVersion`, etc.).
- ViewModel fácil de testear (ChangeNotifier puro).
- Riesgo de ViewModel "god class" mitigado delegando en sub-sistemas (CommandStack, SnapEngine, SelectionManager).

---

## ADR-0002 — Parseo DXF con paquete `dxf ^1.3.0` + wrapper propio

**Estado:** Aceptado

### Contexto
El DXF es un formato extenso. Escribir un parser completo desde cero es meses de trabajo; el paquete `dxf` de Dart cubre las primitivas 2D más comunes (LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, POLYLINE, TEXT, MTEXT, INSERT, POINT; parcial para HATCH/SPLINE/DIMENSION).

### Decisión
Usar `dxf ^1.3.0` para la lectura y construir `DxfParserWrapper` que convierta la salida del paquete a nuestros modelos internos (`CadFile`). El wrapper centraliza mapeos, normalización (ByLayer, bulges, MTEXT strip) y errores.

### Alternativa descartada
- Parser DXF escrito a mano desde cero (alto costo, bajo retorno para v1.0).
- Depender directamente de las clases del paquete en toda la app (acoplamiento alto).

### Consecuencias
- Soporte limitado para HATCH/SPLINE/DIMENSION avanzados en v1.0 (ver RF-ENT).
- Entidades desconocidas se conservan con handle y se advierten.
- El wrapper permite migrar de paquete sin tocar el resto de la app.

---

## ADR-0003 — Escritura DXF con writer propio (`DxfWriter`)

**Estado:** Aceptado

### Contexto
El paquete `dxf` tiene soporte de escritura limitado y no controlamos el formato de salida. Necesitamos guardar R12 y R2000 con conversiones (LWPOLYLINE → POLYLINE en R12), precisión de 6 decimales y control total de secciones.

### Decisión
Implementar `DxfWriter` propio en `lib/parsers/dxf_writer.dart` (serialización a String, ejecución en Isolate). Es un serializer determinista y testeable.

### Alternativa descartada
- Escribir con el paquete `dxf` (control insuficiente de versiones y conversiones).

### Consecuencias
- Un componente más que mantener, pero pequeño y con tests de round-trip.
- Libertad para emitir exactamente lo que necesitamos (HEADER mínimo, TABLES, ENTITIES).

---

## ADR-0004 — Edición con patrón Command + CommandStack propio

**Estado:** Aceptado

### Contexto
La edición requiere undo/redo robusto de cualquier operación (crear, mover, borrar, rotar, escalar, modificar props, capas). No queremos dependencias externas frágiles ni acoplamiento a paquetes de undo genéricos.

### Decisión
Implementar el patrón **Command** (`CadCommand.execute/undo`) con `CommandStack` propio (límite 100). Todas las mutaciones del documento pasan por la pila. Ver `docs/EDITING.md` §3.

### Alternativa descartada
- Paquetes de undo/redo genéricos (poco adaptados a geometría CAD, riesgo de mantenimiento).
- Memento global del documento completo (costoso en memoria con archivos grandes).

### Consecuencias
- Garantía de undo/redo para cualquier operación futura (solo hay que implementar un `CadCommand`).
- Tests unitarios sencillos por comando (execute+undo = original).

---

## ADR-0005 — DWG: MVP con guía; v0.3+ ODA File Converter (CLI local)

**Estado:** Aceptado (etapado)

### Contexto
DWG es binario propietario; no hay parser Dart puro (investigación 2026-07). Las opciones son: mensaje de no soporte, servicio cloud, SDK nativo, o CLI local de conversión.

### Decisión
- **MVP (v0.1–v0.2):** mensaje de no soporte + guía para convertir a DXF.
- **v0.3+:** integrar **ODA File Converter** (gratuito, multiplataforma, CLI batch) para convertir DWG → DXF localmente, con setup guiado del binario. **No subir planos a la nube por defecto.**
- Servicios cloud (Apryse/CloudConvert) quedan como opción premium futura con consentimiento explícito.

### Alternativa descartada
- Cloud como primera opción (fuga de datos de planos, costo).

### Consecuencias
- Privacidad preservada (conversión local).
- Dependencia de que el usuario instale ODA File Converter en desktop; en móvil, alternativa: intentar conversión local vía paquete nativo (FFI a librería C++) como POC futuro.

---

## ADR-0006 — Renderizado con CustomPainter + InteractiveViewer

**Estado:** Aceptado

### Contexto
El renderizado CAD 2D necesita control total del canvas (grid, ejes, grosores, LOD, culling) y gestos nativos de zoom/pan.

### Decisión
Usar `CustomPainter` (CadPainter) dentro de `InteractiveViewer` + `RepaintBoundary`. Transformación de vista gestionada por `transformationController`, con `CoordinateTransform` para mundo↔canvas.

### Alternativa descartada
- Impeller 3D / Flame / canvas-kit (sobre-ingeniería para 2D; complejidad innecesaria).

### Consecuencias
- Control total del renderizado y del hit-testing (coordenadas transformadas).
- Requiere optimizaciones propias (culling, cache) — ver PERFORMANCE.md.

---

## ADR-0007 — Unidades internas siempre mm

**Estado:** Aceptado

### Contexto
Los DXF pueden venir en distintas unidades (`$INSUNITS`) y el usuario quiere visualizar en mm/cm/m/pulgadas. Si almacenáramos en la unidad del archivo, cada entidad tendría un factor distinto.

### Decisión
Normalizar todo a **mm** al parsear. La conversión ocurre solo en la capa de entrada/salida (parser, writer, UI de entrada/salida). `UnitsType` define factor a mm.

### Alternativa descartada
- Almacenar en unidades del archivo y convertir en render (errores de redondeo y complejidad en edición).

### Consecuencias
- Geometría uniforme para edición, snapping y medición.
- Al guardar, se puede escribir en la unidad original del archivo (reconvertir) o en mm según preferencia.

---

## ADR-0008 — DGN fuera de alcance para v1.0

**Estado:** Aceptado

### Contexto
El usuario mencionó "todos los tipos CAD". DGN (MicroStation) es binario propietario distinto de DWG, sin demanda clara en v1.0.

### Decisión
No soportar DGN en v1.0. Evaluar en v2.0 vía conversión (ODA o Apryse). Al abrir un `.dgn` se muestra un mensaje informativo.

### Alternativa descartada
- Soporte DGN en v1.0 (costo alto, beneficio bajo).

### Consecuencias
- Alcance enfocado; roadmap v2.0 incluye DGN como candidato.

---

## Tabla resumen

| # | Decisión | Alternativa | Estatus |
|---|----------|-------------|---------|
| ADR-0001 | Provider + ChangeNotifier | Riverpod | Aceptado |
| ADR-0002 | Paquete `dxf` + wrapper | Parser propio | Aceptado |
| ADR-0003 | `DxfWriter` propio | Escribir con paquete | Aceptado |
| ADR-0004 | Patrón Command + CommandStack | Paquetes undo externos | Aceptado |
| ADR-0005 | DWG local (ODA) tras MVP | Cloud primero | Aceptado (etapado) |
| ADR-0006 | CustomPainter + InteractiveViewer | Impeller/Flame | Aceptado |
| ADR-0007 | Unidades internas en mm | Unidad del archivo | Aceptado |
| ADR-0008 | DGN fuera de v1.0 | Soporte nativo | Aceptado |
