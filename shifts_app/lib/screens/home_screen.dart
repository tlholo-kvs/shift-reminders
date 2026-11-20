import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  const _ManualAlarmCard({required this.alarm});

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF26365E);
    const accent = Color(0xFFEAFB67);
    final period = alarm.time.hour >= 12 ? 'PM' : 'AM';
    final days = alarm.weekdays
        .map(
          (day) =>
              ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
        )
        .join(', ');

    return Container(
      decoration: BoxDecoration(
        color: alarm.enabled ? surface : const Color(0xFF34405A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: alarm.enabled
            ? const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alarm.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: alarm.enabled,
                activeThumbColor: accent,
                activeTrackColor: accent.withValues(alpha: 0.35),
                onChanged: null,
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(alarm.time),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  period,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            days,
            style: const TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF171F36);
    const accent = Color(0xFFEAFB67);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alarms',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Alarm Rules',
            onPressed: () => context.go('/rules'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visibleShifts.isEmpty && _manualAlarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.alarm, size: 52, color: navy),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No alarms yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No shifts imported yet.\nTap + to import a CSV.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: _manualAlarms.length + _visibleShifts.length,
              itemBuilder: (context, index) {
                if (index < _manualAlarms.length) {
                  return _ManualAlarmCard(alarm: _manualAlarms[index]);
                }
                final shiftIndex = index - _manualAlarms.length;
                final shift = _visibleShifts[shiftIndex];
                return ShiftTile(shift: shift, rule: _ruleFor(shift));
              },
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 76,
          decoration: const BoxDecoration(
            color: navy,
            border: Border(top: BorderSide(color: Color(0xFF26365E))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Alarms',
                onPressed: () {},
                icon: const Icon(Icons.alarm, color: accent),
              ),
              Material(
                color: accent,
                shape: const CircleBorder(),
                elevation: 4,
                child: Tooltip(
                  message: 'Import shifts',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        context.push('/import').then((_) => _loadData()),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.add, size: 30, color: navy),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Alarm rules',
                onPressed: () => context.go('/rules'),
                icon: const Icon(Icons.tune, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
