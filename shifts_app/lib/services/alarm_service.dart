import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../models/manual_alarm.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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
  }

  Future<void> scheduleAll(
    List<Shift> shifts,
    List<ShiftRule> rules,
    TimeOfDay nightBefore,
  ) async {
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
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'android.intent.action.SET_ALARM',
            arguments: <String, dynamic>{
              'android.intent.extra.alarm.HOUR': rule.alarmTime.hour,
              'android.intent.extra.alarm.MINUTES': rule.alarmTime.minute,
              'android.intent.extra.alarm.MESSAGE':
                  '${rule.displayName} starts at ${_formatTime(rule.shiftStart)}',
              'android.intent.extra.alarm.SKIP_UI': true,
              'android.intent.extra.alarm.VIBRATE': true,
            },
          );
          await intent.launch();
        } else {
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
    for (var id = 80000; id < 90000; id++) {
      await _plugin.cancel(id);
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
              'android.intent.extra.alarm.MESSAGE':
                  alarm.label.isEmpty ? 'Alarm' : alarm.label,
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
