/// Lista horizontal de archivos recientes (docs/UX_FLOWS.md, RF-RECIENTES-02).
///
/// Tarjetas con nombre y fecha; tocar reabre el archivo, deslizar lo elimina
/// del historial (RF-RECIENTES-03).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cad_view_model.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';

/// Lista de recientes.
class RecentFilesList extends StatelessWidget {
  const RecentFilesList({super.key, required this.onOpen});

  /// Callback al tocar un archivo reciente.
  final void Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadViewModel>();
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    final recents = vm.recentFiles;

    if (recents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Tus archivos recientes aparecerán aquí.',
          style: AppType.body.copyWith(color: palette.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: recents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final r = recents[index];
          return _RecentCard(
            name: r.name,
            date: r.date,
            onTap: () => onOpen(r.path),
            onDismiss: () => vm.removeRecent(r.path),
          );
        },
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.name,
    required this.date,
    required this.onTap,
    required this.onDismiss,
  });

  final String name;
  final int date;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.select<CadViewModel, AppThemePalette>(
      (v) => AppThemes.byMode(v.themeMode),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDismiss,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.outline.withValues(alpha: 0.4)),
          boxShadow: AppElevation.z1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.description_outlined, color: palette.accent, size: 22),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label,
            ),
            Text(
              _fmtDate(date),
              style: AppType.caption.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hoy ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}';
  }
}
