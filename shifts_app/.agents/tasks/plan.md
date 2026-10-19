# Implementation Plan — Shift Reminders App

## Project Context

- **Project**: `shifts_app` — a greenfield Flutter app (skeleton only: `main.dart` prints "Hello World")
- **Flutter SDK**: `^3.11.1` (Dart `>=3.11.1 <4.0.0`), confirmed via `pubspec.lock`
- **Android**: Kotlin, `compileSdk`/`targetSdk`/`minSdk` delegated to `flutter.*` variables; `build.gradle.kts` uses Kotlin DSL
- **iOS**: Standard Flutter iOS runner; `Info.plist` has no notification keys yet
- **Current deps**: only `flutter`, `flutter_test`, `flutter_lints` — everything must be added
- **Analysis**: `analysis_options.yaml` inherits `package:flutter_lints/flutter.yaml` — run `flutter analyze` to verify clean code

---

## Implementation Order

The items below are ordered strictly by dependency. Each leaves the project in a buildable state.

---

- [ ] 1. **Add all dependencies to `pubspec.yaml`**

  Replace the `dependencies` and `dev_dependencies` blocks. Pin exact minimum versions as shown — these are the lowest semver-compatible releases that support Dart ≥3.11 and Flutter ≥3.18.

  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    flutter_local_notifications: ^18.0.0
    android_intent_plus: ^5.0.0
    file_picker: ^8.0.0
    csv: ^6.0.0
    shared_preferences: ^2.3.0
    permission_handler: ^11.3.0
    intl: ^0.19.0
    go_router: ^14.0.0
  ```

  Files: `pubspec.yaml`

  Verify: `flutter pub get` — exits 0 with no resolution errors; `pubspec.lock` updated.

---

- [ ] 2. **Update `AndroidManifest.xml` — permissions and flutter_local_notifications receiver**

  Add the following inside the `<manifest>` element (before `<application>`):

  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.SET_ALARM"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```

  Add the following inside `<application>` (required by `flutter_local_notifications` for scheduled notifications and boot-restoration):

  ```xml
  <receiver android:exported="false"
      android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
  <receiver android:exported="false"
      android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
      <action android:name="android.intent.action.BOOT_COMPLETED"/>
      <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
      <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
  </receiver>
  ```

  Also update the `<queries>` block to include the alarm app intent (needed for `android_intent_plus` targeting `android.intent.action.SET_ALARM`):

  ```xml
  <intent>
    <action android:name="android.intent.action.SET_ALARM"/>
  </intent>
  ```

  Files: `android/app/src/main/AndroidManifest.xml`

  Verify: `flutter build apk --debug` (or `flutter analyze`) — no manifest merge errors.

---

- [ ] 3. **Update `ios/Runner/Info.plist` — notification usage description**

  Add the following key–value pair inside the root `<dict>`:

  ```xml
  <key>NSUserNotificationUsageDescription</key>
  <string>Shift Reminders uses notifications to alert you before each shift and the night before.</string>
  ```

  Also add the `UIBackgroundModes` key to allow background notification delivery:

  ```xml
  <key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
    <string>remote-notification</string>
  </array>
  ```

  Files: `ios/Runner/Info.plist`

  Verify: `flutter analyze` — no issues; `flutter build ios --no-codesign` on a Mac CI would confirm, but on Windows confirm the plist is valid XML (well-formed).

---

