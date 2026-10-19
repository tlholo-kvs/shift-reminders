import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../services/storage_service.dart';

class RulesScreen extends StatefulWidget {
  final StorageService storageService;

  const RulesScreen({super.key, required this.storageService});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  List<ShiftRule> _rules = [];
  TimeOfDay _nightBefore = nightBeforeDefault;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rules = await widget.storageService.loadRules();
    final nightBefore = await widget.storageService.loadNightBefore();
    if (mounted) {
      setState(() {
        _rules = rules;
        _nightBefore = nightBefore;
        _loading = false;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editAlarmTime(int ruleIndex) async {
    final current = _rules[ruleIndex].alarmTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Rules')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ..._rules
                    .asMap()
                    .entries
                    .where((e) => e.value.type != ShiftType.off)
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
