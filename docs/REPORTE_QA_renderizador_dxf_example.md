# Reporte de QA — Renderizador CAD/DXF

- **Archivo analizado (caso de falla):** `files_cad/example.dxf`
- **Casos adicionales:** Anexo A — `files_cad/banera.dxf` (solo se ven las
  cotas); Anexo B — comparativa `files_cad/comparar/original.dxf` vs
  `files_cad/comparar/modificado_por_aplicacion.dxf` (lectura ↔ escritura);
  Anexo C — fuentes de cotas descomunales; Anexo D — cotas dibujadas con
  inclinación; Anexo E — texto vertical "Sin guardar" en la barra superior
- **Documento de referencia:** `docs/CORREGIR_instrucciones-correccion-renderizador-dxf.md`
- **Código auditado:** `lib/renderers/*.dart`, `lib/parsers/dxf_parser.dart`, `lib/models/*.dart`, `lib/controllers/*.dart`, `lib/utils/*.dart`
- **Fecha:** 2026-08-01
- **Autor del reporte:** Empleado de testing (QA)

---

## Checklist de verificación

> **Instrucción:** en esta primera parte del checklist, **marque con `[x]` los
> ítems ya cumplidos/verificados** (repruebe el síntoma descrito en la sección
> correspondiente y confirme la corrección en la app). Deje `[ ]` los que aún
> falten por revisar o corregir.

### Hallazgos de código (sección 3)

- [ ] BUG-01 — Halo de selección: resaltar solo el trazo, no la caja envolvente
- [ ] BUG-02 — Grips dibujados con el transform de vista (siguen el pan)
- [ ] BUG-03 — Cotas con LOD: sin piso fijo de 12 px
- [ ] BUG-04 — Umbral LOD de texto ~8 px en vez de 2 px
- [ ] BUG-05 — Viewport clipping y orden de prioridad de dibujo
- [ ] BUG-06 — Caché / índice espacial (sin re-resolver bloques por frame)
- [ ] BUG-07 — Parser conserva bloques anónimos/dinámicos (`*D…`, `*X3`)
- [ ] BUG-08 — `SOLID`/`TRACE` soportado por el parser
- [ ] BUG-09 — `entityBoundsInFile` de INSERT usa el punto base del bloque
- [ ] BUG-10 — Hit-test de LWPOLYLINE abierta sin cierre fantasma
- [ ] BUG-11 — Bulge del segmento de cierre en LWPOLYLINE cerrada
- [ ] BUG-12 — Estilo de cota inexistente con fallback a `Standard`/`$DIMSTYLE`
- [ ] BUG-13 — `$INSUNITS=0` sin forzar mm
- [ ] BUG-14 — Ejes cartesianos sin atravesar el viewport
- [ ] BUG-15 — HATCH con relleno even-odd correcto
- [ ] BUG-16 — Alineación vertical de TEXT/MTEXT correcta
- [ ] BUG-17 — Entidades BYBLOCK heredan el color del INSERT
- [ ] BUG-18 — Dimensiones no alineadas respetan su rotación

### Anexos

- [ ] BUG-19 — Parser conserva las entidades de los bloques (Anexo A)
- [ ] BUG-20 — Writer no corrompe las cotas al guardar (Anexo B)
- [ ] BUG-21 — Writer conserva precisión, `370` y `62` BYLAYER (Anexo B)
- [ ] BUG-22 — Writer emite header y tablas completas (Anexo B)
- [ ] BUG-23 — Altura de fuente de cota coherente (Anexo C)
- [ ] BUG-24 — Cotas horizontales/verticales no se dibujan inclinadas: usar el eje del grupo 50 (Anexo D)
- [ ] BUG-25 — Barra superior sin texto vertical "Sin guardar" (Anexo E)

---

## 1. Resumen ejecutivo

El archivo `example.dxf` es un plano urbano (manzana con calles, veredas,
lotes y mobiliario) de **~1570 × 1881 unidades**, generado por `dxfrw 0.6.3`,
versión DXF `AC1021` (2007). Contiene **~10.000 entidades** en el espacio
modelo y 575 definiciones de bloque.

Se auditaron 18 posibles fallos de código. **6 son críticos** y explican
directamente los síntomas descritos en el documento de corrección:

1. **Selección**: el "halo" dibuja la caja envolvente completa de la entidad
   (rectángulo celeste gigante) en lugar de resaltar solo el trazo. → **doc §E**
2. **Grips**: se dibujan sin aplicar el transform de vista (offset + inversión
   de Y); no siguen la geometría al hacer pan. → **doc §E**
3. **Cotas**: no tienen LOD; el texto se fuerza a un **mínimo** de 12 px, por lo
   que las 532 cotas se ven **siempre**, generando la "masa de cotas cruzadas".
   → **doc §C2**
4. **Sin Viewport Clipping ni orden de prioridad** de dibujo: las cotas/textos
   se pintan encima de muros, sin el orden "muros → columnas → puertas → …".
   → **doc §B y §D**
5. **Sin caché ni índice espacial**: cada frame re-resuelve bloques, texto y
   bounds (~10.000 entidades, con inserciones de bloques de 367 entidades).
   → **doc §A y §H**
6. **Bloques anónimos dinámicos (`*D…`, `*X3`)** se descartan en el parser, y
   `SOLID` (1.064 en el archivo) no es soportado → geometría que desaparece.

A continuación el detalle, con archivo:línea, comportamiento observado,
causa raíz y cómo se relaciona con el archivo analizado.

---

## 2. Metodología

- Inventario de entidades y estructuras del DXF (script Python sobre pares
  `(código, valor)`), incluyendo: HEADER, TABLES (LTYPE/LAYER/DIMSTYLE),
  BLOCKS y ENTITIES.
- Lectura estática del código (parser → modelo → ViewModel → painter).
- Comparación **dato ↔ código** (p. ej. dimensiones con estilo inexistente,
  bloques anónimos, `$INSUNITS=0`, contornos de HATCH con 10/20 y 11/21).
- Verificación de los requisitos A–H del documento contra la implementación.

### Inventario del archivo (ENTITIES + bloques)

