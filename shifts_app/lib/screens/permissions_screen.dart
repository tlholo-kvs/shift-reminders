import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/storage_service.dart';

class PermissionsScreen extends StatefulWidget {
  final StorageService storageService;

  const PermissionsScreen({super.key, required this.storageService});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _grantPermissions() async {
    setState(() => _requesting = true);

    await Permission.notification.request();

    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    await widget.storageService.setOnboarded();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _skip() async {
    await widget.storageService.setOnboarded();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.alarm, size: 72),
              const SizedBox(height: 24),
              Text(
                'Shift Reminders',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Shift Reminders needs notification permission to alert you before shifts and the night before.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _requesting ? null : _grantPermissions,
                child: _requesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Grant Permissions'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _requesting ? null : _skip,
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
