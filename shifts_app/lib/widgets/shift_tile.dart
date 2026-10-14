import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';

class ShiftTile extends StatelessWidget {
  final Shift shift;
  final ShiftRule? rule;

  const ShiftTile({super.key, required this.shift, required this.rule});

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPast = shift.isPast;
    final textStyle = isPast
        ? TextStyle(color: Theme.of(context).disabledColor)
        : null;

    final String trailingText;
    if (shift.type == ShiftType.off || rule == null) {
      trailingText = 'No alarm';
    } else {
      trailingText = _formatTime(rule!.alarmTime);
    }

    return ListTile(
      leading: Icon(
        Icons.schedule,
        color: isPast ? Theme.of(context).disabledColor : null,
      ),
      title: Text(
        DateFormat('EEE d MMM yyyy').format(shift.date),
        style: textStyle,
      ),
      subtitle: Text(
        rule?.displayName ?? shift.type.displayName,
        style: textStyle,
      ),
      trailing: Text(
        trailingText,
        style: textStyle,
      ),
    );
  }
}
