# Changelog

## [0.4.13] - 2026-08-01 — BUG-05: orden de pintado por prioridad + viewport clipping
### Fixed
- **BUG-05 (doc §D) — No había orden de prioridad de dibujo**: el painter solo separaba rellenos primero / resto después, por lo que cotas y textos se pintaban debajo de muros/polilíneas según el orden del archivo. Ahora se pinta por categoría (doc §D): muros → columnas → puertas → ventanas → polilíneas → equipamiento → bloques → símbolos → textos → cotas (los rellenos HATCH/SOLID/3DFACE van detrás de todo para no tapar líneas). La clasificación prioriza el **tipo** (un TEXT en capa "MUROS" es texto y va encima) y usa una heurística de capa solo para la geometría lineal
- **BUG-05 (doc §B) — Sin viewport clipping**: ninguna geometría se recortaba a los límites del viewport; líneas/polilíneas/textos parcialmente visibles se dibujaban completos (y las auxiliares XLINE/RAY cuando existan). Ahora el pintado de entidades se envuelve en `canvas.save()/clipRect(Offset.zero & size)/restore()`
### Added
- `lib/utils/render_priority.dart` — `renderPriority(CadEntity)`: orden de pintado por categorías según doc §D (tipo primero, capa después), documentado y con valores 0–10
- Test: `test/utils/render_priority_test.dart` (cada categoría, heurística por capa, el tipo gana sobre la capa, orden completo ascendente)
### Changed
- `lib/renderers/cad_painter.dart` — sort ESTABLE por prioridad (índice original como desempate, `List.sort` de Dart no es estable) + clipping al viewport en el bloque de entidades

## [0.4.12] - 2026-08-01 — BUG-23 (Anexo C): fuentes de cota desproporcionadas al guardar
### Fixed
- **BUG CRÍTICO — las variables del HEADER nunca se parseaban**: el bloque que lee `$ACADVER`, `$INSUNITS`, `$EXTMIN/MAX` y `$DIMTXT` estaba anidado dentro de `if (pair.code == 0)`, pero esas variables llegan con **código de grupo 9** → jamás se ejecutaba. `files_cad/original.dxf` (AC1021, `$INSUNITS=0`) se leía como `AC1015` + mm. Ahora el parseo es un bloque propio `section == 'HEADER' && pair.code == 9` (verificado con probe real: `version=AC1021 insUnits=0 unitless`). Es la raíz parcial de BUG-13 (unidades forzadas a mm) y el habilitador del fallback `$DIMTXT`
- **"Las fuentes de las cotas quedan muy grandes" en el archivo guardado** (Anexo C del reporte QA): la causa raíz era que el archivo de salida **no tenía ninguna fuente de altura de texto de cota** — sin grupo `140` por cota, sin tabla `DIMSTYLE` y sin `$DIMTXT/$DIMSCALE/$DIMASZ` en el header. Al reabrir (en la app o en AutoCAD/LibreCAD), el programa caía al `dimtxt` por defecto (~2.5 u), que para cotas de ~1.5–2.3 u deja **el texto más alto que la propia cota**
### Added
- **Writer — tabla `DIMSTYLE`**: `_writeTables` ahora emite la tabla con los estilos únicos referenciados por las DIMENSION (nombre code 2, `dimtxt`=140, `dimasz`=41, DIMEXO/DIMDLI/DIMEXE, DIMTAD=1), recopilados por `_collectDimStyles` (las cotas sin estilo se agrupan en `Standard`)
- **Writer — header de cota**: `_writeHeader` escribe `$DIMTXT`, `$DIMASZ` y `$DIMSCALE` (code 40) a partir del primer estilo efectivo (`_firstDimStyle`), para que los CAD externos usen el dimtxt real del dibujo
- **Parser — fallback `$DIMTXT`** (BUG-23c): si no hay tabla `DIMSTYLE`, la altura de texto de las cotas usa el `$DIMTXT` del header en vez de quedar en 0 (que antes forzaba el `len*0.04` + piso de 12 px y agravaba el tamaño en el guardado)
### Changed
- `lib/parsers/dxf_writer.dart` — `_writeTables` (tabla DIMSTYLE tras LAYER), `_writeHeader` (variables de cota), nuevos `_var40`/`_firstDimStyle`/`_collectDimStyles`
- `lib/parsers/dxf_parser.dart` — `headerDimTxt` leído del HEADER y aplicado como último recurso en `DIMENSION`
### Added
- Tests: `test/parsers/dxf_writer_test.dart` (tabla DIMSTYLE con dimtxt/dimasz, header `$DIMTXT`/`$DIMASZ`, roundtrip preserva textHeight 2.5), `test/parsers/dxf_parser_test.dart` (grupo nuevo `HEADER: variables de código 9`: lee `$ACADVER`/`$INSUNITS`, variables no reconocidas no rompen; fallback `$DIMTXT` sin DIMSTYLE, sin `$DIMTXT` → 0)

