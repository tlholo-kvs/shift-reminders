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
        builder: (context, state) =>
            RulesScreen(
              storageService: storageService,
              alarmService: alarmService,
            ),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) =>
            PermissionsScreen(storageService: storageService),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF56856E);
    const darkGreen = Color(0xFF285640);
    const paleGreen = Color(0xFFB6CCC1);
    const alarmNavy = Color(0xFF171F36);
    const alarmAccent = Color(0xFFEAFB67);
    const alarmCanvas = Color(0xFF121A2C);

    return MaterialApp.router(
      title: 'Shift Reminders',
      routerConfig: _router,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: alarmNavy,
          onPrimary: Colors.white,
          secondary: alarmAccent,
          onSecondary: alarmNavy,
          tertiary: paleGreen,
          onTertiary: Colors.white,
          error: Color(0xFFBA1A1A),
          onError: Colors.white,
          surface: alarmCanvas,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: alarmCanvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: alarmNavy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandGreen,
            foregroundColor: Colors.white,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandGreen,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
        ),
        dividerColor: darkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(borderSide: BorderSide(color: paleGreen)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: paleGreen),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: alarmAccent, width: 2),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: brandGreen,
        ),
      ),
    );
  }
}
