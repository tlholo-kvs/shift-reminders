import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/category_screen.dart';
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
        pageBuilder: (context, state) => _buildRoute(
          state,
          HomeScreen(
            storageService: storageService,
            alarmService: alarmService,
          ),
        ),
        redirect: (context, state) async {
          final firstLaunch = await storageService.isFirstLaunch();
          if (firstLaunch) return '/permissions';
          return null;
        },
      ),
      GoRoute(
        path: '/import',
        pageBuilder: (context, state) => _buildRoute(
          state,
          ImportScreen(
            storageService: storageService,
            alarmService: alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/rules',
        pageBuilder: (context, state) => _buildRoute(
          state,
          RulesScreen(
            storageService: storageService,
            alarmService: alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (context, state) => _buildRoute(
          state,
          CategoryScreen(
            storageService: storageService,
            alarmService: alarmService,
          ),
        ),
      ),
      GoRoute(
        path: '/category/:category',
        pageBuilder: (context, state) => _buildRoute(
          state,
          CategoryScreen(
            storageService: storageService,
            alarmService: alarmService,
            initialCategory: state.pathParameters['category'],
          ),
        ),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) => _buildRoute(
          state,
          PermissionsScreen(storageService: storageService),
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

  @override
  Widget build(BuildContext context) {
    const brandPurple = Color(0xFF8B5CF6);
    const alarmNavy = Color(0xFF171A45);
    const alarmCanvas = Color(0xFF11192E);
    const cardSurface = Color(0xFF1A2146);

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
          secondary: brandPurple,
          onSecondary: alarmNavy,
          tertiary: cardSurface,
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
            backgroundColor: brandPurple,
            foregroundColor: Colors.white,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandPurple,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: brandPurple,
          foregroundColor: Colors.white,
        ),
        dividerColor: cardSurface,
        iconTheme: const IconThemeData(color: Colors.white),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: cardSurface),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: cardSurface),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: brandPurple, width: 2),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: brandPurple,
        ),
      ),
    );
  }
}
