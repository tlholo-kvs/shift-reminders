import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift.dart';
import '../models/shift_rule.dart';

class StorageService {
  static const _shiftsKey = 'shifts';
  static const _rulesKey = 'rules';
  static const _nightBeforeKey = 'nightBefore';
  static const _onboardedKey = 'onboarded';

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
    return list
        .map((e) => Shift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRules(
      List<ShiftRule> rules, TimeOfDay nightBefore) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRules =
        jsonEncode(rules.map((r) => r.toJson()).toList());
    final encodedNightBefore = jsonEncode(
        {'hour': nightBefore.hour, 'minute': nightBefore.minute});
    await prefs.setString(_rulesKey, encodedRules);
    await prefs.setString(_nightBeforeKey, encodedNightBefore);
  }

  Future<List<ShiftRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rulesKey);
    if (raw == null) return List<ShiftRule>.from(ShiftRule.defaults);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ShiftRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TimeOfDay> loadNightBefore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nightBeforeKey);
    if (raw == null) return nightBeforeDefault;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return TimeOfDay(
        hour: map['hour'] as int, minute: map['minute'] as int);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_onboardedKey) ?? false);
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }
}
