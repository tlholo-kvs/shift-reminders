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
  final Map<String, dynamic>? importResult;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.alarmService,
    this.importResult,
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
    final colors = Theme.of(context).colorScheme;
    final days = alarm.weekdays.isEmpty
        ? alarm.scheduledDate == null
              ? 'Once'
              : 'Once · ${DateFormat('EEE d MMM').format(alarm.scheduledDate!)}'
        : alarm.weekdays
              .map(
                (day) =>
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
              )
              .join(', ');

    return Material(
      color: alarm.enabled ? colors.surface : colors.surfaceContainer,
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
                width: 82,
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
                          color: alarm.enabled
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
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
                      style: TextStyle(
                        color: colors.onSurface,
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
                        color: alarm.enabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.enabled,
                activeThumbColor: colors.onPrimary,
                activeTrackColor: colors.primary,
                inactiveThumbColor: colors.onSurfaceVariant,
                inactiveTrackColor: colors.surfaceContainerHighest,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final result = widget.importResult;
      if (result?['importSuccess'] != true) return;
      final count = result?['count'] ?? 0;
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: colors.surface,
          content: Text(
            'Updated successfully — $count shift(s) imported',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    });
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
    final result = await context.push<ManualAlarm>(
      '/alarm/editor',
      extra: alarm,
    );
    if (result == null) return;
    setState(() {
      final index = _manualAlarms.indexWhere((item) => item.id == result.id);
      if (index != -1) _manualAlarms[index] = result;
    });
    await _saveManualAlarms();
  }

  Future<void> _deleteManualAlarm(ManualAlarm alarm) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete alarm?'),
        content: Text('Remove "${alarm.label}" and its schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
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
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
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
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text(
                'Delete alarm',
                style: TextStyle(color: colors.error),
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
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete shift alarm?'),
        content: Text('Remove the alarm for ${shift.type.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _shifts.removeWhere(
        (item) => item.date == shift.date && item.type == shift.type,
      );
    });
    await widget.storageService.saveShifts(_shifts);
    final nightBefore = await widget.storageService.loadNightBefore();
    await widget.alarmService.scheduleAll(_shifts, _rules, nightBefore);
  }

  Future<void> _showShiftAlarmActions(Shift shift) async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
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
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text(
                'Delete alarm',
                style: TextStyle(color: colors.error),
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
      if (alarm.weekdays.isEmpty) {
        final date = alarm.scheduledDate;
        if (date == null) continue;
        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          alarm.time.hour,
          alarm.time.minute,
        );
        if (candidate.isAfter(now) &&
            (next == null || candidate.isBefore(next))) {
          next = candidate;
          label = alarm.label;
        }
        continue;
      }

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canvas = theme.scaffoldBackgroundColor;
    final surface = colors.surface;
    final accent = colors.primary;
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
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.alarm_rounded,
                        size: 34,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Remind',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Me',
                      style: TextStyle(
                        color: accent,
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
                      child: Icon(Icons.person_rounded, color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTime,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Good afternoon. Here's your schedule.",
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT ALARM',
                        style: TextStyle(
                          color: accent,
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
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 34,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(Icons.alarm_rounded, color: accent, size: 52),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextAlarm.time,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your alarms',
                        style: TextStyle(
                          color: colors.onSurface,
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
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text(
                        'No alarms yet',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else ...[
                  for (final category in const [
                    'early',
                    'middle',
                    'late',
                    'anytime',
                  ])
                    Builder(
                      builder: (context) {
                        final categoryManualAlarms = category == 'anytime'
                            ? _manualAlarms.where((alarm) {
                                final id = alarm.id.toLowerCase();
                                return !id.startsWith('shift_early') &&
                                    !id.startsWith('shift_middle') &&
                                    !id.startsWith('shift_late');
                              }).toList()
                            : <ManualAlarm>[];
                        final categoryShifts = category == 'anytime'
                            ? <Shift>[]
                            : _visibleShifts.where((shift) {
                                if (category == 'early') {
                                  return shift.type == ShiftType.earlyShift ||
                                      shift.type == ShiftType.earlyShiftWFH;
                                }
                                if (category == 'middle') {
                                  return shift.type == ShiftType.middleShift ||
                                      shift.type == ShiftType.middleShiftWFH;
                                }
                                return shift.type == ShiftType.lateShift ||
                                    shift.type == ShiftType.lateShiftWFH;
                              }).toList();
                        final count =
                            categoryManualAlarms.length + categoryShifts.length;
                        if (count == 0) return const SizedBox.shrink();
                        final title =
                            '${category[0].toUpperCase()}${category.substring(1)}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.outline),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: category == 'anytime',
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                8,
                                0,
                                8,
                                8,
                              ),
                              iconColor: colors.primary,
                              collapsedIconColor: colors.onSurfaceVariant,
                              title: Text(
                                '$title alarms',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: colors.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                              children: [
                                for (
                                  var i = 0;
                                  i < categoryManualAlarms.length;
                                  i++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: SizedBox(
                                      height: 84,
                                      child: _ManualAlarmCard(
                                        alarm: categoryManualAlarms[i],
                                        onTap: () =>
                                            context.push('/category/$category'),
                                        onLongPress: () =>
                                            _showManualAlarmActions(
                                              categoryManualAlarms[i],
                                            ),
                                        onChanged: (enabled) async {
                                          final index = _manualAlarms
                                              .indexWhere(
                                                (item) =>
                                                    item.id ==
                                                    categoryManualAlarms[i].id,
                                              );
                                          if (index == -1) return;
                                          setState(() {
                                            _manualAlarms[index] =
                                                _manualAlarms[index].copyWith(
                                                  enabled: enabled,
                                                );
                                          });
                                          await _saveManualAlarms();
                                        },
                                      ),
                                    ),
                                  ),
                                for (final shift in categoryShifts)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: SizedBox(
                                      height: 84,
                                      child: ShiftTile(
                                        shift: shift,
                                        rule: _ruleFor(shift),
                                        onTap: () =>
                                            context.push('/category/$category'),
                                        onLongPress: () =>
                                            _showShiftAlarmActions(shift),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => context.push('/categories'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm, color: accent, size: 22),
                      SizedBox(height: 4),
                      Text(
                        'Alarms',
                        style: TextStyle(
                          color: accent,
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
                    onPressed: () async {
                      final result = await context.push<ManualAlarm>(
                        '/alarm/editor',
                      );
                      if (result == null) return;
                      setState(() => _manualAlarms.add(result));
                      await _saveManualAlarms();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Add Alarm',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: colors.onPrimary,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        color: colors.onSurfaceVariant,
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Import',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: colors.onSurfaceVariant,
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
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
