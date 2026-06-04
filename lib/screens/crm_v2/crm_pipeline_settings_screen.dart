import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmPipelineSettingsScreen extends StatefulWidget {
  const CrmPipelineSettingsScreen({super.key});
  @override
  State<CrmPipelineSettingsScreen> createState() => _CrmPipelineSettingsScreenState();
}

class _CrmPipelineSettingsScreenState extends State<CrmPipelineSettingsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _pipelines = [];
  String? _expandedPipelineId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      _pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _pipelines = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showCreatePipeline() {
    final nameCtrl = TextEditingController();
    bool isDefault = false;
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
                const Expanded(child: Text('New Pipeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Pipeline Name *',
                  filled: true, fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
                child: Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Set as Default', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('New deals will use this pipeline by default', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  Switch(value: isDefault, activeColor: AppColors.primary, onChanged: (v) => setSheet(() => isDefault = v)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) { _msg('Name is required', error: true); return; }
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await _api.createCrmPipeline(name: nameCtrl.text.trim(), isDefault: isDefault);
                      _msg('Pipeline created');
                      _load();
                    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
                  },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Create Pipeline'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStage(String pipelineId) {
    final nameCtrl = TextEditingController();
    final slaDaysCtrl = TextEditingController();
    String selectedType = 'OPEN';
    const types = ['OPEN', 'WON', 'LOST'];
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
                const Expanded(child: Text('Add Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Stage Name *',
                  filled: true, fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Stage Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(children: types.map((t) {
                final selected = selectedType == t;
                Color c = t == 'WON' ? AppColors.success : t == 'LOST' ? AppColors.error : AppColors.primary;
                return GestureDetector(
                  onTap: () => setSheet(() => selectedType = t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: selected ? c : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 10),
              TextField(
                controller: slaDaysCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'SLA Days (optional)',
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
                    if (nameCtrl.text.trim().isEmpty) { _msg('Stage name is required', error: true); return; }
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await _api.addCrmPipelineStage(
                        pipelineId,
                        name: nameCtrl.text.trim(),
                        type: selectedType,
                        slaDays: int.tryParse(slaDaysCtrl.text),
                      );
                      _msg('Stage added');
                      _load();
                    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
                  },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Add Stage'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Color _stageTypeColor(String? type) {
    switch (type) {
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
          const Expanded(child: Text('Pipeline Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 18, color: AppColors.primary)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showCreatePipeline,
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 20)),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _pipelines.isEmpty
            ? const Center(child: Text('No pipelines found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pipelines.length,
                  itemBuilder: (_, i) => _pipelineTile(_pipelines[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _pipelineTile(Map<String, dynamic> pipeline) {
    final id = pipeline['id'] as String;
    final name = pipeline['name'] ?? 'Pipeline';
    final isDefault = pipeline['isDefault'] == true;
    final stages = (pipeline['stages'] as List?)?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
    final isExpanded = _expandedPipelineId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expandedPipelineId = isExpanded ? null : id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('$name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (isDefault) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                      child: const Text('DEFAULT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ]),
                Text('${stages.length} stages', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
            ]),
          ),
        ),
        if (isExpanded) ...[
          const Divider(height: 1, color: AppColors.surfaceLight),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Stages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                GestureDetector(
                  onTap: () => _showAddStage(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Add Stage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              if (stages.isEmpty)
                const Text('No stages yet', style: TextStyle(fontSize: 12, color: AppColors.textHint))
              else
                ...stages.asMap().entries.map((e) {
                  final s = e.value;
                  final stageName = s['name'] ?? '';
                  final stageType = s['type'] as String?;
                  final slaDays = s['slaDays'];
                  final color = _stageTypeColor(stageType);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$stageName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      if (slaDays != null) Text('${slaDays}d SLA', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                      const SizedBox(width: 8),
                      if (stageType != null && stageType != 'OPEN')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(stageType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                        ),
                    ]),
                  );
                }),
            ]),
          ),
        ],
      ]),
    );
  }
}
