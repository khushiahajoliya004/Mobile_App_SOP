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
  List<Map<String, String>> _companyRoles = [];
  bool _loadingTasks = true;
  bool _loadingRoles = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      final projectRolesRes = await _api.getProjectTechRoles(widget.project.id);
      _roles = (projectRolesRes.data['data'] as List? ?? [])
          .map((e) => ProjectTechRole.fromJson(e))
          .toList();
    } catch (_) {
      _roles = [];
    }
    try {
      final companyRolesRes = await _api.getTimesheetCompanyRoles(widget.project.companyId);
      _companyRoles = (companyRolesRes.data['data'] as List? ?? [])
          .map<Map<String, String>>((r) => {
                'id': r['id']?.toString() ?? '',
                'name': r['name']?.toString() ?? '',
              })
          .where((r) => r['id']!.isNotEmpty)
          .toList();
    } catch (_) {
      _companyRoles = [];
    }
    setState(() => _loadingRoles = false);
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
              Tab(text: 'Tasks'),
              Tab(text: 'Tech Roles'),
              Tab(text: 'Hour Assignments'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildTasksTab(),
                _buildRolesTab(),
                _buildHourAssignmentsTab(),
              ],
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
    if (_companyRoles.isEmpty) {
      return const Center(
        child: Text(
          'No roles found.\nCreate roles in the company Roles module first.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _companyRoles.length,
      itemBuilder: (_, i) {
        final companyRole = _companyRoles[i];
        final projectRole = _roles.where(
          (r) => r.roleName == companyRole['name'],
        ).firstOrNull;
        return _buildRoleCard(companyRole, projectRole);
      },
    );
  }

  Widget _buildRoleCard(Map<String, String> companyRole, ProjectTechRole? projectRole) {
    final hasMembers = projectRole != null && projectRole.users.isNotEmpty;
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
                  child: const Icon(Icons.engineering_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    companyRole['name']!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAssignUser(companyRole, projectRole),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Assign'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (hasMembers) ...[
              const SizedBox(height: 10),
              const Text('Members:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: projectRole!.users.map((u) => Chip(
                  label: Text(u.userName ?? u.userId, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFEDE9FE),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => _removeUser(widget.project.id, projectRole.id, u.userId),
                  visualDensity: VisualDensity.compact,
                )).toList(),
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
        companyId: widget.project.companyId,
        api: _api,
        onCreated: _loadRoles,
      ),
    );
  }

  void _openAssignUser(Map<String, String> companyRole, ProjectTechRole? projectRole) async {
    String roleId;
    if (projectRole != null) {
      roleId = projectRole.id;
    } else {
      try {
        final res = await _api.createProjectTechRole(widget.project.id, {
          'roleName': companyRole['name'],
        });
        roleId = res.data['data']['id'];
        await _loadRoles();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initialise role'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignUserSheet(
        projectId: widget.project.id,
        companyId: widget.project.companyId,
        roleId: roleId,
        roleName: companyRole['name']!,
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

  Widget _buildHourAssignmentsTab() {
    if (_loadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'No tasks found.\nCreate tasks first to assign hour ranges.',
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
                            contentPadding: const EdgeInsets.only(
                              left: 20,
                              right: 12,
                            ),
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              s.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              s.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => _openHourAssignments(s),
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: const Text(
                                'Hours',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
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

  void _openHourAssignments(ProjectSubtask subtask) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HourAssignmentsSheet(
        subtask: subtask,
        techRoles: _roles,
        api: _api,
      ),
    );
  }
}

class _HourAssignmentsSheet extends StatefulWidget {
  final ProjectSubtask subtask;
  final List<ProjectTechRole> techRoles;
  final ApiService api;

  const _HourAssignmentsSheet({
    required this.subtask,
    required this.techRoles,
    required this.api,
  });

  @override
  State<_HourAssignmentsSheet> createState() => _HourAssignmentsSheetState();
}

class _HourAssignmentsSheetState extends State<_HourAssignmentsSheet> {
  List<SubtaskRoleAssignment> _assignments = [];
  bool _loading = true;
  bool _showForm = false;
  String? _selectedRoleId;
  final _minCtrl = TextEditingController(text: '0.25');
  final _maxCtrl = TextEditingController(text: '1.5');
  final _estCtrl = TextEditingController(text: '1.0');
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _estCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getSubtaskRoleAssignments(widget.subtask.id);
      setState(() {
        _assignments =
            (res.data['data'] as List? ?? [])
                .map((e) => SubtaskRoleAssignment.fromJson(e))
                .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a tech role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final min = double.tryParse(_minCtrl.text) ?? 0.25;
    final max = double.tryParse(_maxCtrl.text) ?? 1.5;
    final est = double.tryParse(_estCtrl.text) ?? 1.0;
    if (max < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max hours must be >= min hours'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.createSubtaskRoleAssignment({
        'projectSubtaskId': widget.subtask.id,
        'projectTechRoleId': _selectedRoleId,
        'minHours': min,
        'maxHours': max,
        'estimatedHours': est,
      });
      setState(() {
        _showForm = false;
        _selectedRoleId = null;
      });
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create assignment'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.api.deleteSubtaskRoleAssignment(id);
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete assignment'),
          backgroundColor: Colors.red,
        ),
      );
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hour Assignments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.subtask.name,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showForm = !_showForm),
                icon: Icon(_showForm ? Icons.close : Icons.add, size: 16),
                label: Text(_showForm ? 'Cancel' : 'Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showForm) ...[
            DropdownButtonFormField<String>(
              value: _selectedRoleId,
              decoration: InputDecoration(
                labelText: 'Tech Role *',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              items: widget.techRoles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.roleName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedRoleId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    decoration: InputDecoration(
                      labelText: 'Min h',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    decoration: InputDecoration(
                      labelText: 'Max h',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _estCtrl,
                    decoration: InputDecoration(
                      labelText: 'Est h',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Assignment'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No hour assignments yet.\nTap + Add to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _assignments.length,
                itemBuilder: (_, i) {
                  final a = _assignments[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        a.roleName ?? 'Role',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${a.minHours}h – ${a.maxHours}h  |  Est: ${a.estimatedHours}h',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _delete(a.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CreateRoleSheet extends StatefulWidget {
  final String projectId;
  final String companyId;
  final ApiService api;
  final VoidCallback onCreated;
  const _CreateRoleSheet({
    required this.projectId,
    required this.companyId,
    required this.api,
    required this.onCreated,
  });

  @override
  State<_CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends State<_CreateRoleSheet> {
  List<Map<String, String>> _companyRoles = [];
  Map<String, String>? _selectedRole;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final res = await widget.api.getTimesheetCompanyRoles(widget.companyId);
      final raw = res.data;
      final list = raw is List ? raw : (raw['data'] is List ? raw['data'] : []);
      setState(() {
        _companyRoles = (list as List)
            .map<Map<String, String>>((r) => {
                  'id': r['id']?.toString() ?? '',
                  'name': r['name']?.toString() ?? '',
                })
            .where((r) => r['id']!.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedRole == null) return;
    setState(() => _submitting = true);
    try {
      await widget.api.createProjectTechRole(widget.projectId, {
        'roleName': _selectedRole!['name'],
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add role'), backgroundColor: Colors.red),
        );
      }
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
          const Text('Add Tech Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Select from your company roles', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_companyRoles.isEmpty)
            const Text('No roles found. Create roles in the Roles module first.', style: TextStyle(color: Colors.grey))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _companyRoles.length,
                itemBuilder: (_, i) {
                  final role = _companyRoles[i];
                  final isSelected = _selectedRole?['id'] == role['id'];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.engineering_rounded, size: 16, color: AppColors.primary),
                    ),
                    title: Text(role['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                    tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () => setState(() => _selectedRole = role),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || _selectedRole == null) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_selectedRole != null ? 'Add ${_selectedRole!['name']}' : 'Select a role first'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AssignUserSheet extends StatefulWidget {
  final String projectId;
  final String companyId;
  final String roleId;
  final String roleName;
  final ApiService api;
  final VoidCallback onAssigned;
  const _AssignUserSheet({
    required this.projectId,
    required this.companyId,
    required this.roleId,
    required this.roleName,
    required this.api,
    required this.onAssigned,
  });


  @override
  State<_AssignUserSheet> createState() => _AssignUserSheetState();
}

class _AssignUserSheetState extends State<_AssignUserSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _allUsers = [];
  List<Map<String, String>> _filtered = [];
  Map<String, String>? _selected;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await widget.api.getTimesheetCompanyUsers(
        widget.companyId,
        roleName: widget.roleName,
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw['data'] is List ? raw['data'] : []);
      final users = (list as List)
          .map<Map<String, String>>((u) => {
                'id': u['id'] ?? '',
                'name': (u['name'] ?? '').toString(),
                'email': (u['email'] ?? '').toString(),
              })
          .where((u) => u['id']!.isNotEmpty)
          .toList();
      setState(() {
        _allUsers = users;
        _filtered = users;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allUsers
          .where((u) =>
              u['name']!.toLowerCase().contains(q) ||
              u['email']!.toLowerCase().contains(q))
          .toList();
      if (_selected != null &&
          !_filtered.any((u) => u['id'] == _selected!['id'])) {
        _selected = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await widget.api.assignUserToTechRole(
        widget.projectId,
        widget.roleId,
        _selected!['id']!,
      );
      widget.onAssigned();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selected!['name']} assigned to ${widget.roleName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to assign user'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No users found', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final u = _filtered[i];
                  final isSelected = _selected?['id'] == u['id'];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        (u['name']!.isNotEmpty ? u['name']![0] : '?').toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(u['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(u['email']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () => setState(() => _selected = u),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || _selected == null) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selected != null ? 'Assign ${_selected!['name']}' : 'Select a user first',
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
