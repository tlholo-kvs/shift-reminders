import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
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
  List<ShiftRule> _rules = [];
  List<ManualAlarm> _manualAlarms = [];
  TimeOfDay _nightBefore = nightBeforeDefault;
  String _alarmToneId = 'mixkit_morning_clock_alarm_1003';
  bool _loading = true;
  Map<String, dynamic> _alarmDebugInfo = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rules = await widget.storageService.loadRules();
    final nightBefore = await widget.storageService.loadNightBefore();
    final manualAlarms = await widget.storageService.loadManualAlarms();
    final alarmToneId = await widget.storageService.loadAlarmTone();
    final alarmDebugInfo = await widget.alarmService.getAlarmDebugInfo();
    if (mounted) {
      setState(() {
        _rules = rules;
        _nightBefore = nightBefore;
        _manualAlarms = manualAlarms;
        _alarmToneId = alarmToneId;
        _alarmDebugInfo = alarmDebugInfo;
        _loading = false;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editNightBefore() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _nightBefore,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _nightBefore = picked;
    });
    await widget.storageService.saveRules(_rules, _nightBefore);
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

  Future<void> _openShiftAlarm(ShiftRule rule) async {
    final existing = _manualAlarms.where(
      (alarm) => alarm.id == 'shift_${rule.type.name}',
    );
    final alarm = existing.isEmpty
        ? ManualAlarm(
            id: 'shift_${rule.type.name}',
            label: rule.displayName,
            time: rule.alarmTime,
            weekdays: const {1, 2, 3, 4, 5, 6, 7},
            toneId: _alarmToneId,
          )
        : existing.first;

    await _editManualAlarm(alarm, true);
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Office shifts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ..._rules
                    .asMap()
                    .entries
                    .where(
                      (e) =>
                          e.value.type != ShiftType.off &&
                          !e.value.type.name.toLowerCase().contains('wfh'),
                    )
                    .map((e) {
                      final rule = e.value;
                      return ListTile(
                        onTap: () => _openShiftAlarm(rule),
                        title: Text(rule.displayName),
                        subtitle: Text(
                          'Alarm at ${_formatTime(rule.alarmTime)} — shift starts ${_formatTime(rule.shiftStart)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit alarm time',
                          onPressed: () => _openShiftAlarm(rule),
                        ),
                      );
                    }),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'WFH shifts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ..._rules
                    .asMap()
                    .entries
                    .where(
                      (e) => e.value.type.name.toLowerCase().contains('wfh'),
                    )
                    .map((e) {
                      final rule = e.value;
                      return ListTile(
                        onTap: () => _openShiftAlarm(rule),
                        title: Text(rule.displayName),
                        subtitle: Text(
                          'Alarm at ${_formatTime(rule.alarmTime)} — shift starts ${_formatTime(rule.shiftStart)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit WFH alarm time',
                          onPressed: () => _openShiftAlarm(rule),
                        ),
                      );
                    }),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Monday to Sunday alarms',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ..._manualAlarms.map((alarm) {
                  final days = alarm.weekdays
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
                      style: const TextStyle(color: Colors.white),
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
                ListTile(
                  title: const Text('Night-before notification'),
                  subtitle: Text(_formatTime(_nightBefore)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit notification time',
                    onPressed: _editNightBefore,
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Alarm debugging',
                    style: TextStyle(
                      color: Colors.white,
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
