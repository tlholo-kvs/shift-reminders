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
  final bool enabled;
  final String toneId;

  const ManualAlarm({
    required this.id,
    required this.label,
    required this.time,
    required this.weekdays,
    this.enabled = true,
    this.toneId = 'mixkit_morning_clock_alarm_1003',
  });

  ManualAlarm copyWith({
    String? label,
    TimeOfDay? time,
    Set<int>? weekdays,
    bool? enabled,
    String? toneId,
  }) {
    return ManualAlarm(
      id: id,
      label: label ?? this.label,
      time: time ?? this.time,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      toneId: toneId ?? this.toneId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'time': {'hour': time.hour, 'minute': time.minute},
    'weekdays': weekdays.toList(),
    'enabled': enabled,
    'toneId': toneId,
  };

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
        : <int>{1, 2, 3, 4, 5, 6, 7};

    return ManualAlarm(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label']?.toString() ?? 'Weekday alarm',
      time: TimeOfDay(
        hour: (time['hour'] is num) ? (time['hour'] as num).toInt() : 7,
        minute: (time['minute'] is num) ? (time['minute'] as num).toInt() : 0,
      ),
      weekdays: weekdays.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : weekdays,
      enabled: json['enabled'] as bool? ?? true,
      toneId: json['toneId'] as String? ?? 'mixkit_morning_clock_alarm_1003',
    );
  }
}