| Entidad | Cantidad | Soporte del parser |
|---|---|---|
| LINE | 5.947 | ✅ |
| LWPOLYLINE | 3.857 (100 con bulges, 1.082 cerradas) | ✅ |
| MTEXT | 711 | ✅ (parcial: ignora anclaje) |
| TEXT | 1.078 (alto 0.19–0.63 u) | ✅ |
| HATCH | 503 | ✅ (aprox. aristas de arco) |
| ARC | 654 | ✅ |
| DIMENSION | 532 (todas tipo 32 alineadas) | ✅ (solo alineadas) |
| INSERT | 295 | ✅ (4 refs a bloque anónimo `*X3`) |
| CIRCLE | 115 | ✅ |
| POINT | 1 | ✅ |
| **SOLID** | **1.064** (todas en bloques anónimos `*D…`) | ❌ **omitidas** |
| POLYLINE / ELLIPSE / 3DFACE / SPLINE | 0 | — |

- Capas: 73 definidas, 68 referenciadas → **todas** resuelven (sin capas
  huérfanas).
- Bloques: 575 definiciones. Los `INSERT` usan bloques **con nombre** (Puerta,
  RCPLS004, CWALL 01/02, NIVEL, …) más 4 referencias a `*X3` (anónimo) y 18 a
  bloques **vacíos** (AVE_RENDER/AVE_GLOBAL, que son nulos por diseño).
- DIMSTYLE: solo existe `Standard` (dimtxt 2.5, dimasz 2.5). **Las cotas
  referencian el estilo `TOTO-COTAS`, que no existe** en la tabla.
- `$INSUNITS = 0` (sin unidades). El contenido ("ancho calle: 19.00m") indica
  que el dibujo está en **metros**, no en mm.

---

## 3. Hallazgos (bugs de código)

Cada hallazgo: **impacto** (Alta/Media/Baja), **síntoma**, **causa raíz**,
**dónde** y **recomendación**.

---

### BUG-01 — (Alta) El halo de selección dibuja la caja envolvente completa (celeste gigante)

- **Dónde:** `lib/renderers/cad_painter.dart:855-876` (`_paintSelectionHalo`) y
  `997-1012` (`_entityScreenBounds`).
- **Síntoma:** al tocar una entidad se dibuja un rectángulo redondeado celeste
  (`selectionColor` = `#63B3ED` en tema oscuro) que abarca todo el AABB de la
  entidad. Para un muro (CWALL 01/02 tiene 231-261 LINE + 136-166 ARC) o una
  polilínea que bordea la manzana, el rectángulo abarca **todo el dibujo**.
- **Causa:** el halo se construye desde `_entityScreenBounds(e)`, es decir, el
  bounding box de la entidad (y para `CadInsert` se resuelve el bloque entero).
  El documento §E pide resaltar **solo el trazo** (cambio de color/grosor), sin
  bounding boxes.
- **Evidencia en archivo:** bloques CWALL con cientos de entidades → el halo de
  cualquiera de sus partes cubre toda la pared.
- **Recomendación:** para la selección, repintar la geometría con
  color/grosor aumentado (sin bbox). Si se conserva halo, limitarlo al
  trazo (p. ej. dibujar la entidad con `selectionColor`).

---

### BUG-02 — (Alta) Grips dibujados sin el transform de vista

- **Dónde:** `lib/renderers/grip_renderer.dart:38-39`.
  ```dart
  final sx = g.x * scale;   // debería ser transform.worldToScreenX(g.x)
  final sy = g.y * scale;   // debería ser transform.worldToScreenY(g.y)
  ```
  El painter le pasa solo `transform.scale` (`cad_painter.dart:196`).
- **Síntoma:** los grips se pintan **sin offset de pan** y **sin invertir Y**:
  quedan pegados a la esquina superior-izquierda del origen y no acompañan a la
  geometría al hacer pan; el arrastre (grip activo) no coincide con lo que el
  usuario ve.
- **Causa:** `GripRenderer` no recibe el `CoordinateTransform` (a diferencia de
  `SnapRenderer`).
- **Recomendación:** pasar el `transform` completo (como hace `_snap.paint`) y
  usar `worldToScreenX/Y`.

---

### BUG-03 — (Alta) Cotas sin LOD: texto forzado a un mínimo de 12 px

- **Dónde:** `lib/renderers/cad_painter.dart:718-723`.
  ```dart
  var textH = d.textHeight > 0 ? d.textHeight : len * 0.04;
  textH *= dimTextScale;
  final textPx = textH * transform.scale;
  if (textPx < 12) { textH = 12 / transform.scale; }   // ← clamp mínimo
  ```
- **Síntoma:** el texto de cota **siempre** se dibuja con ≥ 12 px, incluso en
  vista general. Las 532 cotas del archivo aparecen todas simultáneamente
  → "miles de cotas cruzadas" y etiquetas superpuestas. Contradice el doc §C2
  ("las cotas solo deben aparecer con zoom suficiente").
- **Causa:** el clamp es un **mínimo**, no un umbral de ocultación. El doc pide
  que por debajo de un tamaño se **oculten**.
- **Evidencia:** en `example.dxf` la medición típica es ~2,7 unidades; con el
  estilo inexistente el texto cae a `len*0.04 = 0,107` y al clamp de 12 px.
- **Recomendación:** invertir la lógica: si `textPx < umbral` (p. ej. 8-12 px)
  **no dibujar** la cota ni su texto (LOD por zoom).

---

### BUG-04 — (Media) Umbral LOD de texto: 2 px en vez de ~8 px

- **Dónde:** `lib/renderers/cad_painter.dart:394-397`.
  ```dart
  final size = height * transform.scale;
  if (size < 2) { return; } // LOD
  ```
- **Síntoma:** los textos del archivo (alto 0,3 u) se renderizan a partir de
  2 px, cuando aún son ilegibles; a zoom medio se ve ruido de texto diminuto.
- **Causa:** umbral demasiado permisivo vs. doc §C1 (mínimo ~8 px).
- **Recomendación:** subir el umbral a ~8 px (configurable) y cachear el
  `TextPainter` por (texto, alto) para no relayout en cada frame (doc §H).

---

### BUG-05 — (Alta) No hay Viewport Clipping ni orden de prioridad de dibujo

- **Dónde:** `lib/renderers/cad_painter.dart:163-181`.
  - Culling: solo descarta entidades cuyo AABB no intersecta el viewport
    (`_cull`, `_visibleWorldRect` con +20%).
  - Orden: **únicamente** dibuja los HATCH primero y el resto en el orden del
    archivo. No implementa el orden del doc §D (muros → columnas → puertas →
    ventanas → polilíneas → equipamiento → bloques → símbolos → textos →
    cotas → hatch).
