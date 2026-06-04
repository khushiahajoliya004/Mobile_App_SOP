import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class PermissionListScreen extends StatefulWidget {
  const PermissionListScreen({super.key});
  @override
  State<PermissionListScreen> createState() => _PermissionListScreenState();
}

class _PermissionListScreenState extends State<PermissionListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _operations = [];
  String _search = '';
  String? _filterModuleId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await Future.wait([_loadPermissions(), _loadModules(), _loadOperations()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPermissions() async {
    try {
      final res = await _api.getPermissions();
      _permissions = _parseList(res.data);
    } catch (_) { _permissions = []; }
  }

  Future<void> _loadModules() async {
    try {
      final res = await _api.getModules();
      _modules = _parseList(res.data);
    } catch (_) { _modules = []; }
  }

  Future<void> _loadOperations() async {
    try {
      final res = await _api.getOperations();
      _operations = _parseList(res.data);
    } catch (_) { _operations = []; }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _permissions;
    if (_filterModuleId != null) {
      list = list.where((p) => p['module']?['id'] == _filterModuleId).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
        '${p['name'] ?? ''}'.toLowerCase().contains(q) ||
        '${p['code'] ?? ''}'.toLowerCase().contains(q) ||
        '${p['module']?['name'] ?? ''}'.toLowerCase().contains(q)
      ).toList();
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
    String? selectedModuleId = existing?['module']?['id'];
    String? selectedOperationId = existing?['operation']?['id'];

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
                  Expanded(child: Text(isEdit ? 'Edit Permission' : 'New Permission', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: 'Permission Name *',
                    filled: true, fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Module *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedModuleId,
                      isExpanded: true,
                      hint: const Text('Select module', style: TextStyle(fontSize: 14)),
                      items: _modules.map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text('${m['name']}', style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => setSheet(() => selectedModuleId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Operation *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedOperationId,
                      isExpanded: true,
                      hint: const Text('Select operation', style: TextStyle(fontSize: 14)),
                      items: _operations.map((o) => DropdownMenuItem<String>(value: o['id'] as String, child: Text('${o['name']}', style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => setSheet(() => selectedOperationId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _save(ctx, isEdit: isEdit, id: existing?['id'], name: name.text, moduleId: selectedModuleId, operationId: selectedOperationId),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEdit ? 'Update Permission' : 'Create Permission'),
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

  Future<void> _save(BuildContext ctx, {required bool isEdit, String? id, required String name, String? moduleId, String? operationId}) async {
    if (name.trim().isEmpty) { _msg('Name is required', error: true); return; }
    if (moduleId == null) { _msg('Select a module', error: true); return; }
    if (operationId == null) { _msg('Select an operation', error: true); return; }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        await _api.updatePermission(id, {'name': name.trim(), 'moduleId': moduleId, 'operationId': operationId});
        _msg('Permission updated');
      } else {
        await _api.createPermission(name: name.trim(), moduleId: moduleId, operationId: operationId);
        _msg('Permission created');
      }
      await _loadPermissions();
      if (mounted) setState(() => _loading = false);
    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
  }

  void _confirmDelete(Map<String, dynamic> perm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Permission', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${perm['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deletePermission(perm['id']); _msg('Permission deleted'); _loadPermissions(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(Map<String, dynamic> perm) async {
    final isActive = perm['status'] == 'ACTIVE';
    try {
      await _api.updatePermissionStatus(perm['id'], isActive ? 'INACTIVE' : 'ACTIVE');
      _msg('Status updated');
      _loadPermissions();
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
                hintText: 'Search permissions...',
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
      // Module filter chips
      if (_modules.isNotEmpty)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('All', null),
              ..._modules.map((m) => _filterChip('${m['name']}', m['id'] as String)),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_filtered.length} permissions', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _init, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
            ? const Center(child: Text('No permissions found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _init,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _tile(_filtered[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _filterChip(String label, String? moduleId) {
    final selected = _filterModuleId == moduleId;
    return GestureDetector(
      onTap: () => setState(() => _filterModuleId = moduleId),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> perm) {
    final isActive = perm['status'] == 'ACTIVE';
    final moduleName = perm['module']?['name'] ?? '';
    final operationName = perm['operation']?['name'] ?? '';
    final code = perm['code'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: isActive ? AppColors.primarySurface : AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.key_rounded, color: isActive ? AppColors.primary : AppColors.textHint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${perm['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (code.isNotEmpty) Text(code, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace')),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${perm['status'] ?? ''}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.error)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          if (moduleName.isNotEmpty) _badge(moduleName, AppColors.primary),
          if (operationName.isNotEmpty) _badge(operationName, AppColors.accent),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: perm)),
          const SizedBox(width: 8),
          _actionBtn(isActive ? Icons.block_rounded : Icons.check_circle_outline, isActive ? AppColors.warning : AppColors.success, () => _toggleStatus(perm)),
          const SizedBox(width: 8),
          _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(perm)),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
