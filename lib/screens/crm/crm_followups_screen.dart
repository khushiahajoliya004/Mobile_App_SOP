import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmFollowUpsScreen extends StatefulWidget {
  const CrmFollowUpsScreen({super.key});

  @override
  State<CrmFollowUpsScreen> createState() => _CrmFollowUpsScreenState();
}

class _CrmFollowUpsScreenState extends State<CrmFollowUpsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _leads = [];
  String _filterStatus = '';
  bool _filterOverdue = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getCrmFollowUps(
        status: _filterStatus.isEmpty ? null : _filterStatus,
        overdue: _filterOverdue ? true : null,
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      setState(() {
        _followUps = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLeads() async {
    try {
      final res = await _api.getCrmDeals();
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      _leads = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  bool _isOverdue(Map<String, dynamic> followUp) {
    final status = (followUp['status'] ?? '').toString().toUpperCase();
    if (status == 'COMPLETED' || status == 'CANCELLED') return false;
    final scheduledAt = followUp['scheduledAt'];
    if (scheduledAt == null) return false;
    final date = DateTime.tryParse(scheduledAt.toString());
    return date != null && date.isBefore(DateTime.now());
  }

  void _showCreateSheet() async {
    await _loadLeads();
    if (!mounted) return;

    String? selectedLeadId;
    String type = 'CALL';
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.accent.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Schedule Follow-Up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedLeadId,
                  decoration: const InputDecoration(labelText: 'Select Deal *'),
                  items: _leads
                      .map(
                        (l) => DropdownMenuItem(
                          value: l['id']?.toString(),
                          child: Text(
                            (l['contact'] is Map ? l['contact']['name'] : null)
                                ?? l['name']?.toString()
                                ?? l['customerName']?.toString()
                                ?? 'Unknown',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedLeadId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scheduled At'),
                  subtitle: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setSheetState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['CALL', 'MEETING', 'VISIT']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (selectedLeadId == null) return;
                    try {
                      await _api.createCrmFollowUp(
                        dealId: selectedLeadId!,
                        scheduledAt: selectedDate,
                        type: type,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  child: const Text('Schedule Follow-Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _completeFollowUp(Map<String, dynamic> followUp) {
    String? selectedOutcome;
    final notesCtrl = TextEditingController();
    const outcomes = [
      'INTERESTED',
      'CALL_LATER',
      'VISIT_PLANNED',
      'TEST_DRIVE_PLANNED',
      'QUOTATION_REQUIRED',
      'BOOKING_EXPECTED',
      'NOT_INTERESTED',
      'LOST',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Complete Follow-Up',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Outcome *',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: outcomes.map((o) => GestureDetector(
                    onTap: () => setSheetState(() => selectedOutcome = o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selectedOutcome == o ? AppColors.primary : AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedOutcome == o ? AppColors.primary : AppColors.textHint.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        o.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedOutcome == o ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (selectedOutcome == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please select an outcome')),
                      );
                      return;
                    }
                    try {
                      await _api.completeCrmFollowUp(
                        followUp['id'].toString(),
                        outcome: selectedOutcome!,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Complete Follow-Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _rescheduleFollowUp(Map<String, dynamic> followUp) async {
    DateTime selected = DateTime.now().add(const Duration(hours: 1));
    final existing = followUp['scheduledAt'];
    if (existing != null) {
      selected = DateTime.tryParse(existing.toString()) ?? selected;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Reschedule Follow-Up',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('New Date & Time'),
                subtitle: Text(
                  '${selected.day}/${selected.month}/${selected.year} ${selected.hour}:${selected.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && ctx.mounted) {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(selected),
                    );
                    if (time != null) {
                      setSS(() {
                        selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await _api.rescheduleFollowUp(
                      followUp['id'].toString(),
                      selected.toUtc().toIso8601String(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
                child: const Text('Confirm Reschedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }
    return Container(
      color: AppColors.scaffoldBg,
      child: Stack(
        children: [
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _followUps.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _followUps.length,
                          itemBuilder: (_, i) => _buildFollowUpCard(_followUps[i]),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: null,
              backgroundColor: AppColors.primary,
              onPressed: _showCreateSheet,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final statuses = ['', 'PENDING', 'COMPLETED'];
    final labels = ['All', 'Pending', 'Completed'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(statuses.length, (i) {
                  final selected = _filterStatus == statuses[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _filterStatus = statuses[i]);
                      _load();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.textHint.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _filterOverdue = !_filterOverdue);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filterOverdue ? AppColors.error.withValues(alpha: 0.1) : AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _filterOverdue ? AppColors.error : AppColors.textHint.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 13,
                      color: _filterOverdue ? AppColors.error : AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'Overdue',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _filterOverdue ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp) {
    final isOverdue = _isOverdue(followUp);
    final status = (followUp['status'] ?? 'PENDING').toString().toUpperCase();
    final deal = followUp['deal'] is Map ? followUp['deal'] as Map : null;
    final dealContact = deal?['contact'] is Map ? deal!['contact'] as Map : null;
    final leadName = dealContact?['name']?.toString()
        ?? deal?['name']?.toString()
        ?? (followUp['lead'] is Map ? followUp['lead']['customerName'] : null)
        ?? followUp['leadName']?.toString()
        ?? 'Unknown';
    final scheduledAt = followUp['scheduledAt'] != null
        ? DateTime.tryParse(followUp['scheduledAt'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: AppColors.error, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isOverdue ? AppColors.error : AppColors.primary)
                          .withValues(alpha: 0.15),
                      (isOverdue ? AppColors.error : AppColors.accent)
                          .withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  followUp['type'] == 'CALL'
                      ? Icons.phone
                      : followUp['type'] == 'MEETING'
                      ? Icons.groups
                      : Icons.location_on,
                  color: isOverdue ? AppColors.error : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName.toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scheduledAt != null
                          ? '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}'
                          : 'No date',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          if (isOverdue) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          if (status == 'PENDING' || status == 'SCHEDULED') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => _completeFollowUp(followUp),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Complete',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _rescheduleFollowUp(followUp),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Reschedule',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'COMPLETED':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'CANCELLED':
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'No follow-ups',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to schedule one',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
