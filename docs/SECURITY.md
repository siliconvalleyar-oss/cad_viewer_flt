# Seguridad y Privacidad — CAD Viewer & Editor

**Versión:** 0.3.1
**Fecha:** 2026-07-31
**Propósito:** Políticas y decisiones de seguridad y privacidad de la aplicación. Pilar de diseño: **procesamiento local, mínimos permisos, transparencia**.

---

## 1. Principios

1. **Los planos nunca salen del dispositivo** — todo el parseo, renderizado, edición y exportación es local.
2. **Mínimos permisos** — la app solicita únicamente lo imprescindible por plataforma.
3. **Transparencia** — cualquier operación que involucre un servicio externo (conversión DWG remota, futura) se anuncia explícitamente.
4. **Sin telemetría del contenido** — no se envía contenido de archivos a servidores de analítica.

---

## 2. Modelo de amenazas

| Amenaza | Mitigación |
|---------|------------|
| Fuga de planos por upload no autorizado | Diseño local-only; conversión DWG local (CLI) preferida sobre cloud (ADR-0005) |
| Acceso a archivos por otra app | Permisos de almacenamiento mínimos; en Android 11+ scoped storage / SAF |
| DXF malicioso (parseo) | Parseo en Isolate (aislamiento de crash); try-catch exhaustivo; nunca ejecutar contenido |
| DoS por archivo gigante | Límite con advertencia (> 10 MB), cancelación de carga |
| Persistencia accidental de contenido | En prefs solo rutas y miniaturas (nunca contenido completo) |
| Path traversal / escritura fuera de sandbox | Validar rutas; escribir solo en rutas elegidas por el usuario (file picker save) |

---

## 3. Permisos por plataforma

### Android

| Permiso | API | Necesario para |
|---------|-----|----------------|
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | 33+ | Acceso a galería (opcional) |
| `WRITE_EXTERNAL_STORAGE` | ≤ 32 (si se usa) | Guardar PNG en galería |
| `READ_EXTERNAL_STORAGE` | ≤ 32 | Abrir archivos (o usar SAF/Storage Access Framework) |
| — | 30+ | Preferir **SAF** (`ACTION_OPEN_DOCUMENT`) sobre permisos crudos |

> El paquete `file_picker` usa SAF en Android moderno; minimizar permisos declarados.

### iOS

| Key (Info.plist) | Propósito |
|------------------|-----------|
| `LSSupportsOpeningDocumentsInPlace` | Abrir documentos in-place |
| `UIFileSharingEnabled` | Compartir via Files |
| `NSPhotoLibraryAddUsageDescription` | Guardar PNG a galería |

### Desktop/Web

- Windows/macOS/Linux: `file_picker` sin permisos especiales.
- Web: sandbox del navegador; sin acceso al sistema de archivos (solo drag&drop / input file). Advertir limitaciones.

---

## 4. Conversión DWG (riesgo externo)

| Modo | Riesgo | Medida |
|------|--------|--------|
| MVP: guía a conversión | Ninguno (no se hace) | Mensaje claro |
| v0.3+: ODA File Converter (CLI local) | Bajo (local) | Lanzar el binario configurado por el usuario; verificar hash/checksum en setup |
| Futuro: servicio cloud | **Alto (los planos salen del dispositivo)** | Consentimiento explícito + aviso + contrato de datos + cifrado en tránsito (HTTPS) + política de borrado |

**Decisión:** local-first (ADR-0005). Si se añade cloud en el futuro, se requiere: pantalla de consentimiento, indicador visible durante la conversión, y entrada en la política de privacidad.

---

## 5. Persistencia local

| Dato | Dónde | Notas |
|------|-------|-------|
| Rutas de recientes | `shared_preferences` | Solo rutas (el usuario puede limpiar historial) |
| Miniaturas | `shared_preferences` (base64, ≤ 100 KB) | Imágenes de baja resolución |
| Preferencias (tema, unidades, snap) | `shared_preferences` | Sin contenido sensible |
| Autosave | App documents dir (`path_provider`) | Borrar al guardar manualmente; ofrecer limpieza |
| Archivos temporales de conversión DWG | App temp dir | Borrar tras parseo |

**Cifrado:** no se requiere cifrado en reposo para v1.0 (datos son preferencias y rutas). Si se añade almacenamiento de documentos del usuario, evaluar `flutter_secure_storage`.

---

## 6. Política de privacidad

- Requerida para publicación en Google Play y App Store.
- Contenido mínimo: qué datos se recopilan (ningún contenido de planos), permisos usados, procesamiento local, política de conversión DWG, contacto.
- **Redactada:** ver `docs/PRIVACY.md` (incluye el formulario de datos para Google Play y las Privacy Nutrition Labels de App Store).

---

## 7. Checklist de seguridad

- [ ] Procesamiento 100% local en v1.0
- [ ] Conversión DWG: CLI local por defecto; cloud requiere consentimiento
- [ ] Permisos mínimos declarados por plataforma (SAF en Android 30+)
- [ ] Parseo en Isolate con try-catch exhaustivo (sin crash por archivo malicioso)
- [ ] Límite de tamaño de archivo con advertencia
- [ ] Sin contenido de planos en shared_preferences
- [ ] Temp files de conversión eliminados
- [x] Política de privacidad redactada (`docs/PRIVACY.md`)
- [ ] Revisar el correo de contacto antes del release (placeholder en PRIVACY.md §8)
- [ ] Auditoría de dependencias (`flutter pub outdated`, `dependabot`)
