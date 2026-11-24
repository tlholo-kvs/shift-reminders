import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifts_app/models/manual_alarm.dart';

void main() {
  test('round-trips a one-time alarm without converting it to repeats', () {
    final date = DateTime(2026, 11, 24);
    final alarm = ManualAlarm(
      id: 'one-time',
      label: 'Appointment',
      time: const TimeOfDay(hour: 9, minute: 30),
      weekdays: const {},
      scheduledDate: date,
    );

    final restored = ManualAlarm.fromJson(alarm.toJson());

    expect(restored.weekdays, isEmpty);
    expect(restored.scheduledDate, date);
  });

  test('preserves selected repeat days without a one-time date', () {
    final alarm = ManualAlarm.fromJson({
      'id': 'weekly',
      'label': 'Weekly alarm',
      'time': {'hour': 7, 'minute': 0},
      'weekdays': [2, 4],
    });

    expect(alarm.weekdays, {2, 4});
    expect(alarm.scheduledDate, isNull);
  });
}
