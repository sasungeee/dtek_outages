import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';

class ScheduleTimeline extends StatelessWidget {
  final DaySchedule day;

  const ScheduleTimeline({super.key, required this.day});

  Color _statusColor(SlotStatus s, ColorScheme scheme) {
    switch (s) {
      case SlotStatus.yes:
        return Colors.white;
      case SlotStatus.no:
        return const Color(0xFF4A4A4A);
      case SlotStatus.maybe:
        return const Color(0xFF9E9E9E);
      case SlotStatus.first:
      case SlotStatus.second:
        return const Color(0xFF6B6B6B);
      case SlotStatus.mfirst:
      case SlotStatus.msecond:
        return const Color(0xFFB0B0B0);
      case SlotStatus.unknown:
        return scheme.surfaceContainerHighest;
    }
  }

  Color _statusFg(SlotStatus s) {
    if (s == SlotStatus.yes) return Colors.black87;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('dd.MM.yyyy (EEEE)', 'uk').format(day.date);
    final title = day.isToday
        ? 'Сьогодні · $dateLabel'
        : day.isTomorrow
            ? 'Завтра · $dateLabel'
            : dateLabel;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  day.isToday ? Icons.today : Icons.event,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (day.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Оновлено: ${day.updatedAt}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!day.isAvailable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day.emptyMessage ?? 'Графік відсутній',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              _buildGrid(context),
            if (day.isAvailable) ...[
              const SizedBox(height: 12),
              _buildLegend(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.6,
          ),
          itemCount: day.slots.length,
          itemBuilder: (context, i) {
            final slot = day.slots[i];
            final bg = _statusColor(slot.status, scheme);
            final fg = _statusFg(slot.status);
            return Tooltip(
              message: '${slot.start}–${slot.end}\n${slot.status.label}',
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  slot.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context) {
    final items = [
      (SlotStatus.yes, 'Світло є'),
      (SlotStatus.no, 'Світла немає'),
      (SlotStatus.maybe, 'Можливо відкл.'),
      (SlotStatus.first, 'Перші 30 хв'),
      (SlotStatus.second, 'Другі 30 хв'),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: items.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _statusColor(e.$1, scheme),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
            const SizedBox(width: 4),
            Text(e.$2, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      }).toList(),
    );
  }
}
