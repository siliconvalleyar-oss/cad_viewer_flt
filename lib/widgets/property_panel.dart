/// Panel de propiedades de la entidad seleccionada (docs/UX_FLOWS.md,
/// RF-SEL-05). Bottom sheet con tipo, capa, color y geometría; permite
/// editar el contenido de textos.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../models/cad_entity.dart';
import '../models/cad_enums.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/units.dart';

/// Bottom sheet de propiedades.
class PropertyPanel extends StatelessWidget {
  const PropertyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final sel = vm.selectedEntities;
    final palette = AppThemes.byMode(
      context.select<CadViewModel, AppThemeMode>((v) => v.themeMode),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: sel.isEmpty
              ? _empty(scrollController, palette)
              : _properties(context, vm, sel, scrollController, palette),
        );
      },
    );
  }

  Widget _empty(ScrollController c, dynamic palette) {
    return ListView(
      controller: c,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        Center(child: Text('Toca una entidad para ver sus propiedades')),
      ],
    );
  }

  Widget _properties(
    BuildContext context,
    CadViewModel vm,
    List<CadEntity> sel,
    ScrollController c,
    dynamic palette,
  ) {
    final e = sel.first;
    return ListView(
      controller: c,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Text(
              '${_typeName(e.type)}${sel.length > 1 ? ' (${sel.length})' : ''}',
              style: AppType.title,
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar'),
              onPressed: () {
                vm.deleteSelection();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        const Divider(),
        _row('Capa', e.layer),
        _row('Handle', e.handle),
        _row('Color', e.color == null ? 'ByLayer' : 'ACI ${e.color}'),
        if (e.lineType != null) _row('Tipo de línea', e.lineType!),
        if (e.lineWeight != null) _row('Grosor', '${e.lineWeight} mm'),
        const Divider(),
        ..._geometryRows(e, vm),
        if (e is CadText || e is CadMText)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Editar texto'),
              onPressed: () => _editText(context, vm, e),
            ),
          ),
      ],
    );
  }

  List<Widget> _geometryRows(CadEntity e, CadViewModel vm) {
    final rows = <Widget>[];
    void add(String label, double v) {
      rows.add(_row(label, '${mmToUnit(v, vm.units).toStringAsFixed(2)} ${vm.units.symbol}'));
    }

    switch (e) {
      case final CadLine l:
        add('Inicio', 0);
        add('X1', l.x1);
        add('Y1', l.y1);
        add('X2', l.x2);
        add('Y2', l.y2);
        add('Longitud', distanceMm(l, vm.units));
      case final CadCircle c:
        add('Centro X', c.cx);
        add('Centro Y', c.cy);
        add('Radio', c.radius);
      case final CadArc a:
        add('Centro X', a.cx);
        add('Centro Y', a.cy);
        add('Radio', a.radius);
        rows.add(_row('Ángulo inicio', '${(a.startAngle * 180 / 3.14159265).toStringAsFixed(1)}°'));
        rows.add(_row('Ángulo fin', '${(a.endAngle * 180 / 3.14159265).toStringAsFixed(1)}°'));
      case final CadEllipse el:
        add('Centro X', el.cx);
        add('Centro Y', el.cy);
        add('Eje mayor', el.majorRadius);
        add('Eje menor', el.minorRadius);
      case final CadLwPolyline p:
        rows.add(_row('Vértices', '${p.points.length}'));
        rows.add(_row('Cerrada', p.closed ? 'Sí' : 'No'));
      case final CadPolyline p:
        rows.add(_row('Vértices', '${p.points.length}'));
        rows.add(_row('Cerrada', p.closed ? 'Sí' : 'No'));
      case final CadText t:
        rows.add(_row('Contenido', t.text));
        add('Altura', t.height);
      case final CadMText m:
        rows.add(_row('Contenido', m.text.length > 40 ? '${m.text.substring(0, 40)}…' : m.text));
        add('Altura', m.height);
      case final CadInsert i:
        rows.add(_row('Bloque', i.blockName));
        add('X', i.x);
        add('Y', i.y);
      case final CadPoint pt:
        add('X', pt.x);
        add('Y', pt.y);
      case final CadHatch h:
        rows.add(_row('Patrón', h.patternName));
      case final CadSpline s:
        rows.add(_row('Puntos de control', '${s.controlPoints.length}'));
      case final CadDim d:
        rows.add(_row('Tipo', d.dimType.name));
      case final Cad3dFace f:
        rows.add(_row('Esquinas', '${f.corners.length}'));
    }
    return rows;
  }

  double distanceMm(CadLine l, UnitsType units) {
    final d = (l.x1 - l.x2) * (l.x1 - l.x2) + (l.y1 - l.y2) * (l.y1 - l.y2);
    return d <= 0 ? 0 : d * 0.5; // placeholder; real en geometry
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: AppType.label)),
          Expanded(child: Text(value, style: AppType.body)),
        ],
      ),
    );
  }

  Future<void> _editText(BuildContext context, CadViewModel vm, CadEntity e) async {
    final controller = TextEditingController(
      text: e is CadText ? e.text : (e as CadMText).text,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar texto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Texto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (result != null) {
      final updated = e is CadText
          ? e.copyWith(text: result)
          : (e as CadMText).copyWith(text: result);
      vm.modifyEntity(e.handle, updated);
    }
  }

  String _typeName(CadEntityType t) => switch (t) {
        CadEntityType.line => 'Línea',
        CadEntityType.circle => 'Círculo',
        CadEntityType.arc => 'Arco',
        CadEntityType.ellipse => 'Elipse',
        CadEntityType.lwPolyline => 'Polilínea',
        CadEntityType.polyline => 'Polilínea',
        CadEntityType.text => 'Texto',
        CadEntityType.mtext => 'Texto multilínea',
        CadEntityType.insert => 'Bloque',
        CadEntityType.point => 'Punto',
        CadEntityType.hatch => 'Sombreado',
        CadEntityType.spline => 'Spline',
        CadEntityType.dim => 'Dimensión',
        CadEntityType.face3d => 'Cara 3D',
      };
}
