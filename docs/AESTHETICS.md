# Estéticas de Visualización — CAD Viewer & Editor

**Versión:** 0.3.0  
**Propósito:** Documento de referencia visual con las estéticas profesionales de planos CAD/autocad y su aplicación en la app. Complementa a `docs/DESIGN.md`.

---

## 1. Plano Arquitectónico Clásico — Blueprint Premium

### Inspiración
AutoCAD, Revit, ArchiCAD. Lámina ejecutiva A1/A0. Documento técnico listo para construcción.

### Características

| Aspecto | Valor |
|---------|-------|
| Fondo | Azul marino extremadamente oscuro (`#0A0E14` a `#0F1923`) |
| Líneas | Blancas, muy finas, vectoriales, sin ruido |
| Jerarquía | Muros gruesos → aberturas medias → detalles finos → vegetación ultrafina |
| Sombras | Ninguna |
| Rellenos | Ninguno |
| Texto | Sans-serif técnica, mayúsculas, muy limpia |

### Paleta

| Elemento | Color |
|----------|-------|
| Fondo | `#0A0E14` |
| Línea principal | `#FFFFFF` |
| Línea secundaria | `#A0AEC0` |
| Texto | `#E2E8F0` |
| Cotas | `#CBD5E0` |
| Vegetación | `#718096` |

### Uso en la app
- Tema "Blueprint" disponible en Settings.
- Configuración de grosores por tipo de entidad.
- Tipografía técnica forzada (JetBrains Mono o similar).
- Sin efectos de sombra, relleno ni gradientes en renderizado.

---

## 2. Poster Publicitario de Servicios AutoCAD

### Inspiración
Material comercial. Marketing técnico. Presentación premium de servicios de dibujo arquitectónico.

### Características

| Aspecto | Valor |
|---------|-------|
| Fondo | Azul oscuro (`#0F172A`) |
| Líneas | Blancas |
| Acento | Amarillo dorado (`#F6C90E` o `#F59E0B`) |
| Bloques | Rectangulares, alineados, jerarquía visual |
| Tipografía | Sans-serif muy gruesa, mayúsculas, gran contraste |

### Paleta

| Elemento | Color |
|----------|-------|
| Fondo | `#0F172A` |
| Línea | `#FFFFFF` |
| Acento primario | `#F6C90E` |
| Acento secundario | `#F59E0B` |
| Texto principal | `#F8FAFC` |
| Texto secundario | `#94A3B8` |

### Uso en la app
- Modo "Presentación" para capturas y exportaciones.
- Botones y highlights en amarillo dorado.
- Paneles informativos con bordes de acento.
- Ideal para exportar vistas completas a PNG/PDF con título y leyenda.

---

## 3. Infografía de Comandos AutoCAD

### Inspiración
Material educativo. Guía rápida. Manual técnico.

### Características

| Aspecto | Valor |
|---------|-------|
| Fondo | Azul oscuro (`#0F172A`) con textura blueprint sutil |
| Líneas | Blancas difusas como decoración de fondo |
| Títulos | Amarillo (`#F6C90E`) |
| Texto | Blanco, sans-serif limpia |
| Bloques | Organizados en categorías con iconos |
| Espaciado | Muy ordenado, alineación perfecta |

### Paleta

| Elemento | Color |
|----------|-------|
| Fondo | `#0F172A` |
| Línea decorativa | `#1E293B` |
| Título | `#F6C90E` |
| Texto | `#F1F5F9` |
| Icono | `#94A3B8` |
| Borde bloque | `#334155` |

### Uso en la app
- Modo "Referencia" o "Educativo".
- Mostrar leyenda de entidades con iconos.
- Exportar infografías de capas o entidades del dibujo.
- Overlay de comandos/ayuda en el viewer.

---

## 4. Captura de Pantalla de AutoCAD — Interfaz Oscura

### Inspiración
Entorno de trabajo real. AutoCAD, AutoCAD LT. Espacio de trabajo profesional durante edición.

### Características

| Aspecto | Valor |
|---------|-------|
| Fondo app | Gris oscuro (`#1E1E1E` o `#252526`) |
| Área de dibujo | Negro (`#000000` o `#1A1A1A`) |
| Grid | Gris muy fino (`#2D2D30`) |
| Ribbon | Gris oscuro con bordes sutiles |
| Entidades | Blancas, colores por capa |
| Muros | Blancos |
| Puertas | Amarillas |
| Mobiliario | Verdes |
| Cocina | Celeste |
| Dormitorios | Verde oliva |

