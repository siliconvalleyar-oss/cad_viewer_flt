# CAD Viewer & Editor

**Current version:** 0.4.0 (documentación) · código: 1.0.0 · **Licencia:** [MIT](LICENSE.md)

Aplicación Flutter multiplataforma para **visualizar y editar** archivos CAD en formatos DXF, DWG y opcionalmente DGN. Compatible con archivos de **AutoCAD** y **LibreCAD**.

## Características

### Visor
- Apertura de archivos `.dxf` y `.dwg` desde almacenamiento local
- Renderizado de entidades: líneas, círculos, arcos, elipses, polilíneas, textos, bloques y sombreados
- Gestión de capas con visibilidad, bloqueo y color de visualización
- Zoom y pan con gestos táctiles (pellizco, arrastre, doble toque)
- Selección de entidades y consulta de propiedades
- Captura de pantalla y exportación a PNG
- Compartir archivo original
- Historial de archivos recientes
- 6 temas: claro, oscuro + 4 estéticas profesionales CAD (Blueprint, Poster, Infografía, AutoCAD Dark)
- Selección de unidades (mm, cm, m, pulgadas)

### Editor
- Creación de entidades: líneas, círculos, arcos, elipses, polilíneas, textos, puntos
- Mover, rotar, escalar, copiar y borrar con selección múltiple
- **Undo/redo completo** (patrón Command, pila de 100)
- Snapping: endpoint, midpoint, center, intersection, grid, polar + ortho
- Grips de edición directa (v0.3)
- Línea de comandos estilo AutoCAD/LibreCAD con coordenadas relativas/polares (v0.3)
- Herramientas de medición: distancia, ángulo, área
- Guardar como DXF (R12/R2000) con autoguardado
- Capas editables: crear, renombrar, cambiar color, borrar

## Stack

| Componente | Tecnología |
|------------|-----------|
| Framework | Flutter 3.x / Dart 3.x |
| Parsing DXF | `dxf ^1.3.0` + wrapper propio |
| Escritura DXF | `DxfWriter` propio |
| Estado | Provider + ChangeNotifier |
| Renderizado | CustomPainter + InteractiveViewer |
| Edición | Patrón Command + CommandStack propio |
| File picker | `file_picker` |
| Historial | `shared_preferences` |
| Screenshot | `screenshot` |
| Compartir | `share_plus` |
| Storage | `path_provider` |

## Estructura

```
lib/
├── main.dart
├── controllers/ (cad_view_model, command_stack, snap_engine, selection_manager)
├── models/ (cad_file, cad_entity, cad_layer, cad_block, cad_document, cad_enums)
├── parsers/ (dxf_parser, dxf_writer, dwg_parser)
├── renderers/ (cad_painter, layer_manager, grid_renderer, axis_renderer, grip_renderer, snap_renderer)
├── screens/ (home_screen, viewer_screen, layer_panel)
├── widgets/ (zoom_controls, property_panel, command_bar, toolbar_edit, recent_files_list)
└── utils/ (coordinate_transform, geometry, units, aci_colors, file_helper)
```

## Notas DWG

DWG es formato binario cerrado (sin parser Dart puro). Estrategia:
- **v0.1–v0.2:** mensaje de no soporte + guía para convertir a DXF
- **v0.3+:** conversión local con ODA File Converter (gratuito, multiplataforma, CLI)
- Servicios cloud (Apryse, CloudConvert) como opción futura con consentimiento explícito

## Manual de usuario

### 1. Instalación

| Plataforma | Cómo se instala |
|------------|-----------------|
| Android | Instalar el APK/AAB desde Google Play o el archivo `.apk` |
| iOS | Desde App Store |
| Windows / macOS / Linux | Instalador o binario portable |
| Web | Abrir la URL; se usa el navegador (limitaciones en DWG) |

### 2. Primeros pasos — abrir un plano

