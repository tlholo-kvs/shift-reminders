import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:excel_community/excel_community.dart';
import 'package:go_router/go_router.dart';
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
          final date = _dateFromCell(row[1]?.value);
          if (date == null) continue;
          final typeText = _cellText(row[2]?.value);
          shifts.add(Shift(date: date, type: ShiftType.fromString(typeText)));
        } catch (_) {
          // Skip header rows and malformed rows.
        }
      }
    }
    return shifts;
  }

  DateTime? _dateFromCell(CellValue? value) {
    if (value is DateCellValue) {
      return value.asDateTimeLocal();
    }
    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal();
    }

    final text = _cellText(value);
    if (text.isEmpty) return null;

    for (final pattern in const [
      'dd-MMM-yy',
      'dd-MMM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'd/M/yyyy',
    ]) {
      final date = DateFormat(pattern).tryParseStrict(text);
      if (date != null) return date;
    }

    return DateTime.tryParse(text);
  }

  String _cellText(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.text?.trim() ?? '';
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is FormulaCellValue) {
      return _cellText(value.cachedValue);
    }
    return value.toString().trim();
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

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() => _scheduling = false);
      _showError('Failed to schedule alarms: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        leading: TextButton.icon(
          onPressed: _scheduling ? null : () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          label: const Text(''),
        ),
        leadingWidth: 56,
        title: const Text(
          'Import Alarms',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: _hasParsed ? Alignment.topCenter : Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisAlignment: _hasParsed
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171F36),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8EEF8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'XLS',
                                      style: TextStyle(
                                        color: Color(0xFF15A36A),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Icon(
                                      Icons.sync_alt,
                                      color: Color(0xFF7867F6),
                                      size: 34,
                                    ),
                                  ),
                                  Container(
                                    width: 58,
                                    height: 58,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7867F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.schedule,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Import from File',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload a CSV or Excel file containing your alarms',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: const Text(
                                    'Choose File',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF7867F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed:
                                      _scheduling ? null : _pickFile,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                        OutlinedButton.icon(
                          icon: _loadingLink
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link),
                          label: const Text(
                            'Import from Excel Link',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7867F6),
                            side: const BorderSide(
                              color: Color(0xFF7867F6),
                            ),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _scheduling || _loadingLink
                              ? null
                              : _importFromLink,
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
                                    DateFormat(
                                      'EEE d MMM yyyy',
                                    ).format(shift.date),
                                  ),
                                  subtitle: Text(shift.type.displayName),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _scheduling ? null : _confirmAndSchedule,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7867F6),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _scheduling
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Confirm & Schedule Alarms'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
