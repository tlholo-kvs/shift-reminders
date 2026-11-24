import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/manual_alarm.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../services/alarm_service.dart';
import '../services/storage_service.dart';

class CategoryScreen extends StatefulWidget {
  final StorageService storageService;
  final AlarmService alarmService;
  final String? initialCategory;

  const CategoryScreen({
    super.key,
    required this.storageService,
    required this.alarmService,
    this.initialCategory,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Shift> _shifts = [];
  List<ShiftRule> _rules = [];
  List<ManualAlarm> _manualAlarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.storageService.loadShifts(),
      widget.storageService.loadRules(),
      widget.storageService.loadManualAlarms(),
    ]);
    if (!mounted) return;
    setState(() {
      _shifts = results[0] as List<Shift>;
      _rules = results[1] as List<ShiftRule>;
      _manualAlarms = results[2] as List<ManualAlarm>;
      _loading = false;
    });
  }

  String get _selected {
    final value = widget.initialCategory?.toLowerCase();
    if (value == 'early' || value == 'middle' || value == 'late') return value!;
    return 'anytime';
  }

  bool get _showOverview => widget.initialCategory == null;

  List<Shift> get _categoryShifts => _shifts.where((shift) {
    if (shift.isPast || shift.type == ShiftType.off) return false;
    if (_selected == 'early') {
      return shift.type == ShiftType.earlyShift ||
          shift.type == ShiftType.earlyShiftWFH;
    }
    if (_selected == 'middle') {
      return shift.type == ShiftType.middleShift ||
          shift.type == ShiftType.middleShiftWFH;
    }
    return shift.type == ShiftType.lateShift ||
        shift.type == ShiftType.lateShiftWFH;
  }).toList();

  String _time(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')}';
  }

  ShiftRule? _ruleFor(Shift shift) {
    for (final rule in _rules) {
      if (rule.type == shift.type) return rule;
    }
    return null;
  }

  Future<void> _toggleManualAlarm(ManualAlarm alarm, bool enabled) async {
    final index = _manualAlarms.indexWhere((item) => item.id == alarm.id);
    if (index == -1) return;
    setState(() {
      _manualAlarms[index] = alarm.copyWith(enabled: enabled);
    });
    await widget.storageService.saveManualAlarms(_manualAlarms);
    await widget.alarmService.scheduleManualAlarms(_manualAlarms);
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFF0B1020);
    const surface = Color(0xFF1B2749);
    const purple = Color(0xFF7867F6);

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          _showOverview
              ? 'Alarm Categories'
              : '${_selected[0].toUpperCase()}${_selected.substring(1)} Alarms',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showOverview
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final category in const [
                  'early',
                  'middle',
                  'late',
                  'anytime',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.push('/category/$category'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: purple.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  category == 'anytime'
                                      ? Icons.alarm
                                      : category == 'early'
                                      ? Icons.wb_sunny_outlined
                                      : category == 'middle'
                                      ? Icons.light_mode_outlined
                                      : Icons.nights_stay_outlined,
                                  color: purple,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  '${category[0].toUpperCase()}${category.substring(1)} alarms',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: _selected == 'anytime'
                  ? [
                      if (_manualAlarms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: Text('No anytime alarms')),
                        )
                      else
                        for (final alarm in _manualAlarms)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              height: 84,
                              decoration: BoxDecoration(
                                color: alarm.enabled
                                    ? surface
                                    : const Color(0xFF12192B),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _time(alarm.time),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 25,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          alarm.time.hour >= 12 ? 'PM' : 'AM',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      alarm.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: alarm.enabled,
                                    onChanged: (value) =>
                                        _toggleManualAlarm(alarm, value),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ]
                  : [
                      if (_categoryShifts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: Text('No shifts in this category'),
                          ),
                        )
                      else
                        for (final shift in _categoryShifts)
                          Builder(
                            builder: (context) {
                              final rule = _ruleFor(shift);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                rule == null
                                                    ? '--:--'
                                                    : _time(rule.alarmTime),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 25,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              rule == null
                                                  ? ''
                                                  : rule.alarmTime.hour >= 12
                                                  ? 'PM'
                                                  : 'AM',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shift.type.displayName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              DateFormat(
                                                'EEE d MMM',
                                              ).format(shift.date),
                                              style: const TextStyle(
                                                color: purple,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
            ),
    );
  }
}