- [ ] 4. **Create `lib/models/shift.dart` — Shift data model**

  Define `ShiftType` enum and `Shift` class.

  - `ShiftType` values: `earlyShift`, `earlyShiftWFH`, `middleShift`, `lateShift`, `off`
  - Static factory `ShiftType.fromString(String s)` — lowercase + trim the input, match:
    - `'early shift wfh'` → `earlyShiftWFH`  *(check WFH first, before plain early shift)*
    - `'early shift'` → `earlyShift`
    - `'middle shift'` → `middleShift`
    - `'late shift'` → `lateShift`
    - `'off'` → `off`
    - Anything else → throw `ArgumentError`
  - `Shift` fields: `final DateTime date`, `final ShiftType type`
  - `Shift.fromCsvRow(List<dynamic> row)` factory — ignores `row[0]` (day of week), parses `row[1]` with `intl` `DateFormat('dd-MMM-yy').parse(...)`, calls `ShiftType.fromString(row[2])`. Handle optional header row: if `row[1]` throws a `FormatException`, the caller skips that row.
  - `toJson()` / `Shift.fromJson(Map<String, dynamic>)` for persistence (store date as ISO-8601 string, shiftType as enum index or name string).
  - `bool get isPast` → `date.isBefore(DateTime.now().copyWith(hour:0,minute:0,second:0,microsecond:0))`

  Files: `lib/models/shift.dart`

  Verify: `flutter analyze lib/models/shift.dart` — no issues.

---

- [ ] 5. **Create `lib/models/shift_rule.dart` — ShiftRule model**

  - `ShiftRule` fields: `final ShiftType type`, `TimeOfDay alarmTime`, `TimeOfDay shiftStart`
  - Default rules list as a `static const List<ShiftRule> defaults` (hardcoded):
    - `earlyShift`: alarm 06:40, start 08:00
    - `earlyShiftWFH`: alarm 07:30, start 08:00
    - `middleShift`: alarm 09:40, start 11:00
    - `lateShift`: alarm 13:45, start 14:00
    - `off`: alarm null / no alarm (represent as alarm 00:00, but `AlarmService` will skip `off` type)
  - `toJson()` / `ShiftRule.fromJson(...)` — store `TimeOfDay` as `{'hour': h, 'minute': m}`
  - A top-level `TimeOfDay nightBeforeDefault` constant = `TimeOfDay(hour: 20, minute: 0)` (configurable via settings)

  Files: `lib/models/shift_rule.dart`

  Verify: `flutter analyze lib/models/shift_rule.dart` — no issues.

---

- [ ] 6. **Create `lib/services/storage_service.dart` — SharedPreferences persistence**

  Uses `shared_preferences`. Provides:

  - `Future<void> saveShifts(List<Shift> shifts)` — serialise to JSON list, store under key `'shifts'`
  - `Future<List<Shift>> loadShifts()` — deserialise from key `'shifts'`; return `[]` on missing key
  - `Future<void> saveRules(List<ShiftRule> rules, TimeOfDay nightBefore)` — serialise under key `'rules'` and `'nightBefore'`
  - `Future<List<ShiftRule>> loadRules()` — return `ShiftRule.defaults` if key missing
  - `Future<TimeOfDay> loadNightBefore()` — return `nightBeforeDefault` if key missing
  - `Future<bool> isFirstLaunch()` — read key `'onboarded'`; returns `true` if not set
  - `Future<void> setOnboarded()` — write `true` to key `'onboarded'`

  Files: `lib/services/storage_service.dart`

  Verify: `flutter analyze lib/services/storage_service.dart` — no issues.

---

- [ ] 7. **Create `lib/services/csv_parser.dart` — CSV parsing**

  Uses `csv` and `intl` packages.

  - `List<Shift> parseCsv(String csvContent)`:
    1. Use `CsvToListConverter().convert(csvContent)` to get `List<List<dynamic>>`
    2. For each row, attempt `Shift.fromCsvRow(row)` inside a try/catch; skip rows that throw (covers header row and blank rows)
    3. Return the list of valid `Shift` objects

  Files: `lib/services/csv_parser.dart`

  Verify: `flutter analyze lib/services/csv_parser.dart` — no issues.

---

