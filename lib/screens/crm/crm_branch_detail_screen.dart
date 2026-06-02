import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmBranchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> branch;
  const CrmBranchDetailScreen({super.key, required this.branch});

  @override
  State<CrmBranchDetailScreen> createState() => _CrmBranchDetailScreenState();
}

class _CrmBranchDetailScreenState extends State<CrmBranchDetailScreen> {
  final _api = ApiService();

  bool _teamLoading = true;
  bool _usersLoading = true;
  bool _assigning = false;

  List<Map<String, dynamic>> _team = [];
  List<Map<String, dynamic>> _allUsers = [];

  // assign form state
  Map<String, dynamic>? _selectedUser;
  String? _selectedRole;
  Map<String, dynamic>? _selectedReportingTo;

  static const _roles = [
    {'label': 'Branch Manager', 'value': 'BRANCH_MANAGER'},
    {'label': 'Team Leader',    'value': 'TEAM_LEADER'},
    {'label': 'Sales Manager',  'value': 'SALES_MANAGER'},
    {'label': 'Receptionist',   'value': 'RECEPTIONIST'},
  ];

  bool get _showReportingTo =>
      _selectedRole == 'SALES_MANAGER' || _selectedRole == 'RECEPTIONIST';

  List<Map<String, dynamic>> get _teamLeaders => _team
      .where((m) => (m['branchRole'] ?? '').toString() == 'TEAM_LEADER')
      .toList();

  @override
  void initState() {
    super.initState();
    _loadTeam();
    _loadUsers();
  }