### Paleta

| Elemento | Color |
|----------|-------|
| Fondo app | `#1E1E1E` |
| Área dibujo | `#1A1A1A` |
| Grid | `#2D2D30` |
| Ribbon/panels | `#252526` |
| Borde panel | `#3E3E42` |
| Texto UI | `#CCCCCC` |
| Entidad blanca | `#FFFFFF` |
| Entidad amarilla | `#FFD700` |
| Entidad verde | `#4CAF50` |
| Entidad celeste | `#00BCD4` |

### Uso en la app
- Tema "AutoCAD Dark" — inspirado directamente en la interfaz de AutoCAD.
- Ribbon superior simulado (opcional) para botones de herramienta.
- Cursor personalizado tipo crosshair.
- ViewCube simulado para orientación 2D/3D (placeholder en MVP).
- Línea de comandos inferior (placeholder para shortcuts).

---

## 5. Implementación de Temas en la App

### ThemeData definitions

```dart
// 1. Blueprint Premium
final blueprintTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF0A0E14),
  canvasColor: Color(0xFF0F1923),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF0F1923),
    brightness: Brightness.dark,
    primary: Colors.white,
    secondary: Color(0xFFA0AEC0),
  ),
  fontFamily: 'JetBrainsMono',
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF0A0E14).withOpacity(0.85),
    elevation: 0,
  ),
);

// 2. Poster Publicitario
final posterTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF0F172A),
  canvasColor: Color(0xFF0F172A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFFF6C90E),
    brightness: Brightness.dark,
    primary: Color(0xFFF6C90E),
    secondary: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF0F172A).withOpacity(0.9),
    elevation: 0,
  ),
);

// 3. Infografía Educativa
final infographicTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF0F172A),
  canvasColor: Color(0xFF0F172A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFFF6C90E),
    brightness: Brightness.dark,
    primary: Color(0xFFF6C90E),
    secondary: Color(0xFFF1F5F9),
  ),
  fontFamily: 'Inter',
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF0F172A).withOpacity(0.9),
    elevation: 0,
  ),
);

// 4. AutoCAD Dark
final autocadTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF1E1E1E),
  canvasColor: Color(0xFF1A1A1A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF3E3E42),
    brightness: Brightness.dark,
    primary: Color(0xFFCCCCCC),
    secondary: Color(0xFFD4D4D4),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF252526),
    elevation: 0,
    foregroundColor: Color(0xFFCCCCCC),
  ),
);
```

### ACI Color Mapping por tema

```dart
Color getAciColor(int aci, AppThemeMode themeMode) {
  if (themeMode == AppThemeMode.blueprint) {
    // Mapear todo a blancos/grises sobre azul marino
    if (aci == 7) return Color(0xFFE2E8F0);
    return Color(0xFFA0AEC0);
  }
  if (themeMode == AppThemeMode.autocad) {
    // Paleta AutoCAD estándar
    switch (aci) {
      case 1: return Color(0xFFFF0000); // rojo
      case 2: return Color(0xFFFFFF00); // amarillo
      case 3: return Color(0xFF00FF00); // verde
      case 4: return Color(0xFF00FFFF); // cyan
      case 5: return Color(0xFF0000FF); // azul
      case 6: return Color(0xFFFF00FF); // magenta
      case 7: return Color(0xFFFFFFFF); // blanco
      default: return Color(0xFFCCCCCC);
    }
  }
  // Default: usar colores ACI estándar
  return standardAciColor(aci);
}
```

---

## 6. Selección de Tema desde UI

### SettingsSheet

```dart
List<ThemeOption> themeOptions = [
  ThemeOption(
    id: 'light',
    label: 'Claro',
    description: 'Fondo blanco, rejilla gris claro',
  ),
  ThemeOption(
    id: 'dark',
    label: 'Oscuro',
    description: 'Fondo gris oscuro, rejilla tenue',
  ),
  ThemeOption(
    id: 'blueprint',
    label: 'Blueprint Premium',
    description: 'Azul marino oscuro, líneas blancas finas',
    assetPreview: 'assets/previews/blueprint_preview.png',
  ),
  ThemeOption(
    id: 'poster',
    label: 'Poster Publicitario',
    description: 'Azul oscuro con acento amarillo dorado',
    assetPreview: 'assets/previews/poster_preview.png',
  ),
  ThemeOption(
    id: 'infographic',
    label: 'Infografía Educativa',
    description: 'Azul oscuro, títulos amarillos, bloques informativos',
    assetPreview: 'assets/previews/infographic_preview.png',
  ),
  ThemeOption(
    id: 'autocad',
    label: 'AutoCAD Dark',
    description: 'Interfaz oscura estilo AutoCAD',
    assetPreview: 'assets/previews/autocad_preview.png',
  ),
];
```

