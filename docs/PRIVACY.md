# Política de Privacidad — CAD Viewer & Editor

**Versión:** 1.0
**Fecha de entrada en vigor:** 2026-07-31
**Última revisión:** 2026-07-31
**Titular responsable:** CAD Viewer & Editor contributors
**Ámbito:** Aplicación móvil/desktop **CAD Viewer & Editor** disponible en Google Play, App Store y plataformas de escritorio.

> Esta política es el texto de referencia para la declaración de privacidad exigida por Google Play Console, Apple App Store Connect y los directorios de apps de escritorio. Se publica también en el apartado "Acerca de / Privacidad" dentro de la aplicación.

---

## 1. Resumen (para el usuario)

- **Tus planos se quedan en tu dispositivo.** La aplicación procesa, visualiza y edita tus archivos CAD (DXF, DWG) **completamente en local**.
- **No recopilamos ni transmitimos el contenido de tus archivos.** No hay servidores de la app, no hay telemetría de contenido, no hay cuentas.
- **No vendemos ni compartimos datos personales** con terceros.
- Únicamente se almacenan preferencias locales (tema, unidades) y un historial de rutas de archivos que abriste — que puedes borrar en cualquier momento.

---

## 2. Datos que la aplicación recopila

### 2.1 Ningún contenido de archivos CAD

La aplicación **no recopila, no sube ni envía** el contenido de los archivos DXF/DWG/DGN que el usuario abre o edita. Todo el procesamiento (lectura, renderizado, edición, medición, exportación) ocurre localmente en el dispositivo.

### 2.2 Datos almacenados localmente

| Dato | Finalidad | Dónde se almacena | Cómo se elimina |
|------|-----------|-------------------|-----------------|
| Rutas de los últimos 10 archivos abiertos | Mostrar "Recientes" en la pantalla de inicio | `shared_preferences` del dispositivo | Botón "Borrar historial" en Ajustes, o borrando los datos de la app |
| Miniaturas de vista previa (≤ 100 KB, baja resolución) | Mostrar las tarjetas de archivos recientes | `shared_preferences` (base64) | Junto con el historial |
| Preferencias: tema, unidades, grid, snap | Recordar tus ajustes | `shared_preferences` | Borrando los datos de la app |
| Copia de autoguardado (`*.autosave.dxf`) | Recuperar tu trabajo en edición tras un cierre inesperado | Directorio de documentos de la app (`path_provider`) | Se elimina al guardar manualmente; también se elimina al borrar los datos de la app |
| Archivos temporales de conversión DWG→DXF | Permitir abrir DWG vía conversión local | Directorio temporal de la app | Se eliminan automáticamente tras el procesamiento |

### 2.3 Permisos solicitados

| Plataforma | Permiso | Uso |
|------------|---------|-----|
| Android | Almacenamiento / SAF (Storage Access Framework) | Abrir archivos CAD elegidos por el usuario |
| Android 13+ | `READ_MEDIA_IMAGES` (opcional) | Guardar capturas PNG en la galería, solo si el usuario lo pide |
| iOS | `NSPhotoLibraryAddUsageDescription` | Guardar capturas PNG en Fotos, solo si el usuario lo pide |
| iOS | `LSSupportsOpeningDocumentsInPlace` / `UIFileSharingEnabled` | Abrir documentos desde la app "Archivos" y compartir el archivo original |

La aplicación **no** solicita permisos de ubicación, cámara, micrófono, contactos ni acceso a la red para funciones de la app.

---

## 3. Procesamiento local vs. servicios externos

### 3.1 Conversión DWG (importante)

DWG es un formato propietario de Autodesk. Según la versión de la aplicación:

- **MVP (v0.1–v0.2):** la app muestra un mensaje indicando que el formato no es compatible y guía al usuario a convertir el archivo a DXF por sus propios medios. **No se envía ningún dato.**
- **v0.3+:** la app puede invocar el **ODA File Converter** — una herramienta local que el usuario instala voluntariamente — para convertir DWG→DXF **en su propio dispositivo**. **El archivo no sale del dispositivo.**
- **Futuro (opcional):** si en una versión futura se ofreciera conversión en la nube, se hará **únicamente con consentimiento explícito** del usuario, con un aviso visible durante el proceso, y esta política se actualizará antes de activarse.

