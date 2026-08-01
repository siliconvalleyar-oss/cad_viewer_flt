/// Sesión editable de trabajo (docs/DATA_MODEL.md §7).
///
/// Dart puro. `CadDocument` envuelve un `CadFile` y mantiene el estado de
/// sesión (selección, capa actual, dirty, versiones). `exportCadFile()`
/// produce un `CadFile` **limpio** sin estado de sesión (DATA_MODEL §11.5).
///
/// En v0.1 las mutaciones son inmutables (devuelven un nuevo `CadDocument`);
/// los comandos de edición (Fase 9) delegarán aquí sus cambios.
library;

import 'package:collection/collection.dart';

import 'cad_block.dart';
import 'cad_entity.dart';
import 'cad_file.dart';
import 'cad_layer.dart';

/// Sesión de trabajo sobre un archivo.
class CadDocument {
  const CadDocument({
    required this.cadFile,
    this.entities = const [],
    this.layers = const [],
    this.blocks = const [],
    this.selection = const {},
    this.currentLayer = '0',
    this.dirty = false,
    this.documentVersion = 0,
  });

  /// Crea una sesión limpia a partir de un archivo (DATA_MODEL §7).
  factory CadDocument.fromCadFile(CadFile file) {
    final firstLayer = file.layers.isNotEmpty ? file.layers.first.name : '0';
    return CadDocument(
      cadFile: file,
      entities: List<CadEntity>.unmodifiable(file.entities),
      layers: List<CadLayer>.unmodifiable(file.layers),
      blocks: List<CadBlock>.unmodifiable(file.blocks),
      currentLayer: file.layerByName(firstLayer)?.name ?? '0',
    );
  }

  /// Archivo base (inmutable por convención).
  final CadFile cadFile;

  /// Entidades de trabajo.
  final List<CadEntity> entities;

  /// Capas de trabajo.
  final List<CadLayer> layers;

  /// Bloques de trabajo.
  final List<CadBlock> blocks;

  /// Handles seleccionados.
  final Set<String> selection;

  /// Capa activa (entidades nuevas).
  final String currentLayer;

  /// Cambios sin guardar.
  final bool dirty;

  /// Incrementa en cada cambio estructural.
  final int documentVersion;

  /// Convierte la sesión → archivo limpio (sin displayColor, isCurrent,
  /// selección ni dirty).
  CadFile exportCadFile() {
    final cleanLayers = layers
        .map(
          (l) => l.copyWith(
            displayColor: null,
            isCurrent: false,
          ),
        )
        .toList(growable: false);
    return CadFile(
      fileName: cadFile.fileName,
      format: cadFile.format,
      version: cadFile.version,
      header: cadFile.header,
      layers: cleanLayers,
      lineTypes: cadFile.lineTypes,
      entities: entities,
      blocks: blocks,
    );
  }

  /// Busca una entidad por handle; `null` si no existe.
  CadEntity? getEntity(String handle) {
    for (final entity in entities) {
      if (entity.handle == handle) {
        return entity;
      }
    }
    return null;
  }

  /// Entidades visibles (capa `visible && !frozen`; capa inexistente → visible).
  List<CadEntity> getVisibleEntities() {
    return entities
        .where((e) {
          final layer = _layerByName(e.layer);
          return layer == null || layer.isRenderable;
        })
        .toList(growable: false);
  }

  /// Devuelve una copia con una entidad añadida (dirty + version++).
  CadDocument addEntity(CadEntity entity) {
    return _mutated(
      entities: List<CadEntity>.unmodifiable([...entities, entity]),
    );
  }

  /// Devuelve una copia sin la entidad indicada (dirty + version++).
  CadDocument removeEntity(String handle) {
    return _mutated(
      entities: List<CadEntity>.unmodifiable(
        entities.where((e) => e.handle != handle),
      ),
    );
  }

