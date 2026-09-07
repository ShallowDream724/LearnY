import 'package:flutter/material.dart';

import '../../../core/schedule/schedule_models.dart';

class ScheduleCourseEntry extends StatelessWidget {
  const ScheduleCourseEntry({
    super.key,
    required this.item,
    required this.onOpen,
    this.stacked = false,
  });

  final TodayScheduleItem item;
  final ValueChanged<String> onOpen;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = item.courseId;
    final canOpen = id != null && id.isNotEmpty;
    const colors = [Color(0xFF187D8D), Color(0xFF3B68AF), Color(0xFFB65B5D)];
    final color =
        colors[item.courseName.codeUnits.fold<int>(
              0,
              (sum, code) => sum + code,
            ) %
            colors.length];
    return Tooltip(
      message: '${item.courseName}\n${item.timeLabel}\n${item.location}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpen ? () => onOpen(id) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stacked)
                  Text(
                    item.timeLabel,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                Row(
                  children: [
                    if (!stacked) ...[
                      SizedBox(
                        width: MediaQuery.textScalerOf(context).scale(44),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.startTime.isEmpty ? '待定' : item.startTime,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: color,
                              ),
                            ),
                            if (item.endTime.isNotEmpty)
                              Text(
                                item.endTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.35,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.courseName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.location.isEmpty ? '地点待定' : item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canOpen && !stacked)
                      const Icon(Icons.chevron_right, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
