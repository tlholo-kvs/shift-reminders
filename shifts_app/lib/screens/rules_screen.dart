import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/manual_alarm.dart';
import '../services/alarm_service.dart';
import '../services/storage_service.dart';

class RulesScreen extends StatefulWidget {
  final StorageService storageService;
  final AlarmService alarmService;

  const RulesScreen({
    super.key,
    required this.storageService,
    required this.alarmService,
  });

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  List<ManualAlarm> _manualAlarms = [];
  String _alarmToneId = 'mixkit_morning_clock_alarm_1003';
  bool _loading = true;
  Map<String, dynamic> _alarmDebugInfo = const {};
  bool _normalWorkWeek = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final manualAlarms = await widget.storageService.loadManualAlarms();
    final alarmToneId = await widget.storageService.loadAlarmTone();
    final normalWorkWeek = await widget.storageService.loadNormalWorkWeek();
    final alarmDebugInfo = await widget.alarmService.getAlarmDebugInfo();
    if (mounted) {
      setState(() {
        _manualAlarms = manualAlarms;
        _alarmToneId = alarmToneId;
        _normalWorkWeek = normalWorkWeek;
        _alarmDebugInfo = alarmDebugInfo;
        _loading = false;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveManualAlarms() async {
    await widget.storageService.saveManualAlarms(_manualAlarms);
    await widget.alarmService.scheduleManualAlarms(_manualAlarms);
  }

  Future<void> _chooseAlarmTone(String toneId) async {
    setState(() => _alarmToneId = toneId);
    await widget.storageService.saveAlarmTone(toneId);
    await widget.alarmService.scheduleManualAlarms(_manualAlarms);
  }

  Future<void> _toggleNormalWorkWeek(bool enabled) async {
    setState(() => _normalWorkWeek = enabled);
    await widget.storageService.saveNormalWorkWeek(enabled);

    if (enabled) {
      final existingIndex = _manualAlarms.indexWhere(
        (alarm) => alarm.id == 'normal_8_5',
      );
      const preset = ManualAlarm(
        id: 'normal_8_5',
        label: 'Normal 8–5',
        time: TimeOfDay(hour: 6, minute: 0),
        weekdays: {1, 2, 3, 4, 5},
        enabled: true,
      );
      setState(() {
        if (existingIndex == -1) {
          _manualAlarms.add(preset);
        } else {
          _manualAlarms[existingIndex] = preset;
        }
      });
    } else {
      setState(() {
        _manualAlarms.removeWhere((alarm) => alarm.id == 'normal_8_5');
      });
    }
    await _saveManualAlarms();
  }

  Future<void> _editManualAlarm([
    ManualAlarm? alarm,
    bool returnToAlarms = false,
  ]) async {
    final result = await context.push<ManualAlarm>(
      '/alarm/editor',
      extra: alarm,
    );
    if (result == null) return;
    setState(() {
      final index = _manualAlarms.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _manualAlarms.add(result);
      } else {
        _manualAlarms[index] = result;
      }
    });
    await _saveManualAlarms();
    if (returnToAlarms && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        leadingWidth: 56,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                CheckboxListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  value: _normalWorkWeek,
                  activeColor: colors.primary,
                  title: const Text(
                    'Normal 8–5 job',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Create Monday–Friday alarms at 06:00'),
                  onChanged: (value) => _toggleNormalWorkWeek(value ?? false),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Manual alarms',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ..._manualAlarms.map((alarm) {
                  final days = alarm.weekdays.isEmpty
                      ? alarm.scheduledDate == null
                            ? 'Once'
                            : 'Once · ${DateFormat('EEE d MMM').format(alarm.scheduledDate!)}'
                      : alarm.weekdays
                            .map(
                              (day) => [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ][day - 1],
                            )
                            .join(', ');
                  return SwitchListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(alarm.label)),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit weekday alarm',
                          onPressed: () => _editManualAlarm(alarm),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${_formatTime(alarm.time)} — $days',
                      style: TextStyle(color: colors.onSurface),
                    ),
                    value: alarm.enabled,
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete alarm',
                      onPressed: () async {
                        setState(() {
                          _manualAlarms.removeWhere(
                            (item) => item.id == alarm.id,
                          );
                        });
                        await _saveManualAlarms();
                      },
                    ),
                    onChanged: (enabled) async {
                      setState(() {
                        final index = _manualAlarms.indexWhere(
                          (item) => item.id == alarm.id,
                        );
                        if (index != -1) {
                          _manualAlarms[index] = alarm.copyWith(
                            enabled: enabled,
                          );
                        }
                      });
                      await _saveManualAlarms();
                    },
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add weekday alarm'),
                  onTap: () => _editManualAlarm(),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _alarmToneId,
                    decoration: const InputDecoration(
                      labelText: 'Default alarm tone',
                    ),
                    items: [
                      for (final tone in AlarmTone.tones)
                        DropdownMenuItem(
                          value: tone.id,
                          child: Text(tone.name),
                        ),
                    ],
                    onChanged: (toneId) {
                      if (toneId != null) _chooseAlarmTone(toneId);
                    },
                  ),
                ),
                const Divider(),
                const Divider(),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Alarm debugging',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Create mock alarm'),
                  subtitle: const Text(
                    'Starts the full-screen alarm in 10 seconds',
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.alarmService.scheduleMockAlarm();
                    final info = await widget.alarmService.getAlarmDebugInfo();
                    if (!mounted) return;
                    setState(() => _alarmDebugInfo = info);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Mock alarm scheduled for 10 seconds'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Alarm debug status'),
                  subtitle: Text(
                    'Last alarm: ${_alarmDebugInfo['lastAlarm'] ?? 'None'} '
                    '• Scheduled sets: ${_alarmDebugInfo['requestCodes'] ?? 0} '
                    '• Exact permission: ${_alarmDebugInfo['exactAlarmPermission'] ?? 'unknown'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Refresh debug status',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final info = await widget.alarmService
                          .getAlarmDebugInfo();
                      if (!mounted) return;
                      setState(() => _alarmDebugInfo = info);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Allow display over other apps'),
                  subtitle: const Text(
                    'Required so the alarm opens over the lock screen',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: widget.alarmService.openOverlayPermissionSettings,
                ),
              ],
            ),
    );
  }
}
