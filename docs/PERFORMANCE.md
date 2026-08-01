# Rendimiento — CAD Viewer & Editor

**Versión:** 0.3.1
**Fecha:** 2026-07-31
**Propósito:** Presupuesto de rendimiento, técnicas de optimización y plan de medición para garantizar una experiencia fluida con archivos CAD de tamaño realista.

---

## 1. Presupuesto de rendimiento

| Métrica | Objetivo | Medición |
|---------|----------|----------|
| FPS en pan/zoom (10 k entidades, 5 MB) | ≥ 60 fps, sin jank | DevTools Performance / profile |
| Parseo DXF 5 MB (dispositivo medio) | < 2 s | Stopwatch alrededor del Isolate |
| Apertura archivo < 1 MB | < 300 ms | Instrumentación en ViewModel |
| Latencia hit-testing | < 16 ms | Profiling de gesto |
| Latencia snap por frame | < 8 ms | Profiling de SnapEngine |
| Memoria con 10 k entidades | < 250 MB | `flutter run --profile` + DevTools Memory |
| Escritura DXF 5 MB | < 2 s | Stopwatch en Isolate |
| Frames jank durante edición | < 1% | DevTools Performance |

> Los valores anteriores son el objetivo del **dispositivo medio de referencia**. El desglose por plataforma y tier de hardware se define en §1.1 y es el que se verifica en CI (TESTING.md §5) y en QA manual (TESTING.md §7).

### 1.1 Presupuestos por plataforma

| Plataforma | Tier de referencia | Parseo 5 MB | Apertura < 1 MB | FPS pan/zoom (10 k) | Memoria (10 k) | Escritura 5 MB | Jank edición |
|------------|--------------------|-------------|-----------------|---------------------|----------------|----------------|--------------|
| **Android** | Gama baja (4 núcleos / 3 GB) | < 4.0 s | < 600 ms | ≥ 30 fps | < 200 MB | < 4.0 s | < 3% |
| **Android** | Gama media (8 núcleos / 6 GB) | < 2.0 s | < 300 ms | ≥ 60 fps | < 250 MB | < 2.0 s | < 1% |
| **Android** | Gama alta (8+ núcleos / 8 GB+) | < 1.2 s | < 300 ms | ≥ 60 fps, sin jank | < 250 MB | < 1.2 s | < 1% |
| **iOS** | iPhone 11 o posterior | < 1.5 s | < 300 ms | ≥ 60 fps | < 250 MB | < 1.5 s | < 1% |
| **Windows** | i5/Ryzen 5, 8 GB | < 1.0 s | < 200 ms | ≥ 60 fps | < 400 MB | < 1.0 s | < 1% |
| **macOS** | Apple Silicon M1+ | < 0.8 s | < 200 ms | ≥ 60 fps | < 400 MB | < 0.8 s | < 1% |
| **Linux** | Equipo medio (4–8 núcleos) | < 1.2 s | < 250 ms | ≥ 60 fps | < 400 MB | < 1.2 s | < 1% |
| **Web** | Navegador moderno (Chrome/Edge) | < 2.5 s | < 500 ms | ≥ 60 fps | < 400 MB (heap) | < 2.5 s | < 2% |

**Criterios de aplicación:**
- **Memoria (Android):** el límite de heap por app varía por dispositivo (típicamente 192–512 MB); el objetivo de < 250 MB deja margen incluso en gama media.
- **Escritura (Web):** el tiempo se mide hasta que el navegador genera el blob de descarga; la descarga en sí no se contabiliza.
- **Parseo (desktop):** límites holgados porque el Isolate dispone de más CPU que en móvil; el cuello de botella real es la I/O y el render.
- **Jank:** < 1% es el objetivo de producción; en QA manual se acepta < 3% en gama baja, documentándolo como limitación conocida.
- **Clasificación de tier (criterio interno del proyecto):** gama baja = 4 núcleos / 3 GB RAM; media = 8 núcleos / 6 GB; alta = 8+ núcleos / 8 GB+.

---

## 2. Cuellos de botella identificados

1. **Renderizado de todas las entidades en cada frame** — sin culling, 50 k entidades = 50 k draw calls por frame.
2. **Parseo síncrono en hilo UI** — bloquea la primera frame hasta N segundos.
3. **Reconstrucción de `shouldRepaint` costosa** — comparar listas grandes cada frame.
4. **TextPainter por texto por frame** — layout de texto caro.
5. **Snap/hit-testing lineales** — O(n) por evento con archivos grandes.
6. **Spatial data sin estructura** — getBounds y culling recorren todo.

---

## 3. Estrategias de optimización

### 3.1 Renderizado