## [0.4.11] - 2026-08-01 — Reporte QA: halo sutil, LOD de cotas, bloques anónimos, writer fiel
### Fixed
- **BUG-01 (doc §E) — Halo de selección dibujaba la caja envolvente gigante**: al tocar una entidad se pintaba un rectángulo redondeado celeste que abarcaba todo el AABB (un muro o polilínea de manzana cubría todo el dibujo). Ahora `_paintSelectionHalo` **repinta solo el trazo de la entidad** con el color de selección (sin bbox); solo los grips conservan un anillo sutil
- **BUG-03 (doc §C2) — Cotas sin LOD (siempre visibles, "masa de cotas")**: el texto de cota se forzaba a un mínimo de 12 px, por lo que las 532 cotas del plano se dibujaban todas simultáneamente. Ahora el tamaño proyectado decide: por debajo de ~8 px la cota completa se **oculta** (LOD por zoom), y el mínimo de legibilidad pasó a 8 px (`clampDimTextHeight` con `minPx: 8`)
- **BUG-04 (doc §C1) — Umbral LOD de texto de 2 px a 8 px**: los textos de alto ~0.3 u se renderizaban desde 2 px (ruido ilegible a zoom medio); ahora desde 8 px
- **BUG-07 — Bloques anónimos/dinámicos (`*D…`, `*X3`) descartados**: el filtro `!b.name.startsWith('*')` eliminaba los bloques anónimos válidos que los INSERT referencian (p. ej. los 4 INSERT a `*X3` en example.dxf quedaban como cruz placeholder). Ahora solo se excluyen `*Model_Space` y `*Paper_Space` (espacios, no bloques de dibujo)
- **BUG-09 (latente) — `entityBoundsInFile` de INSERT no restaba el base point del bloque**: el fit-to-screen y el culling podían no coincidir con la geometría dibujada cuando un bloque tiene base ≠ (0,0). Ahora resta `block.basePoint`, igual que el painter
- **BUG-10 — Hit-test de LWPOLYLINE abierta con cierre fantasma**: el último segmento se medía también contra el primer vértice (`% length` sin chequear `closed`), seleccionando polilíneas abiertas erróneamente al tocar entre final e inicio. Ahora solo se envuelve cuando `closed`
- **BUG-11 (doc F) — Bulge del segmento de cierre en LWPOLYLINE cerrada**: el cierre último→primero se dibujaba recto ignorando el bulge. Ahora se muestrea con `pointOnBulge` cuando el último vértice tiene bulge
- **BUG-14 — Ejes cartesianos que atravesaban todo el viewport**: con `$EXTMIN=(0,0)` el origen está en la esquina y las líneas roja/azul cruzaban todo el dibujo. Ahora los ejes se **acotan a ~25% del viewport** alrededor del origen (menor prioridad visual)
- **BUG-12 — Estilo de cota inexistente (TOTO-COTAS) se perdía**: `dimStyles['TOTO-COTAS']` → `null` → texto/flecha en 0. Ahora cae al **primer DIMSTYLE definido** en la tabla (o a 0 solo si no hay ninguno, y el painter deriva proporcional)
- **BUG-20 (CRÍTICO, writer) — Cotas corruptas al guardar**: el writer escribía `70=0` (perdiendo el bit 0x20 de tipo 32), no escribía el estilo (code 3) y hardcodeaba `*D1`. Ahora `CadDim.dimTypeRawCode` conserva el grupo 70 raw del archivo (parser lo propaga, writer lo escribe), y el writer emite el estilo (code 3) y la medición
- **BUG-21 (writer) — Precisión, lineweight y color BYLAYER perdidos**: `_formatDouble` redondeaba a 6 decimales (ahora 8), no escribía `370` (lineweight, en centésimas de mm) ni `62=256` (BYLAYER explícito)
### Added
- `CadDim.dimTypeRawCode` (int?, grupo 70 raw) con copyWith/==/hashCode; el parser lo propaga (`byCode.containsKey(70)`)
- Tests: `test/parsers/dxf_parser_test.dart` (bloques anónimos se conservan salvo Model/Paper Space, INSERT a *X3 resuelve, DIMSTYLE fallback + raw 70), `test/parsers/dxf_writer_test.dart` (nuevo: estilo code 3 + tipo raw 32, 62=256, 370 en centésimas, precisión 8 decimales), `test/models/cad_file_test.dart` (INSERT con base point ≠ 0), `test/utils/geometry_test.dart` (cierre fantasma en abierta/cerrada)

## [0.4.10] - 2026-08-01 — Fix bloques con 0 entidades (INSERT sin contenido: banera.dxf)
### Fixed
- **"Solo se ve la cota, faltan los vectores de diseño"** en `files_cad/banera.dxf`: el parser **creaba los bloques vacíos** — en `_buildFile` las entidades internas se acumulaban en `currentBlock` vía `copyWith`, pero esa copia **nunca se escribía de vuelta en la lista `blocks`**, así que **todos los bloques quedaban con 0 entidades** (afectaba también a example.dxf). El `INSERT` del bloque `bañera` (10 LINE, 20 ARC, 2 CIRCLE) existía pero su bloque estaba vacío → el painter dibujaba solo el placeholder y el diseño nunca se instanciaba; únicamente la DIMENSION (que renderiza con sus propias coordenadas) era visible. Ahora `ENDBLK` guarda el `currentBlock` acumulado en la lista
### Added
- Test: `test/parsers/dxf_parser_test.dart` — el bloque se puebla con sus entidades internas y el INSERT lo resuelve (caso banera.dxf), y `*Model_Space` normaliza sus entidades al modelo
### Changed
- Robustez: las entidades de tipo conocido (LINE, INSERT, SOLID…) ubicadas en la sección `OBJECTS` (escritores como dxfrw 0.6.3) se rescatan al espacio modelo sin warnings espurios por DICTIONARY/LAYOUT/XRECORD