- **Síntoma:** cotas y textos se pintan **encima** de muros/geometría; no hay
  recorte de geometría parcialmente visible (doc §B). En este archivo las 532
  cotas se superponen sobre las manzanas.
- **Causa:** no se implementa la separación por categoría ni el recorte a los
  límites del viewport.
- **Recomendación:** clasificar por categoría (capa + tipo) y pintar en el
  orden del documento; usar `canvas.save()/clipRect()` para recortar.

---

### BUG-06 — (Alta) Rendimiento: sin caché ni índice espacial; resolución de bloques por frame

- **Dónde:**
  - `cad_painter.dart:165-180` — recorre todas las entidades visibles por frame.
  - `cad_painter.dart:912-995` (`_entityWorldBounds`) — para cada `CadInsert`
    re-resuelve y re-transforma **todas** las entidades del bloque.
  - `cad_painter.dart:438-468` (`_paintInsert`) — vuelve a transformarlas.
  - `cad_painter.dart:398-423` (`_paintText`) — `TextPainter.layout()` por texto
    en cada frame.
- **Síntoma:** en `example.dxf` (≈10.000 entidades, bloques como CWALL 01 con
  367 entidades × 33 inserciones) el costo por frame es enorme: culling +
  pintado + halo re-resuelven los bloques 3 veces. → caídas de frames.
- **Causa:** doc §A (índice espacial) y §H (cachés) no implementados.
- **Recomendación:** precalcular bounds de bloque y geometría transformada
  (caché), introducir QuadTree/R-Tree para el culling, cachear `TextPainter` y
  no resolver bloques en cada frame (invalidar por `documentVersion`).

---

### BUG-07 — (Media) El parser descarta bloques anónimos/dinámicos (`*D…`, `*X3`)

- **Dónde:** `lib/parsers/dxf_parser.dart:241`.
  ```dart
  blocks: blocks.where((b) => !b.name.startsWith('*')).toList(),
  ```
- **Síntoma:** el archivo define 575 bloques, de los cuales los primeros son
  anónimos (`*Model_Space`, `*Paper_Space`, `*D118`, `*D329`, …, `*X3`). El
  filtro elimina **todos** los que empiezan por `*`. Los 4 `INSERT` que
  referencian `*X3` quedan sin bloque → se pinta solo la cruz placeholder
  (`_paintInsertPlaceholder`, `cad_painter.dart:425-433`).
- **Causa:** la intención era excluir solo `*Model_Space`/`*Paper_Space`, pero
  excluye también los bloques anónimos válidos (prefijos `*D`, `*U`, `*T`, `*A`
  de los dynamic blocks de AutoCAD).
- **Recomendación:** excluir solo `*Model_Space` y `*Paper_Space` (o resolver
  los bloques anónimos referenciados por nombre).

---

### BUG-08 — (Media) `SOLID` no es soportado por el parser

- **Dónde:** `lib/parsers/dxf_parser.dart:398-509` (switch de `_parseEntity`,
  sin caso `'SOLID'` → cae en `default` y se omite con warning).
- **Evidencia:** `example.dxf` contiene **1.064 entidades SOLID** (todas dentro
  de los bloques anónimos `*D…`). Geometría que desaparece.
- **Recomendación:** parsear `SOLID` como polígono de 4 esquinas
  (grupos 10/20, 11/21, 12/22, 13/23) y pintarlo como relleno.

---

### BUG-09 — (Media, latente) `entityBoundsInFile` para INSERT ignora el punto base del bloque

- **Dónde:** `lib/models/cad_file.dart:244-247`.
  ```dart
  double tx(double x, double y) => i.x + (x * i.scaleX) * cos - (y * i.scaleY) * sin;
  ```
  (no resta `block.basePoint`), mientras que el painter sí lo hace
  (`cad_painter.dart:452-455`: `i.x + (lx - base.x) * i.scaleX * cos - …`).
- **Síntoma:** el bounds usado por **fit-to-screen** (`CadViewModel._documentBounds`,
  `cad_view_model.dart:427-444`), ventanas de selección y snap puede NO coincidir
  con la geometría realmente dibujada cuando un bloque tiene base ≠ (0,0).
- **Evidencia:** en este archivo todos los bloques tienen base (0,0) → **no
  disparado**, pero es una inconsistencia latente.
- **Recomendación:** unificar la transformación (factor común que reste el
  base point) en `cad_file.dart` y `cad_painter.dart`.

---

### BUG-10 — (Media) Hit-test de LWPOLYLINE abierta: cierre fantasma

- **Dónde:** `lib/utils/geometry.dart:235-251` (`distanceToEntity`).
  ```dart
  final next = p.points[(i + 1) % p.points.length]; // envuelve a 0
  ...
  if (p.closed && i == p.points.length - 1) { … }   // y además el cierre
  ```
- **Síntoma:** para una polilínea **abierta**, el último segmento se mide
  también contra el primer vértice (cierre fantasma); al tocar en la zona entre
  el final y el inicio se selecciona la polilínea erróneamente.
- **Evidencia:** 1.082 polilíneas cerradas y 2.671 abiertas en el archivo.
- **Recomendación:** solo envolver (`% length`) cuando `p.closed`.

---

### BUG-11 — (Baja/Media) Bulge del segmento de cierre en LWPOLYLINE cerrada

- **Dónde:** `lib/renderers/cad_painter.dart:351-378` (`_paintLwPolyline`).
  El bucle `for (i = 0; i < pts.length - 1; i++)` no procesa el segmento
  último→primero; al cerrar hace un `lineTo(first)` recto
  (`cad_painter.dart:373-376`) ignorando el bulge del último vértice.
- **Síntoma:** arcos de cierre de polilíneas cerradas con bulge se dibujan
  rectos.
- **Evidencia:** 100 polilíneas con bulges en el archivo.
- **Recomendación:** muestrear el segmento de cierre con `pointOnBulge` cuando
  `closed` y el último vértice tenga bulge ≠ 0.

---

### BUG-12 — (Media) Estilo de cota inexistente: se pierde dimtxt/dimasz