### ThemeMode enum

```dart
enum AppThemeMode {
  light,
  dark,
  blueprint,
  poster,
  infographic,
  autocad;

  String get label {
    switch (this) {
      case AppThemeMode.light: return 'Claro';
      case AppThemeMode.dark: return 'Oscuro';
      case AppThemeMode.blueprint: return 'Blueprint Premium';
      case AppThemeMode.poster: return 'Poster Publicitario';
      case AppThemeMode.infographic: return 'Infografía Educativa';
      case AppThemeMode.autocad: return 'AutoCAD Dark';
    }
  }
}
```

---

## 7. Configuraciones Adicionales por Estética

> **Temas base Claro/Oscuro:** usan los tokens de `docs/DESIGN.md` (paleta en §2.2, opacidad de rejilla 0.3/0.2 y colores de ejes en §4.1, blur 20px y radius 12dp en §2.2). Las configuraciones siguientes aplican a las 4 estéticas profesionales.

### Blueprint Premium
- Grid opacidad: 0.15
- Ejes: desactivados por defecto (o muy sutiles)
- Líneas CAD: todas blancas o grises muy claras
- Texto: JetBrains Mono, color `#E2E8F0`
- Sin sombras, sin rellenos
- Exportar PNG: fondo azul marino

### Poster Publicitario
- Grid: opacidad 0.1
- Acento amarillo en entidades seleccionadas
- Títulos de panels en amarillo
- Exportar PNG: fondo azul oscuro con acentos amarillos
- Modo ideal para capturas de presentación

### Infografía Educativa
- Grid: opacidad 0.1
- Títulos de secciones en amarillo
- Bloques informativos con borde gris
- Iconografía visible
- Modo ideal para tutoriales y ayuda

### AutoCAD Dark
- Grid: color `#2D2D30`, opacidad 0.5
- Entidades respetando colores originales
- Paneles con fondo `#252526` y borde `#3E3E42`
- Cursor crosshair (draw en canvas)
- Layout simulado (Model/Layout tabs)
- ViewCube placeholder (esquina superior derecha)

---

## 8. Assets Necesarios

```
assets/
├── logo/
│   ├── logo.svg
│   └── logo_animated.json (Rive)
├── previews/
│   ├── blueprint_preview.png
│   ├── poster_preview.png
│   ├── infographic_preview.png
│   └── autocad_preview.png
├── fonts/
│   ├── Inter-Regular.ttf
│   ├── Inter-Medium.ttf
│   ├── Inter-SemiBold.ttf
│   ├── Inter-Bold.ttf
│   └── JetBrainsMono-Regular.ttf
└── icons/
    ├── grid.svg
    ├── axis.svg
    ├── layer.svg
    ├── zoom_in.svg
    ├── zoom_out.svg
    ├── fit_screen.svg
    └── settings.svg
```

---

## 9. Checklist de Verificación de Estética

- [ ] 6 temas definidos y documentados (claro, oscuro + 4 estéticas)
- [ ] ThemeData para cada tema en código
- [ ] Selector de tema en Settings con previews
- [ ] ACI color mapping adaptado por tema
- [ ] Tipografía cargada (Inter + JetBrains Mono)
- [ ] Grid renderizado con opacidad correcta por tema
- [ ] Ejes renderizados con colores correctos por tema
- [ ] Splash animado compatible con todos los temas
- [ ] Exportación PNG respeta tema seleccionado
- [ ] Transiciones suaves entre temas
- [ ] BackdropFilter blur en controles para todos los temas
- [ ] Iconos vectoriales (SVG) para UI
- [ ] Accesibilidad: contraste WCAG AA en todos los temas
- [ ] Onboarding ilustrado con estética consistente
- [ ] Grips de edición visibles en todos los temas
- [ ] Indicador de snap contrastado en todos los temas
- [ ] Ventanas de selección window/crossing con colores por tema
