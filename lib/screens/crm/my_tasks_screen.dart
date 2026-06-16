import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];
  String _filter = 'PENDING';
  late TabController _tabCtrl;

  final _tabs = ['PENDING', 'IN_PROGRESS', 'OVERDUE', 'COMPLETED'];
  final _tabLabels = ['Pending', 'In Progress', 'Overdue', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filter = _tabs[_tabCtrl.index]);
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await _api.getMyTasks(status: _filter);
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      if (mounted) setState(() {
        _tasks = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _tasks = [];
        _loading = false;
      });
    }
  }

  Color _priorityColor(String? p) {
    switch ((p ?? '').toUpperCase()) {
      case 'HIGH':
      case 'URGENT':
        return AppColors.error;
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  IconData _taskIcon(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'REQUIREMENT_CAPTURE':
        return Icons.assignment_rounded;
      case 'FOLLOW_UP':
        return Icons.phone_rounded;
      case 'VISIT':
        return Icons.location_on_rounded;
      case 'TEST_DRIVE':
        return Icons.speed_rounded;
      case 'QUOTATION':
      case 'QUOTATION_FOLLOWUP':
        return Icons.request_quote_rounded;
      case 'NEGOTIATION':
        return Icons.handshake_rounded;
      case 'BOOKING':
        return Icons.bookmark_rounded;
      case 'VEHICLE_ALLOCATION':
        return Icons.directions_car_rounded;
      case 'FINANCE':
        return Icons.account_balance_rounded;
      case 'DOCUMENT_COLLECTION':
        return Icons.folder_rounded;
      case 'INSURANCE':
        return Icons.shield_rounded;
      case 'RTO':
        return Icons.badge_rounded;
      case 'PDI':
        return Icons.checklist_rounded;
      case 'PAYMENT_VERIFICATION':
        return Icons.payments_rounded;
      case 'DELIVERY':
        return Icons.local_shipping_rounded;
      case 'FEEDBACK':
        return Icons.star_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  void _showCompleteDialog(Map<String, dynamic> task) {
    final taskType = task['taskType'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskActionSheet(
        task: task,
        taskType: taskType,
        api: _api,
        onDone: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            tabAlignment: TabAlignment.start,
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _tasks.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primarySurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.task_alt_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${_tabLabels[_tabCtrl.index].toLowerCase()} tasks',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Pull down to refresh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      itemBuilder: (_, i) => _buildTaskCard(_tasks[i]),
                    ),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final type = task['taskType'] ?? '';
    final lead = task['lead'];
    final dueDate = task['dueDateTime'] != null
        ? DateTime.tryParse(task['dueDateTime'].toString())
        : null;
    final isOverdue =
        dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        task['status'] != 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(
                color: AppColors.error.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _taskIcon(type),
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
                        task['taskTitle'] ?? 'Task',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (lead != null)
                        Text(
                          '${lead['customerName'] ?? ''} · ${lead['phone'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor(
                      task['priority'],
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task['priority'] ?? 'MEDIUM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(task['priority']),
                    ),
                  ),
                ),
              ],
            ),
            if (dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
                    size: 13,
                    color: isOverdue ? AppColors.error : AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'Overdue: ${_fmtDate(dueDate)}'
                        : 'Due: ${_fmtDate(dueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOverdue ? AppColors.error : AppColors.textHint,
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
            if (task['status'] != 'COMPLETED' &&
                task['status'] != 'CANCELLED') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showCompleteDialog(task),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Take Action',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month)
      return 'Today ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Task Action Sheet ────────────────────────────────────────────────────────
class _TaskActionSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final String taskType;
  final ApiService api;
  final VoidCallback onDone;
  const _TaskActionSheet({
    required this.task,
    required this.taskType,
    required this.api,
    required this.onDone,
  });
  @override
  State<_TaskActionSheet> createState() => _TaskActionSheetState();
}

class _TaskActionSheetState extends State<_TaskActionSheet> {
  String? _selectedOutcome;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  Map<String, List<String>> get _outcomesByType => {
    'REQUIREMENT_CAPTURE': [
      'FOLLOW_UP',
      'VISIT_PLANNED',
      'TEST_DRIVE_PLANNED',
      'QUOTATION_REQUIRED',
      'BOOKING_EXPECTED',
      'MARK_LOST',
    ],
    'FOLLOW_UP': [
      'CALL_LATER',
      'VISIT_PLANNED',
      'TEST_DRIVE_PLANNED',
      'QUOTATION_REQUIRED',
      'BOOKING_EXPECTED',
      'NOT_INTERESTED',
      'LOST',
    ],
    'QUOTATION_FOLLOWUP': ['ACCEPTED', 'NEGOTIATION', 'REJECTED', 'LOST'],
    'TEST_DRIVE': ['QUOTATION_REQUIRED', 'FOLLOW_UP', 'MARK_LOST'],
    'VISIT': [
      'FOLLOW_UP',
      'TEST_DRIVE_PLANNED',
      'QUOTATION_REQUIRED',
      'MARK_LOST',
    ],
  };

  Map<String, String> get _actionByType => {
    'REQUIREMENT_CAPTURE': 'REQUIREMENT_COMPLETED',
    'FOLLOW_UP': 'FOLLOW_UP_COMPLETED',
    'QUOTATION_FOLLOWUP': 'QUOTATION_RESPONSE',
    'TEST_DRIVE': 'TEST_DRIVE_COMPLETED',
    'VISIT': 'VISIT_COMPLETED',
    'QUOTATION': 'QUOTATION_SENT',
    'BOOKING': 'BOOKING_CONFIRMED',
    'VEHICLE_ALLOCATION': 'VEHICLE_ALLOCATED',
    'FINANCE': 'FINANCE_STATUS_UPDATED',
    'DOCUMENT_COLLECTION': 'DOCUMENTS_VERIFIED',
    'EXCHANGE_EVALUATION': 'EXCHANGE_APPROVED',
    'INSURANCE': 'INSURANCE_COMPLETED',
    'RTO': 'RTO_COMPLETED',
    'ACCESSORIES': 'ACCESSORIES_FITTED',
    'PDI': 'PDI_COMPLETED',
    'PAYMENT_VERIFICATION': 'PAYMENT_COMPLETED',
    'DELIVERY': 'DELIVERY_COMPLETED',
    'FEEDBACK': 'FEEDBACK_SUBMITTED',
  };

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final actionType =
          _actionByType[widget.taskType] ?? 'REQUIREMENT_COMPLETED';
      await widget.api.completeTask(
        widget.task['id'],
        actionType: actionType,
        outcome: _selectedOutcome,
        payload: {
          'notes': _notesCtrl.text.trim(),
          'nextAction': _selectedOutcome,
        },
      );
      widget.onDone();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = _outcomesByType[widget.taskType] ?? [];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.task['taskTitle'] ?? 'Complete Task',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (outcomes.isNotEmpty) ...[
            const Text(
              'Select Outcome',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: outcomes
                  .map(
                    (o) => GestureDetector(
                      onTap: () => setState(() => _selectedOutcome = o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedOutcome == o
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          o.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedOutcome == o
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any notes...',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Complete Task'),
            ),
          ),
        ],
      ),
    );
  }
}
