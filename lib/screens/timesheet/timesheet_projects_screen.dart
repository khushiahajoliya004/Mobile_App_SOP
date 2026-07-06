import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_model.dart';
import '../../models/timesheet_project_model.dart';
import '../../services/api_service.dart';
import 'timesheet_project_detail_screen.dart';

class TimesheetProjectsScreen extends StatefulWidget {
  final UserModel user;
  const TimesheetProjectsScreen({super.key, required this.user});

  @override
  State<TimesheetProjectsScreen> createState() =>
      _TimesheetProjectsScreenState();
}

class _TimesheetProjectsScreenState extends State<TimesheetProjectsScreen> {
  final _api = ApiService();
  List<TimesheetProject> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getTimesheetProjects(widget.user.companyId ?? '');
      setState(() {
        _projects =
            (res.data['data'] as List? ?? [])
                .map((e) => TimesheetProject.fromJson(e))
                .toList();
        _loading = false;
      });
    } catch (e) {
      String msg = 'Failed to load projects. Tap to retry.';
      if (e is DioException) {
        final status = e.response?.statusCode;
        final serverMsg = e.response?.data is Map
            ? (e.response!.data['message'] ?? '')
            : '';
        if (status != null) {
          msg = 'Error $status${serverMsg.isNotEmpty ? ': $serverMsg' : ''}. Tap to retry.';
        } else {
          msg = 'Cannot reach server. Check connection and tap to retry.';
        }
      }
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateProjectSheet(
        user: widget.user,
        api: _api,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Project',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _load,
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _projects.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No projects yet.\nTap + to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _projects.length,
                          itemBuilder: (_, i) => _buildCard(_projects[i]),
                        ),
            ),
    );
  }

  Widget _buildCard(TimesheetProject p) {
    final isClient = p.type == 'CLIENT';
    final statusActive = p.status == 'ACTIVE';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TimesheetProjectDetailScreen(
              project: p,
              user: widget.user,
            ),
          ),
        ).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isClient
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.type,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isClient
                            ? const Color(0xFF059669)
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusActive
                          ? const Color(0xFFD1FAE5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusActive
                            ? const Color(0xFF059669)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (p.clientName != null) ...[
                const SizedBox(height: 4),
                Text(
                  p.clientName!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Budget: ${p.totalEstimatedHours.toStringAsFixed(0)}h',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (p.startDate != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${p.startDate}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  final UserModel user;
  final ApiService api;
  final VoidCallback onCreated;
  const _CreateProjectSheet({
    required this.user,
    required this.api,
    required this.onCreated,
  });

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '100');
  String _type = 'INTERNAL';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clientCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.api.createTimesheetProject({
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'totalEstimatedHours': double.tryParse(_hoursCtrl.text) ?? 100,
        'companyId': widget.user.companyId ?? '',
        if (_clientCtrl.text.isNotEmpty) 'clientName': _clientCtrl.text.trim(),
      });
      widget.onCreated();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Project created successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create project'),
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
              'Create Project',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Project Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'INTERNAL', child: Text('Internal')),
                DropdownMenuItem(value: 'CLIENT', child: Text('Client')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            if (_type == 'CLIENT')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _clientCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            TextFormField(
              controller: _hoursCtrl,
              decoration: const InputDecoration(
                labelText: 'Budget Hours *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter a valid number';
                return null;
              },
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
                    : const Text('Create Project'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