- **Dónde:** `lib/parsers/dxf_parser.dart:476-494` (resolución de `dimStyles`).
  - El archivo declara solo el DIMSTYLE `Standard` (dimtxt 140 = 2.5,
    dimasz 41 = 2.5), pero las 532 cotas usan el estilo `TOTO-COTAS`
    (grupo 3). `dimStyles['TOTO-COTAS']` → `null` → `textHeight=0`,
    `arrowSize=0`.
  - En `cad_painter.dart:718` cae al fallback `len*0.04` y al clamp de 12 px
    (BUG-03).
- **Síntoma:** el tamaño de texto/flecha de las cotas no es el del dibujo y
  combina mal con el LOD.
- **Recomendación:** fallback a un estilo por defecto (p. ej. el primer
  DIMSTYLE de la tabla o valores estándar) en vez de 0; y no forzar el mínimo
  de 12 px.

---

### BUG-13 — (Media) `$INSUNITS = 0` (sin unidades) se interpreta como mm

- **Dónde:** `lib/models/cad_enums.dart:67-70` (`fromInsUnits`) y
  `lib/controllers/cad_view_model.dart:275`:
  ```dart
  units = file.header.units == UnitsType.unitless ? UnitsType.mm : file.header.units;
  ```
- **Evidencia:** `example.dxf` tiene `$INSUNITS=0`; el contenido ("ancho calle:
  19.00m") indica que el dibujo está en **metros**. La app muestra las
  mediciones/cotas y la barra de estado en "mm".
- **Síntoma:** etiquetas de cota y medidas incorrectas (2,7 en vez de 2,7 m,
  19,00 mm en vez de 19,00 m).
- **Recomendación:** ofrecer selección de unidad al abrir o inferir por escala
  (1 unidad = 1 m cuando el dibujo es un plano urbano), y aplicar el factor de
  conversión correcto en `formatLength`.

---

### BUG-14 — (Media) Ejes cartesianos atraviesan todo el viewport

- **Dónde:** `lib/renderers/axis_renderer.dart:47-52`.
  - Con el origen visible dibuja el eje X **de borde a borde** y el eje Y
    **de borde a borde** del canvas.
- **Evidencia:** en `example.dxf`, `$EXTMIN = (0,0)` → el origen está en la
  esquina del plano → ambas líneas (roja X y azul Y) cruzan todo el dibujo.
  Coincide con "líneas infinitas o auxiliares que atraviesan todo el dibujo".
- **Recomendación:** acotar los ejes a la extensión del dibujo (o al origen
  dentro de límites razonables) y darles menor prioridad visual.

---

### BUG-15 — (Media) HATCH: contornos aproximados y relleno sin even-odd

- **Dónde:**
  - Parser `lib/parsers/dxf_parser.dart:616-660` (`_parseHatch`): ignora los
    extremos de cada arista (`11/21`) y los bulges (`42`/`72`); para aristas de
    arco el contorno se aproxima con rectas entre los puntos `10/20`.
  - Painter `lib/renderers/cad_painter.dart:591-619` (`_paintHatch`): rellena
    con winding por defecto (no even-odd), ignora `patternName`/`scale`/
    `rotation`, y suma un borde a cada contorno.
- **Síntoma:** hatch con islas (huecos) se rellena entero; arcos de contorno
  se ven poligonales; el patrón nunca se dibuja (siempre SOLID).
- **Recomendación:** leer 11/21 y bulges, usar `PathFillType.evenOdd`, aplicar
  `scale`/`rotation` del hatch y cachear los contornos (doc §H).

---

### BUG-16 — (Baja/Media) Alineación vertical de TEXT/MTEXT incorrecta

- **Dónde:** `lib/renderers/cad_painter.dart:380-423` (`_paintText`).
  - `painter.paint(canvas, Offset(dx, -painter.height))` coloca el **tope** del
    texto en el punto de inserción. Para `TEXT` el punto DXF es la **línea
    base**; para `MTEXT` depende del punto de anclaje (grupo 71), que el parser
    ignora (`dxf_parser.dart:442-450`).
- **Síntoma:** los textos se desplazan en Y respecto a su posición real.
- **Evidencia:** 1.076 TEXT + 178 MTEXT con contenido en el archivo.
- **Recomendación:** usar la línea base (offset `-ascent`) para TEXT y respetar
  el anclaje (1=TL, 2=TC, 3=TR, 4=ML, 5=MC, …) para MTEXT.

---

### BUG-17 — (Baja) Entidades BYBLOCK no heredan el color del INSERT

- **Dónde:** `lib/renderers/cad_painter.dart:457-467` pinta cada entidad del
  bloque con `entityColorResolver(world)`; el color `null` (BYBLOCK) se
  resuelve por la capa de la **entidad del bloque**, no por el color del
  `INSERT`.
- **Síntoma:** colores de bloques incorrectos respecto a AutoCAD.
- **Recomendación:** pasar el color efectivo del `INSERT` como fallback al
  resolver el color de las entidades del bloque.

---

### BUG-18 — (Baja, latente) Dimensiones no alineadas se dibujan como alineadas

- **Dónde:** `lib/renderers/cad_painter.dart:692-777` (`_paintDimension`) solo
  implementa la forma alineada (x3/y3 → x4/y4). Los tipos 0 (rotada), 3
  (diámetro) y 4 (radio) usan otros grupos (13/23 y 14/24 con dirección, 15/25,
  …). Además `hasExt2 = d.x4 != 0 || d.y4 != 0` (`cad_painter.dart:700`) falla
  si una cota legítima está en y=0/x=0.
- **Evidencia:** en este archivo todas las cotas son tipo 32 (alineadas) → **no
  disparado**, riesgo en otros archivos.
- **Recomendación:** manejar por `dimType` y usar un flag explícito de
  "hay grupo 14/24" en el modelo.

---

## 4. Incompatibilidades archivo ↔ código (resumen)

| Dato del archivo | Valor | Impacto en el código |
|---|---|---|
| `$ACADVER` AC1021 (DXF 2007) | — | Parseo ASCII directo OK (no binario). |
| `$INSUNITS = 0` | sin unidades (metros) | App fuerza **mm** → medidas/cotas mal (BUG-13). |
| DIMSTYLE solo `Standard` | dimtxt 2.5 / dimasz 2.5 | Cotas usan estilo `TOTO-COTAS` inexistente → fallback (BUG-12). |
| Bloques anónimos `*D…`, `*X3` | 575 defs | Filtro `!startsWith('*')` los elimina (BUG-07). |
| 1.064 `SOLID` (en bloques `*D…`) | — | No soportado → omitidas (BUG-08). |
| HATCH contornos con 10/20 y 11/21 | — | Solo lee inicios 10/20 (OK en contornos cerrados; arcos aproximados, BUG-15). |
| 100 LWPOLYLINE con bulges; 1.082 cerradas | — | Cierre con bulge no muestreado (BUG-11); hit-test de cierre fantasma (BUG-10). |
| 532 DIMENSION tipo 32 | medición ~2,7 u | LOD mínimo 12 px → siempre visibles (BUG-03). |
| Altos de texto 0,19–0,63 u | — | LOD 2 px muy permisivo (BUG-04). |
| `$EXTMIN = (0,0)` | origen en esquina | Ejes X/Y cruzan todo el viewport (BUG-14). |
| Entidades por capas | 68/68 resuelven | Sin problema de capas. |

---

## 5. Mapeo de requisitos del documento vs. estado actual

| Requisito (doc) | Estado | Dónde |
|---|---|---|
| A. Viewport Culling | ⚠️ Parcial (AABB por entidad, **sin índice espacial**) | `cad_painter.dart:163-171, 907-910` |
| B. Viewport Clipping | ❌ No implementado | `cad_painter.dart:215-316` |
| C1. Texto mín. 8 px | ⚠️ Parcial (2 px) | `cad_painter.dart:394-397` |
| C2. Cotas ocultas a bajo zoom | ❌ (clamp **mínimo** 12 px) | `cad_painter.dart:720-723` |
| C3. LOD por nivel de zoom | ❌ No existe | — |
| D. Prioridad de renderizado | ❌ (solo hatch primero) | `cad_painter.dart:172-181` |
| E. Selección/highlight sutil | ❌ (halo bbox + grips rotos) | BUG-01, BUG-02 |
| F. Bloques y transformaciones | ⚠️ Parcial (base point inconsistente, anónimos descartados) | BUG-07, BUG-09 |
| G. Capas visibles/activas | ✅ `isRenderable` | `cad_document.dart:100-108`, `cad_layer.dart:51` |
| H. Cachés (geometría/bloques/textos/hatch) | ❌ Nada en caché | BUG-06 |

---

## 6. Ranking de prioridad de corrección

1. **BUG-01** Selección/halo (doc §E) — cambio de color del trazo, sin bbox.
2. **BUG-03 + BUG-12** LOD de cotas (doc §C2) — ocultar por debajo del umbral y
   usar el DIMSTYLE correcto.
3. **BUG-06** Rendimiento / caché / índice espacial (doc §A, §H).
4. **BUG-05** Orden de pintado y clipping (doc §B, §D).
5. **BUG-02** Grips con transform de vista.
6. **BUG-07 + BUG-08** Bloques anónimos y SOLID.
7. **BUG-04** Umbral LOD de texto (doc §C1).
8. **BUG-14** Ejes acotados.
9. **BUG-10 / BUG-11 / BUG-15 / BUG-16** precisión de hit-test, bulges, hatch,
   alineación de texto.
10. **BUG-13** Unidades.
11. **BUG-09 / BUG-17 / BUG-18** latentes (base point, color BYBLOCK, tipos de
    cota).

---

## 7. Recomendaciones finales

- **Unificar la transformación de bloque** en un solo lugar (base point +
  escala + rotación + Y-invertida) para que bounds, hit-test, snap y pintado
  coincidan siempre (BUG-09/02).
- **Separar datos y representación**: precomputar una "geometría plana" de cada
  entidad (incluidos bloques resueltos) y cachearla invalidada por
  `documentVersion`; así culling, halo y pintado usan la misma geometría sin
  re-transformar por frame (BUG-06).
- **Implementar LOD por categoría** con los umbrales del doc (8 px texto,
  cotas solo con zoom, hatch con zoom cercano) en lugar de clamps mínimos
  (BUG-03/04).
- **Cobertura del parser**: añadir `SOLID`, `XLINE/RAY` (recortados al
  viewport, doc §B), `ATTRIB/ATTDEF`, tipos de cota 0/3/4 y bloques anónimos
  (BUG-07/08/18).
- **Validación regresión**: reabrir `example.dxf` y verificar (1) vista general
  limpia, (2) zoom progresivo de detalles, (3) selección sin rectángulos
  gigantes y con grips que siguen al pan.

---

## 8. Anexo A — `files_cad/banera.dxf` (solo se ven las cotas)

### 8.1 Síntoma reportado

La aplicación muestra **únicamente la cota** (dimensión), pero no los vectores
de la bañera, aunque el dibujo es simple (una bañera + una cota).

### 8.2 Estructura del archivo (verificada par a par)

| Sección | Contenido |
|---|---|
| `ENTITIES` | **1 DIMENSION** (tipo `70=33`, bloque `*D1`, estilo `Standard`) + **1 INSERT** (bloque `bañera`, punto `(-1100,300)`, escala 1) |
| `BLOCKS` | 4 bloques: `*Model_Space` (vacío), `*Paper_Space` (vacío), `*D1` (3 LINE + 2 SOLID + 1 MTEXT, geometría de la cota), `bañera` (**10 LINE + 20 ARC + 2 CIRCLE**, la bañera) |

- La **toda la geometría de la bañera** vive dentro del bloque nombrado
  `bañera` (base point `(0,0)`), referenciado por el único INSERT.
- La **cota** se dibuja desde sus puntos de definición: `13=(-1100,400)`,
  `14=(300,400)` → línea de cota de **1400 u** sobre la bañera (mundo
  aproximado de la bañera: `x∈[-1105,295]`, `y∈[-350,350]`).
- No es problema de codificación: el nombre `bañera` está en UTF-8
  (`0xC3 0xB1`) y el parser decodifica con `utf8.decode` (dxf_parser.dart:66).

### 8.3 Causa raíz — BUG-19 (CRÍTICO): el parser pierde las entidades de los bloques

**Comportamiento observado** (ejecutado el parser real): el bloque `bañera`
se parsea con **0 entidades** (sus 32 entidades LINE/ARC/CIRCLE se pierden).

**Causa raíz** en `lib/parsers/dxf_parser.dart`:

1. `dxf_parser.dart:176` — `blocks.add(block)` inserta un `CadBlock` con
   `entities = const []` (cad_block.dart:17).
2. `dxf_parser.dart:205-208` — al leer cada entidad de bloque se acumula vía
   `currentBlock = currentBlock.copyWith(entities: [...])` que crea una **nueva
   instancia inmutable**, reasignando solo la variable local `currentBlock`.
3. Esa instancia final (con las entidades) **nunca se escribe de vuelta** en la
   lista `blocks`. Al final del parseo, `blocks` contiene las instancias
   originales vacías.
4. `dxf_parser.dart:241` — además, `!b.name.startsWith('*')` descarta todos los
   bloques anónimos (`*D1`, `*Model_Space`, `*Paper_Space`).

**Consecuencia en el renderizado:**

- El INSERT de la bañera → `_paintInsert` (cad_painter.dart:442-444) encuentra
  el bloque pero `block.entities.isEmpty` → cae en `_paintInsertPlaceholder`
  (cad_painter.dart:425-433): solo un punto con cruz de 5 px en `(-1100,300)`,
  prácticamente invisible. **Los 32 vectores de la bañera no se pintan.**
- La DIMENSION **sí** se pinta porque el painter la dibuja desde sus puntos de
  definición `x3/y3` y `x4/y4` (`_paintDimension`, cad_painter.dart:692) y no
  depende del bloque `*D1`. **Por eso solo se ve la cota.**

Este BUG-19 es la causa raíz común que también explica el Anexo B (escritura).

---

## 9. Anexo B — `files_cad/comparar/original.dxf` vs `modificado_por_aplicacion.dxf`

### 9.1 Qué se comparó

- `original.dxf`: AC1021 (R2007), generado por `dxfrw`, 581.776 líneas.
- `modificado_por_aplicacion.dxf`: AC1015 (R2000), 325.552 líneas — el mismo
  dibujo **guardado por la aplicación** (`DxfWriter.write` con versión r2000
  por defecto: cad_view_model.dart:179, 309-312).

### 9.2 Hallazgos de la comparación (par a par)

| Aspecto | Original | Guardado por la app | ¿Fiel? |
|---|---|---|---|
| `ENTITIES` (10.025 entidades) | TEXT 1078, INSERT 295, MTEXT 179, HATCH 502, LINE 3395, LWPOLYLINE 3753, ARC 237, DIMENSION 532, CIRCLE 53, POINT 1 | **Mismos conteos exactos** | ✅ (contenido conservado) |
| `BLOCKS` | **575** bloques con geometría: LINE 2552, SOLID 1064, MTEXT 532, LWPOLYLINE 104, ARC 417, CIRCLE 62, HATCH 1 | **40** bloques, **todos vacíos** | ❌ (se pierde toda la geometría de bloques) |
| Bloques anónimos | 535 (`*D1`…`*D532`, `*X3`, `*Model_Space`, `*Paper_Space`) | **0** (filtrados en dxf_parser.dart:241) | ❌ |
| INSERT (295) | refs a 40 bloques + `AVE_RENDER`(16) + `AVE_GLOBAL`(2) + `*X3`(4) | mismas refs, pero `*X3` no se escribe → **4 huérfanas** | ❌ |
| DIMENSION tipo (`70`) | 532 × `32` | 532 × `0` | ❌ (BUG-20) |
| DIMENSION bloque (`2`) | 532 bloques únicos `*D1`…`*D532` | 532 × `*D1` hardcodeado | ❌ (BUG-20) |
| DIMENSION estilo (`3`) | `TOTO-COTAS`(530), `COTA100`(2) | **ausente** (el writer no escribe `3`) | ❌ (BUG-20) |
| Tablas (`TABLES`) | LTYPE, LAYER, STYLE, APPID, VPORT, DIMSTYLE, BLOCK_RECORD | solo LTYPE (Continuous) + LAYER | ❌ (BUG-22) |
| Secciones | HEADER, CLASSES, TABLES, BLOCKS, ENTITIES, OBJECTS | HEADER, TABLES, BLOCKS, ENTITIES | ❌ |
| `$ACADVER` | `AC1021` (2007) | `AC1015` (2000) | ⚠️ degradado |
| `$INSUNITS` | `0` (sin unidades) | `4` (mm) — la app fuerza mm (cad_view_model.dart:275) | ❌ |
| Precisión coords | 14-15 cifras (`1477.13392900523`) | 6 decimales (`1477.133929`) | ⚠️ BUG-21 |
| LineWeight (`370`) | presente | **omitido** | ❌ BUG-21 |
| Color `62=256` (BYLAYER) | presente | **omitido** (normalizado a null en dxf_parser.dart:396) | ❌ BUG-21 |

### 9.3 BUG-20 (CRÍTICO): las cotas se corrompen al guardar

- `dxf_writer.dart:442-443` escribe **siempre** `*D1` como bloque de la cota,
  pero el bloque `*D1` **nunca se escribe** (anónimo + filtrado) → las 532 cotas
  quedan con referencia a un bloque inexistente. En AutoCAD/LibreCAD las cotas
  aparecerían rotas.
- `cad_enums.dart:39-43`: `DimType.fromDxfCode(32)` = `32 & 0x07 = 0` →
  `rotated`; el getter `dxfCode => index` (cad_enums.dart:36) escribe `70=0`,
  **perdiendo el bit `0x20`** (texto horizontal) del tipo original `32`.
- El estilo (`code 3`, `TOTO-COTAS`/`COTA100`) no se escribe, y la tabla
  `DIMSTYLE` tampoco (solo LTYPE+LAYER, dxf_writer.dart:86-172) → los textos y
  flechas de cota pierden su estilo al reabrir el archivo.

### 9.4 BUG-21 (medio): pérdida de precisión, grosor de línea y color BYLAYER

- `_formatDouble` (dxf_writer.dart:627-632) redondea a 6 decimales o entero:
  coordenadas 14-15 cifras → 6 decimales (1 µm en mm; acumulable en bloques).
- `_common` (dxf_writer.dart:563-584) no escribe `370` (lineweight) ni `62`
  cuando el color es BYLAYER (normalizado a `null` en dxf_parser.dart:396).

### 9.5 BUG-22 (medio): header y tablas mínimas

- Header reducido a 8 variables (`_writeHeader`, dxf_writer.dart:66-84):
  `$ACADVER`, `$INSUNITS`, `$EXTMIN/MAX`, `$CLAYER`, `$LTSCALE`, `$TEXTSIZE`,
  `$CELWEIGHT`. El original tenía ~180 (`$DIMTXT`, `$DIMSCALE`, `$HANDSEED`,
  UC, etc.).
- `$INSUNITS`: el original es `0` (sin unidades) y la app fuerza `mm` (4)
  internamente (cad_view_model.dart:275), cambiando la semántica del archivo.
- Sin secciones `CLASSES` ni `OBJECTS` (referencias a datos de objetos como
  `DIMASSOC`, xdata, etc.).

### 9.6 Qué sucede al reabrir (conexión con la lectura)

- **Toda la geometría que vivía en bloques desaparece**: los 40 bloques
  escritos están vacíos por el BUG-19 (el parser nunca devolvió las entidades
  acumuladas), y los 535 anónimos (`*D…` = geometría de cotas, `*X3`) se
  filtran al parsear. Al reabrir el archivo, cada INSERT dibuja el placeholder
  (punto + cruz) y el contenido del bloque no aparece.
- Las **entidades directas** (LINE/LWPOLYLINE/ARC/TEXT/MTEXT/HATCH/CIRCLE/POINT
  en ENTITIES) y las **cotas** (dibujadas desde sus defpoints, no desde su
  bloque) **sí** se ven → reproduce exactamente el síntoma de `banera.dxf`:
  "solo se muestran las cotas, no los vectores".
- Las cotas guardadas quedan rotas para otros programas (bloque `*D1`
  inexistente, sin `DIMSTYLE`, tipo degradado).

### 9.7 Conclusión de los Anexos

La lectura y la escritura comparten la **misma causa raíz (BUG-19)**: las
entidades acumuladas en `currentBlock` nunca se devuelven a la lista `blocks`.
Ello produce (a) que al **leer** un dibujo basado en bloques (como `banera.dxf`)
solo se rendericen las cotas, y (b) que al **guardar** el archivo resulte con
los bloques vacíos, sin anónimos y con las cotas degradadas. **Corregir
BUG-19 (escribir `currentBlock` de vuelta en `blocks`) es el fix de mayor
impacto**; le siguen BUG-20 (persistir el bloque de la cota y su estilo/tipo),
BUG-21 (precisión, lineweight, color) y BUG-22 (header/tablas).

---

## 10. Anexo C — Las fuentes de las cotas quedan muy grandes

### 10.1 Síntoma

En el archivo guardado por la aplicación, el **texto de las cotas se ve muy
grande** (desproporcionado respecto de la propia cota y de la geometría).

### 10.2 Datos verificados (parser real de la app)

| Métrica | original.dxf | modificado_por_aplicacion.dxf |
|---|---|---|
| Cotas (DIMENSION) | 532 | 532 |
| `textHeight` (parser) | **0 en las 532** | **0 en las 532** |
| Longitud medida promedio (13/23→14/24) | **2.29 u** (mediana 1.58) | 2.29 u |
| Grupo 140 en la entidad | ausente | ausente |
| Tabla `DIMSTYLE` | solo `Standard` (140=`2.5`) | **inexistente** |
| `$DIMTXT`/`$DIMSCALE`/`$DIMASZ` (header) | 2.5 / 0.05 / 2.5 | **no escritos** |

Causas de fondo (BUG-23):

1. **El parser no resuelve la altura de texto** — `dxf_parser.dart:476-493`:
   las cotas referencian los estilos `TOTO-COTAS` (530) y `COTA100` (2) que **no
   existen** en la tabla `DIMSTYLE` (solo hay `Standard`). Como la entidad
   tampoco trae grupo 140, `textHeight = 0` en las 532 cotas.
2. **El writer no conserva la información de altura** — al guardar, con
   `textHeight=0` no se escribe el grupo 140 (`dxf_writer.dart:459-461`), no se
   escribe la tabla `DIMSTYLE` (solo LTYPE+LAYER, `dxf_writer.dart:86-172`) y el
   header mínimo no incluye `$DIMTXT/$DIMSCALE/$DIMASZ` (`dxf_writer.dart:66-84`).
   El archivo guardado queda **sin ninguna fuente de altura de texto de cota**.

### 10.3 Qué sucede al reabrir (dos efectos)

**a) En otro CAD (AutoCAD/LibreCAD):** sin `140`, sin `DIMSTYLE` y sin
`$DIMTXT`, el programa cae al `dimtxt` por defecto (≈ 2.5 en unidades métricas,
`$INSUNITS=4`). Para cotas cuya longitud medida es ~1.58 u (mediana), un texto
de 2.5 u es **más alto que la propia cota** → fuentes desproporcionadamente
grandes.

