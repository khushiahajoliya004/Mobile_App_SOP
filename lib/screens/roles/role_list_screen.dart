import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _roles = [];
  String _search = '';
  String _companyId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    _companyId = user?.companyId ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getRoles();
      _roles = _p(res.data);
    } catch (_) {
      _roles = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _p(dynamic raw) {
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map)
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _roles;
    final q = _search.toLowerCase();
    return _roles
        .where((r) => '${r['name'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  int _permCount(Map<String, dynamic> role) =>
      ((role['permissions'] ?? []) as List).length;

  Future<void> _toggleStatus(Map<String, dynamic> role) async {
    final newStatus = role['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await _api.genericPatch('/roles/${role['id']}/status/$newStatus', {});
      _msg('Status updated');
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
  }

  void _confirmDelete(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Role',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${role['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteRole(role['id']);
                _msg('Deleted');
                _load();
              } catch (e) {
                _msg('Failed: $e', error: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(
      text: existing?['description'] ?? '',
    );

    // Load permissions grouped by module
    List<Map<String, dynamic>> allPerms = [];
    try {
      final res = await _api.getPermissions();
      allPerms = _p(res.data);
    } catch (_) {}

    // Group by module
    final moduleMap = <String, List<Map<String, dynamic>>>{};
    for (final p in allPerms) {
      final modName = p['module']?['name'] ?? 'Other';
      moduleMap.putIfAbsent(modName, () => []);
      moduleMap[modName]!.add(p);
    }

    // Pre-select existing permissions
    final selectedIds = <String>{};
    if (existing != null) {
      for (final p in (existing['permissions'] ?? []) as List) {
        selectedIds.add(p['id'] ?? '');
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoleFormScreen(
          isEdit: isEdit,
          nameCtrl: nameCtrl,
          descCtrl: descCtrl,
          moduleMap: moduleMap,
          selectedIds: selectedIds,
          onSave: (name, desc, permIds) async {
            try {
              if (isEdit) {
                await _api.updateRole(
                  existing['id'],
                  name: name,
                  description: desc,
                  permissionIds: permIds,
                );
                _msg('Role updated');
              } else {
                await _api.createRole(
                  name: name,
                  description: desc,
                  companyId: _companyId.isNotEmpty ? _companyId : null,
                  permissionIds: permIds,
                );
                _msg('Role created');
              }
              _load();
            } catch (e) {
              _msg('Failed: $e', error: true);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search roles...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showForm(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_filtered.length} roles',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No roles',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
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
      ],
    );
  }

  Widget _tile(Map<String, dynamic> role) {
    final status = role['status'] ?? '';
    final permCount = _permCount(role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if ((role['description'] ?? '').toString().isNotEmpty)
                  Text(
                    role['description'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  '$permCount permissions',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'ACTIVE'
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: status == 'ACTIVE'
                    ? AppColors.success
                    : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _toggleStatus(role),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                status == 'ACTIVE' ? Icons.block : Icons.check_circle_outline,
                size: 14,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showForm(existing: role),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _confirmDelete(role),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Separate screen for role create/edit with permission checkboxes
class _RoleFormScreen extends StatefulWidget {
  final bool isEdit;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final Map<String, List<Map<String, dynamic>>> moduleMap;
  final Set<String> selectedIds;
  final Future<void> Function(String name, String desc, List<String> permIds)
  onSave;

  const _RoleFormScreen({
    required this.isEdit,
    required this.nameCtrl,
    required this.descCtrl,
    required this.moduleMap,
    required this.selectedIds,
    required this.onSave,
  });

  @override
  State<_RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<_RoleFormScreen> {
  late Set<String> _selected;
  bool _saving = false;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 16,
              bottom: 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  widget.isEdit ? 'Edit Role' : 'Create Role',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selected.length} permissions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Name + Description
                TextField(
                  controller: widget.nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Role Name *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: widget.descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Permissions by module
                const Text(
                  'Permissions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...widget.moduleMap.entries.map((entry) {
                  final moduleName = entry.key;
                  final perms = entry.value;
                  final isExpanded = _expanded.contains(moduleName);
                  final checkedCount = perms
                      .where((p) => _selected.contains(p['id']))
                      .length;
                  final allChecked = checkedCount == perms.length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Column(
                      children: [
                        // Module header
                        GestureDetector(
                          onTap: () => setState(() {
                            if (isExpanded)
                              _expanded.remove(moduleName);
                            else
                              _expanded.add(moduleName);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() {
                                    if (allChecked) {
                                      for (final p in perms)
                                        _selected.remove(p['id']);
                                    } else {
                                      for (final p in perms)
                                        _selected.add(p['id']);
                                    }
                                  }),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: allChecked
                                          ? AppColors.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: allChecked
                                            ? AppColors.primary
                                            : AppColors.textHint,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: allChecked
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    moduleName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$checkedCount/${perms.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: AppColors.textHint,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Permissions
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: perms.map((p) {
                                final checked = _selected.contains(p['id']);
                                final opName =
                                    p['operation']?['name'] ??
                                    p['code']?.toString().split('_').last ??
                                    '';
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    if (checked)
                                      _selected.remove(p['id']);
                                    else
                                      _selected.add(p['id']);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? AppColors.primary.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.primary
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          checked
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 14,
                                          color: checked
                                              ? AppColors.primary
                                              : AppColors.textHint,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          opName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: checked
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Save
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (widget.nameCtrl.text.trim().isEmpty) return;
                            setState(() => _saving = true);
                            await widget.onSave(
                              widget.nameCtrl.text.trim(),
                              widget.descCtrl.text.trim(),
                              _selected.toList(),
                            );
                            if (mounted) {
                              setState(() => _saving = false);
                              Navigator.pop(context);
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.isEdit ? 'Update Role' : 'Create Role'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
