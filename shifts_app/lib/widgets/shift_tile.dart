import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';

class ShiftTile extends StatelessWidget {
  final Shift shift;
  final ShiftRule? rule;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ShiftTile({
    super.key,
    required this.shift,
    required this.rule,
    this.onTap,
    this.onLongPress,
  });

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
    final dateName = DateFormat('EEE').format(shift.date).toUpperCase();
    final dateNumber = DateFormat('d MMM').format(shift.date);

    return Material(
      color: enabled ? surface : const Color(0xFF12192B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        alarmTime,
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
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
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
