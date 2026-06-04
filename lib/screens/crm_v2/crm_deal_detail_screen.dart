import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmDealDetailScreen extends StatefulWidget {
  final String dealId;
  final String dealName;
  const CrmDealDetailScreen({super.key, required this.dealId, required this.dealName});
  @override
  State<CrmDealDetailScreen> createState() => _CrmDealDetailScreenState();
}

class _CrmDealDetailScreenState extends State<CrmDealDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _deal;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _stageHistory = [];
  List<Map<String, dynamic>> _pipelineStages = [];
  int _tab = 0; // 0=Timeline, 1=Follow-ups, 2=Stage History

  static const _activityTypes = ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmDeal(widget.dealId);
      final raw = res.data;
      _deal = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
      // Load pipeline stages
      final pipelineId = _deal?['pipelineId'] as String?;
      if (pipelineId != null) {
        final pRes = await _api.getCrmPipeline(pipelineId);
        final pRaw = pRes.data;
        final pData = pRaw is Map ? pRaw['data'] ?? pRaw : {};
        final stages = pData['stages'];
        if (stages is List) _pipelineStages = stages.map((s) => Map<String, dynamic>.from(s)).toList();
      }
    } catch (_) {}
    final contactId = _deal?['contactId'] as String?;
    if (contactId != null) {
      try {
        final res = await _api.getCrmActivities(contactId: contactId, limit: 50);
        final raw = res.data;
        _activities = raw is List ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
            : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) { _activities = []; }
    }
    try {
      final res = await _api.getCrmFollowUpsByDeal(widget.dealId);
      final raw = res.data;
      _followUps = raw is List ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _followUps = []; }
    try {
      final res = await _api.getCrmActivities(dealId: widget.dealId, limit: 30);
      final raw = res.data;
      _stageHistory = (raw is List ? raw : ((raw is Map ? (raw['data'] ?? []) : []) as List))
          .map((e) => Map<String, dynamic>.from(e))
          .where((a) => a['type'] == 'STAGE_CHANGE' || a['type'] == 'stage_change')
          .toList();
    } catch (_) { _stageHistory = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showMoveStage() {
    if (_pipelineStages.isEmpty) { _msg('No stages available', error: true); return; }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Move to Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            ..._pipelineStages.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['name']}', style: const TextStyle(fontSize: 14)),
              trailing: _deal?['stageId'] == s['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                try { await _api.moveCrmDealStage(widget.dealId, s['id'].toString()); _msg('Stage updated'); _load(); }
                catch (e) { _msg('Failed: $e', error: true); }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showMarkLost() {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Mark as Lost', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl, maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Lost Reason (optional)', alignLabelWithHint: true,
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
                  try { await _api.markDealLost(widget.dealId, lostReason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null); _msg('Deal marked as lost'); _load(); }
                  catch (e) { _msg('Failed: $e', error: true); }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Mark as Lost'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLogActivity() {
    String selectedType = _activityTypes.first;
    final notesCtrl = TextEditingController();
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
              _dropdown<String>(selectedType, 'Type', [
                ..._activityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
              ], (v) => setSheet(() => selectedType = v ?? _activityTypes.first)),
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
                      await _api.createCrmActivityLog(type: selectedType, dealId: widget.dealId, notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null);
                      _msg('Activity logged'); _load();
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

  Widget _dropdown<T>(T value, String hint, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 14)), items: items, onChanged: onChanged)),
  );

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'CALL': return Icons.phone_rounded;
      case 'EMAIL': return Icons.email_rounded;
      case 'MEETING': return Icons.groups_rounded;
      case 'TASK': return Icons.task_alt_rounded;
      default: return Icons.notes_rounded;
    }
  }

  Color _activityColor(String? type) {
    switch (type) {
      case 'CALL': return AppColors.primary;
      case 'EMAIL': return AppColors.accent;
      case 'MEETING': return AppColors.success;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final deal = _deal ?? {};
    final name = deal['name'] ?? widget.dealName;
    final status = deal['status'] as String?;
    final value = ((deal['expectedValue'] ?? deal['value']) as num?)?.toDouble();
    final contactName = deal['contact']?['name'] ?? deal['contactName'] ?? '';
    final contactPhone = deal['contact']?['phone'] ?? '';
    final stageName = deal['stage']?['name'] ?? deal['stageName'] ?? '';
    final currentStageId = deal['stageId'] as String?;
    final statusColor = status == 'WON' ? AppColors.success : status == 'LOST' ? AppColors.error : AppColors.primary;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(status == 'WON' ? Icons.emoji_events_rounded : status == 'LOST' ? Icons.cancel_rounded : Icons.handshake_rounded, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (contactName.isNotEmpty) Text('$contactName${contactPhone.isNotEmpty ? ' • $contactPhone' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (status != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor))),
              if (value != null) Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success)),
            ]),
          ]),
          if (stageName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: Text('Stage: $stageName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          ],
          if (_pipelineStages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _pipelineStages.map((s) {
                  final isActive = s['id'] == currentStageId;
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: isActive ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)),
                    child: Text('${s['name']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary)),
                  );
                }).toList(),
              ),
            ),
          ],
          if (status == 'OPEN') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _actionBtn(Icons.swap_horiz_rounded, 'Move Stage', AppColors.primary, _showMoveStage)),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.check_circle_outline_rounded, 'Won', AppColors.success, () async {
                try { await _api.markDealWon(widget.dealId); _msg('Deal marked as won'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
              })),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.cancel_outlined, 'Lost', AppColors.error, _showMarkLost)),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: ['Timeline', 'Follow-ups', 'Stage History'].asMap().entries.map((e) {
            final selected = _tab == e.key;
            final counts = [_activities.length, _followUps.length, _stageHistory.length];
            return GestureDetector(
              onTap: () => setState(() => _tab = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)),
                child: Text('${e.value} (${counts[e.key]})', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList()),
        ]),
      ),
      Expanded(child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _tab == 0 ? _timelineTab() : _tab == 1 ? _followUpsTab() : _stageHistoryTab(),
      )),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
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
        final notes = a['notes'] ?? '';
        final date = a['createdAt'] as String?;
        String dateStr = '';
        if (date != null) { try { final dt = DateTime.parse(date).toLocal(); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
        final color = _activityColor(type);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_activityIcon(type), size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(type ?? 'Activity', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
                const Spacer(),
                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              if (notes.toString().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('$notes', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
          ]),
        );
      },
    );
  }

  Widget _followUpsTab() {
    if (_followUps.isEmpty) return const Center(child: Text('No follow-ups scheduled', style: TextStyle(color: AppColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followUps.length,
      itemBuilder: (_, i) {
        final f = _followUps[i];
        final type = f['type'] ?? '';
        final status = f['status'] ?? 'PENDING';
        final scheduled = f['scheduledAt'] as String?;
        String dateStr = '';
        if (scheduled != null) { try { final dt = DateTime.parse(scheduled).toLocal(); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
        final isDone = status == 'COMPLETED';
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
                Text('$type Follow-up', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
            ])),
            if (!isDone)
              GestureDetector(
                onTap: () async {
                  try { await _api.completeCrmFollowUp(f['id'].toString(), outcome: 'Done'); _msg('Completed'); _load(); }
                  catch (e) { _msg('Failed: $e', error: true); }
                },
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check_rounded, size: 16, color: AppColors.success)),
              ),
          ]),
        );
      },
    );
  }

  Widget _stageHistoryTab() {
    if (_stageHistory.isEmpty) return const Center(child: Text('No stage changes recorded', style: TextStyle(color: AppColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stageHistory.length,
      itemBuilder: (_, i) {
        final s = _stageHistory[i];
        final notes = s['notes'] ?? '';
        final date = s['createdAt'] as String?;
        String dateStr = '';
        if (date != null) { try { final dt = DateTime.parse(date).toLocal(); dateStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Stage Changed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              if (notes.toString().isNotEmpty) Text('$notes', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
          ]),
        );
      },
    );
  }
}
