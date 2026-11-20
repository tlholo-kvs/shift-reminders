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
    if (mounted) {
      setState(() {
        _rules = rules;
        _nightBefore = nightBefore;
        _manualAlarms = manualAlarms;
        _alarmToneId = alarmToneId;
        _loading = false;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editAlarmTime(int ruleIndex) async {
    final current = _rules[ruleIndex].alarmTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;

    final updated = ShiftRule(
      type: _rules[ruleIndex].type,
      alarmTime: picked,
      shiftStart: _rules[ruleIndex].shiftStart,
    );
    setState(() {
      _rules[ruleIndex] = updated;
    });
    await widget.storageService.saveRules(_rules, _nightBefore);
  }

  Future<void> _editNightBefore() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _nightBefore,
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

  Future<void> _editManualAlarm([ManualAlarm? alarm]) async {
    var label = alarm?.label ?? 'Weekday alarm';
    var time = alarm?.time ?? const TimeOfDay(hour: 7, minute: 0);
    var weekdays = Set<int>.from(
      alarm?.weekdays ?? {1, 2, 3, 4, 5, 6, 7},
    );
    var enabled = alarm?.enabled ?? true;
    var toneId = alarm?.toneId ?? _alarmToneId;

    final result = await showDialog<ManualAlarm>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(alarm == null ? 'Add alarm' : 'Edit alarm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: TextEditingController(text: label),
                      decoration: const InputDecoration(
                        labelText: 'Alarm name',
                      ),
                      onChanged: (value) => label = value,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null) {
                          setDialogState(() => time = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(_formatTime(time)),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1]),
                            selected: weekdays.contains(day),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  weekdays.add(day);
                                } else {
                                  weekdays.remove(day);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: toneId,
                      decoration: const InputDecoration(
                        labelText: 'Alarm tone',
                      ),
                      items: [
                        for (final tone in AlarmTone.tones)
                          DropdownMenuItem(
                            value: tone.id,
                            child: Text(tone.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => toneId = value);
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
                      value: enabled,
                      onChanged: (value) {
                        setDialogState(() => enabled = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: weekdays.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(
                          ManualAlarm(
                            id:
                                alarm?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            label: label.trim().isEmpty
                                ? 'Weekday alarm'
                                : label.trim(),
                            time: time,
                            weekdays: weekdays,
                            enabled: enabled,
                            toneId: toneId,
                          ),
                        ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _manualAlarms.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _manualAlarms.add(result);
      } else {
        _manualAlarms[index] = result;
      }
    });
    await _saveManualAlarms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to alarms'),
        ),
        leadingWidth: 150,
        title: const Text('Alarm Rules'),
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
                        title: Text(rule.displayName),
                        subtitle: Text(
                          'Alarm at ${_formatTime(rule.alarmTime)} — shift starts ${_formatTime(rule.shiftStart)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit alarm time',
                          onPressed: () => _editAlarmTime(e.key),
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
                        title: Text(rule.displayName),
                        subtitle: Text(
                          'Alarm at ${_formatTime(rule.alarmTime)} — shift starts ${_formatTime(rule.shiftStart)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit WFH alarm time',
                          onPressed: () => _editAlarmTime(e.key),
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
                        (day) =>
                            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                [day - 1],
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
              ],
            ),
    );
  }
}
