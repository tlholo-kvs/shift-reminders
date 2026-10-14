import 'package:intl/intl.dart';

enum ShiftType {
  earlyShift,
  earlyShiftWFH,
  middleShift,
  lateShift,
  off;

  static ShiftType fromString(String s) {
    final lower = s.trim().toLowerCase();
    if (lower == 'early shift wfh') return ShiftType.earlyShiftWFH;
    if (lower == 'early shift') return ShiftType.earlyShift;
    if (lower == 'middle shift') return ShiftType.middleShift;
    if (lower == 'late shift') return ShiftType.lateShift;
    if (lower == 'off') return ShiftType.off;
    throw ArgumentError('Unknown shift type: $s');
  }

  String get displayName {
    switch (this) {
      case ShiftType.earlyShift:
        return 'Early Shift';
      case ShiftType.earlyShiftWFH:
        return 'Early Shift WFH';
      case ShiftType.middleShift:
        return 'Middle Shift';
      case ShiftType.lateShift:
        return 'Late Shift';
      case ShiftType.off:
        return 'Off';
    }
  }
}

class Shift {
  final DateTime date;
  final ShiftType type;

  const Shift({required this.date, required this.type});

  factory Shift.fromCsvRow(List<dynamic> row) {
    final dateStr = row[1].toString().trim();
    final date = DateFormat('dd-MMM-yy').parse(dateStr);
    final type = ShiftType.fromString(row[2].toString().trim());
    return Shift(date: date, type: type);
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.name,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      date: DateTime.parse(json['date'] as String),
      type: ShiftType.values.firstWhere((e) => e.name == json['type']),
    );
  }

  bool get isPast {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return date.isBefore(today);
  }
}
