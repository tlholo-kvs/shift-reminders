import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../models/manual_alarm.dart';
import '../services/alarm_service.dart';
import '../services/storage_service.dart';
import '../widgets/shift_tile.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final AlarmService alarmService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.alarmService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ManualAlarmCard extends StatelessWidget {
  final ManualAlarm alarm;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onChanged;

  const _ManualAlarmCard({
    required this.alarm,
    required this.onTap,
    required this.onLongPress,
    required this.onChanged,
  });

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF1A2146);
    const accent = Color(0xFF8B5CF6);
    final days = alarm.weekdays
        .map(
          (day) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
        )
        .join(', ');

    return Material(
      color: alarm.enabled ? surface : const Color(0xFF12192B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTime(alarm.time),
                        style: TextStyle(
                          color: alarm.enabled ? Colors.white : Colors.white54,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      alarm.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      days,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: alarm.enabled ? accent : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: accent,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFB90F2D),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  List<Shift> _shifts = [];
  List<ShiftRule> _rules = [];
  List<ManualAlarm> _manualAlarms = [];
  bool _loading = true;

  List<Shift> get _visibleShifts => _shifts
      .where((shift) => !shift.isPast && shift.type != ShiftType.off)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shifts = await widget.storageService.loadShifts();
    final rules = await widget.storageService.loadRules();
    final manualAlarms = await widget.storageService.loadManualAlarms();
    if (mounted) {
      setState(() {
        _shifts = shifts;
        _rules = rules;
        _manualAlarms = manualAlarms;
        _loading = false;
      });
    }
  }

  ShiftRule? _ruleFor(Shift shift) {
    try {
      return _rules.firstWhere((r) => r.type == shift.type);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveManualAlarms() async {
    await widget.storageService.saveManualAlarms(_manualAlarms);
    await widget.alarmService.scheduleManualAlarms(_manualAlarms);
  }

  Future<void> _editManualAlarm(ManualAlarm alarm) async {
    var label = alarm.label;
    var time = alarm.time;
    var weekdays = Set<int>.from(alarm.weekdays);
    var enabled = alarm.enabled;
    var toneId = alarm.toneId;

    final result = await showDialog<ManualAlarm>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171A45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Edit Alarm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: label),
                      decoration: const InputDecoration(labelText: 'Alarm name'),
                      onChanged: (value) => label = value,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: time,
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              alwaysUse24HourFormat: true,
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => time = picked);
                        }
                      },
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(
                              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                            ),
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
                    DropdownButtonFormField<String>(
                      initialValue: toneId,
                      decoration: const InputDecoration(labelText: 'Alarm tone'),
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
                          alarm.copyWith(
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

    if (result == null) return;
    setState(() {
      final index = _manualAlarms.indexWhere((item) => item.id == result.id);
      if (index != -1) _manualAlarms[index] = result;
    });
    await _saveManualAlarms();
  }

  Future<void> _deleteManualAlarm(ManualAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171A45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Delete alarm?'),
        content: Text('Remove "${alarm.label}" and its schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB90F2D),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _manualAlarms.removeWhere((item) => item.id == alarm.id);
    });
    await _saveManualAlarms();
  }

  Future<void> _showManualAlarmActions(ManualAlarm alarm) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit alarm'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editManualAlarm(alarm);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B7A)),
              title: const Text(
                'Delete alarm',
                style: TextStyle(color: Color(0xFFFF6B7A)),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteManualAlarm(alarm);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteShift(Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171A45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Delete shift alarm?'),
        content: Text('Remove the alarm for ${shift.type.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB90F2D),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _shifts.removeWhere(
        (item) =>
            item.date == shift.date && item.type == shift.type,
      );
    });
    await widget.storageService.saveShifts(_shifts);
    final nightBefore = await widget.storageService.loadNightBefore();
    await widget.alarmService.scheduleAll(_shifts, _rules, nightBefore);
  }

  Future<void> _showShiftAlarmActions(Shift shift) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit alarm'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/rules');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFFF6B7A),
              ),
              title: const Text(
                'Delete alarm',
                style: TextStyle(color: Color(0xFFFF6B7A)),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteShift(shift);
              },
            ),
          ],
        ),
      ),
    );
  }

  ({String title, String time}) _nextAlarm() {
    final now = DateTime.now();
    DateTime? next;
    String label = 'No upcoming alarm';

    for (final alarm in _manualAlarms.where((alarm) => alarm.enabled)) {
      for (final weekday in alarm.weekdays) {
        var candidate = DateTime(
          now.year,
          now.month,
          now.day,
          alarm.time.hour,
          alarm.time.minute,
        );
        while (candidate.weekday != weekday || !candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        if (next == null || candidate.isBefore(next)) {
          next = candidate;
          label = alarm.label;
        }
      }
    }

    for (final shift in _visibleShifts) {
      final rule = _ruleFor(shift);
      if (rule == null) continue;
      final candidate = DateTime(
        shift.date.year,
        shift.date.month,
        shift.date.day,
        rule.alarmTime.hour,
        rule.alarmTime.minute,
      );
      if (candidate.isAfter(now) &&
          (next == null || candidate.isBefore(next))) {
        next = candidate;
        label = rule.displayName;
      }
    }

    if (next == null) return (title: label, time: '--:--');
    final time =
        '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    final today = DateTime(now.year, now.month, now.day);
    final candidateDay = DateTime(next.year, next.month, next.day);
    final dayLabel = candidateDay == today
        ? 'Today'
        : candidateDay.difference(today).inDays == 1
        ? 'Tomorrow'
        : '${next.day}/${next.month}';
    return (title: '$dayLabel • $time', time: label);
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFF11192E);
    const surface = Color(0xFF1A2146);
    const purple = Color(0xFF8B5CF6);
    final nextAlarm = _nextAlarm();
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final dateLabel = DateFormat('EEEE, d MMMM').format(now).toUpperCase();

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(backgroundColor: canvas, toolbarHeight: 0, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB55CF6), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Wake',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Up',
                      style: TextStyle(
                        color: purple,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person_rounded, color: purple),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Color(0xFF8A90B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Good afternoon. Here's your schedule.",
                  style: TextStyle(color: Color(0xFF8A90B8), fontSize: 16),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25235E), Color(0xFF35205F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: purple.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT ALARM',
                        style: TextStyle(
                          color: purple,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nextAlarm.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.alarm_rounded,
                            color: purple,
                            size: 52,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextAlarm.time,
                        style: const TextStyle(
                          color: Color(0xFFAAAED0),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your alarms',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_manualAlarms.isEmpty && _visibleShifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text(
                        'No alarms yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else ...[
                  for (var i = 0; i < _manualAlarms.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 84,
                        child: _ManualAlarmCard(
                          alarm: _manualAlarms[i],
                          onTap: () {
                            final alarm = _manualAlarms[i];
                            final id = alarm.id.toLowerCase();
                            final category = id.startsWith('shift_early')
                                ? 'early'
                                : id.startsWith('shift_middle')
                                ? 'middle'
                                : id.startsWith('shift_late')
                                ? 'late'
                                : 'anytime';
                            context.push('/category/$category');
                          },
                          onLongPress: () =>
                              _showManualAlarmActions(_manualAlarms[i]),
                          onChanged: (enabled) async {
                            setState(() {
                              _manualAlarms[i] = _manualAlarms[i].copyWith(
                                enabled: enabled,
                              );
                            });
                            await _saveManualAlarms();
                          },
                        ),
                      ),
                    ),
                  for (final shift in _visibleShifts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 84,
                        child: ShiftTile(
                          shift: shift,
                          rule: _ruleFor(shift),
                          onTap: () {
                            final category =
                                shift.type == ShiftType.earlyShift ||
                                    shift.type == ShiftType.earlyShiftWFH
                                ? 'early'
                                : shift.type == ShiftType.middleShift ||
                                      shift.type == ShiftType.middleShiftWFH
                                ? 'middle'
                                : 'late';
                            context.push('/category/$category');
                          },
                          onLongPress: () => _showShiftAlarmActions(shift),
                        ),
                      ),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFF171A45),
            border: Border(top: BorderSide(color: Color(0xFF26365E))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => context.push('/categories'),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm, color: purple, size: 22),
                      SizedBox(height: 4),
                      Text(
                        'Alarms',
                        style: TextStyle(
                          color: purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: FilledButton.icon(
                    onPressed: () => context.go('/rules'),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Add Alarm',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      context.push('/import').then((_) => _loadData()),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        color: Colors.white60,
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Import',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => context.go('/rules'),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: Colors.white60,
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