- [ ] 8. **Create `lib/services/alarm_service.dart` — alarm and notification scheduling**

  This is the core service. It coordinates `flutter_local_notifications` (both platforms, night-before; plus iOS wake notification) and `android_intent_plus` (Android wake alarm).

  **Initialisation** (`Future<void> init()`):
  - Initialise `FlutterLocalNotificationsPlugin` with:
    - Android init settings: `AndroidInitializationSettings('@mipmap/ic_launcher')`
    - iOS init settings: `DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)` — permissions are requested separately on the permissions screen
  - Call `plugin.initialize(settings)`

  **`Future<void> scheduleAll(List<Shift> shifts, List<ShiftRule> rules, TimeOfDay nightBefore)`**:
  - Cancel all existing notifications first: `plugin.cancelAll()`
  - For each shift where `!shift.isPast` and `shift.type != ShiftType.off`:
    - Find the matching `ShiftRule` from `rules`
    - **Night-before notification** (both platforms):
      - `scheduledDate` = shift.date minus 1 day, at `nightBefore` time (20:00 by default)
      - If that datetime is also in the past, skip it
      - Use `plugin.zonedSchedule(...)` with `usingExactAlarmClock: true`
      - Notification ID: derive deterministically from date, e.g. `shift.date.millisecondsSinceEpoch ~/ 1000 * 10 + 1` (keep under 2^31)
      - Title: `'Shift Tomorrow'`
      - Body: e.g. `'${shiftRule.displayName} tomorrow — alarm set for ${_formatTime(rule.alarmTime)}'`
      - Android channel: `'shift_reminders_night'`, importance `Importance.high`
    - **Wake alarm / notification**:
      - On **Android**: fire `android_intent_plus` `AndroidIntent` with action `android.intent.action.SET_ALARM`, extras:
        ```dart
        {
          'android.intent.extra.alarm.HOUR': rule.alarmTime.hour,
          'android.intent.extra.alarm.MINUTES': rule.alarmTime.minute,
          'android.intent.extra.alarm.MESSAGE': 'Early Shift starts at 08:00', // dynamic
          'android.intent.extra.alarm.SKIP_UI': true,
          'android.intent.extra.alarm.VIBRATE': true,
        }
        ```
        Check platform: `Platform.isAndroid` before calling
      - On **iOS**: `plugin.zonedSchedule(...)` at the exact alarm datetime
        - Notification ID: same base as night-before + 0 offset
        - Title: `'Time to get up!'`
        - Body: `'${shiftRule.displayName} starts at ${_formatTime(rule.shiftStart)}'`
        - iOS notification details: `DarwinNotificationDetails(presentAlert: true, presentSound: true)`
        - Android channel: `'shift_reminders_alarm'`, importance `Importance.max`

  **Helper** `String _formatTime(TimeOfDay t)` → `'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'`

  **`Future<int> countScheduled(List<Shift> shifts)`** — returns count of non-past, non-off shifts.

  **Important note on `zonedSchedule`**: import `package:flutter_local_notifications/flutter_local_notifications.dart` and `package:timezone/data/latest_all.dart` / `package:timezone/timezone.dart`. Add `timezone: ^0.9.0` to `pubspec.yaml` if not transitively present (it is a transitive dep of `flutter_local_notifications` ≥18 — confirm after `pub get`). Call `tz.initializeTimeZones()` in `main()` before `runApp`.

  Files: `lib/services/alarm_service.dart`

  Verify: `flutter analyze lib/services/alarm_service.dart` — no issues.

---

- [ ] 9. **Create `lib/app.dart` — GoRouter setup and app entry widget**

  - Define `GoRouter` with routes:
    - `/` → `HomeScreen`
    - `/import` → `ImportScreen`
    - `/rules` → `RulesScreen`
    - `/permissions` → `PermissionsScreen`
  - Add a `redirect` on `/`: check `StorageService.isFirstLaunch()`; if true redirect to `/permissions`
  - Export a `ShiftRemindersApp` `StatelessWidget` that returns `MaterialApp.router(routerConfig: router, title: 'Shift Reminders')`
  - Wrap with a `ChangeNotifierProvider` or simple `InheritedWidget` if state sharing is needed — keep it simple; pass `StorageService` and `AlarmService` as constructor args or via `Provider` if you add it. **Decision**: use plain constructor pass-down via `GoRouter`'s `extra` parameter and screen constructors — do not add a state management package; the task does not require it.

  Files: `lib/app.dart`

  Verify: `flutter analyze lib/app.dart` — no issues.