## [0.4.9] - 2026-08-01 — Fix bloques con espejo (escala negativa): arcos y bulges invertidos
### Fixed
- **"Sobresalen cosas por fuera del vector diagonal"**: en `files_cad/example.dxf` los bloques de puertas (ARC de giro) y sanitarios (LWPOLYLINE con bulge) se insertan con **escala negativa** (`esc=(-1,1)`, `esc=(-1.15,1.15)`, etc.) y rotación (252.6°, 287.4°…). `_transformBlockEntity` no manejaba el **espejo**: un espejo invierte la orientación, por lo que los ángulos de ARC/ELLIPSE/TEXT deben **reflejarse** (θ → rot−θ o π+rot−θ) y los extremos del arco **intercambiarse**, y el **bulge de LWPOLYLINE debe negarse**. Sin esto, los arcos de giro de puertas y las curvas de griferías se dibujaban por el lado equivocado, "sobresaliendo" del vector
### Added
- `lib/utils/block_transform.dart` — `transformBlockEntity` (público, extraído de CadPainter): mapea ángulos con escala+rotación+espejo (`_mapAngle`), intercambia extremos de ARC con espejo, niega bulge de LWPOLYLINE con espejo, refleja rotación de TEXT/MTEXT/ELLIPSE/INSERT anidado
- Test: `test/utils/block_transform_test.dart` (ARC espejo X/Y/doble espejo, caso real 252.6°, bulge negado, rotación de texto/elipse reflejada)
### Changed
- `lib/renderers/cad_painter.dart` — usa `transformBlockEntity` (eliminado `_transformBlockEntity` privado); culling de INSERT también pasa por el nuevo transform

## [0.4.8] - 2026-08-01 — Fix texto vertical "Sin guardar" en la barra superior
### Fixed
- **Texto en vertical que ensanchaba la barra superior del visor**: el indicador de cambios sin guardar (`Text('Sin guardar')`) no tenía `maxLines`/`overflow`; cuando la barra quedaba estrecha (botón volver + nombre de archivo + botones undo/redo/guardar/capas/info/rotar/ajustar), el área flexible se reducía y Flutter envolvía la palabra **carácter a carácter en vertical**, disparando la altura de la barra y ocupando más pantalla de lo normal. Ahora se limita a 1 línea con elipsis

## [0.4.7] - 2026-08-01 — Soporte SOLID/TRACE (áreas rellenas) + compatibilidad example.dxf
### Added
- **Soporte completo de entidades `SOLID` y `TRACE`** (áreas rellenas 2D, marcador `AcDbTrace`): el parser las descartaba con "Entidad SOLID no soportada" — los planos con muros/columnas/rellenos (p. ej. `files_cad/example.dxf`, 1064 SOLID) perdían todo ese contenido. Nueva entidad `CadSolid` (4 esquinas 10-13/20-23, como 3DFACE; si la 3ª y 4ª coinciden es un triángulo) con render **relleno** (alpha 0.45 + contorno), bounds, selección, snap, hit-testing, transformaciones (mover/rotar/escalar), writer DXF (`SOLID`/`AcDbTrace`) y panel de propiedades (esquinas + área)
- Test: `test/parsers/dxf_parser_test.dart` (SOLID cuadrilátero con AcDbTrace, TRACE triángulo, sin aviso de entidad no soportada)

## [0.4.6] - 2026-08-01 — Fix capas invisibles en tema claro (contraste ACI)
### Fixed
- **Capas que no se veían (se veían las cotas pero no los vectores)**: `LayerManager` no adaptaba el color ACI al fondo del lienzo (la doc lo prometía: "el tema adapte el ACI 7 blanco → oscuro en tema claro", pero nunca se implementó). En el tema **Claro** (lienzo blanco), las capas de color blanco/amarillo (ACI 7, 2…) eran **invisibles**; las cotas (capa de color saturado) sí se veían. Ahora se aplica una **adaptación de contraste WCAG**: `aci_colors.ensureContrast` oscurece colores claros sobre fondos claros y aclara colores oscuros sobre fondos oscuros, garantizando ≥ 3:1 de contraste
### Added
- `lib/utils/aci_colors.dart` — `relativeLuminance`, `contrastRatio` y `ensureContrast` (WCAG, interpolación hasta contraste mínimo)
- `LayerManager.canvasBackground` (ARGB) + adaptación en `entityColor` y `layerColor`; `viewer_screen` y `layer_panel` pasan `palette.canvasBackground`
- Test: `test/utils/aci_colors_test.dart` (luminancia, contraste, blanco→oscuro en claro, blanco intacto en oscuro, amarillo/rojo, gris oscuro aclarado)

