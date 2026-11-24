import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/manual_alarm.dart';

class AlarmEditorScreen extends StatefulWidget {
  final ManualAlarm? alarm;
  final String defaultToneId;

  const AlarmEditorScreen({
    super.key,
    this.alarm,
    this.defaultToneId = 'mixkit_morning_clock_alarm_1003',
  });

  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  late TextEditingController _labelController;
  late int _hour;
  late int _minute;
  late Set<int> _weekdays;
  late bool _enabled;
  late String _toneId;
  bool _snoozeEnabled = true;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _labelController = TextEditingController(
      text: alarm?.label ?? 'Morning routine',
    );
    _hour = alarm?.time.hour ?? 6;
    _minute = alarm?.time.minute ?? 0;
    _weekdays = Set<int>.from(alarm?.weekdays ?? {1, 2, 3, 4, 5});
    _enabled = alarm?.enabled ?? true;
    _toneId = alarm?.toneId ?? widget.defaultToneId;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String get _repeatLabel {
    if (_weekdays.length == 7) return 'Every day';
    if (_weekdays.length == 5 && _weekdays.containsAll({1, 2, 3, 4, 5})) {
      return 'Monday - Friday';
    }
    if (_weekdays.isEmpty) return 'Never';
    return _weekdays
        .map(
          (day) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
        )
        .join(', ');
  }

  void _save() {
    if (_weekdays.isEmpty) return;
    final alarm = ManualAlarm(
      id: widget.alarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelController.text.trim().isEmpty
          ? 'Alarm'
          : _labelController.text.trim(),
      time: TimeOfDay(hour: _hour, minute: _minute),
      weekdays: _weekdays,
      enabled: _enabled,
      toneId: _toneId,
    );
    context.pop(alarm);
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFF11192E);
    const surface = Color(0xFF1A2146);
    const purple = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        foregroundColor: Colors.white,
        toolbarHeight: 72,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        leadingWidth: 88,
        title: Text(
          widget.alarm == null ? 'New alarm' : 'Edit alarm',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _weekdays.isEmpty ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: purple,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          children: [
            const Text(
              'SET TIME',
              style: TextStyle(
                color: purple,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF3C3F82), width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: purple,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimeWheel(
                        value: _hour,
                        count: 24,
                        labelBuilder: (value) =>
                            value.toString().padLeft(2, '0'),
                        onChanged: (value) => setState(() => _hour = value),
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _TimeWheel(
                        value: _minute,
                        count: 60,
                        labelBuilder: (value) =>
                            value.toString().padLeft(2, '0'),
                        onChanged: (value) => setState(() => _minute = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DetailTile(
              icon: Icons.label_outline,
              title: 'Label',
              trailing: SizedBox(
                width: 180,
                child: TextField(
                  controller: _labelController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Alarm name',
                  ),
                ),
              ),
            ),
            _DetailTile(
              icon: Icons.repeat,
              title: 'Repeat',
              trailing: Text(
                _repeatLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              spacing: 7,
              children: [
                for (var day = 1; day <= 7; day++)
                  InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      setState(() {
                        if (_weekdays.contains(day)) {
                          _weekdays.remove(day);
                        } else {
                          _weekdays.add(day);
                        }
                      });
                    },
                    child: Container(
                      width: 43,
                      height: 43,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _weekdays.contains(day)
                            ? purple
                            : const Color(0xFF252C4A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailTile(
              icon: Icons.music_note_outlined,
              title: 'Sound',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _toneId,
                  dropdownColor: surface,
                  icon: const Icon(Icons.chevron_right, color: Colors.white38),
                  items: [
                    for (final tone in AlarmTone.tones)
                      DropdownMenuItem(value: tone.id, child: Text(tone.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _toneId = value);
                    }
                  },
                ),
              ),
            ),
            _DetailTile(
              icon: Icons.notifications_active_outlined,
              title: 'Snooze',
              subtitle: '5 min - 3 times',
              trailing: Switch(
                value: _snoozeEnabled,
                onChanged: (value) {
                  setState(() => _snoozeEnabled = value);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _weekdays.isEmpty ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text(
              'Save alarm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  final int value;
  final int count;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;

  const _TimeWheel({
    required this.value,
    required this.count,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = FixedExtentScrollController(initialItem: value);
    return SizedBox(
      width: 120,
      height: 180,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 64,
        diameterRatio: 1.6,
        squeeze: 1.05,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final selected = index == value;
            return Center(
              child: Text(
                labelBuilder(index),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: selected ? 42 : 28,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _DetailTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171A45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white54),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: Colors.white38)),
        trailing: trailing,
      ),
    );
  }
}
