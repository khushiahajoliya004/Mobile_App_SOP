import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_deal_detail_screen.dart';

class CrmDealsScreen extends StatefulWidget {
  const CrmDealsScreen({super.key});
  @override
  State<CrmDealsScreen> createState() => _CrmDealsScreenState();
}

class _CrmDealsScreenState extends State<CrmDealsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _deals = [];
  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _contacts = [];
  String? _selectedPipelineId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      _pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (_pipelines.isNotEmpty && _selectedPipelineId == null) {
        _selectedPipelineId = _pipelines.first['id'] as String?;
      }
    } catch (_) {}
    try {
      final res = await _api.getCrmContacts();
      final raw = res.data;
      _contacts = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmDeals(
        pipelineId: _selectedPipelineId,
        search: _search.isNotEmpty ? _search : null,
      );
      final raw = res.data;
      _deals = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _deals = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  List<Map<String, dynamic>> get _currentPipelineStages {
    if (_selectedPipelineId == null) return [];
    try {
      final pipeline = _pipelines.firstWhere((p) => p['id'] == _selectedPipelineId);
      final stages = pipeline['stages'];
      if (stages is List) return stages.map((s) => Map<String, dynamic>.from(s)).toList();
    } catch (_) {}
    return [];
  }

  void _showCreateForm() {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String? selectedContactId;
    String? selectedPipelineId = _selectedPipelineId;
    String? selectedStageId;

    List<Map<String, dynamic>> stages = [];
    if (selectedPipelineId != null) {
      try {
        final p = _pipelines.firstWhere((p) => p['id'] == selectedPipelineId);
        final s = p['stages'];
        if (s is List) {
          stages = s.map((e) => Map<String, dynamic>.from(e)).toList();
          if (stages.isNotEmpty) selectedStageId = stages.first['id'] as String?;
        }
      } catch (_) {}
    }

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
                  const Expanded(child: Text('New Deal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                _field(nameCtrl, 'Deal Name *'),
                const SizedBox(height: 10),
                _field(valueCtrl, 'Deal Value', type: TextInputType.number),
                const SizedBox(height: 10),
                const Text('Contact *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedContactId, 'Select contact', [
                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 14))),
                  ..._contacts.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text('${c['name']}', style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedContactId = v)),
                const SizedBox(height: 10),
                const Text('Pipeline *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedPipelineId, 'Select pipeline', [
                  ..._pipelines.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text('${p['name']}', style: const TextStyle(fontSize: 14)))),
                ], (v) {
                  setSheet(() {
                    selectedPipelineId = v;
                    selectedStageId = null;
                    stages = [];
                    if (v != null) {
                      try {
                        final p = _pipelines.firstWhere((p) => p['id'] == v);
                        final s = p['stages'];
                        if (s is List) {
                          stages = s.map((e) => Map<String, dynamic>.from(e)).toList();
                          if (stages.isNotEmpty) selectedStageId = stages.first['id'] as String?;
                        }
                      } catch (_) {}
                    }
                  });
                }),
                if (stages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Stage *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  _dropdown<String>(selectedStageId, 'Select stage', [
                    ...stages.map((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text('${s['name']}', style: const TextStyle(fontSize: 14)))),
                  ], (v) => setSheet(() => selectedStageId = v)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) { _msg('Deal name is required', error: true); return; }
                      if (selectedContactId == null) { _msg('Contact is required', error: true); return; }
                      if (selectedPipelineId == null || selectedStageId == null) { _msg('Pipeline and stage are required', error: true); return; }
                      Navigator.pop(ctx);
                      setState(() => _loading = true);
                      try {
                        await _api.createCrmDeal(
                          name: nameCtrl.text.trim(),
                          contactId: selectedContactId!,
                          pipelineId: selectedPipelineId!,
                          stageId: selectedStageId!,
                          expectedValue: double.tryParse(valueCtrl.text),
                        );
                        _msg('Deal created');
                        _load();
                      } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Create Deal'),
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

  void _showMoveStage(Map<String, dynamic> deal) {
    final stages = _currentPipelineStages;
    if (stages.isEmpty) { _msg('No stages available', error: true); return; }
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
            const SizedBox(height: 12),
            ...stages.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['name']}', style: const TextStyle(fontSize: 14)),
              trailing: deal['stageId'] == s['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _api.moveCrmDealStage(deal['id'] as String, s['id'] as String);
                  _msg('Stage updated');
                  _load();
                } catch (e) { _msg('Failed: $e', error: true); }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showDealActions(Map<String, dynamic> deal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${deal['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _actionTile(ctx, Icons.swap_horiz_rounded, 'Move Stage', AppColors.primary, () => _showMoveStage(deal)),
            _actionTile(ctx, Icons.check_circle_outline_rounded, 'Mark Won', AppColors.success, () async {
              try { await _api.markDealWon(deal['id'] as String); _msg('Deal marked as won'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            }),
            _actionTile(ctx, Icons.cancel_outlined, 'Mark Lost', AppColors.error, () {
              Navigator.pop(ctx);
              _showMarkLost(deal);
            }),
            _actionTile(ctx, Icons.delete_outline, 'Delete Deal', AppColors.error, () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (d) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Delete Deal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  content: Text('Delete "${deal['name']}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(d);
                        try { await _api.deleteCrmDeal(deal['id'] as String); _msg('Deal deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      onTap: () { Navigator.pop(ctx); onTap(); },
    );
  }

  void _showMarkLost(Map<String, dynamic> deal) {
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
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Lost Reason (optional)',
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
                    await _api.markDealLost(deal['id'] as String, lostReason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null);
                    _msg('Deal marked as lost');
                    _load();
                  } catch (e) { _msg('Failed: $e', error: true); }
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'WON': return AppColors.success;
      case 'LOST': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) { _search = v; _load(); },
              decoration: InputDecoration(
                hintText: 'Search deals...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showCreateForm,
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      if (_pipelines.isNotEmpty)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _pipelines.map((p) {
              final selected = _selectedPipelineId == p['id'];
              return GestureDetector(
                onTap: () { setState(() => _selectedPipelineId = p['id'] as String?); _load(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${p['name']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_deals.length} deals', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _deals.isEmpty
            ? const Center(child: Text('No deals found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _deals.length,
                  itemBuilder: (_, i) => _dealTile(_deals[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _dealTile(Map<String, dynamic> deal) {
    final name = '${deal['name'] ?? ''}';
    final status = deal['status'] as String?;
    final value = (deal['expectedValue'] ?? deal['value'] as num?)?.toDouble();
    final contactName = deal['contact']?['name'] ?? deal['contactName'] ?? '';
    final stageName = deal['stage']?['name'] ?? deal['stageName'] ?? '';
    final statusColor = _statusColor(status);
    return GestureDetector(
      onTap: () => _showDealActions(deal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(
                status == 'WON' ? Icons.emoji_events_rounded : status == 'LOST' ? Icons.cancel_rounded : Icons.handshake_rounded,
                color: statusColor, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (contactName.isNotEmpty) Text(contactName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (status != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ),
              if (value != null) ...[
                const SizedBox(height: 4),
                Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              ],
            ]),
          ]),
          if (stageName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: Text(stageName, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CrmDealDetailScreen(dealId: deal['id'].toString(), dealName: name))),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary), SizedBox(width: 4), Text('Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary))])),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDealActions(deal),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.more_horiz_rounded, size: 14, color: AppColors.textSecondary), SizedBox(width: 4), Text('Manage', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))])),
            ),
          ]),
        ]),
      ),
    );
  }
}
