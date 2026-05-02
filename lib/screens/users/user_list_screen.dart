import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _sops = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUser = await _auth.getUser();
    await _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getUsers();
      _users = _parseList(res.data);
    } catch (_) {
      _users = [];
    }

    try {
      final res = await _api.getRoles();
      _roles = _parseList(
        res.data,
      ).where((r) => r['status'] == 'ACTIVE').toList();
    } catch (_) {
      _roles = [];
    }

    if (_currentUser?.isCompanyAdmin == true) {
      try {
        final res = await _api.getSops();
        _sops = _parseList(res.data);
      } catch (_) {
        _sops = [];
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
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
      final email = '${u['email'] ?? ''}'.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  String _fullName(Map<String, dynamic> u) =>
      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

  List<String> _getRoles(Map<String, dynamic> u) =>
      ((u['roles'] ?? []) as List).map((r) => '${r['name'] ?? ''}').toList();

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  // ─── Create / Edit ─────────────────────────────────────────────────────

  void _showUserForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final firstName = TextEditingController(text: existing?['firstName'] ?? '');
    final lastName = TextEditingController(text: existing?['lastName'] ?? '');
    final email = TextEditingController(text: existing?['email'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final password = TextEditingController();
    String userType =
        existing?['userType'] ??
        (_currentUser?.isCompanyAdmin == true ? 'USER' : '');
    bool aiEnabled = existing?['aiEnabled'] == true;
    String? sopId = existing?['sopId'];
    List<String> selectedRoleIds = ((existing?['roles'] ?? []) as List)
        .map((r) => '${r['id']}')
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit User' : 'New User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // First + Last name
                Row(
                  children: [
                    Expanded(child: _field(firstName, 'First Name *')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(lastName, 'Last Name *')),
                  ],
                ),
                const SizedBox(height: 10),

                // Email + Phone
                _field(email, 'Email *', type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(phone, 'Phone', type: TextInputType.phone),
                const SizedBox(height: 10),

                // Password (create only)
                if (!isEdit) ...[
                  _field(password, 'Password *', obscure: true),
                  const SizedBox(height: 10),
                ],

                // User Type (non-company users)
                if (_currentUser?.isCompanyAdmin != true) ...[
                  const Text(
                    'User Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['SUPER_ADMIN', 'DISTRIBUTOR', 'COMPANY', 'USER']
                        .map(
                          (t) => ChoiceChip(
                            label: Text(
                              t.replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 12,
                                color: userType == t
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: userType == t,
                            selectedColor: AppColors.primary,
                            onSelected: (_) =>
                                setSheetState(() => userType = t),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // SOP Assignment (company admin only)
                if (_currentUser?.isCompanyAdmin == true &&
                    _sops.isNotEmpty) ...[
                  const Text(
                    'Assign SOP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sopId,
                        isExpanded: true,
                        hint: const Text(
                          'No SOP assigned',
                          style: TextStyle(fontSize: 14),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No SOP assigned'),
                          ),
                          ..._sops.map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(
                                '${s['name']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setSheetState(() => sopId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // AI Enabled toggle (company admin only)
                if (_currentUser?.isCompanyAdmin == true) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable AI Analysis',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Auto-process recordings without approval',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: aiEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setSheetState(() => aiEnabled = v),
                  ),
                  const SizedBox(height: 8),
                ],

                // Role Assignment (company admin only)
                if (_currentUser?.isCompanyAdmin == true &&
                    _roles.isNotEmpty) ...[
                  const Text(
                    'Assign Roles',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles.map((role) {
                      final id = role['id'] as String;
                      final selected = selectedRoleIds.contains(id);
                      return FilterChip(
                        label: Text(
                          '${role['name']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setSheetState(() {
                          if (selected) {
                            selectedRoleIds.remove(id);
                          } else {
                            selectedRoleIds.add(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  if (selectedRoleIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${selectedRoleIds.length} role(s) selected',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveUser(
                      ctx,
                      isEdit: isEdit,
                      id: existing?['id'],
                      firstName: firstName.text,
                      lastName: lastName.text,
                      email: email.text,
                      phone: phone.text,
                      password: password.text,
                      userType: userType,
                      aiEnabled: aiEnabled,
                      sopId: sopId,
                      roleIds: selectedRoleIds,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEdit ? 'Update User' : 'Create User'),
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

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _saveUser(
    BuildContext ctx, {
    required bool isEdit,
    String? id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String userType,
    required bool aiEnabled,
    String? sopId,
    required List<String> roleIds,
  }) async {
    if (firstName.trim().isEmpty ||
        lastName.trim().isEmpty ||
        email.trim().isEmpty) {
      _msg('First name, last name, and email are required', error: true);
      return;
    }
    if (!isEdit && password.length < 6) {
      _msg('Password must be at least 6 characters', error: true);
      return;
    }

    Navigator.pop(ctx);
    setState(() => _loading = true);

    try {
      if (isEdit && id != null) {
        await _api.updateUser(
          id,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          roleIds: roleIds,
          aiEnabled: aiEnabled,
        );
        // Assign SOP separately
        if (_currentUser?.isCompanyAdmin == true) {
          await _api.assignSopToUser(id, sopId);
        }
        _msg('User updated');
      } else {
        final companyId = _currentUser?.companyId ?? '';
        final res = await _api.createUser(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
          userType: userType.isNotEmpty ? userType : 'USER',
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          companyId: companyId.isNotEmpty ? companyId : null,
          roleIds: roleIds.isNotEmpty ? roleIds : null,
          aiEnabled: aiEnabled,
        );
        // Assign SOP after creation
        if (_currentUser?.isCompanyAdmin == true && sopId != null) {
          final newId = res.data is Map
              ? (res.data['data']?['id'] ?? res.data['id'])
              : null;
          if (newId != null) {
            await _api.assignSopToUser(newId, sopId);
          }
        }
        _msg('User created');
      }
      _loadAll();
    } catch (e) {
      _msg('Failed: $e', error: true);
      setState(() => _loading = false);
    }
  }

  // ─── Delete ────────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete User',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${_fullName(user)}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteUser(user['id']);
                _msg('User deleted');
                _loadAll();
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

  // ─── Toggle Status ────────────────────────────────────────────────────────

  void _confirmToggleStatus(Map<String, dynamic> user) {
    final isActive = user['status'] == 'ACTIVE';
    final action = isActive ? 'Deactivate' : 'Activate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$action User',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('$action "${_fullName(user)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final newStatus = isActive ? 'INACTIVE' : 'ACTIVE';
                await _api.updateUserStatus(user['id'], newStatus);
                _msg('Status updated');
                _loadAll();
              } catch (e) {
                _msg('Failed: $e', error: true);
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  // ─── Toggle AI ────────────────────────────────────────────────────────────

  Future<void> _toggleAi(Map<String, dynamic> user) async {
    final newVal = user['aiEnabled'] != true;
    try {
      await _api.updateUser(user['id'], aiEnabled: newVal);
      setState(() => user['aiEnabled'] = newVal);
      _msg('AI ${newVal ? 'enabled' : 'disabled'} for ${user['firstName']}');
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + Add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showUserForm(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_filtered.length} users',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadAll,
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
        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadAll,
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

  Widget _userTile(Map<String, dynamic> user) {
    final name = _fullName(user);
    final email = user['email'] ?? '';
    final userType = user['userType'] ?? '';
    final status = user['status'] ?? '';
    final roles = _getRoles(user);
    final sopName = user['sop']?['name'];
    final aiEnabled = user['aiEnabled'] == true;
    final isCompanyAdmin = _currentUser?.isCompanyAdmin == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar + Name + Status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: status == 'ACTIVE'
                    ? AppColors.primarySurface
                    : AppColors.surfaceLight,
                child: Text(
                  name.isNotEmpty
                      ? '${name[0]}${name.contains(' ') ? name.split(' ').last[0] : ''}'
                      : '?',
                  style: TextStyle(
                    color: status == 'ACTIVE'
                        ? AppColors.primary
                        : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'ACTIVE'
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: status == 'ACTIVE'
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Type + Roles + Phone
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(userType.replaceAll('_', ' '), AppColors.primary),
              ...roles.take(2).map((r) => _chip(r, AppColors.accent)),
              if (roles.length > 2)
                _chip('+${roles.length - 2}', AppColors.textHint),
            ],
          ),

          // Row 3: SOP + AI (company admin only)
          if (isCompanyAdmin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (sopName != null) ...[
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sopName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // AI toggle
                GestureDetector(
                  onTap: () => _toggleAi(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: aiEnabled
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: aiEnabled
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI ${aiEnabled ? 'ON' : 'OFF'}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: aiEnabled
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Row 4: Actions
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(
                Icons.edit_outlined,
                AppColors.primary,
                () => _showUserForm(existing: user),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                status == 'ACTIVE'
                    ? Icons.block_rounded
                    : Icons.check_circle_outline,
                status == 'ACTIVE' ? AppColors.warning : AppColors.success,
                () => _confirmToggleStatus(user),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                Icons.delete_outline,
                AppColors.error,
                () => _confirmDelete(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}
