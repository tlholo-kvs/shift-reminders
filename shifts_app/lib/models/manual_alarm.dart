import 'package:flutter/material.dart';

class AlarmTone {
  final String id;
  final String name;

  const AlarmTone(this.id, this.name);

  static const tones = <AlarmTone>[
    AlarmTone('mixkit_morning_clock_alarm_1003', 'Morning Clock Alarm'),
    AlarmTone('mixkit_scanning_sci_fi_alarm_905', 'Scanning Sci-Fi Alarm'),
    AlarmTone('mixkit_street_public_alarm_997', 'Street Public Alarm'),
    AlarmTone('mixkit_alert_alarm_1005', 'Alert Alarm'),
  ];

  static AlarmTone find(String id) {
    return tones.firstWhere((tone) => tone.id == id, orElse: () => tones.first);
  }
}

class ManualAlarm {
  final String id;
  final String label;
  final TimeOfDay time;
  final Set<int> weekdays;
  final DateTime? scheduledDate;
  final bool enabled;
  final String toneId;

  const ManualAlarm({
    required this.id,
    required this.label,
    required this.time,
    required this.weekdays,
    this.scheduledDate,
    this.enabled = true,
    this.toneId = 'mixkit_morning_clock_alarm_1003',
  });

  ManualAlarm copyWith({
    String? label,
    TimeOfDay? time,
    Set<int>? weekdays,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    bool? enabled,
    String? toneId,
  }) {
    return ManualAlarm(
      id: id,
      label: label ?? this.label,
      time: time ?? this.time,
      weekdays: weekdays ?? this.weekdays,
      scheduledDate: clearScheduledDate
          ? null
          : scheduledDate ?? this.scheduledDate,
      enabled: enabled ?? this.enabled,
      toneId: toneId ?? this.toneId,
    );
  }

  Map<String, dynamic> toJson() {
    final occurrenceDate =
        scheduledDate ?? (weekdays.isEmpty ? DateTime.now() : null);
    return {
      'id': id,
      'label': label,
      'time': {'hour': time.hour, 'minute': time.minute},
      'weekdays': weekdays.toList(),
      'scheduledDate': occurrenceDate == null
          ? null
          : '${occurrenceDate.year.toString().padLeft(4, '0')}-'
                '${occurrenceDate.month.toString().padLeft(2, '0')}-'
                '${occurrenceDate.day.toString().padLeft(2, '0')}',
      'enabled': enabled,
      'toneId': toneId,
    };
  }

  factory ManualAlarm.fromJson(Map<String, dynamic> json) {
    final timeValue = json['time'];
    final time = timeValue is Map
        ? timeValue.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final weekdaysValue = json['weekdays'];
    final weekdays = weekdaysValue is Iterable
        ? weekdaysValue
              .whereType<num>()
              .map((day) => day.toInt())
              .where((day) => day >= 1 && day <= 7)
              .toSet()
        : weekdaysValue == null
        ? <int>{1, 2, 3, 4, 5, 6, 7}
        : <int>{};
    final scheduledDate = json['scheduledDate'] is String
        ? DateTime.tryParse(json['scheduledDate'] as String)
        : null;
    final today = DateTime.now();

    return ManualAlarm(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label']?.toString() ?? 'Weekday alarm',
      time: TimeOfDay(
        hour: (time['hour'] is num) ? (time['hour'] as num).toInt() : 7,
        minute: (time['minute'] is num) ? (time['minute'] as num).toInt() : 0,
      ),
      weekdays: weekdays,
      scheduledDate: scheduledDate == null
          ? (weekdays.isEmpty
                ? DateTime(today.year, today.month, today.day)
                : null)
          : DateTime(
              scheduledDate.year,
              scheduledDate.month,
              scheduledDate.day,
            ),
      enabled: json['enabled'] as bool? ?? true,
      toneId: json['toneId'] as String? ?? 'mixkit_morning_clock_alarm_1003',
    );
  }
}