1. En la pantalla de inicio, toca **“Abrir archivo”**.
2. Selecciona un archivo `.dxf` (o `.dwg` según versión).
3. El dibujo se ajusta automáticamente a la pantalla (fit).
4. Usa **un dedo para arrastrar** (pan), **pellizco para zoom** y **doble toque para acercar**.
5. La barra inferior muestra las coordenadas del cursor: `(X: 123.45, Y: 678.90)`.

### 3. Navegación en el visor

| Acción | Gesto / control |
|--------|-----------------|
| Mover la vista (pan) | Arrastrar con un dedo |
| Zoom | Pellizcar con dos dedos |
| Zoom en un punto | Doble toque |
| Zoom con botones | Botones flotantes `+` / `−` (abajo a la derecha) |
| Ajustar dibujo a pantalla | Botón **fit** (⤢) en la barra superior o el control flotante |
| Abrir/cerrar panel de capas | Botón **Capas** (abajo a la izquierda) |

### 4. Capas

- **Mostrar/ocultar:** toca el interruptor junto al nombre de la capa.
- **Presets:** botones *Mostrar todas* / *Ocultar todas*.
- **Color de visualización:** cambia el color en pantalla sin alterar el archivo (útil en temas oscuros).
- **Bloquear:** hace la capa visible pero no editable.
- **Crear/renombrar/borrar** capas (disponible en el menú de capa) — *según versión (v0.2+)*.

### 5. Seleccionar y consultar entidades

- **Toca una entidad** para seleccionarla: se resalta y aparece el panel de propiedades (tipo, capa, color, geometría).
- **Toca fuera** o pulsa ESC para deseleccionar.
- **Selección múltiple:** mantén Shift y toca; o arrastra para selección por ventana (verde = contenidas, azul = tocadas).
- `Ctrl+A` selecciona todo; `Ctrl+C / Ctrl+V / Ctrl+X` copia, pega y corta.

### 6. Edición

> Disponible según versión (v0.2+). Consulta `docs/EDITING.md` para el detalle.

**Crear entidades** (toolbar de dibujo): Line, Circle, Arc, Ellipse, Polyline, Text, Point. Al tocar el primer punto, un preview elástico te guía; ESC termina.

**Transformar la selección:** la toolbar contextual permite Mover, Rotar, Escalar, Copiar y Borrar.

**Snapping (precisión):** al dibujar o mover, el cursor “magnetiza” a puntos finales, medios, centros e intersecciones. El indicador muestra el tipo de snap activo. `F8` activa/desactiva ortho (solo ejes X/Y); `F3` activa/desactiva snap.

**Grips:** al seleccionar, aparecen puntos de control para ajustar la geometría directamente (extremos, radios, vértices).

**Deshacer/Rehacer:** `Ctrl+Z` / `Ctrl+Y` (o botones). Toda operación de edición se puede deshacer.

**Medición:** comandos `DIST`, `ANGLE` y `AREA` (o desde la toolbar) muestran distancia, ángulo y área sin crear entidades.

### 7. Guardar y exportar

| Acción | Cómo |
|--------|------|
| Guardar como DXF | Toolbar → Guardar (o `Ctrl+S`); eliges DXF **R2000** (por defecto) o **R12** (máxima compatibilidad) |
| Captura PNG | Botón de captura: guarda la vista actual como imagen, respetando el tema |
| Compartir archivo original | Botón Compartir en la barra superior |

- **Autoguardado:** cada 5 minutos se guarda una copia de seguridad; al reabrir se ofrece restaurarla.
- Al salir con cambios sin guardar, la app pregunta antes de continuar.

### 8. Formatos soportados

| Formato | Soporte |
|---------|---------|
| **DXF ASCII** (R12, R2000, R2004, R2007, R2010, R2013, R2018) | Lectura y escritura completa |
| **DXF binario** | No soportado en v1.0 (se avisa y se guía a convertir a ASCII) |
| **DWG** | v0.1–0.2: guía de conversión; v0.3+: conversión local con ODA File Converter |
| **DGN** | Fuera de alcance en v1.0 |

Los archivos de **LibreCAD** (exportados en DXF R12) son totalmente compatibles.

### 9. Temas y ajustes

