import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'services/alarm_service.dart';
import 'services/storage_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  String? timezoneName;
  if (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows) {
    try {
      timezoneName = await const MethodChannel(
        'com.example.shifts_app/timezone',
      ).invokeMethod<String>('getTimezone');
    } catch (_) {}
  }
  timezoneName ??= DateTime.now().timeZoneName;
  try {
    tz.setLocalLocation(tz.getLocation(timezoneName));
  } catch (_) {
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == offset.inMilliseconds) {
        tz.setLocalLocation(location);
        break;
      }
    }
  }
  final alarmService = AlarmService();
  final storageService = StorageService();
  await alarmService.init();
  runApp(ShiftRemindersApp(
    alarmService: alarmService,
    storageService: storageService,
  ));
}