---

- [ ] 10. **Rewrite `lib/main.dart` — app initialisation**

  ```dart
  import 'package:flutter/material.dart';
  import 'package:timezone/data/latest_all.dart' as tz;
  import 'services/alarm_service.dart';
  import 'app.dart';

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    final alarmService = AlarmService();
    await alarmService.init();
    runApp(ShiftRemindersApp(alarmService: alarmService));
  }
  ```

  Files: `lib/main.dart`

  Verify: `flutter analyze lib/main.dart` — no issues.

---

- [ ] 11. **Create `lib/screens/permissions_screen.dart`**

  - On `initState`, call `permission_handler` to request:
    - `Permission.notification` (both platforms)
    - `Permission.scheduleExactAlarm` (Android 12+ only — wrap in `Platform.isAndroid && await Permission.scheduleExactAlarm.isDenied`)
  - Show a simple screen with the app logo/title, a brief explanation ("Shift Reminders needs notification permission to alert you before shifts"), and a "Grant Permissions" button
  - After permissions are granted (or user taps "Continue anyway"), call `StorageService.setOnboarded()` then `context.go('/')`

  Files: `lib/screens/permissions_screen.dart`

  Verify: `flutter analyze lib/screens/permissions_screen.dart` — no issues.

---

- [ ] 12. **Create `lib/widgets/shift_tile.dart`**

  A `ListTile`-based widget showing:
  - Leading icon: calendar emoji or `Icons.schedule`
  - Title: formatted date (e.g. `'Wed 14 Oct 2026'`) using `intl` `DateFormat('EEE d MMM yyyy')`
  - Subtitle: shift type display name (e.g. `'Early Shift WFH'`)
  - Trailing: alarm time string if applicable, or `'Off'` / `'No alarm'`
  - Greyed-out style when `shift.isPast`

  Constructor: `ShiftTile({required Shift shift, required ShiftRule? rule})`

  Files: `lib/widgets/shift_tile.dart`

  Verify: `flutter analyze lib/widgets/shift_tile.dart` — no issues.

---

- [ ] 13. **Create `lib/screens/home_screen.dart`**

  - `StatefulWidget`; loads shifts from `StorageService` in `initState`
  - `AppBar` title: `'Shift Reminders'`; actions: gear icon → `context.go('/rules')`, plus icon → `context.go('/import')`
  - Body: `ListView.builder` over `shifts` list, each item a `ShiftTile`
  - Empty state: centred text `'No shifts imported yet.\nTap + to import a CSV.'`
  - Receives `StorageService` and `AlarmService` via constructor (passed through GoRouter `extra`)
  - On return from `/import`, call `setState` to reload shifts (use `context.push('/import')` and `then` callback, or `GoRouter` refresh notifier — use `then` for simplicity)

  Files: `lib/screens/home_screen.dart`

  Verify: `flutter analyze lib/screens/home_screen.dart` — no issues.

---