  Future<void> _loadTeam() async {
    final branchId = widget.branch['id']?.toString() ?? '';
    if (branchId.isEmpty) { setState(() => _teamLoading = false); return; }
    try {
      final res = await _api.getBranchTeam(branchId);
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      if (mounted) {
        setState(() {
          _team = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _teamLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teamLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final res = await _api.getUsers();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? raw['users'] ?? []) as List : []);
      if (mounted) {
        setState(() {
          _allUsers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _usersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _assignUser() async {
    if (_selectedUser == null || _selectedRole == null) return;
    final branchId = widget.branch['id']?.toString() ?? '';
    setState(() => _assigning = true);
    try {
      await _api.assignUserToBranch(
        branchId,
        userId: _selectedUser!['id'].toString(),
        branchRole: _selectedRole!,
        reportingToUserId: _selectedReportingTo?['userId']?.toString() ??
            _selectedReportingTo?['id']?.toString(),
      );
      if (mounted) {
        setState(() {
          _assigning = false;
          _selectedUser = null;
          _selectedRole = null;
          _selectedReportingTo = null;
        });
        _loadTeam();
        _showSnack('Member assigned successfully', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _assigning = false);
        _showSnack('Failed: $e');
      }
    }
  }

  Future<void> _removeUser(Map<String, dynamic> member) async {
    final branchId = widget.branch['id']?.toString() ?? '';
    final userId = member['userId']?.toString() ?? member['id']?.toString() ?? '';
    final user = member['user'] is Map ? member['user'] as Map : member;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove $name from this branch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.removeUserFromBranch(branchId, userId);
      if (mounted) { _loadTeam(); _showSnack('Member removed', success: true); }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
  }

  // ── Pick user from searchable bottom sheet ──
  Future<void> _pickUser() async {
    final picked = await _showUserPicker(
      title: 'Select Member',
      users: _allUsers,
    );
    if (picked != null) setState(() => _selectedUser = picked);
  }

  Future<void> _pickReportingTo() async {
    final tlUsers = _teamLeaders.map((m) {
      final u = m['user'] is Map ? m['user'] as Map : m;
      return Map<String, dynamic>.from(u);
    }).toList();
    final picked = await _showUserPicker(
      title: 'Reports To (Team Leader)',
      users: tlUsers,
    );
    if (picked != null) setState(() => _selectedReportingTo = picked);
  }

  Future<Map<String, dynamic>?> _showUserPicker({
    required String title,
    required List<Map<String, dynamic>> users,
  }) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(users);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email…',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (q) {
                      final lower = q.toLowerCase();
                      setSheet(() {
                        filtered = users.where((u) {
                          final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
                          final email = (u['email'] ?? '').toString().toLowerCase();
                          return name.contains(lower) || email.contains(lower);
                        }).toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No users found', style: TextStyle(color: AppColors.textHint)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
                            final email = u['email']?.toString() ?? '';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(name.isNotEmpty ? name : email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: email.isNotEmpty ? Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
                              onTap: () => Navigator.pop(ctx, u),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Role styling ──
  Color _roleColor(String role) {
    switch (role) {
      case 'BRANCH_MANAGER': return const Color(0xFF92400E);
      case 'TEAM_LEADER':    return const Color(0xFF1E40AF);
      case 'SALES_MANAGER':  return const Color(0xFF065F46);
      case 'RECEPTIONIST':   return const Color(0xFF9D174D);
      default:               return const Color(0xFF4338CA);
    }
  }

  Color _roleBg(String role) {
    switch (role) {
      case 'BRANCH_MANAGER': return const Color(0xFFFEF3C7);
      case 'TEAM_LEADER':    return const Color(0xFFDBEAFE);
      case 'SALES_MANAGER':  return const Color(0xFFD1FAE5);
      case 'RECEPTIONIST':   return const Color(0xFFFCE7F3);
      default:               return const Color(0xFFE0E7FF);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'BRANCH_MANAGER': return 'Branch Manager';
      case 'TEAM_LEADER':    return 'Team Leader';
      case 'SALES_MANAGER':  return 'Sales Manager';
      case 'RECEPTIONIST':   return 'Receptionist';
      default:               return role.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.branch['name']?.toString() ?? 'Branch';
    final code = widget.branch['code']?.toString() ?? '';
    final city = widget.branch['city']?.toString() ?? '';
    final status = (widget.branch['status'] ?? 'ACTIVE').toString().toUpperCase();
    final isActive = status == 'ACTIVE';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 4, right: 16, bottom: 14,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Icon(Icons.business_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async { await _loadTeam(); await _loadUsers(); },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Branch info card ──
                  _buildInfoCard(name, code, city, status, isActive),
                  const SizedBox(height: 16),

                  // ── Assign Member card ──
                  _buildAssignCard(),
                  const SizedBox(height: 16),

                  // ── Team Members card ──
                  _buildTeamCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String name, String code, String city, String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (code.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
                        child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (city.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 2),
                      Text(city, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignCard() {
    final userName = _selectedUser != null
        ? '${_selectedUser!['firstName'] ?? ''} ${_selectedUser!['lastName'] ?? ''}'.trim()
        : null;
    final reportingName = _selectedReportingTo != null
        ? '${_selectedReportingTo!['firstName'] ?? ''} ${_selectedReportingTo!['lastName'] ?? ''}'.trim()
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Assign Member', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // User picker
          const Text('Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _pickerTile(
            value: userName,
            hint: _usersLoading ? 'Loading users…' : 'Select a user',
            icon: Icons.person_outline_rounded,
            onTap: _usersLoading ? null : _pickUser,
            onClear: _selectedUser != null ? () => setState(() => _selectedUser = null) : null,
          ),
          const SizedBox(height: 12),

          // Role dropdown
          const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined), isDense: true),
            hint: const Text('Select role'),
            items: _roles.map((r) => DropdownMenuItem<String>(
              value: r['value'] as String,
              child: Text(r['label'] as String),
            )).toList(),
            onChanged: (v) => setState(() {
              _selectedRole = v;
              _selectedReportingTo = null;
            }),
          ),
          const SizedBox(height: 12),

          // Reports to (conditional)
          if (_showReportingTo) ...[
            const Text('Reports To (Team Leader)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _teamLeaders.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: const Text('No Team Leaders in this branch yet.', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                  )
                : _pickerTile(
                    value: reportingName,
                    hint: 'Select team leader',
                    icon: Icons.supervisor_account_outlined,
                    onTap: _pickReportingTo,
                    onClear: _selectedReportingTo != null ? () => setState(() => _selectedReportingTo = null) : null,
                  ),
            const SizedBox(height: 12),
          ],

          // Assign button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_selectedUser == null || _selectedRole == null || _assigning) ? null : _assignUser,
              icon: _assigning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_assigning ? 'Assigning…' : 'Assign to Branch'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required String? value,
    required String hint,
    required IconData icon,
    required VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: value != null ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: value != null ? AppColors.primarySurface : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: value != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Team Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (!_teamLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_team.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_teamLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ))
          else if (_team.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.people_outline_rounded, size: 32, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text('No team members assigned yet.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _team.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _buildMemberRow(_team[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final user = member['user'] is Map ? member['user'] as Map : member;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final role = member['branchRole']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final reportingTo = member['reportingTo'] is Map ? member['reportingTo'] as Map : null;
    final reportingName = reportingTo != null
        ? '${reportingTo['firstName'] ?? ''} ${reportingTo['lastName'] ?? ''}'.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : (user['email']?.toString() ?? ''),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (reportingName != null && reportingName.isNotEmpty)
                  Text('Reports to $reportingName',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (role.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _roleBg(role),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_roleLabel(role), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _roleColor(role))),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _removeUser(member),
          ),
        ],
      ),
    );
  }
}
