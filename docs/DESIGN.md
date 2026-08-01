# Diseño Visual y Experiencia de Usuario — CAD Viewer & Editor

**Versión:** 0.3.0 · **Estado:** Aprobado (equipo de diseño)
**Equipo responsable:** Design Lead · UX · Motion  
**Propósito:** Visión de diseño visual y UX de la aplicación CAD Viewer & Editor Flutter. **Los tokens autoritativos (espaciado, radios, elevación, opacidad, color semántico, tipografía, breakpoints, motion, estados de componente, accesibilidad) viven en `docs/DESIGN_SYSTEM.md`**. Este documento describe la intención de diseño a alto nivel; la tabla de paleta en §2.2 es la referencia visual de los temas base, cuyos roles formales están definidos en DESIGN_SYSTEM.md §2.5.

## Índice

1. [Filosofía](#1-filosofía-de-diseño)
2. [Identidad visual](#2-identidad-visual)
3. [Pantallas](#3-diseño-de-pantallas)
4. [Componentes](#4-componentes-específicos)
5. [Landscape](#5-adaptabilidad-landscape)
6. [Animaciones](#6-animaciones-y-microinteracciones)
7. [Assets](#7-assets-e-icono-launcher)
8. [Características adicionales](#8-características-adicionales)
9. [Requisitos de sistema](#9-requisitos-de-sistema)
10. [Implementación](#10-especificaciones-de-implementación)
11. [Checklist](#11-checklist-de-verificación)

> **Tokens, estados y motion:** ver `docs/DESIGN_SYSTEM.md`. **Flujos y estados de UI:** ver `docs/UX_FLOWS.md`. **Estéticas temáticas:** ver `docs/AESTHETICS.md`.

---

## 1. Filosofía de Diseño

La aplicación se concibe como herramienta profesional de visualización de planos CAD para arquitectos, ingenieros y diseñadores. El diseño transmite precisión, claridad y minimalismo.

### Pilares de UX

1. **Inmersión en el dibujo** — El área de visualización ocupa el máximo espacio. Controles discretos y semitransparentes que no interfieren con la lectura del plano.
2. **Control intuitivo** — Gestos naturales (pinch, pan, tap) y botones contextuales que aparecen solo cuando se necesitan.
3. **Feedback inmediato** — Respuesta visual clara y háptica (vibración ligera) en cada acción.

---

## 2. Identidad Visual

### 2.1 Logotipo y Animación

- **Logo:** `assets/logo.svg` (vectorial). Símbolo abstracto de planos técnicos (cuadrícula, compás, intersección de líneas) + nombre de la app en tipografía sans-serif geométrica.
- **Splash screen:** Animación de trazado (`stroke-dashoffset`) durante 1.5s con desvanecimiento. Usar `AnimationController` o Rive.
- **Loading:** Mientras se parsean archivos pesados, logo en miniatura + indicador de progreso circular.

### 2.2 Paleta de Colores

| Elemento               | Modo Claro                 | Modo Oscuro                |
|------------------------|----------------------------|----------------------------|
| Fondo de la app        | `#F5F7FA`                  | `#1A1D23`                  |
| Fondo del lienzo       | `#FFFFFF`                  | `#1E2128`                  |
| Rejilla                | `#D0D5DD` (trazo fino)     | `#3A3F4A` (trazo fino)     |
| Eje X                   | `#E53E3E`                  | `#FC8181`                  |
| Eje Y                   | `#2B6CB0`                  | `#63B3ED`                  |
| Texto principal         | `#1A202C`                  | `#EDF2F7`                  |
| Texto secundario        | `#4A5568`                  | `#A0AEC0`                  |
| Acentos (botones)       | `#3182CE`                  | `#63B3ED`                  |
| Capas (colores)         | Respetar ACI original, permitir override |

**Controles:** Fondo semitransparente con `BackdropFilter` (blur 20px), bordes redondeados 12dp.

### 2.3 Tipografía

- **Familia:** Inter (variable) + JetBrains Mono (coordenadas/medidas)
- **Escala:** ver `type.*` en `docs/DESIGN_SYSTEM.md` §2.6
- **Interlineado:** 1.5x

### 2.4 Iconografía

- Estilo: Feather Icons o Material Icons con trazo uniforme 1.5px
- Tamaños: 24dp (botones), 16dp (listas)

---

## 3. Diseño de Pantallas

### 3.1 Pantalla de Inicio (Home)

```
┌─────────────────────────────────────────────┐
│  [logo] CAD Viewer                    [⚙️]  │
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│            [📁 Abrir archivo]               │
│                                             │
│                                             │
│  Recientes                                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │ 📄 file1 │ │ 📄 file2 │ │ 📄 file3 │       │
│  └─────────┘ └─────────┘ └─────────┘       │
│                                             │
└─────────────────────────────────────────────┘
```

- Botón "Abrir archivo" grande, centrado, con elevación
- Lista horizontal de recientes con miniatura/placeholder
- Transición a Viewer: fade-through

### 3.2 Pantalla de Visualización (Viewer)

```
┌─────────────────────────────────────────────┐
│ ← file.dxf    [Fit] [ℹ️]                     │
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│                                             │
│               CANVAS CAD                     │
│                                             │
│                                             │
│                                             │
│ [+] [-]                           [Layers]  │
├─────────────────────────────────────────────┤
│ (X: 123.45, Y: 678.90)            v1.0.0   │
└─────────────────────────────────────────────┘
```

**AppBar:**
- Fondo translúcido con `BackdropFilter` blur
- Botón retroceso, nombre archivo truncado, botón fit-to-screen, botón info
- En landscape: altura 44dp, nombre se acorta

**Controles flotantes:**
- Zoom: bottom-right, botones + y - apilados con indicador de porcentaje
- Capas: bottom-left, botón para abrir panel
- Auto-ocultar tras 3s de inactividad

**Panel de capas:** BottomSheet en móvil, panel lateral fijo en landscape

**Panel de propiedades:** Bottom sheet 40% altura en móvil, ventana flotante en desktop

### 3.3 Pantalla de Ajustes (Settings)

Accesible desde icono engranaje en Home:
- Tema: claro / oscuro / automático
- Unidades: mm / pulgadas / metros
- Rejilla: tipo y espaciado
- Mostrar/ocultar ejes
- Versión de la app (desde pubspec)
- Política de privacidad (opcional)

---

## 4. Componentes Específicos

### 4.1 Rejilla y Ejes

**Rejilla:**
- Cartesianas: líneas cada 10/50/100 unidades (según escala)
- Polar: círculos concéntricos + radios
- Isométrica: líneas a 30° y 150°
- Opacidad: 0.3 (claro), 0.2 (oscuro)
- Tipos seleccionables desde ajustes

**Ejes X/Y:**
- Líneas continuas por el origen (0,0)
- Color: rojo (X), azul (Y)
- Flecha en extremo positivo + etiqueta "X"/"Y"
- Ocultar si origen fuera de vista o por configuración

### 4.2 Indicador de Coordenadas

Barra inferior fija:
- Formato: `(X: 123.45, Y: 678.90)`
- Muestra coordenadas del cursor al arrastrar
- Al seleccionar entidad: coordenadas de inserción/centro
- Fondo semitransparente, siempre visible

### 4.3 Controles de Zoom

- Zoom doble: gesto pellizco + botones
- Botones flotantes: `+`, `-`, fit-to-screen
- Mantener presionado → zoom acelerado
- Indicador de porcentaje entre botones
- Animación de zoom: `Curves.fastOutSlowIn` 200ms

### 4.4 Selección de Entidades

- Tap en entidad → resaltado con halo azul (trazo discontinuo 2px)
- Animación de "respiración" (opacidad oscilante) 1s
- Panel de propiedades emerge automáticamente
- Selección se mantiene hasta tap en área vacía o nueva selección

---

### 4.5 Diseño de Edición (v0.2+)

### Toolbar de edición contextual
- Aparece al seleccionar entidades (bottom center, flotante).
- Controles: Mover, Rotar, Escalar, Copiar, Borrar, Propiedades, y (al crear) Line, Circle, Arc, Ellipse, Polyline, Text, Point.
- Mismo lenguaje visual que los demás controles: BackdropFilter blur 20px, radius 12dp, auto-ocultar 3s.

### CommandBar (línea de comandos)
- Barra inferior colapsable con campo de entrada, historial y autocompletado.
- Estado activo resaltado en borde (acento del tema).
- En desktop/tablet: atajos de teclado (ver `docs/EDITING.md` §7.4).

### Grips y selección
- Grips: cuadrados 8dp azules (huecos) / rojos (activos), dibujados en la capa overlay del canvas.
- Selección múltiple: color de ventana verde (window) / azul (crossing) con opacidad 0.15 y borde 1.5px.
- Halo de selección: azul discontinuo 2px con animación "respiración" (opacidad 0.6→1.0, 1s).

### Snap indicator
- Marcador geométrico según modo: endpoint (cuadrado), midpoint (triángulo), center (círculo), intersection (X), nearest (rombo).
- Color amarillo por defecto, contrastado en todos los temas.
- Tamaño 12dp, no interfiere con la lectura del plano.

### Status bar durante edición
- Muestra el punto snapped actual y las coordenadas del cursor: `(X: 123.45, Y: 678.90) — Snap: END`.
- Durante creación, muestra longitud/radio en vivo (ej: `L=50.00`).

### 4.6 Modo Edición y Preview en Vivo

Durante gestos de creación/transformación el canvas muestra **preview sin mutar el documento**:
- Línea elástica (rubber band) con color de la capa actual.
- Círculo/arco con radio en vivo y lectura de valor en status bar.
- Mover: las entidades siguen al cursor con halo translúcido; al soltar se ejecuta el comando.

Regla: el documento solo cambia al **commit** del comando (ver `docs/EDITING.md` §3).

---

## 5. Adaptabilidad Landscape

### Reglas

- **AppBar:** altura 44dp, nombre truncado
- **Coordenadas:** mover a lateral (left/right)
- **Paneles:** laterales fijos en lugar de bottom sheets
  - Capas → panel derecho
  - Propiedades → panel izquierdo
- **Zoom controls:** bottom-right, tamaño reducido
- **Transición:** `OrientationBuilder` sin recargar dibujo

---

## 6. Animaciones y Microinteracciones

| Acción                      | Animación                          | Duración |
|-----------------------------|------------------------------------|----------|
| Apertura de archivo         | Fade-through Home → Viewer         | 300ms    |
| Panel de capas              | Slide easeOutCubic                 | 300ms    |
| Selección de entidad        | Halo "respiración" opacidad        | 1000ms   |
| Zoom con botones            | Curves.fastOutSlowIn               | 200ms    |
| Botón presionado            | Elevación reducida                 | 100ms    |
| Splash logo                 | Stroke-dash trazado + fade         | 1500ms   |

**Feedback háptico:**
- Light impact al seleccionar entidad
- Medium impact al abrir/cerrar paneles

---

## 7. Assets e Icono Launcher

- **Icono launcher:** Generado desde `assets/logo.svg` con `flutter_launcher_icons`
  - Densidades: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
  - iOS: todas las resoluciones requeridas
- **Logo en app:** `assets/logo.svg` escalado
- **Fuentes:** `assets/fonts/Inter.ttf`, `assets/fonts/JetBrainsMono.ttf`
- **Otros assets:** iconos SVG para rejilla, ejes, capas (opcional, Feather Icons recomendado)

---

## 8. Características Adicionales

### 8.1 Onboarding

- Primera ejecución: tour guiado 3 pasos (gestos, capas, selección)
- Ilustraciones animadas
- Opción "Omitir" + acceso posterior desde Ajustes

### 8.2 Manejo de Errores y Carga

- Diálogos claros: "Versión de DXF no reconocida", "Entidades no soportadas"
- Barra de progreso determinada (basada en tamaño de archivo)
- Botón cancelar durante carga
- Recuperación de sesión: al reabrir, preguntar restaurar último archivo

### 8.3 Modos de Visualización

- **Alto contraste:** invertir colores para exteriores
- **Nocturno:** reducir luminosidad de rejilla y ejes
- **Filtro rápido:** ocultar todos los textos, cotas o entidades de un tipo

### 8.4 Configuración Avanzada

- Espaciado personalizado de rejilla (ej. cada 5mm)
- Unidad de visualización (mm, cm, m, pulgadas)
- Ajuste de origen (0,0) a punto arbitrario

### 8.5 Exportación Profesional

- PNG con opción de incluir/excluir rejilla, ejes, marco
- PDF con metadatos del plano
- Compartir con compresión ZIP si archivo grande

### 8.6 Seguridad

- Procesamiento local (no upload a servidor)
- Advertencia explícita si se usa conversión DWG externa
- Política de privacidad accesible

### 8.7 Rendimiento

- Cache de renderizado: `Picture` reutilizado entre frames
- Culling: solo entidades en viewport (+20% margen)
- LOD: reducir detalle a zoom lejano
- Parseo en `Isolate` para archivos > 1MB

### 8.8 Accesibilidad

- Etiquetas semánticas para lectores de pantalla
- Tamaño mínimo de toque: 44dp
- Contraste WCAG AA en textos

---

## 9. Requisitos de Sistema

- **System bars:** Usar `SystemChrome` y `SafeArea` para evitar solapamientos
- **Landscape:** Adaptar layout con `OrientationBuilder`
- **Plataformas:**
  - Android API 21+
  - iOS 12+
  - Windows, macOS
  - Web: limitado (import condicional `dart:io` vs `dart:html`)
- **Versión en configuración:** Leer desde `pubspec.yaml`

---

## 10. Especificaciones de Implementación

### Tema

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF3182CE),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  fontFamily: 'Inter',
  appBarTheme: AppBarTheme(
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  ),
)
```

### BackdropFilter para controles

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.7),
    borderRadius: BorderRadius.circular(12),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: ...,
  ),
)
```

### SafeArea

```dart
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        AppBar(...),
        Expanded(child: CadView(...)),
        StatusBar(...),
      ],
    ),
  ),
)
```

### OrientationBuilder

```dart
OrientationBuilder(
  builder: (context, orientation) {
    final isLandscape = orientation == Orientation.landscape;
    return Row(
      children: [
        Expanded(child: ViewerScreen(...)),
        if (isLandscape) LayerPanel(...),
      ],
    );
  },
)
```

---

## 11. Checklist de Verificación

- [ ] Logo SVG animado en splash (1.5s)
- [ ] Paleta de colores aplicada en ambos temas
- [ ] Tipografía Inter + JetBrains Mono cargada
- [ ] Rejilla dibujada en canvas con opacidad correcta
- [ ] Ejes X/Y con colores y flechas
- [ ] AppBar con blur y translucidez
- [ ] Controles flotantes con backdrop blur
- [ ] Auto-ocultar controles tras 3s de inactividad
- [ ] Panel de capas como BottomSheet / lateral
- [ ] Panel de propiedades como bottom sheet
- [ ] Transiciones suaves entre pantallas
- [ ] Feedback háptico en acciones clave
- [ ] Onboarding en primera ejecución
- [ ] Manejo de errores con diálogos informativos
- [ ] Status bar con coordenadas siempre visible
- [ ] Landscape adaptado con OrientationBuilder
- [ ] Icono launcher generado para todas las densidades
- [ ] Accesibilidad: etiquetas semánticas, 44dp mínimo
- [ ] Toolbar de edición contextual con blur y auto-ocultar
- [ ] CommandBar colapsable con autocompletado
- [ ] Grips con estados activo/inactivo
- [ ] Indicador de snap por modo (formas distintas)
- [ ] Status bar muestra snap activo y medidas en vivo
- [ ] Preview en vivo sin mutar el documento durante gestos
- [ ] Ventanas de selección window/crossing con colores diferenciados