**b) En la propia app:** `cad_painter.dart:720-724` calcula
`textH = clampDimTextHeight(len * 0.04 * dimTextScale, len, scale)` y
`clampDimTextHeight` (geometry.dart:331-340) impone un **mínimo legible de
12 px** (`minH = 12/scale`). En el zoom inicial "fit" de un dibujo de
~1778 × 2051 u (escala ≈ 0.24–0.49 px/u según el viewport), `minH` queda en
**~25–50 unidades**; como `len*0.04 ≈ 0.09 u` (promedio) queda muy por debajo
del piso, el texto y la línea de cota se clavan en 25–50 u → cada cota de ~2 u
genera líneas de extensión, flechas (`arrow = clampDimArrowSize(textH*1.5…)`,
geometry.dart:347-357) y separación (`gap = textH*1.2`, cad_painter.dart:739)
del orden de **decenas de unidades**: la cota se ve gigante y se superpone a la
geometría. Es la misma causa raíz del BUG-03 (clamp mínimo de cotas) ya
reportado en el §3 de este documento, ahora agravado porque el guardado
descarta el `dimtxt` original (2.5 u).

### 10.4 Correcciones sugeridas (BUG-23)

- **Parser**: resolver el estilo de cota con *fallback* (estilo `Standard` /
  `$DIMSTYLE` del header / `$DIMTXT`) cuando el nombre referenciado no existe,
  en lugar de devolver 0.
