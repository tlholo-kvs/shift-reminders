import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';

class ShiftTile extends StatelessWidget {
  final Shift shift;
  final ShiftRule? rule;

  const ShiftTile({super.key, required this.shift, required this.rule});

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '$hour:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF1B2749);
    const accent = Color(0xFF7867F6);

    final isPast = shift.isPast;
    final enabled = !isPast && shift.type != ShiftType.off && rule != null;

    final alarmTime = rule == null || shift.type == ShiftType.off
        ? '--:--'
        : _formatTime(rule!.alarmTime);
    final period = rule == null ? '' : _period(rule!.alarmTime);
    final dateName = DateFormat('EEE').format(shift.date).toUpperCase();
    final dateNumber = DateFormat('d MMM').format(shift.date);

    return Container(
      decoration: BoxDecoration(
        color: enabled ? surface : const Color(0xFF12192B),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarmTime,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white54,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                if (period.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(period,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule?.displayName ?? shift.type.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$dateName  $dateNumber',
                  style: TextStyle(
                    color: enabled ? accent : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF667085),
            onChanged: null,
          ),
        ],
      ),
    );
  }

  String _period(TimeOfDay time) {
    return time.hour >= 12 ? 'PM' : 'AM';
  }
}
