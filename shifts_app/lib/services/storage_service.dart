import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';
import '../models/manual_alarm.dart';

class StorageService {
  static const _shiftsKey = 'shifts';
  static const _rulesKey = 'rules';
  static const _nightBeforeKey = 'nightBefore';
  static const _onboardedKey = 'onboarded';
  static const _manualAlarmsKey = 'manualAlarms';
  static const _alarmToneKey = 'alarmTone';
  static const _normalWorkWeekKey = 'normalWorkWeek';

  Future<void> saveShifts(List<Shift> shifts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(shifts.map((s) => s.toJson()).toList());
    await prefs.setString(_shiftsKey, encoded);
  }

  Future<List<Shift>> loadShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shiftsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveRules(List<ShiftRule> rules, TimeOfDay nightBefore) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRules = jsonEncode(rules.map((r) => r.toJson()).toList());
    final encodedNightBefore = jsonEncode({
      'hour': nightBefore.hour,
      'minute': nightBefore.minute,
    });
    await prefs.setString(_rulesKey, encodedRules);
    await prefs.setString(_nightBeforeKey, encodedNightBefore);
  }

  Future<List<ShiftRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rulesKey);
    if (raw == null) return List<ShiftRule>.from(ShiftRule.defaults);
    final list = jsonDecode(raw) as List<dynamic>;
    final saved = list
        .map((e) => ShiftRule.fromJson(e as Map<String, dynamic>))
        .toList();

    var rulesChanged = false;
    for (final defaultRule in ShiftRule.defaults) {
      if (!saved.any((rule) => rule.type == defaultRule.type)) {
        saved.add(defaultRule);
        rulesChanged = true;
      }
    }

    final ruleOrder = {
      for (var i = 0; i < ShiftRule.defaults.length; i++)
        ShiftRule.defaults[i].type: i,
    };
    saved.sort(
      (a, b) => (ruleOrder[a.type] ?? 999).compareTo(ruleOrder[b.type] ?? 999),
    );
    if (rulesChanged) {
      await saveRules(saved, await loadNightBefore());
    }
    return saved;
  }

  Future<TimeOfDay> loadNightBefore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nightBeforeKey);
    if (raw == null) return nightBeforeDefault;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_onboardedKey) ?? false);
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<List<ManualAlarm>> loadManualAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_manualAlarmsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ManualAlarm.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveManualAlarms(List<ManualAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _manualAlarmsKey,
      jsonEncode(alarms.map((alarm) => alarm.toJson()).toList()),
    );
  }

  Future<String> loadAlarmTone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_alarmToneKey) ?? 'mixkit_morning_clock_alarm_1003';
  }

  Future<void> saveAlarmTone(String toneId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmToneKey, toneId);
  }

  Future<bool> loadNormalWorkWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_normalWorkWeekKey) ?? false;
  }

  Future<void> saveNormalWorkWeek(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_normalWorkWeekKey, enabled);
  }
}
