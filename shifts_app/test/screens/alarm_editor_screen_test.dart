import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifts_app/screens/alarm_editor_screen.dart';
import 'package:shifts_app/theme/app_theme.dart';

void main() {
  testWidgets('new alarms default to once and can save without repeat days', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AlarmEditorScreen()),
    );

    expect(find.textContaining('Once ·'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save alarm'),
    );
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('M').first);
    await tester.pump();
    expect(find.text('Mon'), findsOneWidget);
    expect(find.textContaining('Once ·'), findsNothing);
  });
}
