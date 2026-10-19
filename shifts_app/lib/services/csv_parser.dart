import 'package:csv/csv.dart';
import '../models/shift.dart';

class CsvParser {
  static List<Shift> parseCsv(String csvContent) {
    final rows = const CsvToListConverter().convert(csvContent);
    final shifts = <Shift>[];
    for (final row in rows) {
      if (row.length < 3) continue;
      try {
        shifts.add(Shift.fromCsvRow(row));
      } catch (_) {
        // Skip header rows and malformed rows
      }
    }
    return shifts;
  }
}
