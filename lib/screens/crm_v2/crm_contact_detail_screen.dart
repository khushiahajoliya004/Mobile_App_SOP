import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmContactDetailScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  const CrmContactDetailScreen({super.key, required this.contactId, required this.contactName});
  @override
  State<CrmContactDetailScreen> createState() => _CrmContactDetailScreenState();
}

class _CrmContactDetailScreenState extends State<CrmContactDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _contact;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _deals = [];
  List<Map<String, dynamic>> _followUps = [];
  int _tab = 0; // 0=Timeline, 1=Deals, 2=Follow-ups

  static const _activityTypes = ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmContact(widget.contactId);
      final raw = res.data;
      _contact = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
    } catch (_) {}
    try {
      final res = await _api.getCrmActivities(contactId: widget.contactId, limit: 50);
      final raw = res.data;
      _activities = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _activities = []; }
    try {
      final res = await _api.getCrmDeals(search: _contact?['phone'] as String?);
      final raw = res.data;
      _deals = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _deals = []; }
    try {
      final res = await _api.getCrmFollowUpsByContact(widget.contactId);
      final raw = res.data;
      _followUps = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _followUps = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showLogActivity() {
    String selectedType = _activityTypes.first;
    final notesCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Log Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _dropdown<String>(selectedType, 'Type', [
                ..._activityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
              ], (v) => setSheet(() => selectedType = v ?? _activityTypes.first)),
              const SizedBox(height: 10),
              _field(titleCtrl, 'Title (optional)'),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl, maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes', alignLabelWithHint: true,
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
                      await _api.createCrmActivityLog(type: selectedType, contactId: widget.contactId, title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null, notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null);
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
    );
  }

  void _showScheduleFollowUp() {
    String selectedType = 'CALL';
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
    final notesCtrl = TextEditingController();
    const types = ['CALL', 'EMAIL', 'MEETING', 'TASK'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Schedule Follow-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _dropdown<String>(selectedType, 'Type', [
                ...types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
              ], (v) => setSheet(() => selectedType = v ?? 'CALL')),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: scheduledAt, firstDate: DateTime.now(), lastDate: DateTime(2030), builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!));
                  if (d != null) setSheet(() => scheduledAt = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Scheduled: ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl, maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)', alignLabelWithHint: true,
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
                      await _api.createCrmFollowUp(contactId: widget.contactId, scheduledAt: scheduledAt, type: selectedType, notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null);
                      _msg('Follow-up scheduled');
                      _load();
                    } catch (e) { _msg('Failed: $e', error: true); }
                  },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Schedule Follow-up'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label, filled: true, fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _dropdown<T>(T value, String hint, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 14)), items: items, onChanged: onChanged)),
  );

  String _stageLabel(String? stage) {
    switch (stage) {
      case 'LEAD': return 'Lead';
      case 'QUALIFIED': return 'Qualified';
      case 'OPPORTUNITY': return 'Opportunity';
      case 'CUSTOMER': return 'Customer';
      default: return stage ?? '';
    }
  }

  Color _stageColor(String? stage) {
    switch (stage) {
      case 'LEAD': return AppColors.primary;
      case 'QUALIFIED': return AppColors.accent;
      case 'OPPORTUNITY': return AppColors.warning;
      case 'CUSTOMER': return AppColors.success;
      default: return AppColors.textHint;
    }
  }

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'CALL': return Icons.phone_rounded;
      case 'EMAIL': return Icons.email_rounded;
      case 'MEETING': return Icons.groups_rounded;
      case 'TASK': return Icons.task_alt_rounded;
      default: return Icons.notes_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Material(color: Colors.white, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    final contact = _contact ?? {};
    final name = contact['name'] ?? widget.contactName;
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';
    final stage = contact['lifecycleStage'] as String?;
    final source = contact['source'] ?? '';
    final company = contact['companyName'] ?? '';
    final stageColor = _stageColor(stage);

    return Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 24, backgroundColor: stageColor.withValues(alpha: 0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: stageColor, fontWeight: FontWeight.w700, fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (company.isNotEmpty) Text('$company', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (stage != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_stageLabel(stage), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stageColor)),
                ),
              ],
            ])),
            Row(children: [
              GestureDetector(onTap: _showLogActivity, child: Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary))),
              GestureDetector(onTap: _load, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary))),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (phone.isNotEmpty) Expanded(child: _infoChip(Icons.phone_rounded, phone, AppColors.success)),
            if (phone.isNotEmpty && email.isNotEmpty) const SizedBox(width: 6),
            if (email.isNotEmpty) Expanded(child: _infoChip(Icons.email_rounded, email, AppColors.accent)),
            if (source.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                child: Text('$source', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          // Tabs
          Row(children: ['Timeline', 'Deals', 'Follow-ups'].asMap().entries.map((e) {
            final selected = _tab == e.key;
            final counts = [_activities.length, _deals.length, _followUps.length];
            return GestureDetector(
              onTap: () => setState(() => _tab = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${e.value} (${counts[e.key]})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList()),
        ]),
      ),
      Expanded(child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _tab == 0 ? _timelineTab() : _tab == 1 ? _dealsTab() : _followUpsTab(),
      )),
    ]);
  }

  Widget _infoChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _timelineTab() {
    if (_activities.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No activities yet', style: TextStyle(color: AppColors.textHint)),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: _showLogActivity, icon: const Icon(Icons.add_rounded), label: const Text('Log Activity')),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (_, i) {
        final a = _activities[i];
        final type = a['type'] as String?;
        final title = a['title'] ?? a['subject'] ?? type ?? 'Activity';
        final notes = a['notes'] ?? '';
        final date = a['createdAt'] as String?;
        String dateStr = '';
        if (date != null) { try { final dt = DateTime.parse(date).toLocal(); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
        final color = type == 'CALL' ? AppColors.primary : type == 'EMAIL' ? AppColors.accent : type == 'MEETING' ? AppColors.success : AppColors.textSecondary;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_activityIcon(type), size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('$title', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              if (notes.toString().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('$notes', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
          ]),
        );
      },
    );
  }

  Widget _dealsTab() {
    if (_deals.isEmpty) return const Center(child: Text('No deals linked', style: TextStyle(color: AppColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      itemBuilder: (_, i) {
        final d = _deals[i];
        final status = d['status'] as String?;
        final value = ((d['expectedValue'] ?? d['value']) as num?)?.toDouble();
        final stageName = d['stage']?['name'] ?? d['stageName'] ?? '';
        final color = status == 'WON' ? AppColors.success : status == 'LOST' ? AppColors.error : AppColors.primary;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.handshake_rounded, size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (stageName.isNotEmpty) Text(stageName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (status != null) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
              if (value != null) Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _followUpsTab() {
    if (_followUps.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No follow-ups scheduled', style: TextStyle(color: AppColors.textHint)),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: _showScheduleFollowUp, icon: const Icon(Icons.add_rounded), label: const Text('Schedule Follow-up')),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followUps.length,
      itemBuilder: (_, i) {
        final f = _followUps[i];
        final type = f['type'] ?? '';
        final status = f['status'] ?? 'PENDING';
        final scheduled = f['scheduledAt'] as String?;
        final notes = f['notes'] ?? '';
        String dateStr = '';
        if (scheduled != null) { try { final dt = DateTime.parse(scheduled).toLocal(); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
        final isDone = status == 'COMPLETED' || status == 'DONE';
        final color = isDone ? AppColors.success : AppColors.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isDone ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('$type Follow-up', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              if (notes.toString().isNotEmpty) Text('$notes', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
            ])),
            if (!isDone)
              GestureDetector(
                onTap: () async {
                  try { await _api.completeCrmFollowUp(f['id'].toString(), outcome: 'Done'); _msg('Follow-up completed'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
                },
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check_rounded, size: 16, color: AppColors.success)),
              ),
          ]),
        );
      },
    );
  }
}
