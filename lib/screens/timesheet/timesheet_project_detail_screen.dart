import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_model.dart';
import '../../models/timesheet_project_model.dart';
import '../../services/api_service.dart';

class TimesheetProjectDetailScreen extends StatefulWidget {
  final TimesheetProject project;
  final UserModel user;
  const TimesheetProjectDetailScreen({
    super.key,
    required this.project,
    required this.user,
  });

  @override
  State<TimesheetProjectDetailScreen> createState() =>
      _TimesheetProjectDetailScreenState();
}

class _TimesheetProjectDetailScreenState
    extends State<TimesheetProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<ProjectTask> _tasks = [];
  List<ProjectTechRole> _roles = [];
  bool _loadingTasks = true;
  bool _loadingRoles = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTasks();
    _loadRoles();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final res = await _api.getProjectTasks(widget.project.id);
      setState(() {
        _tasks =
            (res.data['data'] as List? ?? [])
                .map((e) => ProjectTask.fromJson(e))
                .toList();
        _loadingTasks = false;
      });
    } catch (_) {
      setState(() => _loadingTasks = false);
    }
  }

  Future<void> _loadRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final res = await _api.getProjectTechRoles(widget.project.id);
      setState(() {
        _roles =
            (res.data['data'] as List? ?? [])
                .map((e) => ProjectTechRole.fromJson(e))
                .toList();
        _loadingRoles = false;
      });
    } catch (_) {
      setState(() => _loadingRoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Tasks & Subtasks'),
              Tab(text: 'Tech Roles'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_buildTasksTab(), _buildRolesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final p = widget.project;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 4,
        right: 16,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _chip(p.type, p.type == 'CLIENT' ? Colors.green : Colors.blue),
                const SizedBox(width: 8),
                _chip(
                  '${p.totalEstimatedHours.toStringAsFixed(0)}h budget',
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  Widget _buildTasksTab() {
    if (_loadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'No tasks found.\nDefault tasks should appear after project creation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (_, i) {
        final task = _tasks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                task.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                '${task.subtasks.length} subtask(s)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: task.subtasks.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No subtasks',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ]
                  : task.subtasks
                        .map(
                          (s) => ListTile(
                            dense: true,
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(s.name, style: const TextStyle(fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRolesTab() {
    if (_loadingRoles) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRole,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Role', style: TextStyle(color: Colors.white)),
      ),
      body: _roles.isEmpty
          ? const Center(
              child: Text(
                'No roles yet.\nCreate a tech role to assign team members.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _roles.length,
              itemBuilder: (_, i) => _buildRoleCard(_roles[i]),
            ),
    );
  }

  Widget _buildRoleCard(ProjectTechRole role) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.roleName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (role.description != null)
                        Text(
                          role.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAssignUser(role),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Assign'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (role.users.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Members:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: role.users
                    .map(
                      (u) => Chip(
                        label: Text(
                          u.userName ?? u.userId,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: const Color(0xFFEDE9FE),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () =>
                            _removeUser(widget.project.id, role.id, u.userId),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openCreateRole() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateRoleSheet(
        projectId: widget.project.id,
        api: _api,
        onCreated: _loadRoles,
      ),
    );
  }

  void _openAssignUser(ProjectTechRole role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignUserSheet(
        projectId: widget.project.id,
        roleId: role.id,
        roleName: role.roleName,
        api: _api,
        onAssigned: _loadRoles,
      ),
    );
  }

  Future<void> _removeUser(
    String projectId,
    String roleId,
    String userId,
  ) async {
    try {
      await _api.removeUserFromTechRole(projectId, roleId, userId);
      _loadRoles();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _CreateRoleSheet extends StatefulWidget {
  final String projectId;
  final ApiService api;
  final VoidCallback onCreated;
  const _CreateRoleSheet({
    required this.projectId,
    required this.api,
    required this.onCreated,
  });

  @override
  State<_CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends State<_CreateRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.api.createProjectTechRole(widget.projectId, {
        'roleName': _nameCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create role'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Tech Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Role Name *',
                hintText: 'e.g. Developer, QA, Tech Lead',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Role'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AssignUserSheet extends StatefulWidget {
  final String projectId;
  final String roleId;
  final String roleName;
  final ApiService api;
  final VoidCallback onAssigned;
  const _AssignUserSheet({
    required this.projectId,
    required this.roleId,
    required this.roleName,
    required this.api,
    required this.onAssigned,
  });

  @override
  State<_AssignUserSheet> createState() => _AssignUserSheetState();
}

class _AssignUserSheetState extends State<_AssignUserSheet> {
  final _userIdCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_userIdCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.api.assignUserToTechRole(
        widget.projectId,
        widget.roleId,
        _userIdCtrl.text.trim(),
      );
      widget.onAssigned();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign user'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign User to ${widget.roleName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userIdCtrl,
            decoration: const InputDecoration(
              labelText: 'User ID *',
              hintText: 'Paste the user UUID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Assign User'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
