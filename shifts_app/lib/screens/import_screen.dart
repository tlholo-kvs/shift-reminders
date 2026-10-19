import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _showError('Could not read file bytes.');
        return;
      }

      final csvContent = utf8.decode(bytes);
      final shifts = CsvParser.parseCsv(csvContent);

      setState(() {
        _parsedShifts = shifts;
        _hasParsed = true;
      });
    } catch (e) {
      _showError('Could not parse CSV — check the file format');
    }
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
              label: const Text('Pick CSV File'),
              onPressed: _scheduling ? null : _pickFile,
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
