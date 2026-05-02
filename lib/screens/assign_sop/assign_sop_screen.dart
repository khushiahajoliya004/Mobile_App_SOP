import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AssignSopScreen extends StatefulWidget {
  const AssignSopScreen({super.key});
  @override
  State<AssignSopScreen> createState() => _AssignSopScreenState();
}

class _AssignSopScreenState extends State<AssignSopScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sops = [];
  String _search = '';
  final Map<String, String> _selectedSopMap = {};
  final Map<String, bool> _savingMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.getUsers(), _api.getSops()]);
      _users = _p(
        results[0].data,
      ).where((u) => u['userType'] == 'USER').toList();
      _sops = _p(results[1].data);
      // Pre-populate map
      for (final u in _users) {
        _selectedSopMap[u['id']] = u['sopId'] ?? '';
      }
    } catch (_) {
      _users = [];
      _sops = [];
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
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) {
      final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
          .toLowerCase();
      return name.contains(q) ||
          '${u['email'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  String _fullName(Map<String, dynamic> u) =>
      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

  String _sopName(String? sopId) {
    if (sopId == null || sopId.isEmpty) return 'No SOP assigned';
    final sop = _sops.where((s) => s['id'] == sopId).firstOrNull;
    return sop?['name'] ?? 'Unknown SOP';
  }

  bool _hasChanged(Map<String, dynamic> u) {
    return _selectedSopMap[u['id']] != (u['sopId'] ?? '');
  }

  int get _assignedCount =>
      _users.where((u) => (u['sopId'] ?? '').toString().isNotEmpty).length;

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _assign(Map<String, dynamic> user) async {
    final userId = user['id'];
    final sopId = _selectedSopMap[userId] ?? '';
    setState(() => _savingMap[userId] = true);
    try {
      await _api.assignSopToUser(userId, sopId.isEmpty ? null : sopId);
      // Update local data
      user['sopId'] = sopId.isEmpty ? null : sopId;
      user['sop'] = sopId.isNotEmpty
          ? _sops.where((s) => s['id'] == sopId).firstOrNull
          : null;
      _msg(
        sopId.isNotEmpty
            ? 'SOP assigned to ${_fullName(user)}'
            : 'SOP removed from ${_fullName(user)}',
      );
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
    if (mounted) setState(() => _savingMap[userId] = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

    return Column(
      children: [
        // Header stats
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _miniStat('${_users.length}', 'Total Users', AppColors.primary),
              const SizedBox(width: 12),
              _miniStat('$_assignedCount', 'SOP Assigned', AppColors.success),
              const SizedBox(width: 12),
              _miniStat(
                '${_users.length - _assignedCount}',
                'Unassigned',
                AppColors.warning,
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search users...',
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
        // List
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _userTile(_filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
        ],
      ),
    ),
  );

  Widget _userTile(Map<String, dynamic> user) {
    final name = _fullName(user);
    final email = user['email'] ?? '';
    final currentSopId = _selectedSopMap[user['id']] ?? '';
    final isSaving = _savingMap[user['id']] == true;
    final changed = _hasChanged(user);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: changed
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Current SOP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (user['sopId'] ?? '').toString().isNotEmpty
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: (user['sopId'] ?? '').toString().isNotEmpty
                      ? AppColors.success
                      : AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Text(
                  _sopName(user['sopId']),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (user['sopId'] ?? '').toString().isNotEmpty
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // SOP dropdown + Save
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentSopId.isEmpty ? null : currentSopId,
                      isExpanded: true,
                      hint: const Text(
                        'Select SOP',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text(
                            'No SOP',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                        ..._sops.map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(
                              '${s['name']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedSopMap[user['id']] = v ?? ''),
                    ),
                  ),
                ),
              ),
              if (changed) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isSaving ? null : () => _assign(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
