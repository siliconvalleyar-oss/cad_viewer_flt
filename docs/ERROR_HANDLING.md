# Manejo de Errores y Logging — CAD Viewer & Editor

**Versión:** 0.3.0
**Estado:** Aprobado (arquitectura técnica)
**Equipo responsable:** Arquitecto Técnico · QA
**Propósito:** Taxonomía de errores, `ErrorHandler` centralizado, catálogo de mensajes de usuario y política de logging con privacidad. Complementa a `docs/RULES.md` (reglas B), `docs/SECURITY.md` y `docs/UX_FLOWS.md` (microcopy).

---

## Índice

1. [Principios](#1-principios)
2. [Taxonomía de errores](#2-taxonomía-de-errores)
3. [ErrorHandler centralizado](#3-errorhandler-centralizado)
4. [Catálogo de mensajes](#4-catálogo-de-mensajes)
5. [Política de logging](#5-política-de-logging)
6. [Reporte de crash](#6-reporte-de-crash)

---

## 1. Principios

1. **Nunca un crash por datos del usuario.** Todo parseo/lectura/escritura captura y degrada con gracia.
2. **Error ≠ excepción técnica.** La UI muestra mensaje legible; el detalle va al log.
3. **Todo error tiene recuperación** (retry, guardar como, abrir otro, cancelar).
4. **Privacidad en logs:** nunca loguear contenido de planos, coordenadas completas, ni rutas absolutas del usuario.
5. **Los Isolates no lanzan:** devuelven `{error}` (ver `docs/SERIALIZATION.md` §7).

---

## 2. Taxonomía de errores

Códigos `ERR-XXX` agrupados por dominio.

### 2.1 Archivos (FILE)

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `ERR-FILE-001` | Archivo no encontrado / ruta inválida | Media |
| `ERR-FILE-002` | Permisos denegados al leer | Media |
| `ERR-FILE-003` | Permisos denegados al escribir / solo lectura | Media |
| `ERR-FILE-004` | Archivo demasiado grande (> límite) | Baja (advertencia) |
| `ERR-FILE-005` | Error de I/O genérico | Media |

### 2.2 Parseo (PARSE)

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `ERR-PARSE-001` | No es DXF válido (formato corrupto) | Alta |
| `ERR-PARSE-002` | DXF binario no soportado | Media |
| `ERR-PARSE-003` | Versión DXF no reconocida | Baja (continúa) |
| `ERR-PARSE-004` | Entidades desconocidas (warning, se omiten) | Baja |
| `ERR-PARSE-005` | INSERT con bloque inexistente (warning) | Baja |
| `ERR-PARSE-006` | Timeout de parseo | Alta |
| `ERR-PARSE-007` | DWG: converter no instalado | Media |
| `ERR-PARSE-008` | DWG: conversión fallida | Alta |

### 2.3 Edición (EDIT)

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `ERR-EDIT-001` | Operación sobre capa locked/frozen | Baja (bloqueo silencioso + hint) |
| `ERR-EDIT-002` | Comando no puede deshacerse (invariante rota) | Alta |
| `ERR-EDIT-003` | Entidad no editable (3D/hatch v1.0) | Baja |
| `ERR-EDIT-004` | Undo/redo vacío | Baja (botones disabled) |

### 2.4 Persistencia (STATE)

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `ERR-STATE-001` | Corrupción de shared_preferences | Media |
| `ERR-STATE-002` | Autosave corrupto | Media |
| `ERR-STATE-003` | schemaVersion de autosave futuro | Media |
| `ERR-STATE-004` | Fallo al restaurar sesión | Baja |

### 2.5 Conversión/Export (EXPORT)

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `ERR-EXPORT-001` | Fallo al escribir PNG | Media |
| `ERR-EXPORT-002` | Fallo al compartir | Media |
| `ERR-EXPORT-003` | Entidades no exportables a R12 | Baja (advertencia) |

---

## 3. ErrorHandler centralizado

**Archivo:** `lib/utils/error_handler.dart`

```dart
class AppError {
  final String code;          // 'ERR-PARSE-001'
  final String userMessage;   // traducido (ARB)
  final Object? details;      // detalle técnico (va al log, no a la UI)
  final bool recoverable;
}

class ErrorHandler {
  // Traduce excepción/resultado de Isolate → AppError (userMessage según locale)
  static AppError from(dynamic error, {String? code});

  // Registra en log (con política de privacidad) y devuelve AppError a UI
  static void report(AppError error, {StackTrace? stack});

  // Muestra en UI según severidad (SnackBar / banner / dialog)
  static void show(BuildContext context, AppError error);
}
```

**Reglas de uso:**
- En la UI: `ErrorHandler.show(context, ...)` — nunca try-catch sueltos que solo imprimen.
- En Isolates: retornar `{error: code}`; el worker principal lo traduce.
- En `catch` genérico: asignar código `ERR-UNKNOWN` + `code` derivada del dominio.

---

## 4. Catálogo de mensajes

Fuente única: `lib/l10n/app_es.arb` y `app_en.arb` (ver `docs/UX_FLOWS.md` §5.2 para el tono y ejemplos). Cada `AppError.code` mapea a una clave ARB (`error.ERR_PARSE_001`).

| Código | Clave ARB (es) | Mensaje |
|--------|----------------|---------|
| ERR-FILE-001 | error.ERR_FILE_001 | "Archivo no encontrado" |
| ERR-FILE-003 | error.ERR_FILE_003 | "No se puede guardar aquí. Usa 'Guardar como'." |
| ERR-PARSE-001 | error.ERR_PARSE_001 | "No se pudo leer el archivo. ¿Es un DXF válido?" |
| ERR-PARSE-002 | error.ERR_PARSE_002 | "Este DXF binario no es compatible. Conviértelo a DXF ASCII." |
| ERR-PARSE-007 | error.ERR_PARSE_007 | "DWG requiere conversión. Instala ODA File Converter o convierte a DXF." |
| ERR-PARSE-008 | error.ERR_PARSE_008 | "No se pudo convertir el DWG. Revisa la instalación de ODA." |
| ERR-EDIT-001 | error.ERR_EDIT_001 | "La capa está bloqueada." |
| ERR-STATE-002 | error.ERR_STATE_002 | "Se ignoró una copia de seguridad dañada." |
| ERR-EXPORT-001 | error.ERR_EXPORT_001 | "No se pudo guardar la imagen." |
| ERR-UNKNOWN | error.ERR_UNKNOWN | "Ocurrió un error inesperado. Inténtalo de nuevo." |

---

## 5. Política de logging

### 5.1 Niveles

| Nivel | Uso |
|-------|-----|
| `debug` | Desarrollo: entidades parseadas, timing |
| `info` | Eventos de usuario (archivo abierto, guardado) — sin datos |
| `warning` | Pérdidas documentadas (entidades omitidas, R12), autosave corrupto |
| `error` | AppError con código |
| `fatal` | Crash no recuperable (capturado por zona) |

### 5.2 Qué se loguea / qué NO

| ✅ Se loguea | ❌ NO se loguea |
|--------------|-----------------|
| Código de error (`ERR-PARSE-001`) | Contenido del archivo DXF |
| Nombre de archivo (sanitizado) | Coordenadas/geometría de entidades |
| Duración de parseo/escritura | Rutas absolutas del usuario |
| Versión de la app y plataforma | Datos de identificación |
| Resultado de conversión DWG (ok/fallo) | Contenido del DXF convertido |

**Sanitización:** `sanitizePath(path)` reemplaza segmentos de usuario por `~`; los logs de archivos solo incluyen basename.

### 5.3 Implementación

- Wrapper ligero `AppLogger` (debugPrint en dev; archivo de log en `path_provider` en release, rotado a 1 MB).
- En release: sin verbose; `error`/`fatal` se envían a reporte de crash (ver §6).
- Política documentada en `docs/SECURITY.md` §5.

---

## 6. Reporte de crash

### 6.1 Decisión

- **v1.0: sin SDK de terceros por defecto** (privacidad: los planos y sus metadatos no deben salir del dispositivo; ADR-0005 principio local-first).
- Mecanismo propio: `FlutterError.onError` + `PlatformDispatcher.instance.onError` → escribir stack trace sanitizado a archivo local + diálogo "Enviar diagnóstico (opcional)" con correo/issue template.
- **Futuro:** si se adopta un servicio de crash reporting (ej. Sentry), activarlo con consentimiento y con `beforeSend` que aplica la política de sanitización §5.2. Registrar como ADR cuando ocurra.

### 6.2 Zona de captura

```
runZonedGuarded(
  () => runApp(App()),
  (error, stack) => CrashReporter.capture(error, stack),
);
```

---

## Checklist de errores/logging

- [ ] Todos los códigos ERR-XXX mapeados a mensajes ARB es/en
- [ ] ErrorHandler usado en toda la UI (sin try-catch sueltos)
- [ ] Isolates retornan `{error}` (no lanzan)
- [ ] Logs sanitizados (sin contenido de planos ni rutas completas)
- [ ] Crash reporter local con consentimiento
- [ ] Tests: cada código de error muestra el mensaje correcto
- [ ] ERR-EDIT-002 (invariante de undo rota) tratado como bug crítico (fail-fast en debug)