### 3.2 Sin análisis ni publicidad

La aplicación **no** integra SDK de analítica, publicidad ni seguimiento de terceros en v1.0. No se envían eventos de uso que incluyan nombres de archivos ni contenido.

### 3.3 Diagnósticos de fallo

En caso de un fallo inesperado, la aplicación puede generar un **informe de diagnóstico local** (trazas técnicas sin contenido de planos, sin coordenadas de dibujo ni rutas completas). Este informe **no se envía automáticamente**: solo si el usuario elige voluntariamente "Enviar diagnóstico" (por correo o formulario de incidencias), y únicamente contiene la información técnica indicada en la pantalla de consentimiento.

---

## 4. Compartición con terceros

- **No vendemos, alquilamos ni compartimos datos personales** con terceros.
- **No transferimos datos fuera del dispositivo** salvo lo que el usuario haga explícitamente (por ejemplo, usar el botón "Compartir" del sistema operativo, que está controlado por el propio sistema y por la app de destino que el usuario elija).
- **No utilizamos los datos para publicidad** ni perfilado.

---

## 5. Retención y seguridad

- **Retención:** las preferencias e historial se conservan mientras estén instalados en el dispositivo; el usuario puede borrarlos en cualquier momento (Ajustes → Borrar historial, o desinstalando la app).
- **Seguridad:** las rutas y miniaturas se guardan en almacenamiento privado de la aplicación (no accesible por otras apps). No se requiere cifrado adicional porque **no se almacena contenido de planos**.
- **Protección ante archivos maliciosos:** el procesamiento de archivos se aísla (parseo en procesos separados) y los archivos dañados no afectan al resto de la aplicación.

---

## 6. Menores

La aplicación está dirigida a profesionales y estudiantes de diseño, arquitectura e ingeniería. No recopila datos personales de menores ni está orientada a un público menor de edad. Al no recopilar datos, no se aplican requisitos específicos de consentimiento parental.

---

## 7. Cambios en esta política

Si esta política cambia, se actualizará la versión al inicio de este documento y la fecha de revisión. En caso de cambios relevantes para el tratamiento de datos (por ejemplo, la introducción de conversión en la nube), se notificará dentro de la aplicación antes de que el cambio surta efecto.

---

## 8. Contacto

Para cualquier consulta sobre privacidad o para solicitar la eliminación de datos locales:

- **Correo:** [soporte@example.com] *(sustituir por el correo real del titular antes de publicar)*
- **Enlace a esta política:** dentro de la app, en Ajustes → Acerca de → Privacidad

---

## 9. Declaración para tiendas (Google Play / App Store)

### Google Play Console — Formulario de datos

| Pregunta | Respuesta |
|----------|-----------|
| ¿Recopila datos la app? | No (sin cuenta, sin telemetría, sin contenido) |
| ¿Comparte datos con terceros? | No |
| Tipo de datos recopilados | Ninguno |
| ¿Usa cifrado en tránsito? | N/A (sin transmisión de datos) |
| ¿Elimina datos a petición? | N/A (los datos locales se borran con la app) |
| Política de privacidad (URL) | La publicada en este documento |

### App Store Connect — Privacy Nutrition Labels

| Categoría | Declaración |
|-----------|-------------|
| Data Not Collected | Marcar **"Data Not Collected"** para todas las categorías |
| Tracking | **"Does Not Track"** |
| NSPrivacyAccessedAPITypes | Declarar únicamente las APIs de acceso a archivos/sistema necesarias para la funcionalidad de abrir/guardar documentos |

---

## 10. Cumplimiento

- **GDPR (UE):** al no recopilar datos personales, la app no procesa datos de sujetos de la UE; las obligaciones de transparencia se cumplen con esta política.
- **CCPA/CPRA (California):** al no recopilar ni vender información personal, no se requieren mecanismos de opt-out adicionales.
- **LGPD (Brasil):** aplica la misma lógica: sin datos personales tratados.

---

*Documento de referencia técnica: `docs/SECURITY.md` (modelo de amenazas y políticas de ingeniería).*
