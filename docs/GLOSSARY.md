# Glosario — CAD Viewer & Editor

**Versión:** 0.3.0
**Fecha:** 2026-07-31
**Propósito:** Definiciones de términos CAD y de la aplicación para alinear al equipo, a las IAs colaboradoras y a los reviewers.

---

## A

| Término | Definición |
|---------|------------|
| **ACI (AutoCAD Color Index)** | Índice de color 1–255 usado en DXF para colorear entidades/capas. 7 = blanco, 1–6 colores primarios, 256 = ByLayer. |
| **AppBar** | Barra superior de Material con título y acciones (back, fit, info). |
| **Arc** | Entidad de arco: centro, radio, ángulo inicial/final. |
| **ARB** | Formato de recursos de localización de Flutter (`app_en.arb`). |

## B

| Término | Definición |
|---------|------------|
| **Block** | Conjunto reutilizable de entidades con punto base; se inserta con `INSERT`. |
| **Bulge** | Valor que describe la curvatura de un segmento de polilínea en DXF: `bulge = tan(θ/4)`. 0 = recto. |
| **ByLayer / ByBlock** | Modo de herencia de color/grosor: la entidad toma el valor de su capa (o del bloque). |

## C

| Término | Definición |
|---------|------------|
| **CadDocument** | Sesión de trabajo editable (entidades, capas, selección, dirty). Distinto del archivo (`CadFile`). |
| **CadFile** | Modelo del contenido de un archivo CAD (header, capas, entidades, bloques). |
| **CadEntity** | Entidad geométrica del dibujo (línea, círculo, texto...). |
| **Culling** | No dibujar entidades fuera del viewport. |
| **Crossing selection** | Selección por ventana azul (derecha→izquierda): entidades que tocan el rectángulo. |
| **CommandStack** | Pila de comandos ejecutados para undo/redo. |
| **CommandBar** | Línea de entrada de comandos estilo AutoCAD/LibreCAD. |
| **Control points (CP)** | Puntos de control de una spline. |

## D

| Término | Definición |
|---------|------------|
| **DGN** | Formato binario de MicroStation (Bentley). Fuera de alcance v1.0. |
| **Dimension** | Entidad de cota (DIM). Mide y muestra una distancia/ángulo. |
| **Dirty flag** | Indicador de que hay cambios sin guardar. |
| **DWG** | Formato binario propietario de Autodesk. |
| **DXF** | Drawing Exchange Format: formato de texto ASCII de AutoCAD, abierto. |

## E

| Término | Definición |
|---------|------------|
| **Endpoint** | Punto extremo de una entidad (modo de snap). |
| **Entity** | Elemento geométrico básico del dibujo. |
| **Extents (extMin/extMax)** | Límites del dibujo (bounding box global). |
| **Extrusión (210/220/230)** | Vector normal del plano de la entidad. |

## F

| Término | Definición |
|---------|------------|
| **Fit to screen** | Ajustar el dibujo al 80% del viewport, centrado. |
| **Frozen layer** | Capa no renderizada ni editable (diferente de invisible). |

## G

| Término | Definición |
|---------|------------|
| **Grip** | Punto de control de edición directa mostrado al seleccionar una entidad. |
| **Grid** | Rejilla de referencia cartesiana/polar/isométrica. |
| **Group codes** | Pares código/valor que estructuran el DXF (10=X, 20=Y, 8=capa...). |

## H

| Término | Definición |
|---------|------------|
| **Handle** | Identificador único de entidad en el archivo (código 5). |
| **Hatch** | Sombreado/relleno con patrón dentro de un contorno. |
| **Hit-testing** | Detección de qué entidad está bajo un punto del canvas. |

## I

| Término | Definición |
|---------|------------|
| **INSERT** | Referencia a un bloque (instancia) con posición, escala y rotación. |
| **Intersection** | Punto de cruce de dos entidades (modo de snap). |
| **Isolate** | Hilo de Dart para procesamiento pesado fuera del hilo de UI. |

## L

| Término | Definición |
|---------|------------|
| **Layer** | Capa: agrupación de entidades con color/tipo de línea/visibilidad. |
| **LOD (Level of Detail)** | Reducir detalle al alejar el zoom. |
| **Locked layer** | Capa visible pero no editable ni seleccionable. |
| **LWPOLYLINE** | Polilínea ligera (R14+): vértices en bloque contiguo. |

## M

| Término | Definición |
|---------|------------|
| **Memento** | Patrón que captura el estado previo para undo (snapshot). |
| **Midpoint** | Punto medio de un segmento (modo de snap). |
| **MTEXT** | Texto multilínea con códigos de formato. |
| **Model space** | Espacio de dibujo (frente a paper space). |

## O

| Término | Definición |
|---------|------------|
| **ODA File Converter** | Herramienta gratuita de Open Design Alliance que convierte DWG ↔ DXF (CLI/GUI). |
| **Ortho** | Restricción de entrada a ejes X/Y (F8). |
| **Offset** | Copia paralela a distancia dada. |

## P

| Término | Definición |
|---------|------------|
| **Pan** | Desplazar la vista sin cambiar el zoom. |
| **Point** | Entidad de punto. |
| **POLYLINE** | Polilínea pesada (R12): vértices como subentidades VERTEX + SEQEND. |
| **Polar snap** | Snap a ángulos múltiplos de un paso (15° por defecto). |
| **PropertyPanel** | Hoja inferior con propiedades de la entidad seleccionada. |

## R

| Término | Definición |
|---------|------------|
| **R12 / R2000 / R2010** | Versiones de DXF (códigos `$ACADVER`: AC1009, AC1015, AC1024...). |
| **Round-trip** | Parse → write → parse produce el mismo modelo. |
| **Rubber band** | Línea elástica de preview durante creación/edición. |

## S

| Término | Definición |
|---------|------------|
| **SAF (Storage Access Framework)** | Mecanismo de Android 5+ para acceder a archivos sin permisos crudos. |
| **Snap** | Magnetismo de cursor a puntos geométricos (endpoint, midpoint, center...). |
| **Spatial index** | Estructura (grid hash / R-tree) para acelerar búsquedas por cercanía. |
| **SPLINE** | Curva suave definida por puntos de control y nudos. |
| **Sweep** | Gestos/panel que se desliza desde el borde (bottom sheet). |

## T

| Término | Definición |
|---------|------------|
| **TextPainter** | Clase de Flutter para dibujar texto en canvas. |
| **TRIM** | Comando de recorte de entidades. |

## U

| Término | Definición |
|---------|------------|
| **Undo/Redo** | Deshacer/rehacer operaciones vía CommandStack. |
| **UnitsType** | Enumerado de unidades (mm, cm, m, inch...). Internamente mm. |

## V

| Término | Definición |
|---------|------------|
| **VERTEX/SEQEND** | Subentidades que componen una POLYLINE pesada en DXF. |
| **Version counters** | Contadores en el ViewModel para rebuild selectivo. |
| **Viewport** | Área visible del canvas. |

## W

| Término | Definición |
|---------|------------|
| **Window selection** | Selección por ventana verde (izquierda→derecha): entidades contenidas. |

---

## Siglas de la documentación

| Sigla | Significado |
|-------|-------------|
| ADR | Architecture Decision Record |
| DoD | Definition of Done |
| FRD | Functional Requirements Document |
| NFR | Non-Functional Requirements |
| QA | Quality Assurance |
| RF | Requisito Funcional |
| RNF | Requisito No Funcional |
