import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class PromptSettingsScreen extends StatefulWidget {
  const PromptSettingsScreen({super.key});
  @override
  State<PromptSettingsScreen> createState() => _PromptSettingsScreenState();
}

class _PromptSettingsScreenState extends State<PromptSettingsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _masterPrompt;
  List<Map<String, dynamic>> _stageTemplates = [];

  final _masterName = TextEditingController();
  final _masterDescription = TextEditingController();
  final _masterPromptCtrl = TextEditingController();

  static const _stages = ['EVALUATION', 'PARTICIPANT_EXTRACTION', 'CALL_SUMMARY', 'MANAGER_REVIEW'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _masterName.dispose();
    _masterDescription.dispose();
    _masterPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getMyPrompt();
      final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
      if (data is Map) {
        _masterPrompt = Map<String, dynamic>.from(data);
        _masterName.text = _masterPrompt?['name'] ?? '';
        _masterDescription.text = _masterPrompt?['description'] ?? '';
        _masterPromptCtrl.text = _masterPrompt?['promptTemplate'] ?? '';
      }
    } catch (_) {}
    try {
      final res = await _api.getLlmTemplates();
      final raw = res.data;
      _stageTemplates = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _stageTemplates = []; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveMasterPrompt() async {
    if (_masterPromptCtrl.text.trim().isEmpty) {
      _msg('Prompt template is required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.updateMyPrompt({
        'name': _masterName.text.trim().isNotEmpty ? _masterName.text.trim() : 'Company Prompt',
        if (_masterDescription.text.trim().isNotEmpty) 'description': _masterDescription.text.trim(),
        'promptTemplate': _masterPromptCtrl.text.trim(),
      });
      _msg('Master prompt saved');
    } catch (e) { _msg('Failed: $e', error: true); }
    if (mounted) setState(() => _saving = false);
  }

  void _showNewStageTemplate() {
    String? selectedStage = _stages.first;
    final promptCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final maxTokensCtrl = TextEditingController(text: '8000');

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
                  const Expanded(child: Text('New Stage Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
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
                _field(nameCtrl, 'Template Name (optional)'),
                const SizedBox(height: 10),
                TextField(
                  controller: promptCtrl,
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
                _field(maxTokensCtrl, 'Max Tokens', type: TextInputType.number),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (promptCtrl.text.trim().isEmpty) { _msg('Prompt template is required', error: true); return; }
                      Navigator.pop(ctx);
                      try {
                        await _api.createLlmTemplate({
                          'stage': selectedStage,
                          'name': nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : '$selectedStage Template',
                          'promptTemplate': promptCtrl.text.trim(),
                          'maxTokens': int.tryParse(maxTokensCtrl.text) ?? 8000,
                          'temperature': 0,
                          'variables': ['transcript', 'evaluationJson'],
                          'isActive': true,
                        });
                        _msg('Stage template created');
                        _load();
                      } catch (e) { _msg('Failed: $e', error: true); }
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Create Template'),
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

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
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
          tabs: const [Tab(text: 'Master Prompt'), Tab(text: 'Stage Templates')],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(controller: _tab, children: [
                _masterPromptTab(),
                _stageTemplatesTab(),
              ]),
      ),
    ]);
  }

  Widget _masterPromptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Master Prompt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('This prompt is used as the company-level base for call evaluations.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _field(_masterName, 'Name'),
        const SizedBox(height: 10),
        _field(_masterDescription, 'Description'),
        const SizedBox(height: 10),
        TextField(
          controller: _masterPromptCtrl,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: 'Prompt Template *',
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
            onPressed: _saving ? null : _saveMasterPrompt,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Master Prompt'),
          ),
        ),
      ]),
    );
  }

  Widget _stageTemplatesTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          const Expanded(child: Text('Stage Templates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: _showNewStageTemplate,
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      Expanded(
        child: _stageTemplates.isEmpty
            ? const Center(child: Text('No stage templates yet', style: TextStyle(color: AppColors.textHint)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stageTemplates.length,
                itemBuilder: (_, i) {
                  final t = _stageTemplates[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        if (t['stage'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('${t['stage']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                      ]),
                      if (t['promptTemplate'] != null) ...[
                        const SizedBox(height: 4),
                        Text('${t['promptTemplate']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
