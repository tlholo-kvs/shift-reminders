import 'dart:io';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../models/manual_alarm.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _timezoneChannel = MethodChannel(
    'com.example.shifts_app/timezone',
  );
  static const MethodChannel _alarmChannel = MethodChannel(
    'com.example.shifts_app/timezone',
  );

  Future<void> scheduleMockAlarm({
    int delaySeconds = 10,
    String toneId = 'mixkit_morning_clock_alarm_1003',
  }) async {
    if (!Platform.isAndroid) {
      debugPrint(
        '[ALARM DEBUG] Mock alarms are currently implemented on Android',
      );
      return;
    }
    debugPrint(
      '[ALARM DEBUG] Scheduling mock alarm in ${delaySeconds}s '
      '(tone=$toneId)',
    );
    await _alarmChannel.invokeMethod<void>('scheduleMockAlarm', {
      'delaySeconds': delaySeconds,
      'toneId': toneId,
      'label': 'Mock Alarm',
    });
  }

  Future<Map<String, dynamic>> getAlarmDebugInfo() async {
    if (!Platform.isAndroid) return const {};
    final result = await _alarmChannel.invokeMethod<Map<Object?, Object?>>(
      'getAlarmDebugInfo',
    );
    if (result == null) return const {};
    return result.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _clearScheduledNotificationCache() async {
    if (!Platform.isAndroid) return;
    try {
      await _timezoneChannel.invokeMethod<void>('clearScheduledNotifications');
    } catch (_) {}
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
    await _clearScheduledNotificationCache();
  }

  Future<void> scheduleAll(
    List<Shift> shifts,
    List<ShiftRule> rules,
    TimeOfDay nightBefore,
  ) async {
    if (Platform.isAndroid) {
      final alarms = <Map<String, dynamic>>[];
      for (final shift in shifts) {
        if (shift.isPast || shift.type == ShiftType.off) continue;
        ShiftRule? rule;
        try {
          rule = rules.firstWhere((r) => r.type == shift.type);
        } catch (_) {
          continue;
        }
        final scheduledDate = tz.TZDateTime(
          tz.local,
          shift.date.year,
          shift.date.month,
          shift.date.day,
          rule.alarmTime.hour,
          rule.alarmTime.minute,
        );
        if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) continue;
        alarms.add({
          'millis': scheduledDate.millisecondsSinceEpoch,
          'label':
              '${rule.displayName} starts at ${_formatTime(rule.shiftStart)}',
          'toneId': 'mixkit_morning_clock_alarm_1003',
          'id': 'shift_${shift.date.millisecondsSinceEpoch}',
        });
      }
      await _alarmChannel.invokeMethod<void>('scheduleShiftAlarms', {
        'alarms': jsonEncode(alarms),
      });
    }
    await _clearScheduledNotificationCache();
    await _plugin.cancelAll();

    for (final shift in shifts) {
      if (shift.isPast || shift.type == ShiftType.off) continue;

      ShiftRule? rule;
      try {
        rule = rules.firstWhere((r) => r.type == shift.type);
      } catch (_) {
        continue;
      }

      final now = tz.TZDateTime.now(tz.local);

      // Night-before notification (both platforms)
      final nightBeforeDateTime = tz.TZDateTime(
        tz.local,
        shift.date.year,
        shift.date.month,
        shift.date.day - 1,
        nightBefore.hour,
        nightBefore.minute,
      );
      if (nightBeforeDateTime.isAfter(now)) {
        final nightBeforeId = (shift.date.millisecondsSinceEpoch ~/ 60000) * 2;
        await _plugin.zonedSchedule(
          nightBeforeId,
          'Shift Tomorrow',
          '${rule.displayName} tomorrow — alarm set for ${_formatTime(rule.alarmTime)}',
          nightBeforeDateTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'shift_reminders_night',
              'Night Before Reminders',
              channelDescription: 'Notifications the night before a shift',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      // Wake alarm / notification
      final wakeDateTime = tz.TZDateTime(
        tz.local,
        shift.date.year,
        shift.date.month,
        shift.date.day,
        rule.alarmTime.hour,
        rule.alarmTime.minute,
      );
      if (wakeDateTime.isAfter(now)) {
        if (!Platform.isAndroid) {
          final wakeId = (shift.date.millisecondsSinceEpoch ~/ 60000) * 2 + 1;
          await _plugin.zonedSchedule(
            wakeId,
            'Time to get up!',
            '${rule.displayName} starts at ${_formatTime(rule.shiftStart)}',
            wakeDateTime,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'shift_reminders_alarm',
                'Wake Alarms',
                channelDescription: 'Wake alarm notifications',
                importance: Importance.max,
                priority: Priority.max,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
  }

  Future<int> countScheduled(List<Shift> shifts) async {
    return shifts.where((s) => !s.isPast && s.type != ShiftType.off).length;
  }

  Future<void> scheduleManualAlarms(List<ManualAlarm> alarms) async {
    if (Platform.isAndroid) {
      await _alarmChannel.invokeMethod<void>('scheduleManualAlarms', {
        'alarms': jsonEncode(alarms.map((alarm) => alarm.toJson()).toList()),
      });
      return;
    }
    if (!Platform.isAndroid) {
      for (var id = 80000; id < 90000; id++) {
        await _plugin.cancel(id);
      }
    }

    for (final alarm in alarms) {
      if (!alarm.enabled) continue;

      for (final weekday in alarm.weekdays) {
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'android.intent.action.SET_ALARM',
            arguments: <String, dynamic>{
              'android.intent.extra.alarm.HOUR': alarm.time.hour,
              'android.intent.extra.alarm.MINUTES': alarm.time.minute,
              'android.intent.extra.alarm.DAYS': <int>[
                weekday == 7 ? 1 : weekday + 1,
              ],
              'android.intent.extra.alarm.MESSAGE': alarm.label.isEmpty
                  ? 'Alarm'
                  : alarm.label,
              'android.intent.extra.alarm.SKIP_UI': true,
              'android.intent.extra.alarm.VIBRATE': true,
              'android.intent.extra.alarm.RINGTONE':
                  'android.resource://com.example.shifts_app/raw/${alarm.toneId}',
            },
          );
          await intent.launch();
          continue;
        }

        final scheduledDate = _nextWeekday(
          weekday,
          alarm.time.hour,
          alarm.time.minute,
        );
        final id = 80000 + (alarm.id.hashCode.abs() % 100) * 7 + weekday;

        await _plugin.zonedSchedule(
          id,
          alarm.label.isEmpty ? 'Alarm' : alarm.label,
          'Scheduled for ${_formatWeekday(weekday)}',
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'manual_alarm_${alarm.toneId}',
              'Manual Alarms',
              channelDescription: 'User-created Monday to Sunday alarms',
              importance: Importance.max,
              priority: Priority.max,
              sound: RawResourceAndroidNotificationSound(alarm.toneId),
              enableVibration: true,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (date.weekday != weekday || !date.isAfter(now)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  String _formatWeekday(int weekday) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday];
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