- **Writer**: persistir el `dimtxt` efectivo como grupo `140` en cada
  DIMENSION y/o reescribir la tabla `DIMSTYLE` y las variables `$DIMTXT`/
  `$DIMSCALE`/`$DIMASZ` del header (evita que CAD externos usen el default).
- **Painter**: sustituir el piso fijo de 12 px por el LOD del documento
  (doc §C1/C2: texto de cota ~8 px, visible solo según zoom), de modo que la
  altura en unidades de mundo no se infle al alejar.

---

## 11. Anexo D — Cotas que se dibujan con inclinación (medición incorrecta)

### 11.1 Síntoma

Algunas cotas que deberían ser **horizontales** se dibujan con una **pequeña
inclinación** (~5–10°, apenas perceptible) pero **suficiente para que el valor
medido sea incorrecto**. Parece ocurrir "cuando hay otra cota muy cerca", como
si dos cotas no pudieran estar en el mismo lugar y una se desplazara.

### 11.2 Investigación: la app no desplaza cotas; el eje sale de 13→14

- **No existe lógica de colisión / desplazamiento entre cotas** en la app
  (búsqueda de `collid / overlap / nudge / spread / separate` en `lib/` sin
  resultados; no hay herramienta de creación de cotas, solo se leen del DXF).