## [0.4.5] - 2026-08-01 — Giro de vista 180° (DXF con UCS rotado)
### Added
- **Giro de vista 180° en el plano** (sentido horario): algunos DXF traen el dibujo en un UCS rotado 180° o con vector de extrusión (0,0,-1) y se veían **girados en plano** (no espejados). Nuevo botón `⟳` (Icons.threesixty) en la AppBar del visor que rota la vista 180° manteniendo el centro del viewport; **se persiste por archivo** (shared_preferences `rotatedFiles`) y se restaura al reabrir el mismo archivo
- `CoordinateTransform.rotate180`: niega ambos ejes mundo→pantalla (`sx = -wx·s+ox`, `sy = +wy·s+oy`), con inversas coherentes, `fitToScreen(rotate180:)`, nuevo `zoomAt()` (mantiene el punto bajo el cursor con rotación) e `isVisible` robusto ante el orden de esquinas invertido
- `CadViewModel.rotateView` + `toggleRotateView(vw, vh)` (mantiene el punto del centro fijo: `offsetX = vw - offsetX`, `offsetY = vh - offsetY`); `fitToScreen`/`zoomAt`/`updateCursor` y `viewer_screen._screenToWorld` usan el transform (antes fórmulas crudas)
- `CadPainter._angleOffset` (π si rotate180) aplicado a arcos, elipses, TEXT/MTEXT y flechas de cota; `_visibleWorldRect`/`_entityScreenBounds` y `GridRenderer` ordenan X **e** Y (antes solo Y)
### Fixed
- **GripRenderer no respetaba offset/inversión de Y**: solo usaba `g.x·scale`. Ahora recibe el `CoordinateTransform` completo y usa `worldToScreenX/Y` (los grips ya quedaban mal ubicados al hacer pan con offset ≠ 0)
### Added
- Tests: `coordinate_transform_test` (rotate180: round-trip, fitToScreen centrado, zoomAt, isVisible) y `cad_view_model_test` (toggle mantiene centro, persistencia por archivo)

## [0.4.4] - 2026-08-01 — Fix panel de propiedades, grosor de línea y cotas descomunales
### Fixed
- **Longitud de línea incorrecta en el panel de propiedades**: `distanceMm` era un placeholder que devolvía `d²·0.5` en vez de la distancia real → una línea de 6.01 mm mostraba "18.05 mm". Ahora usa `distance()` real de geometry; eliminada la fila basura "Inicio"
- **Grosor de línea (grupo 370)**: se mostraba el valor crudo del DXF (en centésimas de mm): 30 → "30.0 mm" y el painter dibujaba trazos de 30 px (bandas enormes que "desbordaban" del vector). Ahora `_lineWeightFrom370` normaliza a mm (30 → 0.30 mm, ≤0 → null/heredar) en `_parseEntity` y `_parseHeavyPolylineFull`; el panel muestra "0.30 mm"
- **Cotas con líneas de extensión descomunales ("cosas que desbordan fuera de rango")**: cuando el DIMSTYLE traía `dimtxt`/`dimasz` en otras unidades, el texto y la separación de la línea de cota quedaban enormes. Nuevos `clampDimTextHeight` (mín 12 px, máx 10% de la medida) y `clampDimArrowSize` (mín 4 px, máx 30%) en geometry.dart, aplicados en `_paintDimension`
### Added
- **`lib/utils/line_types.dart`**: patrón estándar de AutoCAD completo (DASHED/HIDDEN/CENTER/DOT/DASHDOT/PHANTOM/BORDER/DIVIDE + variantes escaladas `2`/`X2` + ISO `ACAD_ISO*nW100`) y `resolveLineTypePattern` (tabla LTYPE del archivo → insensible a mayúsculas → estándar), usado por el painter (antes las variantes `DASHED2`/`DIVIDE2` se veían sólidas)
- Tests: `test/utils/line_types_test.dart` (resolución y variantes escaladas), `test/utils/geometry_test.dart` (clamps de cota), `test/parsers/dxf_parser_test.dart` (370→mm, LTYPE)