- **6 temas:** Claro, Oscuro, Blueprint Premium, Poster, Infografía y AutoCAD Dark (Ajustes → Tema, con vista previa).
- **Unidades:** mm, cm, m o pulgadas (Ajustes → Unidades). Internamente la app trabaja en mm.
- **Grid y ejes:** configura el tipo de rejilla y la visibilidad de los ejes X/Y.
- **Snap:** activa/desactiva cada modo y ajusta la tolerancia.

### 10. Solución de problemas (FAQ)

| Problema | Solución |
|----------|----------|
| “No se pudo leer el archivo” | Asegúrate de que es un DXF ASCII válido; si es binario, conviértelo a ASCII |
| No puedo abrir un DWG | Convierte el archivo a DXF (v0.1–0.2) o instala ODA File Converter (v0.3+) |
| El dibujo se ve cortado | Pulsa el botón **fit** para ajustar a pantalla |
| Se ve muy lento con archivos grandes | Cierra otras apps; se recomienda archivos < 10 MB |
| Borré algo por error | `Ctrl+Z` (o botón deshacer) lo restaura |
| Cambios sin guardar | La app avisa al salir; usa el autoguardado para recuperar la sesión |

---

## Compilación

```bash
flutter pub get
flutter run
flutter build apk --debug
```

## Documentación

| Documento | Contenido |
|-----------|-----------|
| `docs/REQUIREMENTS.md` | Requisitos funcionales y no funcionales (visor + editor) |
| `docs/ARCHITECTURE.md` | Arquitectura, capas, módulos, flujos de datos |
| `docs/DATA_MODEL.md` | Modelo de datos completo (CadFile, CadDocument, comandos) |
| `docs/FORMATS.md` | Formatos CAD: DXF, DWG, DGN, compatibilidad LibreCAD |
| `docs/DXF_WRITER_SPEC.md` | **Spec del escritor DXF**: group codes de salida R12/R2000, precisión y round-trip |
| `docs/EDITING.md` | Sistema de edición: comandos, undo/redo, snapping, grips, línea de comandos |
| `docs/DESIGN.md` | Visión de diseño visual y UX (delega en DESIGN_SYSTEM) |
| `docs/DESIGN_SYSTEM.md` | **Sistema de diseño**: tokens (espaciado, radios, elevación, opacidad, color, tipografía, breakpoints), estados de componentes, motion, iconografía, accesibilidad |
| `docs/UX_FLOWS.md` | **UX**: personas, arquitectura de información, flujos Mermaid, matriz de estados de UI, microcopy, ergonomía (thumb/pen) |
| `docs/AESTHETICS.md` | 6 estéticas profesionales CAD con paletas e implementación |
| `docs/SERIALIZATION.md` | Contrato de serialización (DTOs, Isolates, round-trip, persistencia) |
| `docs/ERROR_HANDLING.md` | Taxonomía de errores ERR-XXX, ErrorHandler, logging con privacidad |
| `docs/API.md` | API de modelos, parsers, state management, renderers |
| `docs/DEVELOPMENT.md` | Guía de desarrollo y fases |
| `docs/PERFORMANCE.md` | Presupuesto y estrategia de rendimiento |
| `docs/TESTING.md` | Estrategia de pruebas y CI |
| `test/files/` | Archivos DXF/DWG de muestra para parsers, writers y round-trip (manifest en `test/files/README.md`) |
| `docs/SECURITY.md` | Seguridad y privacidad |
| `docs/PRIVACY.md` | Política de privacidad (para Google Play / App Store) |
| `docs/ADR.md` | Decisiones de arquitectura |
| `docs/ROADMAP.md` | Roadmap versionado v0.1 → v1.0 |
| `docs/TODO.md` | Lista de tareas por fases |
| `docs/PROMPT.md` | Prompt para generar la app |
| `docs/GLOSSARY.md` | Glosario de términos |
| `docs/CORRECTIONS.md` | Análisis de discrepancias y correcciones |
| `docs/skills/` | Skills detallados para IA/desarrolladores |
