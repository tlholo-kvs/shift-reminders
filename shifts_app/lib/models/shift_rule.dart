import 'package:flutter/material.dart';
import 'shift.dart';

const TimeOfDay nightBeforeDefault = TimeOfDay(hour: 20, minute: 0);

class ShiftRule {
  final ShiftType type;
  final TimeOfDay alarmTime;
  final TimeOfDay shiftStart;

  const ShiftRule({
    required this.type,
    required this.alarmTime,
    required this.shiftStart,
  });

  String get displayName => type.displayName;

  static const List<ShiftRule> defaults = [
    ShiftRule(
      type: ShiftType.earlyShift,
      alarmTime: TimeOfDay(hour: 6, minute: 40),
      shiftStart: TimeOfDay(hour: 8, minute: 0),
    ),
    ShiftRule(
      type: ShiftType.earlyShiftWFH,
      alarmTime: TimeOfDay(hour: 7, minute: 30),
      shiftStart: TimeOfDay(hour: 8, minute: 0),
    ),
    ShiftRule(
      type: ShiftType.middleShift,
      alarmTime: TimeOfDay(hour: 9, minute: 40),
      shiftStart: TimeOfDay(hour: 11, minute: 0),
    ),
    ShiftRule(
      type: ShiftType.lateShift,
      alarmTime: TimeOfDay(hour: 13, minute: 45),
      shiftStart: TimeOfDay(hour: 14, minute: 0),
    ),
    ShiftRule(
      type: ShiftType.off,
      alarmTime: TimeOfDay(hour: 0, minute: 0),
      shiftStart: TimeOfDay(hour: 0, minute: 0),
    ),
  ];

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'alarmTime': {'hour': alarmTime.hour, 'minute': alarmTime.minute},
      'shiftStart': {'hour': shiftStart.hour, 'minute': shiftStart.minute},
    };
  }

  factory ShiftRule.fromJson(Map<String, dynamic> json) {
    final alarmMap = json['alarmTime'] as Map<String, dynamic>;
    final startMap = json['shiftStart'] as Map<String, dynamic>;
    return ShiftRule(
      type: ShiftType.values.firstWhere((e) => e.name == json['type']),
      alarmTime: TimeOfDay(
        hour: alarmMap['hour'] as int,
        minute: alarmMap['minute'] as int,
      ),
      shiftStart: TimeOfDay(
        hour: startMap['hour'] as int,
        minute: startMap['minute'] as int,
      ),
    );
  }
}