## [0.4.3] - 2026-08-01 — Fix líneas punteadas + líneas fantasma (bulges)
### Fixed
- **Líneas punteadas que se veían sólidas**: el parser leía el tipo de línea (grupo 6) pero el painter dibujaba todo con trazo continuo. Ahora se renderizan los guiones: se **parsea la tabla LTYPE** (nombre grupo 2, patrón grupo 49, positivo = trazo / negativo = espacio / 0 = punto) → `CadFile.lineTypes`, y `CadPainter` resuelve el tipo efectivo (entidad → capa → `Continuous` = sólido, con fallback de patrones estándar AutoCAD: DASHED/HIDDEN/CENTER/DOT/DASHDOT/PHANTOM/BORDER/DIVIDE) y dibuja discontinuo (`dashPath` con `PathMetrics`, escala con zoom, mínimo visible 1.5 px) en líneas, círculos, arcos, elipses, polilíneas (ligeras y pesadas), splines y 3DFACE
- **Líneas fantasma fuera del dibujo (bug en bulges)**: `pointOnBulge` (geometry.dart) calculaba `d = distance(...)·0.5·sagitta·0` → `d = 0` y luego `perpX = -(y2-y1)/(d+epsilon)` → vectores de ~1e9 que dibujaban **líneas gigantes fuera del plano** en toda polilínea con arcos. Ahora calcula el centro con `bulgeCenter` y barre el ángulo incluido `4·atan(bulge)` (coherente con el resto de la geometría)
### Added
- `test/utils/geometry_test.dart` (pointOnBulge: extremos, sagitta, semicírculo, bulge negativo, sin coordenadas gigantes; bulgeCenter), `test/utils/path_utils_test.dart` (dashPath: patrones, contornos múltiples, guarda anti-bucle) y `test/parsers/dxf_parser_test.dart` (tabla LTYPE: nombre+patrón, acumulación, mapa vacío, 49 no numéricos)
- `lib/utils/path_utils.dart` — `dashPath()` (PathMetrics/extractPath, patrón alterna trazo/espacio, guarda defensiva contra patrones no positivos)
### Changed
- `CadFile.lineTypes` (nuevo campo con copyWith/==/hashCode por valor profundo), `CadDocument.exportCadFile` lo propaga, `viewer_screen` lo pasa al painter, `shouldRepaint` lo compara

## [0.4.2] - 2026-08-01 — Fix volteo vertical + desproporción por outliers y bloques
### Fixed
- **Volteo vertical 180°**: `CoordinateTransform.worldToScreenY` no invertía Y (el mundo CAD tiene Y hacia arriba, la pantalla hacia abajo) → los dibujos se veían espejados. Ahora `screenY = -worldY·scale + offsetY` con `fitToScreen`, `zoomAt`, `updateCursor`, `_screenToWorld`, grid, arcos, elipses, textos, flechas de cota y halo de selección coherentes con la Y invertida
- **Desproporción por entidades "flotantes"**: `_documentBounds` (fit-to-screen) ahora usa `robustUnion` (bounds.dart): calcula el centro y tamaño medianos de las entidades y descarta outliers >100× en distancia / >1000× en tamaño, para que un punto o texto gigante fuera de escala no aplaste el resto del plano
- **Bloques (INSERT) resueltos en render y bounds**: `CadPainter` ahora pinta el contenido real de los bloques (`_paintInsert`/`_transformBlockEntity`: traslación + escala + rotación, anidados con límite de profundidad 12) en lugar de solo una cruz; `entityBoundsInFile` (público en cad_file) incluye la extensión de los bloques con rotación en fit y culling
### Added
- `test/utils/coordinate_transform_test.dart` (flip de Y, fit centrado, zoom bajo cursor) y `test/models/bounds_test.dart` (robustUnion: outliers lejanos y gigantes, archivos pequeños)
### Changed
- `lib/renderers/grid_renderer.dart`, `cad_painter.dart` — orden de min/max Y tras el flip (culling, halo y rejilla correctos)

## [0.4.1] - 2026-08-01 — Configuración de cotas y fuente
### Added
- **Ajustes de cotas en Configuración** (SettingsSheet → sección "Cotas y texto"): slider de **tamaño del texto de cota** (×0.2–×5.0), slider de **tamaño de flechas** (×0.2–×5.0) y selector de **fuente de la vista** (predeterminada, monoespaciada, serif, sans-serif, condensada, media, cursiva) — persisten en `shared_preferences`
- **CadViewModel**: preferencias `dimTextScale` / `dimArrowScale` / `dimFontFamily` (restaurar, persistir y setters con clamp [0.2, 5.0] y `transformVersion++` para repintado)
- **CadPainter**: parámetros `dimTextScale` / `dimArrowScale` / `dimFontFamily` aplicados en `_paintDimension` (texto × escala del usuario) y `_paintText` (fuente de la vista en cotas, TEXT y MTEXT); `shouldRepaint` compara los nuevos campos
- **Tests**: `test/controllers/cad_view_model_test.dart` (persistencia, defaults, clamp y setter de fuente)
### Changed
- `lib/screens/viewer_screen.dart` — pasa las nuevas preferencias al painter

