import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/shift.dart';
import '../models/shift_rule.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
        final nightBeforeId =
            (shift.date.millisecondsSinceEpoch ~/ 60000) * 2;
        await _plugin.zonedSchedule(
          nightBeforeId,
          'Shift Tomorrow',
          '${rule.displayName} tomorrow — alarm set for ${_formatTime(rule.alarmTime)}',
          nightBeforeDateTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'shift_reminders_night',
              'Night Before Reminders',
              channelDescription:
                  'Notifications the night before a shift',
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
          final wakeId =
              (shift.date.millisecondsSinceEpoch ~/ 60000) * 2 + 1;
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
    return shifts
        .where((s) => !s.isPast && s.type != ShiftType.off)
        .length;
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
