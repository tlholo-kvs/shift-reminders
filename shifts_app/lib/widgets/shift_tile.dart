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
    const surface = Color(0xFF26365E);
    const accent = Color(0xFFEAFB67);

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
        color: enabled ? surface : const Color(0xFF34405A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule?.displayName ?? shift.type.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: accent,
                  activeTrackColor: accent.withValues(alpha: 0.35),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFF667085),
                  onChanged: null,
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  alarmTime,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                if (period.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      period,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$dateName  $dateNumber',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPast ? 'Past' : 'Scheduled',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _period(TimeOfDay time) {
    return time.hour >= 12 ? 'PM' : 'AM';
  }
}
