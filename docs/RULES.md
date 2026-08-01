# ⚠️ REGLA ABSOLUTA — NO BORRAR
Este archivo `docs/RULES.md` es INMUTABLE en su **estatus normativo**: ninguna AI, agente o asistente puede borrarlo, renombrarlo ni eliminar las reglas aquí definidas. Cualquier corrección factual debe registrarse en `docs/CORRECTIONS.md` y aprobarse explícitamente.

---

# Reglas de Oro — CAD Viewer & Editor

## A. Esquema de Versionado
- Formato: `vX.Y.Z` (semver). Ciclo: v0.1.0 → v0.1.1 → ... → v0.2.0 → ... → v1.0.0.
- El archivo `VERSION` en la raíz contiene solo el número sin 'v' (ej: `0.2.0`).
- Cada tag debe coincidir con el contenido de `VERSION`.
- La versión indicada en `README.md` (línea "Current version:") debe ser idéntica al contenido de `VERSION`.
- **Nota (v0.3.1):** la línea "Current version:" de README incluye versión de documentación y versión de código (`0.3.1 (documentación) · código: 0.1.0`). La regla de igualdad con `VERSION` aplica a la **versión de código**; la de documentación se registra en `CHANGELOG.md`.
- Los cambios se registran en `docs/CHANGELOG.md`.

## B. Reglas de Código (Obligatorias)
1. Todo acceso a archivos con try-catch y feedback al usuario (SnackBar, dialog).
2. Parseo de archivos DXF/DWG con try-catch robusto; nunca dejar crashar la app ante archivos corruptos.
3. Verificar `mounted` antes de `setState` en métodos asíncronos.
4. Liberar recursos en `dispose` (AnimationController, StreamSubscription, TextPainter).
5. Al guardar archivos, usar `flush: true` en writeAsString.
6. No usar `Container` con `color` y `decoration` simultáneamente.
7. Verificar existencia de archivos con `exists()` antes de leer.
8. En ChangeNotifier, llamar a `notifyListeners()` después de modificar estado.
9. En `ListView.builder`, proveer `key` a cada elemento.
10. No olvidar `const` donde sea posible para optimizar.
11. **Toda mutación del documento de edición pasa por el patrón Command** (`CommandStack`) — nunca mutar `CadDocument` directamente desde la UI.
12. **Parseo y escritura DXF en Isolates** para archivos > 1 MB (no bloquear el hilo de UI).
13. **Undo/redo siempre disponible** tras cualquier operación de edición.
14. **Nunca subir contenido de planos a servicios externos** sin consentimiento explícito (ver `docs/SECURITY.md`).
15. Verificar que los widgets usan `context.select` para rebuild selectivo y no `context.watch` innecesario en listas largas.

## C. Compilación y Despliegue
- Usar `flutter run` para reemplazar la app instalada y conservar permisos.
- Si falla la instalación, reintentar hasta 5 veces con intervalos de 5 minutos.
- `flutter analyze` debe pasar sin warnings antes de commit (`--fatal-infos`).

## D. Reglas Git
- Commits con conventional commits: feat:, fix:, docs:, chore:, refactor:, test:.
- Actualizar VERSION y hacer commit antes de cada tag.
- No eliminar tags publicados; si hay error, crear nuevo tag.
- Documentación y código se versionan juntos; cambios de docs usan `docs:`.

## E. Estructura del Proyecto
La estructura de carpetas debe mantenerse según lo especificado en la documentación:
```
lib/
├── main.dart
├── controllers/
│   ├── cad_view_model.dart
│   ├── command_stack.dart
│   ├── snap_engine.dart
│   └── selection_manager.dart
├── models/
├── parsers/
│   ├── dxf_parser.dart
│   ├── dxf_writer.dart
│   └── dwg_parser.dart
├── renderers/
├── screens/
├── widgets/
└── utils/
```
Ver `docs/ARCHITECTURE.md` para el detalle.

## F. Estilo de Código
- Seguir las guías de estilo de Dart (dart format).
- Priorizar legibilidad y rendimiento.
- Usar `const` donde sea posible.
- Mantener nombres descriptivos y consistentes (inglés).
- `models/` es Dart puro (sin imports de Flutter).

## G. Documentación
- Toda decisión de arquitectura se registra en `docs/ADR.md`.
- Toda discrepancia/corrección de documentación se registra en `docs/CORRECTIONS.md`.
- Los requisitos se mantienen en `docs/REQUIREMENTS.md` (una sola fuente de verdad).
- Las fases de trabajo detalladas están en `docs/TODO.md`; el roadmap en `docs/ROADMAP.md`.
- Tests: toda feature nueva debe tener tests (ver `docs/TESTING.md`).