  /// Devuelve una copia con las propiedades de una entidad actualizadas
  /// (usa `copyWith`; dirty + version++). No-op si el handle no existe.
  CadDocument setEntityProps(String handle, CadEntity updated) {
    return _mutated(
      entities: List<CadEntity>.unmodifiable(
        entities.map((e) => e.handle == handle ? updated : e),
      ),
    );
  }

  /// Devuelve una copia con la selección reemplazada (no marca dirty).
  CadDocument withSelection(Set<String> newSelection) {
    return CadDocument(
      cadFile: cadFile,
      entities: entities,
      layers: layers,
      blocks: blocks,
      selection: Set<String>.unmodifiable(newSelection),
      currentLayer: currentLayer,
      dirty: dirty,
      documentVersion: documentVersion,
    );
  }

  /// Devuelve una copia con la capa actual cambiada (no marca dirty).
  CadDocument withCurrentLayer(String layerName) {
    return CadDocument(
      cadFile: cadFile,
      entities: entities,
      layers: layers,
      blocks: blocks,
      selection: selection,
      currentLayer: layerName,
      dirty: dirty,
      documentVersion: documentVersion,
    );
  }

  /// Marca la sesión como modificada (no cambia la versión estructural).
  CadDocument markDirty() {
    return CadDocument(
      cadFile: cadFile,
      entities: entities,
      layers: layers,
      blocks: blocks,
      selection: selection,
      currentLayer: currentLayer,
      dirty: true,
      documentVersion: documentVersion,
    );
  }

  /// Copia inmutable con campos modificados (convención del dominio).
  CadDocument copyWith({
    CadFile? cadFile,
    List<CadEntity>? entities,
    List<CadLayer>? layers,
    List<CadBlock>? blocks,
    Set<String>? selection,
    String? currentLayer,
    bool? dirty,
    int? documentVersion,
  }) =>
      CadDocument(
        cadFile: cadFile ?? this.cadFile,
        entities: entities ?? this.entities,
        layers: layers ?? this.layers,
        blocks: blocks ?? this.blocks,
        selection: selection ?? this.selection,
        currentLayer: currentLayer ?? this.currentLayer,
        dirty: dirty ?? this.dirty,
        documentVersion: documentVersion ?? this.documentVersion,
      );

  /// Marca la sesión como guardada.
  CadDocument markSaved() {
    return CadDocument(
      cadFile: cadFile,
      entities: entities,
      layers: layers,
      blocks: blocks,
      selection: selection,
      currentLayer: currentLayer,
      dirty: false,
      documentVersion: documentVersion,
    );
  }

  /// Busca una capa por nombre; `null` si no existe.
  CadLayer? layerByName(String name) {
    for (final layer in layers) {
      if (layer.name == name) {
        return layer;
      }
    }
    return null;
  }

  CadLayer? _layerByName(String name) => layerByName(name);

  CadDocument _mutated({required List<CadEntity> entities}) {
    return CadDocument(
      cadFile: cadFile,
      entities: entities,
      layers: layers,
      blocks: blocks,
      selection: selection,
      currentLayer: currentLayer,
      dirty: true,
      documentVersion: documentVersion + 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CadDocument &&
      other.cadFile == cadFile &&
      const ListEquality<CadEntity>().equals(other.entities, entities) &&
      const ListEquality<CadLayer>().equals(other.layers, layers) &&
      const ListEquality<CadBlock>().equals(other.blocks, blocks) &&
      const SetEquality<String>().equals(other.selection, selection) &&
      other.currentLayer == currentLayer &&
      other.dirty == dirty &&
      other.documentVersion == documentVersion;

  @override
  int get hashCode => Object.hash(
        cadFile,
        const ListEquality<CadEntity>().hash(entities),
        const ListEquality<CadLayer>().hash(layers),
        const ListEquality<CadBlock>().hash(blocks),
        const SetEquality<String>().hash(selection),
        currentLayer,
        dirty,
        documentVersion,
      );
}
