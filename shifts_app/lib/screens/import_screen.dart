import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:excel_community/excel.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../services/alarm_service.dart';
import '../services/csv_parser.dart';
import '../services/storage_service.dart';

class ImportScreen extends StatefulWidget {
  final StorageService storageService;
  final AlarmService alarmService;

  const ImportScreen({
    super.key,
    required this.storageService,
    required this.alarmService,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<Shift> _parsedShifts = [];
  bool _hasParsed = false;
  bool _scheduling = false;
  bool _loadingLink = false;
  final TextEditingController _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _showError('Could not read file bytes.');
        return;
      }

      final fileName = result.files.first.name.toLowerCase();
      _setParsedShifts(_parseBytes(bytes, fileName));
    } catch (e) {
      _showError('Could not parse file — check the format');
    }
  }

  Future<void> _importFromLink() async {
    final text = _linkController.text.trim();
    if (text.isEmpty) {
      _showError('Enter an Excel or CSV link');
      return;
    }

    setState(() => _loadingLink = true);
    try {
      final uri = Uri.parse(text);
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        throw const FormatException('Invalid web link');
      }

      final response = await http.get(_excelExportUri(uri));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed (${response.statusCode})');
      }

      final fileName = uri.path.toLowerCase();
      final shifts = _parseBytes(response.bodyBytes, fileName);
      _setParsedShifts(shifts);
    } catch (e) {
      _showError('Could not download or parse the link');
    } finally {
      if (mounted) setState(() => _loadingLink = false);
    }
  }

  Uri _excelExportUri(Uri uri) {
    if (uri.host == 'docs.google.com' &&
        uri.path.contains('/spreadsheets/d/')) {
      final idMatch = RegExp(r'/spreadsheets/d/([^/]+)').firstMatch(uri.path);
      if (idMatch != null) {
        return Uri.parse(
          'https://docs.google.com/spreadsheets/d/${idMatch.group(1)}/export?format=xlsx',
        );
      }
    }
    return uri;
  }

  List<Shift> _parseBytes(List<int> bytes, String fileName) {
    if (fileName.endsWith('.xlsx') ||
        fileName.endsWith('.xls') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4B &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04)) {
      return _parseExcel(bytes);
    }

    final csvContent = utf8.decode(bytes);
    return CsvParser.parseCsv(csvContent);
  }

  List<Shift> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final shifts = <Shift>[];

    for (final table in excel.tables.values) {
      for (final row in table.rows) {
        if (row.length < 3) continue;
        try {
          final dateValue = row[1]?.value;
          final dateText = dateValue is DateTime
              ? DateFormat('dd-MMM-yy').format(dateValue)
              : dateValue?.toString().trim() ?? '';
          final typeText = row[2]?.value?.toString().trim() ?? '';
          shifts.add(
            Shift(
              date: DateFormat('dd-MMM-yy').parse(dateText),
              type: ShiftType.fromString(typeText),
            ),
          );
        } catch (_) {
          // Skip header rows and malformed rows.
        }
      }
    }
    return shifts;
  }

  void _setParsedShifts(List<Shift> shifts) {
    if (!mounted) return;
    setState(() {
      _parsedShifts = shifts;
      _hasParsed = true;
    });
  }

  Future<void> _confirmAndSchedule() async {
    setState(() => _scheduling = true);
    try {
      final rules = await widget.storageService.loadRules();
      final nightBefore = await widget.storageService.loadNightBefore();
      await widget.alarmService.scheduleAll(_parsedShifts, rules, nightBefore);
      await widget.storageService.saveShifts(_parsedShifts);
      final count =
          await widget.alarmService.countScheduled(_parsedShifts);

      if (mounted) {
        Navigator.of(context).pop(count);
      }
    } catch (e) {
      setState(() => _scheduling = false);
      _showError('Failed to schedule alarms: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Shifts')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick CSV or Excel File'),
              onPressed: _scheduling ? null : _pickFile,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Or import from a link',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkController,
              enabled: !_scheduling && !_loadingLink,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              decoration: const InputDecoration(
                labelText: 'Excel or CSV link',
                hintText: 'https://example.com/shifts.xlsx',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _importFromLink(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: _loadingLink
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('Import from Link'),
              onPressed: _scheduling || _loadingLink ? null : _importFromLink,
            ),
            if (_hasParsed) ...[
              const SizedBox(height: 16),
              Text(
                '${_parsedShifts.length} shift(s) found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _parsedShifts.length,
                  itemBuilder: (context, index) {
                    final shift = _parsedShifts[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.schedule),
                      title: Text(
                          DateFormat('EEE d MMM yyyy').format(shift.date)),
                      subtitle: Text(shift.type.displayName),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _scheduling ? null : _confirmAndSchedule,
                child: _scheduling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm & Schedule Alarms'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
