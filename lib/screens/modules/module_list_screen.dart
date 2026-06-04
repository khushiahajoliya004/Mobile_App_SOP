import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class ModuleListScreen extends StatefulWidget {
  const ModuleListScreen({super.key});
  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _modules = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getModules();
      _modules = _parseList(res.data);
    } catch (_) {
      _modules = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _modules;
    final q = _search.toLowerCase();
    return _modules.where((m) =>
      '${m['name'] ?? ''}'.toLowerCase().contains(q) ||
      '${m['code'] ?? ''}'.toLowerCase().contains(q)
    ).toList();
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _toggleStatus(Map<String, dynamic> module) async {
    final isActive = module['status'] == 'ACTIVE';
    try {
      await _api.updateModuleStatus(module['id'], isActive ? 'INACTIVE' : 'ACTIVE');
      _msg('Status updated');
      _load();
    } catch (e) { _msg('Failed: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search modules...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: _load, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, color: AppColors.primary, size: 20))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text('${_filtered.length} modules', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
            ? const Center(child: Text('No modules found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _tile(_filtered[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _tile(Map<String, dynamic> module) {
    final isActive = module['status'] == 'ACTIVE';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: isActive ? AppColors.primarySurface : AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.extension_rounded, color: isActive ? AppColors.primary : AppColors.textHint, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${module['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('${module['code'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
          if (module['description'] != null && '${module['description']}'.isNotEmpty)
            Text('${module['description']}', style: const TextStyle(fontSize: 11, color: AppColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${module['status'] ?? ''}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.error)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _toggleStatus(module),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: (isActive ? AppColors.warning : AppColors.success).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline, size: 16, color: isActive ? AppColors.warning : AppColors.success),
            ),
          ),
        ]),
      ]),
    );
  }
}
