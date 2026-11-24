import 'package:flutter_test/flutter_test.dart';
import 'package:shifts_app/theme/app_theme.dart';

void main() {
  group('AppTheme.isDaytime', () {
    test('includes 06:00 and excludes 18:00', () {
      expect(AppTheme.isDaytime(DateTime(2026, 1, 1, 6)), isTrue);
      expect(AppTheme.isDaytime(DateTime(2026, 1, 1, 17, 59)), isTrue);
      expect(AppTheme.isDaytime(DateTime(2026, 1, 1, 18)), isFalse);
    });

    test('uses dark mode overnight', () {
      expect(AppTheme.isDaytime(DateTime(2026, 1, 1, 5, 59)), isFalse);
      expect(AppTheme.isDaytime(DateTime(2026, 1, 1, 23, 59)), isFalse);
    });
  });
}