## [0.4.0] - 2026-08-01 — Código implementado + fix de cotas
### Added
- **Código fuente completo implementado** (lib/): parser DXF propio (R12/R2000, LWPOLYLINE con bulges, POLYLINE pesada VERTEX/SEQEND, TEXT/MTEXT, INSERT, HATCH, SPLINE, DIMENSION, 3DFACE), writer DXF R2000/R12, editor con CommandStack (undo/redo, 100), SnapEngine (endpoint/midpoint/center/intersección/cuadrante/nearest/grid/polar + ortho), SelectionManager, CadViewModel (Provider), renderers (CadPainter, grid/axis/grip/snap/layer), 6 temas, pantallas Home/Viewer/LayerPanel/Settings, file_picker 10.3.10 (compat AGP 9), guardado SAF Android, autoguardado con path_provider, icono minimalista (círculo + rombo) y splash animado
- **Fix cotas gigantes (bug 1000x)**: `_paintDimension` usaba altura de texto FIJA de 20 unidades de mundo → en planos de ~100 m las cotas se veían ~1000x más grandes. Ahora: texto con altura real del DIMSTYLE (dimtxt=140) o 4% de la longitud medida, flechas rellenas reales (dimasz=41), puntos de extensión 2 (14/24), medición real (42), etiqueta formateada con `formatLength` en la unidad de visualización y mínimo legible de 12 px
- **CadDim extendido**: `x4/y4` (ext 2), `textHeight`, `arrowSize`, `measurement` + actualización de bounds (painter/cad_file/cad_block/selection_manager), transforms (move/rotate/scale), hit-testing, snap y writer
### Changed
- `docs/skills/` — Estado del proyecto: código fuente ✅ implementado (antes ❌); parcer DXF ✅, writer ✅, edición ✅, tests ✅
- `README.md` — Versión 0.4.0; código implementado

## [0.3.4] - 2026-07-31 — Pendientes v0.3.1 completados
### Added
- `docs/PERFORMANCE.md` §1.1 — **Presupuestos de rendimiento por plataforma**: tabla con Android (gama baja/media/alta por núcleos/RAM), iOS, Windows, macOS, Linux y Web con métricas de parseo 5 MB, apertura < 1 MB, FPS pan/zoom 10 k, memoria, escritura y jank; criterios de aplicación (heap Android, blob Web, jank por tier, clasificación de tier)
- `docs/TESTING.md` §5 — **YAML de GitHub Actions ejecutable** (`.github/workflows/ci.yml`): jobs analyze (`--fatal-infos`), format (`dart format`), unit (cobertura ≥ 70% con lcov), golden (comparación) y bench (tool/benchmark.dart contra PERFORMANCE.md §1/§1.1); `subosito/flutter-action@v2` con `channel: stable` y `cache: true`; notas de fijación de versión y builds iOS/macOS
### Changed
- `docs/PERFORMANCE.md` — Versión 0.3.1; §1 referencia §1.1; checklist §7 con verificación por plataforma; §6 benchmark contra `test/files/`
- `docs/TESTING.md` — Versión 0.3.3; §5 esquema → YAML completo; §6 benchmark actualizado
- `docs/CORRECTIONS.md` — Versión 0.3.4; §2.10 y §6: los dos pendientes v0.3.1 marcados como resueltos
- `README.md` — Versión 0.3.4

## [0.3.3] - 2026-07-31 — Especificación del escritor DXF
### Added
- **`docs/DXF_WRITER_SPEC.md`** — Especificación normativa del `DxfWriter` (group codes de salida R12/R2000): estructura general de salida (HEADER → TABLES → BLOCKS → ENTITIES → EOF), convenciones de precisión (6/8/8/6/4 decimales, sin notación científica), reglas de capa/color/handles, cabeceras de TABLES (LAYER/LTYPE/STYLE mínimos), emisión de bloques y `*Model_Space`, y **spec por entidad** (LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, POLYLINE, TEXT, MTEXT, INSERT, POINT, HATCH, SPLINE, DIMENSION, 3DFACE) con tablas R2000 vs R12, catálogo de warnings W-001…W-006, ejemplos completos (R2000 y R12), matriz de round-trip y casos de `dxf_writer_test.dart`
### Changed
- `docs/FORMATS.md` — §9: referencia a DXF_WRITER_SPEC.md como creada (ya no "pendiente"); versión 0.3.3
- `docs/CORRECTIONS.md` — §6: DXF_WRITER_SPEC.md movido a creados; lista de pendientes renumerada; versión 0.3.3
- `README.md` — Versión 0.3.3; fila `docs/DXF_WRITER_SPEC.md` en el índice de documentación

## [0.3.2] - 2026-07-31 — Archivos de muestra DXF (test/files/)
### Added
- **`test/files/`** — Conjunto de archivos de prueba que desbloquea parsers, writers y round-trip (TESTING.md §2 / FORMATS.md §11):
  - `sample_r12_librecad.dxf` (R12, POLYLINE pesada VERTEX/SEQEND, capas, TEXT)
  - `sample_r12_autocad.dxf` (R12, ARC, CIRCLE, POINT, bloque BOLT + INSERT rotado)
  - `sample_r2000.dxf` (R2000, LWPOLYLINE con bulge, SPLINE, MTEXT con códigos, HATCH SOLID, ELLIPSE)
  - `sample_r2010.dxf` (R2010, DIMENSION alineada + bloque anónimo `*D1`, bloques anidados A→B)
  - `sample_units_inch.dxf` (R2000, `$INSUNITS=1` conversión de unidades)
  - `sample_selection.dxf` (R2000, hit-testing denso: paralelas 0.1, círculos superpuestos, rejilla)
  - `sample_empty.dxf` (R2000, sin entidades)
  - `sample_binary.dxf` (DXF binario real R2000 con sentinel, 17 grupos, termina en EOF)
  - `sample_corrupt.dxf` (truncado a mitad de entidad, sin ENDSEC/EOF → ERR-PARSE-UNEXPECTED_EOF)
  - `sample_dwg.dwg` (stub con magic bytes `AC1032` para detección; placeholder hasta conversión ODA)
  - `test/files/README.md` — Manifest: matriz, convenciones de group codes, regeneración y reemplazo por archivos reales