- La dirección de la línea de cota sale **solo de los defpoints del archivo**:
  `dxf_parser.dart:486` lee `x3/y3 = grupo 13/23` y `x4/y4 = grupo 14/24`, y
  `cad_painter.dart:740-743` calcula la dirección unitaria `(14−13)/len`. Si el
  archivo trae `13` e `14` con Y (o X) ligeramente distinta, la cota se dibuja
  inclinada.

### 11.3 La raíz real: la app ignora el grupo 50 (BUG-24)

- **304/532 cotas traen el grupo 50 (ángulo de rotación de la cota)** y en todas
  es **eje puro**: `0°`/`180°` (horizontal) y `90°`/`270°` (vertical). **Ninguna
  cota del archivo está declarada diagonal.**
- De esas 304, en **110 la dirección real `13→14` NO coincide con el grupo 50**
  (>1°): el archivo declara la cota horizontal/vertical, pero los defpoints
  `13/14` están levemente desalineados (ruido de dibujo), y la app —que ignora el
  grupo 50— dibuja la recta `13→14` **en diagonal**. Ejemplo real: cota vertical
  entre `(1492.988, 1822.760)` y `(1498.528, 1821.666)`: la app la dibuja a
  `11.17°` y mide `5.647` en vez de la vertical `4.600` (proyección sobre el eje).
