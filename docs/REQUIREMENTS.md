# Requisitos — CAD Viewer & Editor

**Versión:** 0.3.0 · **Estado:** Aprobado (producto)
**Fecha:** 2026-07-31
**Equipo responsable:** Product Owner · QA
**Propósito:** Requisitos funcionales (RF) y no funcionales (RNF) de la aplicación Flutter **CAD Viewer & Editor** para visualizar y editar archivos CAD (DXF, DWG, DGN opcional). Documento fuente para estimación, desarrollo y testing.

## Índice

1. [Visión](#1-visión-del-producto)
2. [Actores](#2-actores)
3. [Requisitos funcionales](#3-requisitos-funcionales)
4. [No funcionales](#4-requisitos-no-funcionales-rnf)
5. [User stories](#5-user-stories-resumen-priorizado)
6. [Casos de borde](#6-casos-de-borde-y-reglas-de-negocio)
7. [Priorización por versión](#7-priorización-y-alcance-por-versión)

---

## 1. Visión del producto

Aplicación multiplataforma (Flutter) profesional para **visualizar, inspeccionar y editar** planos técnicos CAD. El público objetivo son arquitectos, ingenieros, diseñadores industriales, topógrafos, estudiantes y profesionales de mecánica que necesitan consultar y hacer modificaciones ligeras de planos en campo, sin una estación de trabajo AutoCAD/LibreCAD.

**Formatos objetivo:**
- **DXF** (AutoCAD y LibreCAD) — soporte primario, lectura y escritura.
- **DWG** (AutoCAD) — soporte secundario vía conversión externa (MVP: guiado a conversión).
- **DGN** (MicroStation) — fuera de alcance para v1.0 (ver ADR-0008).

**Filosofía:** procesamiento local de datos, privacidad por diseño, inmersión en el dibujo, feedback inmediato.

---

## 2. Actores

| Actor | Descripción |
|-------|-------------|
| **Usuario final** | Profesional o estudiante que abre, consulta y edita planos |
| **Usuario experto CAD** | Usuario avanzado que usa línea de comandos, snapping y atajos |
| **Sistema (conversor DWG)** | Servicio/CLI externo que convierte DWG → DXF |

---

## 3. Requisitos funcionales

> Convención: `RF-n` = requisito funcional. Prioridad: **M**ust / **S**hould / **C**ould.

### 3.1 Carga de archivos (RF-CARGA)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-CARGA-01 | Abrir archivos `.dxf` y `.dwg` desde almacenamiento local mediante `file_picker` | M |
| RF-CARGA-02 | Abrir archivos por URI compartida (intent "Abrir con...") en Android/iOS | S |
| RF-CARGA-03 | Detectar formato por extensión y por contenido (magic bytes de DWG) | M |
| RF-CARGA-04 | Leer el contenido con manejo de errores (try-catch) y mensaje amigable | M |
| RF-CARGA-05 | Soportar archivos DXF ASCII de versiones R12, R2000 (R14), R2004, R2007, R2010, R2013, R2018 | M |
| RF-CARGA-06 | No soportar DXF binario en v1.0 (mostrar advertencia) | C |
| RF-CARGA-07 | Archivos DWG: en MVP mostrar mensaje de no soporte + guía de conversión; en v0.3+ convertir vía ODA File Converter (CLI local) | M |
| RF-CARGA-08 | Mostrar indicador de progreso determinada al parsear archivos grandes | M |
| RF-CARGA-09 | Cancelar la carga si el usuario lo desea | S |
| RF-CARGA-10 | Recuperar el último archivo abierto al reiniciar (preguntar al usuario) | C |

### 3.2 Historial y recientes (RF-RECIENTES)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-RECIENTES-01 | Guardar los últimos 10 archivos abiertos (ruta + fecha + miniatura) en `shared_preferences` | M |
| RF-RECIENTES-02 | Mostrar lista horizontal de recientes en Home con miniatura y nombre | M |
| RF-RECIENTES-03 | Tocar un reciente lo reabre; deslizar elimina el registro | S |
| RF-RECIENTES-04 | Persistir miniatura como imagen base64 en prefs (máx. ~100 KB cada una) | S |

### 3.3 Renderizado (RF-RENDER)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-RENDER-01 | Renderizar todas las entidades visibles con `CustomPainter` + `Canvas` | M |
| RF-RENDER-02 | Soportar zoom (pinch + botones) y pan (arrastre) con `InteractiveViewer` | M |
| RF-RENDER-03 | Doble toque = zoom en área (acercar 2x centrado en el punto) | S |
| RF-RENDER-04 | Ajuste a pantalla (fit-to-screen) que escala al 80% del viewport | M |
| RF-RENDER-05 | Colores por capa usando ACI (AutoCAD Color Index) con override por tema | M |
| RF-RENDER-06 | Grosor de línea según `lineWeight` y jerarquía por tipo de entidad (ver AESTHETICS.md) | S |
| RF-RENDER-07 | Grid cartesiano adaptable a la escala; tipos polar e isométrico | S |
| RF-RENDER-08 | Ejes X (rojo) / Y (azul) con flechas, ocultables, ocultos si el origen está fuera de vista | S |
| RF-RENDER-09 | Rendering de textos con `TextPainter` (interlineado, rotación, ancho) | M |
| RF-RENDER-10 | Rendering recursivo de bloques (INSERT) con transformación completa (escala, rotación, mirror opcional) | M |
| RF-RENDER-11 | Culling: solo renderizar entidades dentro del viewport (+20% margen) | M |
| RF-RENDER-12 | LOD: reducir detalle de textos/curvas a zoom lejano | S |
| RF-RENDER-13 | Cache de renderizado con `Picture` reutilizado entre frames | S |
| RF-RENDER-14 | Sombreados (HATCH): soporte básico de patrones sólidos y lineales; patrones complejos simplificados | S |
| RF-RENDER-15 | Cursor crosshair en el canvas (estilo AutoCAD) | S |

### 3.4 Entidades soportadas (RF-ENTIDADES)

| ID | Entidad | Leer | Renderizar | Editar | Prioridad |
|----|---------|------|------------|--------|-----------|
| RF-ENT-01 | LINE | ✅ | ✅ | ✅ | M |
| RF-ENT-02 | CIRCLE | ✅ | ✅ | ✅ | M |
| RF-ENT-03 | ARC | ✅ | ✅ | ✅ | M |
| RF-ENT-04 | ELLIPSE | ✅ | ✅ | ✅ | M |
| RF-ENT-05 | LWPOLYLINE | ✅ | ✅ | ✅ | M |
| RF-ENT-06 | POLYLINE (2D, pesada) | ✅ | ✅ | ✅ | M |
| RF-ENT-07 | TEXT | ✅ | ✅ | ✅ | M |
| RF-ENT-08 | MTEXT | ✅ | ✅ | ⚠️ básico (posición, contenido) | M |
| RF-ENT-09 | INSERT (bloque) | ✅ | ✅ | ⚠️ mover/escalar/rotar; editar contenido del bloque fuera de alcance v1.0 | M |
| RF-ENT-10 | POINT | ✅ | ✅ | ✅ | S |
| RF-ENT-11 | HATCH | ✅ (básico) | ✅ (básico) | ❌ v1.0 | S |
| RF-ENT-12 | SPLINE | ✅ | ✅ | ⚠️ mover; editar control points fuera de alcance | S |
| RF-ENT-13 | DIMENSION | ✅ | ✅ (básico) | ⚠️ mover | S |
| RF-ENT-14 | 3DFACE | ✅ | ✅ (proyección 2D) | ❌ v1.0 | C |
| RF-ENT-15 | Sólidos 3D, MESH, 3DSOLID | ⚠️ detectar y advertir | ❌ | ❌ | C |
| RF-ENT-16 | Entidades desconocidas | Conservar handle, advertir | ❌ | ❌ | M |

### 3.5 Capas (RF-CAPAS)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-CAPA-01 | Listar todas las capas del dibujo con nombre, color ACI y tipo de línea | M |
| RF-CAPA-02 | Alternar visibilidad de capa individual | M |
| RF-CAPA-03 | Presets: mostrar todas / ocultar todas | M |
| RF-CAPA-04 | Cambiar color de visualización de una capa (override, sin tocar el archivo) | M |
| RF-CAPA-05 | Bloquear capa (no editable pero visible) | S |
| RF-CAPA-06 | Crear nueva capa con nombre y color | S |
| RF-CAPA-07 | Renombrar capa | S |
| RF-CAPA-08 | Borrar capa vacía (con confirmación) | S |
| RF-CAPA-09 | Hacer capa actual (las entidades nuevas se crean en ella) | S |
| RF-CAPA-10 | Contador de entidades por capa | C |

### 3.6 Selección e inspección (RF-SELECCION)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-SEL-01 | Tap en entidad = seleccionar (hit-testing por tipo) | M |
| RF-SEL-02 | Tap en área vacía = deseleccionar | M |
| RF-SEL-03 | Selección múltiple con tap adicional (toggle) y selección por ventana/encuadre (arrastrar) | S |
| RF-SEL-04 | Selección por ventana de cruce (crossing, azul) y contención (window, verde) | C |
| RF-SEL-05 | Panel de propiedades de la entidad seleccionada (bottom sheet) | M |
| RF-SEL-06 | Resaltado visual con halo y animación de "respiración" | M |
| RF-SEL-07 | Eliminar selección con tecla ESC / botón | S |
| RF-SEL-08 | Seleccionar todas (Ctrl+A) y selección inversa | C |
| RF-SEL-09 | Selección en capa bloqueada: visible pero no seleccionable | S |

### 3.7 Edición (RF-EDICION)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-EDI-01 | Crear entidades: LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, TEXT, POINT (por gestos y/o comandos) | M |
| RF-EDI-02 | Mover entidades seleccionadas (arrastrar o por comando) | M |
| RF-EDI-03 | Rotar entidades seleccionadas | M |
| RF-EDI-04 | Escalar entidades seleccionadas | M |
| RF-EDI-05 | Borrar entidades seleccionadas (DEL) | M |
| RF-EDI-06 | Copiar (Ctrl+C) / Pegar (Ctrl+V) / Cortar (Ctrl+X) entidades | S |
| RF-EDI-07 | Duplicar (offset de copia) | S |
| RF-EDI-08 | Deshacer (Ctrl+Z) y Rehacer (Ctrl+Y) con pila de comandos | M |
| RF-EDI-09 | Límite de historial de undo: 100 operaciones | S |
| RF-EDI-10 | Editar propiedades de entidad (capa, color, grosor, texto, radio, longitud...) | S |
| RF-EDI-11 | Grips: puntos de edición visibles al seleccionar (mover vértices, estirar extremos) | S |
| RF-EDI-12 | Edición de texto (cambiar contenido) | S |
| RF-EDI-13 | Recorte/empalme (TRIM/FILLET) | C |
| RF-EDI-14 | Offset paralelo | C |
| RF-EDI-15 | Edición de polilínea (añadir/quitar vértices) | C |
| RF-EDI-16 | Mirror de entidades | C |

### 3.8 Snapping y precisión (RF-SNAP)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-SNAP-01 | Snap a punto final (endpoint) | M |
| RF-SNAP-02 | Snap a punto medio (midpoint) | M |
| RF-SNAP-03 | Snap a centro (center) | M |
| RF-SNAP-04 | Snap a intersección (intersection) | M |
| RF-SNAP-05 | Snap a punto de cuadrante (quadrant) | S |
| RF-SNAP-06 | Snap a punto (nearest) | S |
| RF-SNAP-07 | Snap a grid (rejilla) | S |
| RF-SNAP-08 | Snap polar (ángulos múltiplos de 15°/45°) | S |
| RF-SNAP-09 | Ortho (restricción a ejes X/Y) | M |
| RF-SNAP-10 | Indicador visual del snap activo (marcador) | M |
| RF-SNAP-11 | Configuración de modos de snap en Ajustes | M |
| RF-SNAP-12 | Tolerancia de snap adaptada al zoom (píxeles) | M |

### 3.9 Línea de comandos (RF-COMANDO)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-CMD-01 | Entrada de comandos estilo AutoCAD/LibreCAD (LINE, CIRCLE, ERASE, MOVE, ZOOM, LAYER...) | S |
| RF-CMD-02 | Entrada de coordenadas relativas y absolutas (`@10,5`, `#10,5`, `10<45`) | S |
| RF-CMD-03 | Autocompletado de comandos y ayuda contextual | C |
| RF-CMD-04 | Historial de comandos ejecutados | C |
| RF-CMD-05 | Atajos de teclado (hardware keyboard) en desktop/tablet | S |

### 3.10 Medición (RF-MEDICION)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-MED-01 | Medir distancia entre dos puntos | S |
| RF-MED-02 | Medir ángulo | S |
| RF-MED-03 | Calcular área (polígono cerrado o región) | S |
| RF-MED-04 | Mostrar cotas temporales en canvas durante la medición | S |

### 3.11 Unidades (RF-UNIDADES)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-UNI-01 | Unidades internas: siempre mm (normalizar al parsear) | M |
| RF-UNI-02 | Visualización configurable: mm, cm, m, pulgadas | M |
| RF-UNI-03 | Entrada de valores convertidos a la unidad de visualización | S |
| RF-UNI-04 | Leer unidad del encabezado DXF (`$INSUNITS`) y usarla como predeterminada | S |

### 3.12 Guardado y exportación (RF-GUARDADO)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-GUARD-01 | Guardar como DXF (R12 o R2000) el dibujo actual | M |
| RF-GUARD-02 | Guardar en el mismo archivo (sobrescribir) con confirmación | S |
| RF-GUARD-03 | Exportar vista actual a PNG respetando el tema | M |
| RF-GUARD-04 | Exportar PDF (básico, con opción de marco/título) | C |
| RF-GUARD-05 | Compartir archivo original con `share_plus` | M |
| RF-GUARD-06 | Autoguardado periódico del archivo en edición (cada 5 min) | S |
| RF-GUARD-07 | Diálogo "cambios sin guardar" al salir | M |
| RF-GUARD-08 | Exportar selección a DXF (solo entidades seleccionadas) | C |

### 3.13 Temas y estéticas (RF-TEMAS)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-TEMA-01 | Tema claro y oscuro base | M |
| RF-TEMA-02 | 4 estéticas profesionales: Blueprint Premium, Poster, Infografía, AutoCAD Dark (ver AESTHETICS.md) | M |
| RF-TEMA-03 | Selector de tema con previews en Ajustes | M |
| RF-TEMA-04 | Persistencia de tema elegido | M |
| RF-TEMA-05 | Exportación PNG respeta el tema | M |

### 3.14 Pantallas y navegación (RF-PANTALLAS)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-PANT-01 | HomeScreen: logo, botón "Abrir archivo", recientes, ajustes | M |
| RF-PANT-02 | ViewerScreen: canvas, AppBar, status bar de coordenadas, zoom controls | M |
| RF-PANT-03 | LayerPanel (bottom sheet en móvil, lateral en landscape) | M |
| RF-PANT-04 | PropertyPanel (bottom sheet con propiedades) | M |
| RF-PANT-05 | SettingsSheet: tema, unidades, grid, snap, comandos, versión | M |
| RF-PANT-06 | CommandBar: entrada de comandos/coordenadas (colapsable) | S |
| RF-PANT-07 | Toolbar de edición contextual (aparece con selección) | S |
| RF-PANT-08 | Onboarding de 3 pasos en primera ejecución | S |

### 3.15 Feedback y UX (RF-UX)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-UX-01 | Feedback háptico (light impact al seleccionar, medium al abrir paneles) | M |
| RF-UX-02 | Auto-ocultar controles tras 3 s de inactividad | S |
| RF-UX-03 | Controles con `BackdropFilter` blur 20px, radius 12dp | M |
| RF-UX-04 | Coordenadas del cursor siempre visibles en status bar | M |
| RF-UX-05 | Animaciones: fade-through, slide panels, halo de selección, zoom 200 ms | M |
| RF-UX-06 | Manejo de errores con SnackBar/Dialog claros | M |
| RF-UX-07 | Estado vacío (sin entidades / archivo vacío) | M |
| RF-UX-08 | Deshacer/rehacer con feedback visual (SnackBar breve) | S |

### 3.16 Accesibilidad (RF-ACCES)

| ID | Requisito | Prioridad |
|----|-----------|-----------|
| RF-ACC-01 | Contraste WCAG AA en textos de UI | M |
| RF-ACC-02 | Touch targets ≥ 44dp | M |
| RF-ACC-03 | Etiquetas semánticas para lectores de pantalla | S |
| RF-ACC-04 | Escalar tipografía según configuración del sistema | C |

---

## 4. Requisitos no funcionales (RNF)

### 4.1 Rendimiento

| ID | Requisito | Objetivo |
|----|-----------|----------|
| RNF-REND-01 | Parseo de DXF de 5 MB en dispositivo medio | < 2 s (en Isolate) |
| RNF-REND-02 | FPS durante pan/zoom con 5 MB/10 k entidades | ≥ 60 fps, sin jank |
| RNF-REND-03 | Latencia de apertura de archivo < 1 MB | < 300 ms |
| RNF-REND-04 | Memoria máxima en dibujo de 10 k entidades | < 250 MB |
| RNF-REND-05 | Límite recomendado de archivo para v1.0 | 10 MB (advertir si mayor) |

### 4.2 Compatibilidad de plataforma

| ID | Requisito |
|----|-----------|
| RNF-PLAT-01 | Android API 21+ |
| RNF-PLAT-02 | iOS 12+ |
| RNF-PLAT-03 | Windows 10+, macOS 12+, Linux (AppImage/deb) |
| RNF-PLAT-04 | Web: limitado (imports condicionales `dart:io` vs `dart:html`), sin DWG |

### 4.3 Fiabilidad

| ID | Requisito |
|----|-----------|
| RNF-FIAB-01 | Cero crashes ante archivos corruptos o vacíos |
| RNF-FIAB-02 | Todo acceso a archivos con try-catch y feedback |
| RNF-FIAB-03 | Verificación de `mounted` antes de `setState` asíncrono |
| RNF-FIAB-04 | Liberar recursos en `dispose` |

### 4.4 Seguridad y privacidad

| ID | Requisito |
|----|-----------|
| RNF-SEG-01 | Procesamiento local de archivos (sin upload) |
| RNF-SEG-02 | Advertencia explícita si se usa conversión DWG externa/remota |
| RNF-SEG-03 | No almacenar contenido de archivos en prefs (solo rutas y miniaturas) |
| RNF-SEG-04 | Permisos mínimos necesarios declarados por plataforma |

### 4.5 Mantenibilidad

| ID | Requisito |
|----|-----------|
| RNF-MANT-01 | Cobertura de tests unitarios ≥ 70% en parsers y modelos |
| RNF-MANT-02 | `dart format` y `flutter analyze` limpios |
| RNF-MANT-03 | Arquitectura por capas (ver ARCHITECTURE.md) sin dependencias circulares |
| RNF-MANT-04 | Conventional commits y CHANGELOG actualizado |

### 4.6 Localización

| ID | Requisito |
|----|-----------|
| RNF-LOC-01 | Strings extraídos (ARB) desde el inicio |
| RNF-LOC-02 | Idiomas v1.0: español, inglés |
| RNF-LOC-03 | Formato de números/coordenadas según locale |

---

## 5. User stories (resumen priorizado)

### Épica: Carga e inspección (v0.1)
1. Como arquitecto, quiero abrir un DXF de LibreCAD y ver el plano completo, para revisarlo en campo.
2. Como ingeniero, quiero hacer zoom/pan fluido, para inspeccionar detalles.
3. Como topógrafo, quiero ver coordenadas del cursor, para verificar medidas.
4. Como usuario, quiero ocultar capas, para enfocarme en una disciplina.

### Épica: Edición básica (v0.2)
5. Como delineante, quiero seleccionar y mover entidades con undo, para corregir el plano.
6. Como usuario, quiero crear líneas y círculos con snapping, para añadir anotaciones.
7. Como usuario, quiero borrar entidades con confirmación y undo, para limpiar el dibujo.
8. Como usuario, quiero guardar como DXF, para devolver el archivo al equipo.

### Épica: Edición avanzada (v0.3)
9. Como usuario experto, quiero línea de comandos y coordenadas relativas, para dibujar con precisión.
10. Como usuario, quiero grips y edición de propiedades, para ajustar geometría fina.
11. Como usuario, quiero abrir DWG convertido localmente (ODA), para revisar archivos de clientes.
12. Como usuario, quiero medir distancias, ángulos y áreas, para verificación.

---

## 6. Casos de borde y reglas de negocio

| # | Caso | Comportamiento |
|---|------|----------------|
| 1 | DXF sin entidades | Mostrar estado vacío con mensaje |
| 2 | DXF con entidades en capa inexistente | Crear capa implícita "0" al renderizar |
| 3 | ACI fuera de rango (0–255) | Fallback a blanco/gris |
| 4 | INSERT con bloque inexistente | Advertir y omitir |
| 5 | Archivo DWG | MVP: guía de conversión; v0.3+: ODA CLI |
| 6 | Texto con fuente no disponible | Usar fuente por defecto (Inter) |
| 7 | Coordenadas Z ≠ 0 en entidad 2D | Proyección ortogonal (ignorar Z) con nota |
| 8 | Unidades del encabezado ausentes | Asumir mm |
| 9 | Guardar sobre archivo de solo lectura | Pedir "Guardar como..." |
| 10 | Undo vacío / redo vacío | Botones deshabilitados |
| 11 | Selección en capa bloqueada | No seleccionable (visible) |
| 12 | Archivo > 10 MB | Advertencia de rendimiento |
| 13 | DXF binario | Aviso "convierta a DXF ASCII" |
| 14 | Entidad desconocida | Conservar handle, advertir en consola, omitir render |
| 15 | Grid con espaciado < 4 px | Simplificar grid (auto-escalado de paso) |

---

## 7. Priorización y alcance por versión

| Versión | Alcance |
|---------|---------|
| **v0.1.x (Visor)** | Carga DXF, renderizado completo, capas, zoom/pan, selección + propiedades, temas, recientes, PNG/share |
| **v0.2.x (Editor básico)** | Crear/mover/rotar/escalar/borrar, undo/redo, snap básico, ortho, guardar DXF, capas editables, medidas básicas |
| **v0.3.x (Editor avanzado)** | Línea de comandos, coordenadas relativas/polares, grips, edición de propiedades, DWG local (ODA CLI), trim/offset |
| **v1.0.0** | Estable, tests ≥ 70%, publicada en stores, i18n es/en |

Ver `docs/ROADMAP.md` para el detalle.