### Changed
- `docs/TESTING.md` — Nota §2 actualizada: archivos creados (sintéticos validados) + recordatorio de reemplazo por exportaciones reales antes del release; añadido `sample_empty.dxf` a la matriz
- `docs/CORRECTIONS.md` — §6: "Muestras de archivos" movido a creados; versión 0.3.2
- `README.md` — Versión 0.3.2

## [0.3.1] - 2026-07-31 — Documentos críticos de publicación
### Added
- `docs/PRIVACY.md` — Política de privacidad completa para Google Play / App Store: datos recopilados (ninguno de contenido de planos), permisos, procesamiento local, conversión DWG local-first, formulario de datos de Google Play, Privacy Nutrition Labels de App Store, cumplimiento GDPR/CCPA/LGPD
- `LICENSE.md` — Licencia **MIT** (titular por defecto: "CAD Viewer & Editor contributors"; editable según decisión del titular)
- **Manual de usuario** en `README.md` — instalación, primeros pasos, navegación, capas, selección, edición (crear/transformar/snap/grips/undo), guardado y exportación, formatos soportados, temas, FAQ
### Changed
- `docs/SECURITY.md` — Referencia a PRIVACY.md como redactada; checklist de política de privacidad completado
- `docs/CORRECTIONS.md` — Sección 6 actualizada: PRIVACY.md, LICENSE.md, manual de usuario y UX_FLOWS.md marcados como creados; pendientes reordenados (LOCALIZATION, RELEASE, DXF_WRITER_SPEC, QA_MANUAL, etc.); sección "Archivos ajenos detectados" documentando `docs/LEARNINGS.md` (de otro proyecto, decisión pendiente del titular)
- `docs/RULES.md` — Nota §A: la línea "Current version:" de README incluye versión de documentación y de código; la regla de igualdad con VERSION aplica a la versión de código
- `docs/EDITING.md` — Atajo Ctrl+S (Guardar) añadido a la tabla de atajos §7.4
- `README.md` — Añadido al índice de documentación; sección manual de usuario; header con enlace a LICENSE.md; capas marcadas "según versión (v0.2+)"

## [0.3.0] - 2026-07-31 — Documentación profesional de equipo
### Added
- `docs/DESIGN_SYSTEM.md` — Sistema de diseño formal: design tokens nombrados (espaciado 4dp, radios, elevación z0–z5, opacidades, color semántico por tema, tipografía `type.*`, breakpoints xs–xl, motion), matriz de estados de componentes (normal/hover/pressed/disabled/focus/selected/loading), motion design con cubic-bezier y reduced-motion, registro de iconografía, accesibilidad visual (tabla de contraste, estrategia color-blind para capas ACI, dynamic type, semántica del canvas)
- `docs/UX_FLOWS.md` — 4 personas detalladas, arquitectura de información, flujos Mermaid (abrir, seleccionar, crear, mover, guardar), matriz de estados de UI (empty/loading/error/success/offline), microcopy es/en y voz de la app, ergonomía (zonas de pulgar, pen/stylus, palm rejection)
- `docs/SERIALIZATION.md` — Contrato de serialización: DTOs CadFileJson/CadEntityJson, precisión numérica (6/8/4 decimales), schemaVersion y migraciones, round-trip y pruebas, persistencia local (claves prefs `.v1`, autosave), contratos de Isolate
- `docs/ERROR_HANDLING.md` — Taxonomía de errores ERR-XXX (FILE/PARSE/EDIT/STATE/EXPORT), ErrorHandler centralizado, catálogo de mensajes ARB, política de logging con sanitización, reporte de crash local-first
- Diagramas Mermaid (classDiagram y sequenceDiagram) en `docs/ARCHITECTURE.md`, `docs/EDITING.md` y flujos en `docs/UX_FLOWS.md`
- Matriz de compatibilidad formato × versión × operación en `docs/FORMATS.md`
### Changed
- `docs/DESIGN.md` — Reestructurado como visión de alto nivel; delega tokens y especificaciones a DESIGN_SYSTEM.md; TOC y portada profesional
- `docs/REQUIREMENTS.md`, `docs/API.md`, `docs/DEVELOPMENT.md`, `docs/DATA_MODEL.md`, `docs/EDITING.md`, `docs/FORMATS.md`, `docs/ARCHITECTURE.md` — Front-matter profesional (versión, estado, equipo responsable) y TOC
- `README.md` — Índice ampliado con los 4 documentos nuevos; versión 0.3.0
- Auditoría de calidad realizada por equipo de expertos (design lead, UX, arquitecto técnico) con 2 rondas de revisión

