import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../main.dart';
import '../../models/user_model.dart';
import '../../models/timesheet_project_model.dart';
import '../../services/api_service.dart';

class TimesheetReportsScreen extends StatefulWidget {
  final UserModel user;
  const TimesheetReportsScreen({super.key, required this.user});

  @override
  State<TimesheetReportsScreen> createState() => _TimesheetReportsScreenState();
}

class _TimesheetReportsScreenState extends State<TimesheetReportsScreen> {
  final _api = ApiService();

  List<TimesheetProject> _projects = [];
  String? _selectedProjectId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
  }

  Future<void> _loadProjects() async {
    try {
      final res = await _api.getTimesheetProjects(widget.user.companyId ?? '');
      setState(() {
        _projects =
            (res.data['data'] as List? ?? [])
                .map((e) => TimesheetProject.fromJson(e))
                .toList();
      });
    } catch (_) {}
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Select';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await _api.exportTimesheetEntries(
        companyId: widget.user.companyId ?? '',
        dateFrom: _fromDate != null ? _fmt(_fromDate) : null,
        dateTo: _toDate != null ? _fmt(_toDate) : null,
        projectId: _selectedProjectId,
      );

      final bytes = res.data as List<int>;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/timesheet_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export not available. Ask your backend developer to implement it.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Timesheet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Filter entries and download as Excel (.xlsx)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                _label('Date From'),
                _dateTile(_fmt(_fromDate), () => _pickDate(true)),
                const SizedBox(height: 12),

                _label('Date To'),
                _dateTile(_fmt(_toDate), () => _pickDate(false)),
                const SizedBox(height: 12),

                _label('Project (optional)'),
                DropdownButtonFormField<String>(
                  value: _selectedProjectId,
                  decoration: InputDecoration(
                    hintText: 'All projects',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Projects'),
                    ),
                    ..._projects.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedProjectId = v),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : _export,
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_exporting ? 'Exporting...' : 'Export to Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Export generates an Excel file with all timesheet entries for the selected period and project.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _dateTile(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    ),
  );
}
