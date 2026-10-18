import 'package:flutter/material.dart';

import '../models/schedule.dart';

class StatusBanner extends StatelessWidget {
  final OutageReason reason;

  const StatusBanner({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = reason.isActiveOutage;

    final bg = isActive
        ? theme.colorScheme.errorContainer
        : const Color(0xFF5C5A1E); // close to site olive
    final fg = isActive
        ? theme.colorScheme.onErrorContainer
        : const Color(0xFFE8E6C8);

    return Card(
      color: bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isActive)
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: fg, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Активне відключення',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.info_outline, color: fg, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Поточний статус',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              reason.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                height: 1.4,
              ),
            ),
            if (reason.groups.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: reason.groups
                    .map(
                      (g) => Chip(
                        label: Text(g, style: TextStyle(color: fg, fontSize: 12)),
                        backgroundColor: fg.withValues(alpha: 0.15),
                        side: BorderSide(color: fg.withValues(alpha: 0.3)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (reason.updateTimestamp != null) ...[
              const SizedBox(height: 12),
              Text(
                'Дата оновлення інформації – ${reason.updateTimestamp}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.85),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
