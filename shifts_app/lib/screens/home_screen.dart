import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  List<Shift> _shifts = [];
  List<ShiftRule> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shifts = await widget.storageService.loadShifts();
    final rules = await widget.storageService.loadRules();
    if (mounted) {
      setState(() {
        _shifts = shifts;
        _rules = rules;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Alarm Rules',
            onPressed: () => context.go('/rules'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import CSV',
            onPressed: () => context.push('/import').then((_) => _loadData()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No shifts imported yet.\nTap + to import a CSV.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    return ShiftTile(
                      shift: shift,
                      rule: _ruleFor(shift),
                    );
                  },
                ),
    );
  }
}
