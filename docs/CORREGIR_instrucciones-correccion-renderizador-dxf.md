```
ANÁLISIS COMPLETO DEL RENDERIZADOR CAD/DXF Y PLAN DE CORRECCIÓN

======================================================================
PROBLEMA FUNDAMENTAL
======================================================================

El motor de renderizado dibuja todas las entidades del archivo DXF simultáneamente, sin importar el nivel de zoom ni el área visible. Esto provoca:

- Miles de textos y cotas superpuestos formando una masa ilegible.
- Líneas infinitas o auxiliares que atraviesan todo el dibujo.
- Entidades fuera del área visible que contaminan la pantalla.
- Rendimiento deficiente al procesar todas las entidades en cada frame.
- Resaltados (highlight) excesivos que dibujan geometría adicional gigante.
- Una experiencia visual caótica, muy alejada de un visor CAD profesional.

======================================================================
SOLUCIÓN PROPUESTA: SISTEMA DE RENDERIZADO INTELIGENTE
======================================================================

El renderizador debe comportarse como AutoCAD, LibreCAD o DraftSight. Para ello, debe implementar un sistema basado en tres pilares:

1. Viewport Culling (descarte de entidades no visibles).
2. Viewport Clipping (recorte de geometría al área visible).
3. Level of Detail (LOD) progresivo según el zoom.

======================================================================
COMPONENTES DEL SISTEMA
======================================================================

A. VIEWPORT CULLING (DESCARTE POR VISIBILIDAD)

Antes de procesar cualquier entidad, se debe verificar si su Bounding Box (caja envolvente) intersecta el viewport (área visible de la pantalla).

- Si NO hay intersección: la entidad se descarta por completo. No se renderiza.
- Si SÍ hay intersección: la entidad pasa a la siguiente etapa.

Esto mejora drásticamente el rendimiento, la memoria y el consumo de CPU, especialmente en archivos grandes.

Recomendación: implementar un índice espacial (QuadTree, R-Tree, BVH o KD-Tree) para localizar rápidamente las entidades cercanas al viewport y no tener que recorrer todo el archivo en cada actualización.

======================================================================

B. VIEWPORT CLIPPING (RECORTE DE GEOMETRÍA)

Toda geometría que esté parcialmente visible debe recortarse a los límites exactos del viewport. Ninguna línea, polilínea o entidad debe extenderse fuera del área visible de la pantalla.

Esto aplica a todas las entidades:

- LINE
- LWPOLYLINE
- POLYLINE
- SPLINE
- ARC
- ELLIPSE
- RAY
- XLINE (líneas infinitas)
- DIMENSION (cotas)
- LEADER / MLEADER
- HATCH

Ninguna línea auxiliar, infinita o de referencia debe dibujarse completa. Deben recortarse automáticamente.

======================================================================

C. LEVEL OF DETAIL (LOD) POR ZOOM

La cantidad de información mostrada debe depender del nivel de zoom. No todas las entidades tienen la misma importancia.

CRITERIOS DE VISIBILIDAD:

C1. Tamaño mínimo de texto.
   Si el texto proyectado mide menos de aproximadamente 8 píxeles, NO debe renderizarse. Un texto tan pequeño no aporta información útil y genera ruido visual.

C2. Visibilidad de cotas.
   Las cotas solamente deben aparecer cuando el usuario haga suficiente zoom. A baja escala (vista general) deben ocultarse automáticamente.

C3. Niveles de detalle por distancia de zoom.

   ZOOM MUY LEJANO (Vista general del plano):
   - Muros
   - Columnas
   - Puertas
   - Ventanas
   - Polilíneas principales
   - Geometría estructural
   - Límites del plano

   OCULTAR:
   - Todos los textos (independientemente del tamaño)
   - Todas las cotas
   - Símbolos
   - Mobiliario
   - Bloques pequeños
   - Hatch
   - Detalles finos

   ZOOM INTERMEDIO:
   - Todo lo anterior
   - Nombres de ambientes
   - Símbolos principales
   - Bloques grandes
   - Equipamiento principal

   ZOOM CERCANO (Detalle):
   - Todo lo anterior
   - Todos los textos (respetando el tamaño mínimo de 8 píxeles)
   - Todas las cotas
   - Mobiliario
   - Bloques pequeños
   - Hatch
   - Todos los detalles finos

======================================================================

D. PRIORIDAD DE RENDERIZADO

No todas las entidades se dibujan en el mismo orden. Para mantener la legibilidad, se debe establecer un orden de prioridad:

1. Muros y geometría estructural
2. Columnas
3. Puertas
4. Ventanas
5. Polilíneas principales
6. Equipamiento
7. Bloques
8. Símbolos
9. Textos
10. Cotas
11. Hatch

El renderizado debe respetar este orden para que los elementos más importantes no queden ocultos por otros menos relevantes.

======================================================================

E. SELECCIÓN Y HIGHLIGHT (RESALTADO)

El sistema de selección actual presenta errores graves:

- Al tocar una entidad, se resaltan líneas celestes enormes que atraviesan toda la pantalla.
- Se resalta el Bounding Box completo o entidades relacionadas.
- Se seleccionan bloques completos o entidades hijas.

CORRECCIÓN:

- Al seleccionar una entidad, SOLAMENTE debe resaltarse ESA entidad.
- El resaltado debe ser sutil: cambio de color o ligero aumento de grosor.
- No debe crearse geometría adicional.
- No deben extenderse líneas.
- No deben dibujarse Bounding Boxes gigantes.
- La geometría de la entidad no debe modificarse ni desplazarse.

Comportamiento esperado: idéntico a AutoCAD. Al seleccionar una línea, solo esa línea cambia de color.

======================================================================

F. BLOQUES Y TRANSFORMACIONES

El renderizador debe manejar correctamente los bloques INSERT y sus transformaciones.

Verificar:

- INSERT
- BLOCK
- ATTRIB
- ATTDEF

Cada bloque debe renderizarse únicamente una vez, sin duplicar entidades.

Verificar las matrices de transformación para:

- Traslación
- Rotación
- Escala (incluyendo escala negativa y espejado)

Las entidades no deben desplazarse al seleccionarlas. La transformación debe ser precisa y estable.

======================================================================

G. RENDERIZADO DE CAPAS

El renderizador solo debe procesar y mostrar las capas que están visibles y activas. Las capas ocultas o desactivadas no deben consumir recursos ni aparecer en pantalla.

======================================================================

H. OPTIMIZACIONES ADICIONALES

Para mantener la fluidez, especialmente con archivos DXF grandes y complejos:

- Cache de geometría: no recalcular la geometría de cada entidad en cada frame.
- Cache de bloques: las definiciones de bloque deben calcularse una sola vez.
- Cache de textos: las geometrías de texto deben almacenarse en caché.
- Cache de hatch: los patrones de relleno deben estar precargados.
- Cache de polígonos: las geometrías complejas deben estar precalculadas.

El objetivo es que el renderizado sea rápido y estable, sin caídas de frames ni parpadeos.

======================================================================
RESULTADO ESPERADO
======================================================================

Al implementar todas estas correcciones, el visor CAD/DXF debe comportarse como un visor profesional (AutoCAD, LibreCAD, DraftSight).

COMPORTAMIENTO FINAL:

Al abrir un DXF en vista general:
- El plano completo se ve LIMPIO y ORDENADO.
- No aparecen líneas infinitas o auxiliares que sobresalgan del dibujo.
- No aparecen cientos de textos superpuestos.
- No aparecen miles de cotas cruzadas.
- Solo se muestra la geometría estructural principal (muros, columnas, puertas, ventanas).

Al hacer zoom:
- Aparecen progresivamente los detalles: nombres de ambientes, símbolos, equipamiento.
- Al acercarse más, aparecen todos los textos (respetando el tamaño mínimo), cotas, mobiliario, hatch y detalles finos.
- La transición es suave y gradual.

Al seleccionar una entidad:
- SOLAMENTE esa entidad se resalta (cambio de color o ligero grosor).
- No aparecen líneas celestes gigantes.
- No se modifica ni desplaza la geometría.
- No se dibujan Bounding Boxes enormes.

En todo momento:
- El renderizado es FLUIDO, incluso con archivos DXF muy grandes y complejos.
- La experiencia es ESTABLE, PRECISA y VISUALMENTE IDÉNTICA a la de un visor CAD profesional.

======================================================================
CONCLUSIÓN
======================================================================

El renderizador CAD/DXF debe corregirse implementando un sistema integrado de Viewport Culling, Viewport Clipping y Level of Detail (LOD). Estas tres técnicas, aplicadas conjuntamente, resuelven todos los problemas observados:

1. Eliminan la sobrecarga visual de textos, cotas y líneas.
2. Recortan y descartan geometría no visible.
3. Mejoran drásticamente el rendimiento.
4. Proporcionan una experiencia de usuario limpia y profesional.
5. Corrigen los errores de selección y resaltado.

El objetivo final es un visor CAD que funcione de manera idéntica a AutoCAD, con una interfaz limpia, rápida y precisa, independientemente del tamaño o complejidad del archivo DXF.
```
