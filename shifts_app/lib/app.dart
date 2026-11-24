import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/category_screen.dart';
import 'screens/alarm_editor_screen.dart';
import 'models/manual_alarm.dart';
import 'services/alarm_service.dart';
import 'services/storage_service.dart';

class ShiftRemindersApp extends StatefulWidget {
  final AlarmService alarmService;
  final StorageService storageService;

  const ShiftRemindersApp({
    super.key,
    required this.alarmService,
    required this.storageService,
  });

  @override
  State<ShiftRemindersApp> createState() => _ShiftRemindersAppState();
}

class _ShiftRemindersAppState extends State<ShiftRemindersApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildRoute(
          state,
          HomeScreen(
            storageService: widget.storageService,
            alarmService: widget.alarmService,
            importResult: state.extra is Map<String, dynamic>
                ? state.extra as Map<String, dynamic>
                : null,
          ),
        ),
        redirect: (context, state) async {
          final firstLaunch = await widget.storageService.isFirstLaunch();
          if (firstLaunch) return '/permissions';
          return null;
        },
      ),
      GoRoute(
        path: '/import',
        pageBuilder: (context, state) => _buildRoute(
          state,
          ImportScreen(
            storageService: widget.storageService,
            alarmService: widget.alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/rules',
        pageBuilder: (context, state) => _buildRoute(
          state,
          RulesScreen(
            storageService: widget.storageService,
            alarmService: widget.alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (context, state) => _buildRoute(
          state,
          CategoryScreen(
            storageService: widget.storageService,
            alarmService: widget.alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/category/:category',
        pageBuilder: (context, state) => _buildRoute(
          state,
          CategoryScreen(
            storageService: widget.storageService,
            alarmService: widget.alarmService,
            initialCategory: state.pathParameters['category'],
          ),
        ),
      ),
      GoRoute(
        path: '/alarm/editor',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final alarm = extra is ManualAlarm ? extra : null;
          return _buildRoute(
            state,
            AlarmEditorScreen(
              alarm: alarm,
              defaultToneId: 'mixkit_morning_clock_alarm_1003',
            ),
          );
        },
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) => _buildRoute(
          state,
          PermissionsScreen(storageService: widget.storageService),
        ),
      ),
    ],
  );

  CustomTransitionPage<void> _buildRoute(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Timer? _themeTimer;
  late bool _isDaytime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDaytime = AppTheme.isDaytime(DateTime.now());
    _scheduleThemeUpdate();
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleThemeUpdate();
  }

  void _scheduleThemeUpdate() {
    _themeTimer?.cancel();
    final now = DateTime.now();
    final isDaytime = AppTheme.isDaytime(now);
    if (isDaytime != _isDaytime) {
      _isDaytime = isDaytime;
      setState(() {});
    }

    final nextChange = now.hour < 6
        ? DateTime(now.year, now.month, now.day, 6)
        : now.hour < 18
        ? DateTime(now.year, now.month, now.day, 18)
        : DateTime(now.year, now.month, now.day + 1, 6);
    _themeTimer = Timer(nextChange.difference(now), _scheduleThemeUpdate);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Shift Reminders',
      routerConfig: _router,
      themeMode: _isDaytime ? ThemeMode.light : ThemeMode.dark,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
    );
  }
}