| Técnica | Detalle | Estado |
|---------|---------|--------|
| `RepaintBoundary` | Aislar el canvas de la UI circundante | ✅ fase 0.1 |
| `shouldRepaint` granular | Comparar `documentVersion`, `selectionVersion`, `theme`, `transformVersion` — no listas enteras | ✅ |
| **Entity culling** | Solo pintar entidades cuyo bounds intersecta viewport (+20% margen) | ✅ |
| **Spatial index** | Grid hash o R-Tree sobre bounds de entidades (reconstruido en Isolate tras cambios) | ✅ |
| LOD | A zoom lejano: omitir textos < 4 px, simplificar splines/hatches, fusionar polilíneas finas | fase 0.3 |
| Cache de `Picture` | Renderizar a `ui.Picture` y `Picture.toImage` para capas estáticas; reusar entre frames | fase 0.3 |
| `drawLine` en lote | Agrupar trazos del mismo color/grosor en un solo `Path` | fase 0.3 |
| `isComplex` | Entidades fuera de umbral de complejidad se dibujan simplificadas (hatch→contorno) | fase 0.3 |

### 3.2 Parseo y escritura (Isolates)

```
Parseo:
  bytes/string → compute(parseFn, data) → CadFile (en Isolate)
  UI: spinner + progreso por chunks (si el paquete dxf lo permite) o indeterminado
  Límite de 10 MB con advertencia.

Escritura:
  CadFile → compute(writeFn, payload) → String DXF
  Luego writeFile en hilo UI con flush:true.
```

- `compute()` de Flutter requiere datos transferibles: CadFile debe ser serializable (`toJson`/`fromJson` o pasar el string DXF directo).
- Alternativa para control fino: `Isolate.run` (Dart 2.19+) con mensajes por chunks y barra de progreso.

### 3.3 Hit-testing y Snap (estructuras de aceleración)

| Estructura | Uso |
|------------|-----|
| Spatial hash (celdas de tamaño = tolerancia × 8) | Hit-testing y snap por cercanía |
| Índice por capa (`Map<layer, List<entity>>`) | Filtrado rápido por visibilidad |
| Cache de bounds por entidad | `getBounds` O(1) por entidad |

Reconstrucción:
- Tras `documentVersion++` (cambio estructural) → reconstruir en Isolate si > 5 k entidades; en UI si menor.
- Tras toggle de capa → solo filtrar (índice por capa ya existe).

### 3.4 Textos

- `TextPainter` reutilizado por (texto, altura, rotación) mediante cache LRU.
- A LOD lejano: no dibujar textos; dibujar rectángulo placeholder si height < umbral.
- Fuentes: precargar Inter/JetBrains Mono; evitar `FontLoader` en caliente.

### 3.5 Grid

- Calcular líneas de grid solo dentro del viewport y con paso adaptado (paso mínimo 8 px en pantalla).
- Cache de `Path` del grid cuando el paso no cambia.

---

## 4. Arquitectura de datos para rendimiento

```
CadDocument
├── entities: List<CadEntity>          (orden de dibujo = orden de archivo)
├── spatialIndex: SpatialIndex?        (reconstruible)
├── boundsCache: Map<String, Rect>     (por handle)
└── version: int
```

- Las operaciones de lectura de la UI usan **vistas inmutables** generadas por el ViewModel (nunca la lista viva mientras se muta en un gesto).

---

## 5. Perfiles objetivo por tamaño de archivo

| Tamaño | Estrategia |
|--------|-----------|
| < 1 MB | Parseo síncrono aceptable, pero igual por Isolate para UI responsiva |
| 1–10 MB | Isolate + progreso; culling activo; recomendar LOD |
| > 10 MB | Advertencia de rendimiento; culling + LOD obligatorios; desactivar snaps sobre todo el dibujo (solo vecinos) |

---

## 6. Mediciones y herramientas

| Herramienta | Uso |
|-------------|-----|
| Flutter DevTools Performance | Frames, jank, shader compilation |
| Flutter DevTools Memory | Leaks, uso de heap |
| `flutter run --profile` | Perfil realista |
| Timeline events instrumentados | Parseo, escritura, hit-test, snap |
| Integración con `SchedulerBinding` | Detectar frames > 16 ms en dev |
| Benchmark script | Abrir los archivos de `test/files/` y reportar métricas (ver TESTING.md §6); comparar contra §1 y §1.1 en CI y QA manual |

---

## 7. Checklist de rendimiento

- [ ] Culling implementado y verificado (10 k entidades, 60 fps)
- [ ] Spatial index reconstruido eficientemente
- [ ] Parseo y escritura en Isolates
- [ ] `shouldRepaint` sin comparar listas completas
- [ ] Cache de TextPainter y de Picture
- [ ] Grid con paso adaptativo y límite de líneas
- [ ] Snap con límite de candidatos por frame
- [ ] Benchmark en CI con archivos de muestra
- [ ] Presupuestos por plataforma (§1.1) verificados en QA manual y CI
- [ ] Memoria estable con apertura/cierre repetido de archivos