- [ ] 14. **Create `lib/screens/import_screen.dart`**

  - `StatefulWidget` with three states: _idle_, _previewing_, _scheduling_
  - "Pick CSV File" button uses `file_picker`: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true)`
  - On file picked: parse bytes as UTF-8 string, call `CsvParser.parseCsv(...)`, populate `_parsedShifts` list and call `setState`
  - Preview section: `ListView` of parsed rows (date + shift type), with row count shown
  - "Confirm & Schedule Alarms" button:
    1. Load rules from `StorageService`
    2. Call `AlarmService.scheduleAll(shifts, rules, nightBefore)`
    3. Save shifts via `StorageService.saveShifts(shifts)`
    4. Pop screen and show `SnackBar`: `'${count} alarm(s) scheduled'`
  - Handle parse errors gracefully: show a `SnackBar` with `'Could not parse CSV — check the file format'`

  Files: `lib/screens/import_screen.dart`

  Verify: `flutter analyze lib/screens/import_screen.dart` — no issues.

---

- [ ] 15. **Create `lib/screens/rules_screen.dart`**

  - `StatefulWidget`; loads rules and `nightBefore` time from `StorageService` in `initState`
  - Shows one `ListTile` per shift type (skip `off`):
    - Title: shift type display name
    - Subtitle: `'Alarm at HH:mm — shift starts HH:mm'`
    - Trailing: edit icon
    - On tap: open a `showTimePicker` dialog to update the alarm time; save immediately via `StorageService.saveRules(...)`
  - Additional tile at the bottom: `'Night-before notification'` with current time; editable via `showTimePicker`
  - `AppBar` title: `'Alarm Rules'`; back arrow navigates to home

  Files: `lib/screens/rules_screen.dart`

  Verify: `flutter analyze lib/screens/rules_screen.dart` — no issues.

---

- [ ] 16. **Final: run `flutter analyze` and fix any reported issues**

  This is the integration verification step. It will catch:
  - Missing imports
  - Unused variables
  - Type mismatches from `csv` package's `List<dynamic>` rows
  - Any `timezone` import issues

  Run from the project root: `flutter analyze`

  Expected output: `No issues found!`

  If issues exist, fix them in the relevant files. Common fixes:
  - Add `// ignore: depend_on_referenced_packages` only if a transitive dep is used directly (prefer adding it explicitly)
  - Ensure `timezone` is added to `pubspec.yaml` directly if `flutter analyze` reports it as an implicit dep
  - Cast `row[1]` and `row[2]` to `String` explicitly in `Shift.fromCsvRow`

  Files: any file with reported issues

  Verify: `flutter analyze` → `No issues found!`

---

## Summary of Files to Create/Modify

| Action | File |
|--------|------|
| Modify | `pubspec.yaml` |
| Modify | `android/app/src/main/AndroidManifest.xml` |
| Modify | `ios/Runner/Info.plist` |
| Rewrite | `lib/main.dart` |
| Create | `lib/app.dart` |
| Create | `lib/models/shift.dart` |
| Create | `lib/models/shift_rule.dart` |
| Create | `lib/services/csv_parser.dart` |
| Create | `lib/services/alarm_service.dart` |
| Create | `lib/services/storage_service.dart` |
| Create | `lib/screens/home_screen.dart` |
| Create | `lib/screens/import_screen.dart` |
| Create | `lib/screens/rules_screen.dart` |
| Create | `lib/screens/permissions_screen.dart` |
| Create | `lib/widgets/shift_tile.dart` |

## Key Design Decisions

1. **Android alarms via `android_intent_plus` SET_ALARM intent** — this fires a real clock alarm in the system alarm app with `SKIP_UI=true`. The limitation is that one intent fires one alarm; for bulk scheduling we fire one intent per shift. Android may batch or deduplicate alarms in the clock app — this is the best available mechanism without writing a native plugin.

2. **iOS uses `flutter_local_notifications` for both wake and night-before** — iOS has no public API for writing to the Clock app. Local notifications are the correct approach. Users must enable "Allow Notifications" in iOS Settings for the app.

3. **No state management library** — the app is simple enough that `StatefulWidget` + direct service calls are sufficient. Adding Provider/Riverpod would be over-engineering for 4 screens.

4. **GoRouter for navigation** — specified in requirements. The `/permissions` redirect on first launch is handled via `GoRouter.redirect`, which is evaluated on every navigation attempt and checks `StorageService.isFirstLaunch()`.

5. **`timezone` package**: `flutter_local_notifications` ≥18 requires `tz.TZDateTime` for scheduled notifications. `timezone` is a transitive dependency but must be called explicitly via `tz.initializeTimeZones()` in `main()`. Add it explicitly to `pubspec.yaml` to satisfy the linter.

6. **Notification IDs**: derived deterministically from `shift.date.millisecondsSinceEpoch ~/ 60000` to keep IDs stable and avoid duplicates on re-import. Night-before ID = base * 2; wake ID = base * 2 + 1. This keeps IDs well within the 32-bit signed int range for dates in 2025–2030.