## [0.2.0] - 2026-07-31
### Added
- **Alcance ampliado a CAD Viewer & Editor** (visualizar + editar), confirmado por el responsable del proyecto
- `docs/REQUIREMENTS.md` — Requisitos funcionales (RF-*) y no funcionales (RNF-*), actores, user stories, casos de borde, priorización por versión
- `docs/ARCHITECTURE.md` — Arquitectura por capas, módulos, flujos de datos (carga, edición, guardado, snap), Isolates, estado
- `docs/DATA_MODEL.md` — Modelo de datos completo: CadFile, CadDocument (sesión editable), CadLayer extendido (locked/frozen), CommandStack, SelectionManager, unidades en mm
- `docs/FORMATS.md` — Referencia DXF (estructura, group codes, versiones AC1009–AC1032), DWG (ODA File Converter CLI), DGN, compatibilidad LibreCAD (R12, POLYLINE pesada)
- `docs/EDITING.md` — Sistema de edición completo: patrón Command + CommandStack (límite 100), catálogo de comandos, selección múltiple (window/crossing), SnapEngine (9 modos + ortho), grips por tipo de entidad, línea de comandos (catálogo, coordenadas absolutas/relativas/polares), medición, guardado/autoguardado
- `docs/PERFORMANCE.md` — Presupuesto de rendimiento (60 fps / 10 k entidades), culling, spatial index, Isolates, cache, LOD
- `docs/TESTING.md` — Estrategia de pruebas (pirámide), archivos de muestra, cobertura ≥ 70%, CI propuesto, QA manual
- `docs/SECURITY.md` — Seguridad y privacidad: procesamiento local, mínimos permisos, conversión DWG local-first, política de privacidad
- `docs/ADR.md` — 8 decisiones de arquitectura (Provider, paquete dxf, DxfWriter propio, patrón Command, DWG ODA local, CustomPainter, unidades mm, DGN fuera de alcance)
- `docs/ROADMAP.md` — Roadmap versionado v0.1 (visor) → v0.2 (editor básico) → v0.3 (editor avanzado) → v1.0 (release)
- `docs/GLOSSARY.md` — Glosario de términos CAD y de la app
- `docs/CORRECTIONS.md` — Análisis de discrepancias y correcciones aplicadas a toda la documentación
- `docs/skills/CAD_EDITING.md` — Nuevo skill de edición para IA/desarrolladores

### Changed
- `docs/RULES.md` — Corregido: referencias de "KiCad Preview" → "CAD Viewer & Editor"; reglas adaptadas al dominio DXF/DWG (Isolates, Command pattern, nunca subir planos sin consentimiento); sección G de documentación
- `README.md` — Alcance visor+editor, estructura actualizada (controllers/command_stack, snap_engine, selection_manager; parsers/dxf_writer), mención LibreCAD, índice de documentación completo
- `docs/API.md` — Ampliado: CadDocument, DxfWriter, CommandStack, SnapEngine, SelectionManager, CadLayer extendido, CommandBar/ToolbarEdit widgets, version counters
- `docs/DEVELOPMENT.md` — Fases unificadas (visión → edición), pipeline de edición, paquetes, extensión con comandos nuevos
- `docs/TODO.md` — Fases renumeradas 0–13 (sin saltos), fases 8–12 de edición añadidas, DoD actualizadas
- `docs/PROMPT.md` — Prompt ampliado con requisitos completos de edición (comandos, snap, grips, línea de comandos, guardado)
- `docs/DESIGN.md` — Añadidas secciones 4.9 (diseño de edición: toolbar, command bar, grips, snap indicator) y 7.5 (preview en vivo); checklist ampliado
- `docs/AESTHETICS.md` — Corregido `ThemeMode` → `AppThemeMode`; 6 temas; checklist de edición ampliado
- `docs/CONTRIBUTING.md` — Requisitos de docs/tests, analyze, cobertura, review con undo/redo y rendimiento
- `docs/skills/*` — Actualizados con edición, nuevos módulos y referencias cruzadas

## [0.1.0] - 2026-07-31
### Added
- Documentación base completa adaptada a requisitos de app CAD Viewer
- Modelos: CadFile, CadLayer, CadEntity (Line, Circle, Arc, Ellipse, Polyline, LwPolyline, Text, MText, Insert, Point, Hatch, Spline, Dim, 3dFace)
- Arquitectura: screens/, widgets/, renderers/, parsers/, models/, utils/
- State management: CadViewModel con Provider + ChangeNotifier
- Dependencias definidas: dxf ^1.3.0, file_picker, shared_preferences, path_provider, screenshot, share_plus
- Pantallas: HomeScreen (recientes + abrir), ViewerScreen (canvas + controles)
- Features: layer panel, property panel, zoom controls, fit-to-screen, hit-testing
- DWG: soporte planeado vía conversión externa (ODA Teigha / Apryse / VeryPDF)
- Fases de desarrollo definidas (7 fases)
- PROMPT.md generado para solicitud a otra IA
- docs/DESIGN.md: documento completo de diseño visual y UX (paleta, tipografía, splash, pantallas, landscape, animaciones, onboarding, accesibilidad)
- docs/AESTHETICS.md: 4 estéticas profesionales CAD con paletas, ThemeData, ACI mapping, assets y checklist
- docs/TODO.md: lista de tareas accionables en 12 fases con Definition of Done
