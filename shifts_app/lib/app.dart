import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/rules_screen.dart';
import 'services/alarm_service.dart';
import 'services/storage_service.dart';

class ShiftRemindersApp extends StatelessWidget {
  final AlarmService alarmService;
  final StorageService storageService;

  ShiftRemindersApp({
    super.key,
    required this.alarmService,
    required this.storageService,
  });

  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          storageService: storageService,
          alarmService: alarmService,
        ),
        redirect: (context, state) async {
          final firstLaunch = await storageService.isFirstLaunch();
          if (firstLaunch) return '/permissions';
          return null;
        },
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => ImportScreen(
          storageService: storageService,
          alarmService: alarmService,
        ),
      ),
      GoRoute(
        path: '/rules',
        builder: (context, state) => RulesScreen(
          storageService: storageService,
        ),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => PermissionsScreen(
          storageService: storageService,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Shift Reminders',
      routerConfig: _router,
    );
  }
}
