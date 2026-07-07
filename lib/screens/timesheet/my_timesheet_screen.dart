import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_model.dart';
import '../../models/timesheet_project_model.dart';
import '../../models/timesheet_entry_model.dart';
import '../../services/api_service.dart';

class MyTimesheetScreen extends StatefulWidget {
  final UserModel user;
  const MyTimesheetScreen({super.key, required this.user});

  @override
  State<MyTimesheetScreen> createState() => _MyTimesheetScreenState();
}

class _MyTimesheetScreenState extends State<MyTimesheetScreen> {
  final _api = ApiService();

  List<TimesheetEntry> _entries = [];
  List<TimesheetProject> _projects = [];
  List<AvailableSubtask> _availableSubtasks = [];

  bool _loading = true;
  bool _submitting = false;

  // form state
  final _formKey = GlobalKey<FormState>();
  String _date = _today();
  String? _selectedProjectId;
  String? _selectedSubtaskId;
  double _hours = 0.5;
  HourRange _range = HourRange(minHours: 0.25, maxHours: 1.5);
  final _narrationCtrl = TextEditingController();

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _api.getMyTimesheetEntries(widget.user.id),
        _api.getMyTimesheetProjects(widget.user.id),
      ]);
      setState(() {
        _entries =
            (res[0].data['data'] as List? ?? [])
                .map((e) => TimesheetEntry.fromJson(e))
                .toList();
        _projects =
            (res[1].data['data'] as List? ?? [])
                .map((e) => TimesheetProject.fromJson(e))
                .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSubtasks(String projectId) async {
    setState(() {
      _availableSubtasks = [];
      _selectedSubtaskId = null;
    });
    try {
      final res = await _api.getAvailableSubtasks(projectId, widget.user.id);
      setState(() {
        _availableSubtasks =
            (res.data['data'] as List? ?? [])
                .map((e) => AvailableSubtask.fromJson(e))
                .toList();
      });
    } catch (_) {}
  }

  Future<void> _loadHourRange(String subtaskId) async {
    try {
      final res = await _api.getTimesheetHourRange(widget.user.id, subtaskId);
      final range = HourRange.fromJson(res.data['data']);
      setState(() {
        _range = range;
        _hours = range.minHours;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null || _selectedSubtaskId == null) {
      _showSnack('Please select a project and subtask', isError: true);
      return;
    }
    if (_narrationCtrl.text.trim().isEmpty) {
      _showSnack('Please enter a narration', isError: true);
      return;
    }

    final sub = _availableSubtasks.firstWhere(
      (s) => s.subtaskId == _selectedSubtaskId,
    );

    setState(() => _submitting = true);
    try {
      await _api.createTimesheetEntry({
        'date': _date,
        'projectId': _selectedProjectId,
        'projectTaskId': sub.taskId,
        'projectSubtaskId': _selectedSubtaskId,
        'hours': _hours,
        'narration': _narrationCtrl.text.trim(),
        'companyId': widget.user.companyId ?? '',
      });
      _showSnack('Entry logged successfully');
      _narrationCtrl.clear();
      setState(() {
        _selectedSubtaskId = null;
        _hours = _range.minHours;
      });
      _load();
    } catch (e) {
      debugPrint('[Timesheet] Create entry error: $e');
      final msg = e is DioException
          ? (e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Failed to log entry')
          : 'Failed to log entry';
      _showSnack('$msg', isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _deleteEntry(TimesheetEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
          'Remove ${entry.hours}h on ${entry.date} for ${entry.projectName ?? entry.projectId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteTimesheetEntry(entry.id);
      _showSnack('Entry deleted');
      _load();
    } catch (_) {
      _showSnack('Failed to delete entry', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
      ),
    );
  }

  double get _todayTotal {
    final today = _today();
    return _entries
        .where((e) => e.date == today)
        .fold(0.0, (s, e) => s + e.hours);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTodayBadge(),
        const SizedBox(height: 16),
        _buildEntryForm(),
        const SizedBox(height: 20),
        _buildRecentEntries(),
      ],
    );
  }

  Widget _buildTodayBadge() {
    final done = _todayTotal >= 8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 18,
            color: done ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Text(
            '${_todayTotal.toStringAsFixed(1)}h logged today',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: done ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Entry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              // Date
              _label('Date'),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_date),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Project
              _label('Project'),
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: _inputDeco('Select project'),
                items: _projects
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedProjectId = v;
                    _selectedSubtaskId = null;
                    _availableSubtasks = [];
                  });
                  if (v != null) _loadSubtasks(v);
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Subtask
              _label('Subtask'),
              DropdownButtonFormField<String>(
                value: _selectedSubtaskId,
                decoration: _inputDeco(
                  _selectedProjectId == null
                      ? 'Select project first'
                      : 'Select subtask',
                ),
                selectedItemBuilder: (_) => _availableSubtasks
                    .map((s) => Text(s.subtaskName, overflow: TextOverflow.ellipsis))
                    .toList(),
                items: _availableSubtasks
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.subtaskId,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.subtaskName),
                            Text(
                              '${s.taskName} · ${s.minHours}–${s.maxHours}h',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _selectedProjectId == null
                    ? null
                    : (v) {
                        setState(() => _selectedSubtaskId = v);
                        if (v != null) _loadHourRange(v);
                      },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Hours
              _label(
                'Hours  (${_range.minHours}–${_range.maxHours}h)',
              ),
              Slider(
                value: _hours.clamp(_range.minHours, _range.maxHours),
                min: _range.minHours,
                max: _range.maxHours,
                divisions:
                    ((_range.maxHours - _range.minHours) / 0.25).round(),
                label: '${_hours}h',
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _hours = v),
              ),
              Center(
                child: Text(
                  '${_hours.toStringAsFixed(2)}h',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Narration
              _label('Narration'),
              TextFormField(
                controller: _narrationCtrl,
                decoration: _inputDeco('What exactly did you work on?'),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Add Entry'),
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
    );
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Entries (${_entries.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (_entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No entries yet. Log your first entry above.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...(_entries.take(20).map((e) => _buildEntryCard(e))),
      ],
    );
  }

  Widget _buildEntryCard(TimesheetEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${e.hours}h',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.projectName ?? e.projectId,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.taskName ?? ''} · ${e.subtaskName ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    e.narration,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  e.date,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _deleteEntry(e),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final parts = _date.split('-');
    final initial = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    isDense: true,
  );
}
