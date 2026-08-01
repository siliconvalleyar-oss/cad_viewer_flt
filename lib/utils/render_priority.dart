/// Prioridad de renderizado de entidades (docs/CORREGIR_instrucciones-… §D).
///
/// El documento pide un orden de pintado por categorías para que los
/// elementos más importantes no queden ocultos: muros → columnas → puertas →
/// ventanas → polilíneas → equipamiento → bloques → símbolos → textos →
/// cotas → hatch. Menor valor = se pinta primero (detrás); mayor valor = se
/// pinta encima (legibilidad de anotaciones).
library;

import '../models/cad_entity.dart';

/// Devuelve la prioridad de pintado de [e] según el doc §D.
///
/// Orden de decisión: primero por TIPO (los rellenos van detrás de todo y
/// las anotaciones —texto/cota— siempre encima, sin importar el nombre de
/// su capa), luego por heurística de capa solo para la geometría lineal.
///
/// - 0: rellenos (HATCH/SOLID/TRACE/3DFACE) — detrás de todo para que las
///   áreas no tapen líneas.
/// - 1–4: muros/estructura, columnas, puertas, ventanas (heurística por capa).
/// - 5: polilíneas y geometría general.
/// - 6: equipamiento/mobiliario.
/// - 7: bloques (INSERT).
/// - 8: símbolos/anotaciones auxiliares.
/// - 9: TEXT/MTEXT — encima de la geometría.
/// - 10: DIMENSION — encima de todo (anotación de medida).
int renderPriority(CadEntity e) {
  // Rellenos: siempre detrás de la geometría (no tapan líneas/textos).
  if (e is CadHatch || e is CadSolid || e is Cad3dFace) {
    return 0;
  }
  // Anotaciones por tipo: un TEXT en una capa llamada "MUROS" es texto y
  // debe pintarse encima (no enterrarse por la heurística de capa).
  if (e is CadText || e is CadMText) {
    return 9;
  }
  if (e is CadDim) {
    return 10;
  }
  if (e is CadInsert) {
    return 7;
  }

  // Geometría lineal: heurística por capa (doc §D).
  final layer = e.layer.toUpperCase();

  bool inLayer(List<String> keys) => keys.any(layer.contains);

  // Muros y geometría estructural.
  if (inLayer(const [
    'WALL', 'MURO', 'ESTRUCT', 'STRUCT', 'CIMENT',
    'VIGA', 'BEAM', 'LOSA', 'SLAB', 'CONTORNO',
  ])) {
    return 1;
  }
  // Columnas.
  if (inLayer(const ['COLUMN', 'PILAR', 'COLUMNA'])) {
    return 2;
  }
  // Puertas. Ojo: 'PORT' a secas matchea 'SUPPORT' (capa estructural
  // común), por eso se exige 'PORTAL'/'DOOR*'/'PUERTA*'.
  if (inLayer(const ['DOOR', 'DOORS', 'PUERTA', 'PUERTAS', 'PORTAL'])) {
    return 3;
  }
  // Ventanas.
  if (inLayer(const ['WINDOW', 'VENTANA', 'VAN-', 'VANOS'])) {
    return 4;
  }
  // Equipamiento / mobiliario / sanitarios.
  if (inLayer(const [
    'EQUIP', 'MOBIL', 'FURN', 'SANIT', 'ACCES', 'FIXT', 'GRIF', 'APARATO',
  ])) {
    return 6;
  }
  // Símbolos y anotaciones auxiliares.
  if (inLayer(const ['SYMB', 'SIMB', 'NIVEL', 'LEVEL', 'COTA', 'COTAS'])) {
    return 8;
  }
  // Polilíneas y geometría general (líneas, círculos, arcos, splines).
  return 5;
}
