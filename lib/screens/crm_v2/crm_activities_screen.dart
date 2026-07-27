import 'package:flutter/material.dart';
import '../../utils/error_helper.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmActivitiesScreen extends StatefulWidget {
  const CrmActivitiesScreen({super.key});
  @override
  State<CrmActivitiesScreen> createState() => _CrmActivitiesScreenState();
}

class _CrmActivitiesScreenState extends State<CrmActivitiesScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _deals = [];
  String? _filterType;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  static const _activityTypes = ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final res = await _api.getCrmContacts();
      final raw = res.data;
      _contacts = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    try {
      final res = await _api.getCrmDeals();
      final raw = res.data;
      _deals = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmActivities(
        type: _filterType,
        fromDate: _fromDate.toIso8601String().split('T').first,
        toDate: _toDate.toIso8601String().split('T').first,
      );
      final raw = res.data;
      _activities = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _activities = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) { setState(() { _fromDate = picked.start; _toDate = picked.end; }); _load(); }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showLogActivity() {
    String selectedType = _activityTypes.first;
    String? selectedContactId;
    String? selectedDealId;
    final notesCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    DateTime? dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('Log Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                const Text('Activity Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedType, 'Select type', [
                  ..._activityTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedType = v ?? _activityTypes.first)),
                const SizedBox(height: 10),
                _field(titleCtrl, 'Title (optional)'),
                const SizedBox(height: 10),
                const Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedContactId, 'Select contact', [
                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 14))),
                  ..._contacts.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text('${c['name']}', style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedContactId = v)),
                const SizedBox(height: 10),
                const Text('Deal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedDealId, 'Select deal', [
                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 14))),
                  ..._deals.map((d) => DropdownMenuItem<String>(value: d['id'] as String, child: Text('${d['name']}', style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedDealId = v)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                      builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
                    );
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(dueDate != null ? 'Due: ${_fmtDate(dueDate!)}' : 'Set Due Date (optional)', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                    filled: true, fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.createCrmActivityLog(
                          type: selectedType,
                          contactId: selectedContactId,
                          dealId: selectedDealId,
                          title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null,
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          dueDate: dueDate?.toIso8601String(),
                        );
                        _msg('Activity logged');
                        _load();
                      } catch (e) { _msg('Failed: $e', error: true); }
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Log Activity'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdown<T>(T? value, String hint, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(value: value, isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 14)), items: items, onChanged: onChanged),
      ),
    );
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'CALL': return Icons.phone_rounded;
      case 'EMAIL': return Icons.email_rounded;
      case 'MEETING': return Icons.groups_rounded;
      case 'TASK': return Icons.task_alt_rounded;
      default: return Icons.notes_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'CALL': return AppColors.primary;
      case 'EMAIL': return AppColors.accent;
      case 'MEETING': return AppColors.success;
      case 'TASK': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
                child: Row(children: [
                  const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('${_fmtDate(_fromDate)} — ${_fmtDate(_toDate)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showLogActivity,
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _typeChip('All', null),
            ..._activityTypes.map((t) => _typeChip(t, t)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_activities.length} activities', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _activities.isEmpty
            ? const Center(child: Text('No activities found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _activities.length,
                  itemBuilder: (_, i) => _activityTile(_activities[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _typeChip(String label, String? type) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () { setState(() => _filterType = type); _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final title = activity['title'] ?? activity['subject'] ?? type ?? 'Activity';
    final notes = activity['notes'] ?? activity['description'] ?? '';
    final contactName = activity['contact']?['name'] ?? '';
    final dealName = activity['deal']?['name'] ?? '';
    final createdAt = activity['createdAt'] as String?;
    final color = _typeColor(type);
    final icon = _typeIcon(type);

    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('$title', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
          if (type != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
          if (contactName.isNotEmpty || dealName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              if (contactName.isNotEmpty) ...[
                const Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(contactName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
              if (contactName.isNotEmpty && dealName.isNotEmpty) const SizedBox(width: 8),
              if (dealName.isNotEmpty) ...[
                const Icon(Icons.handshake_outlined, size: 12, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(dealName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ]),
          ],
          if (notes.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('$notes', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ])),
      ]),
    );
  }
}
