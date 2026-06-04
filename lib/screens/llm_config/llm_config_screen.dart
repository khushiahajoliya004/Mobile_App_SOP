import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class LlmConfigScreen extends StatefulWidget {
  const LlmConfigScreen({super.key});
  @override
  State<LlmConfigScreen> createState() => _LlmConfigScreenState();
}

class _LlmConfigScreenState extends State<LlmConfigScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  bool _loading = true;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _companies = [];
  String _search = '';
  String? _filterStage;

  static const _stages = ['EVALUATION', 'PARTICIPANT_EXTRACTION', 'CALL_SUMMARY', 'MANAGER_REVIEW', 'GENERIC'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getLlmTemplates(stage: _filterStage);
      _templates = _parseList(res.data);
    } catch (_) { _templates = []; }
    try {
      final res = await _api.getCompanies();
      _companies = _parseList(res.data);
    } catch (_) { _companies = []; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _templates;
    if (_filterStage != null) list = list.where((t) => t['stage'] == _filterStage).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) => '${t['name'] ?? ''}'.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name'] ?? '');
    final promptTemplate = TextEditingController(text: existing?['promptTemplate'] ?? '');
    final description = TextEditingController(text: existing?['description'] ?? '');
    final maxTokens = TextEditingController(text: existing?['maxTokens']?.toString() ?? '4096');
    String? selectedStage = existing?['stage'] ?? _stages.first;
    String? selectedCompanyId = existing?['companyId'];

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
                  Expanded(child: Text(isEdit ? 'Edit Template' : 'New Template', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                _field(name, 'Template Name *'),
                const SizedBox(height: 10),
                _field(description, 'Description'),
                const SizedBox(height: 10),
                const Text('Stage *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStage,
                      isExpanded: true,
                      items: _stages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => setSheet(() => selectedStage = v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Company (leave empty for global)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCompanyId,
                      isExpanded: true,
                      hint: const Text('Global (all companies)', style: TextStyle(fontSize: 14)),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Global (all companies)', style: TextStyle(fontSize: 14))),
                        ..._companies.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text('${c['name']}', style: const TextStyle(fontSize: 14)))),
                      ],
                      onChanged: (v) => setSheet(() => selectedCompanyId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: promptTemplate,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Prompt Template *',
                    alignLabelWithHint: true,
                    filled: true, fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                _field(maxTokens, 'Max Tokens', type: TextInputType.number),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _save(ctx, isEdit: isEdit, id: existing?['id'], name: name.text, description: description.text, promptTemplate: promptTemplate.text, stage: selectedStage, companyId: selectedCompanyId, maxTokens: maxTokens.text),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEdit ? 'Update Template' : 'Create Template'),
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

  Future<void> _save(BuildContext ctx, {required bool isEdit, String? id, required String name, required String description, required String promptTemplate, String? stage, String? companyId, required String maxTokens}) async {
    if (name.trim().isEmpty || promptTemplate.trim().isEmpty) { _msg('Name and prompt template are required', error: true); return; }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      final data = {
        'name': name.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'promptTemplate': promptTemplate.trim(),
        if (stage != null) 'stage': stage,
        if (companyId != null) 'companyId': companyId,
        'maxTokens': int.tryParse(maxTokens) ?? 4096,
        'isActive': true,
      };
      if (isEdit && id != null) {
        await _api.updateLlmTemplate(id, data);
        _msg('Template updated');
      } else {
        await _api.createLlmTemplate(data);
        _msg('Template created');
      }
      _load();
    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
  }

  void _confirmDelete(Map<String, dynamic> t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${t['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deleteLlmTemplate(t['id']); _msg('Deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Templates'), Tab(text: 'Stage Info')],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tab, children: [
          _templatesTab(),
          _stagesTab(),
        ]),
      ),
    ]);
  }

  Widget _templatesTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search templates...',
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
            onTap: () => _showForm(),
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
            _stageChip('All', null),
            ..._stages.map((s) => _stageChip(s, s)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
            ? const Center(child: Text('No templates found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _templateTile(_filtered[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _stageChip(String label, String? stage) {
    final selected = _filterStage == stage;
    return GestureDetector(
      onTap: () => setState(() => _filterStage = stage),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _templateTile(Map<String, dynamic> t) {
    final isActive = t['isActive'] == true;
    final companyName = t['company']?['name'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (companyName != null) Text(companyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          if (t['stage'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${t['stage']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ]),
        if (t['description'] != null && '${t['description']}'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${t['description']}', style: const TextStyle(fontSize: 11, color: AppColors.textHint), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: t)),
          const SizedBox(width: 8),
          _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(t)),
        ]),
      ]),
    );
  }

  Widget _stagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _stages.map((stage) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stage, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(_stageDescription(stage), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
        ]),
      )).toList(),
    );
  }

  String _stageDescription(String stage) {
    switch (stage) {
      case 'EVALUATION': return 'Evaluate call quality against SOP';
      case 'PARTICIPANT_EXTRACTION': return 'Extract participants from call';
      case 'CALL_SUMMARY': return 'Generate call summary';
      case 'MANAGER_REVIEW': return 'Manager review report generation';
      case 'GENERIC': return 'Generic prompt stage';
      default: return '';
    }
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
