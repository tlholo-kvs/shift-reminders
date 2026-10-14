import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'services/alarm_service.dart';
import 'services/storage_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final alarmService = AlarmService();
  final storageService = StorageService();
  await alarmService.init();
  runApp(ShiftRemindersApp(
    alarmService: alarmService,
    storageService: storageService,
  ));
}