- **Conclusión: no es un error del archivo sino de la app**, que debe usar el eje
  del grupo 50 (y la proyección de `14−13` sobre él) en vez de unir `13→14`
  directamente. El guardado no introduce la inclinación (`original.dxf` vs
  `modificado_por_aplicacion.dxf` idénticos).

### 11.4 Datos verificados (example.dxf / original.dxf, 532 cotas)

| Inclinación de la cota (13→14) | Cantidad |
|---|---|
| 0–1° (horizontales) | 189 |
| 1–5° | 27 |
| **5–15° (las "~10°" reportadas)** | **13** |
| 15–85° | 78 |
| 85–89° | 48 |
| 89–90° (verticales) | 177 |

Las cotas desalineadas son **cortas** (0.10–6.3 u) con una diferencia de
0.02–1.09 u en su base: el mismo ruido de dibujo en una base corta produce un
ángulo visible. Por eso se percibe "cuando hay otra cota muy cerca": en las
zonas densas las cotas son cortas y la desalineación se vuelve evidente.

### 11.5 Por qué el valor mide mal (BUG-24)

El painter muestra `formatLength(d.measurement ?? len)`
(`cad_painter.dart:776-779`):

- Solo **19/532** cotas traen grupo 42 (medición real) y **65/532** grupo 1
  (texto); el resto (la mayoría) cae a `len = distance(13,14)`, que es la
  longitud **en diagonal**, no la proyección sobre el eje de la cota.
- Ejemplo: cota que debería medir vertical entre `(1,3)` y `(2,7)` → la app
  muestra `√(1²+4²) = 4.12` en vez de `4.0`. Con ~10° de inclinación el error es
  de ~1.5 %, suficiente para que la medida difiera del valor real del plano.

### 11.6 Correcciones sugeridas (BUG-24)

- **Parser**: leer el **grupo 50** (ángulo de rotación) en `dxf_parser.dart:486`
  y guardarlo en `CadDim` (304/532 cotas lo tienen).
- **Painter**: usar el eje del grupo 50 para la línea de cota
  (`cad_painter.dart:740-743`); si no existe, enderezar al eje dominante cuando
  la inclinación sea menor a un umbral (p. ej. 2–3°).
- **Medición**: calcular la **proyección** de `(14−13)` sobre el eje de la cota
  en vez de la distancia directa; reusar el grupo 42 cuando exista (ya se hace).

---

## 12. Anexo E — Barra superior con texto en vertical ("Sin guardar")

### 12.1 Síntoma

En la barra superior del visor (volver, deshacer, rehacer, guardar, capas,
información, rotar, ajustar a pantalla) aparece un texto **en vertical, letra
por letra**, que ensancha la barra y ocupa más pantalla de lo normal (leído por
el usuario como "singulardar", pero es **"Sin guardar"**).

### 12.2 Causa raíz (BUG-25)

El indicador de cambios sin guardar es `Text('Sin guardar')` **sin `maxLines`
ni `overflow`** (`viewer_screen.dart:557-561`). La barra es una `Row` con un
`Expanded` para el nombre de archivo + 8 `IconButton`. Cuando el ancho
disponible es escaso (pantalla chica / ventana estrecha), el `Expanded` se
reduce y Flutter **envuelve la palabra carácter a carácter en vertical**
(`S i n g u a r d a r`). Como el `Container` de la barra no tiene alto fijo,
crece en altura y el menú ocupa más pantalla de lo normal.

### 12.3 Corrección aplicada (v0.4.8)

`viewer_screen.dart:557-561` — `maxLines: 1` + `overflow: TextOverflow.ellipsis`
sobre el `Text('Sin guardar')`, igual que el nombre de archivo (líneas
551-556). El indicador ya no envuelve en vertical y la barra mantiene su alto
normal.
