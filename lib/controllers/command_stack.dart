/// Pila de comandos para undo/redo (docs/EDITING.md §3, ADR-0004).
///
/// Todo comando implementa `execute`/`undo` sobre un `CadDocument` inmutable
/// devolviendo el documento resultante. La pila mantiene un límite de 100
/// operaciones (RF-EDI-09).
library;

import '../models/cad_document.dart';

/// Comando de edición ejecutable y deshacible (patrón Command).
abstract class CadCommand {
  /// Descripción legible (p. ej. 'Mover 3 entidades').
  String get description;

  /// Aplica el comando al documento y devuelve el documento resultante.
  CadDocument execute(CadDocument doc);

  /// Revierte el comando y devuelve el documento resultante.
  CadDocument undo(CadDocument doc);
}

/// Pila undo/redo con límite de 100 comandos.
class CommandStack {
  final List<CadCommand> _undoStack = <CadCommand>[];
  final List<CadCommand> _redoStack = <CadCommand>[];

  /// Límite de operaciones de undo (RF-EDI-09).
  static const int maxUndo = 100;

  /// `true` si hay algo que deshacer.
  bool get canUndo => _undoStack.isNotEmpty;

  /// `true` si hay algo que rehacer.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Número de operaciones deshacibles.
  int get undoCount => _undoStack.length;

  /// Descripción del siguiente undo (para la UI).
  String? get nextUndoDescription => _undoStack.isEmpty ? null : _undoStack.last.description;

  /// Descripción del siguiente redo (para la UI).
  String? get nextRedoDescription => _redoStack.isEmpty ? null : _redoStack.last.description;

  /// Ejecuta el comando sobre [doc], lo apila y devuelve el documento.
  CadDocument push(CadCommand command, CadDocument doc) {
    final result = command.execute(doc);
    _undoStack.add(command);
    if (_undoStack.length > maxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    return result;
  }

  /// Deshace el último comando y devuelve el documento resultante.
  CadDocument undo(CadDocument doc) {
    if (_undoStack.isEmpty) {
      return doc;
    }
    final command = _undoStack.removeLast();
    _redoStack.add(command);
    return command.undo(doc);
  }

  /// Rehace el último comando deshecho y devuelve el documento resultante.
  CadDocument redo(CadDocument doc) {
    if (_redoStack.isEmpty) {
      return doc;
    }
    final command = _redoStack.removeLast();
    _undoStack.add(command);
    return command.execute(doc);
  }

  /// Limpia ambas pilas (al abrir un archivo nuevo).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
