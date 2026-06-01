import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmLeadDetailScreen extends StatefulWidget {
  final String leadId;
  final String leadName;

  const CrmLeadDetailScreen({
    super.key,
    required this.leadId,
    required this.leadName,
  });

  @override
  State<CrmLeadDetailScreen> createState() => _CrmLeadDetailScreenState();
}

class _CrmLeadDetailScreenState extends State<CrmLeadDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _lead = {};
  List<Map<String, dynamic>> _timeline = [];
  List<Map<String, dynamic>> _assignableUsers = [];
  bool _timelineLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([_loadDetail(), _loadTimeline()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDetail() async {
    try {
      final res = await _api.getLeadDetails(widget.leadId);
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      if (mounted) setState(() => _lead = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadTimeline() async {
    try {
      final res = await _api.getLeadTimeline(widget.leadId);
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      if (mounted) {
        setState(() {
          _timeline = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _timelineLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _timelineLoading = false);
    }
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final res = await _api.getAssignableUsers();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      _assignableUsers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  Future<void> _assignLead() async {
    await _loadAssignableUsers();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Lead'),
        content: SizedBox(
          width: double.maxFinite,
          child: _assignableUsers.isEmpty
              ? const Text('No users available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _assignableUsers.length,
                  itemBuilder: (_, i) {
                    final u = _assignableUsers[i];
                    return ListTile(
                      title: Text(
                        '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
                      ),
                      onTap: () async {
                        try {
                          await _api.assignLead(widget.leadId, u['id']);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadDetail();
                        } catch (_) {}
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _markLost() async {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Lost'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Why is this lead lost?',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.markLeadLost(
                  widget.leadId,
                  reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDetail();
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFollowUp() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String type = 'CALL';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Schedule Follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Tap to change date'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDlgState(() => selectedDate = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: type,
                items: ['CALL', 'VISIT', 'EMAIL', 'WHATSAPP']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setDlgState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.createFollowUp(
                    leadId: widget.leadId,
                    scheduledAt: selectedDate,
                    type: type,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Follow-up scheduled', success: true);
                  _loadTimeline();
                } catch (e) {
                  _showSnack('Failed: $e');
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: SizedBox.expand(
        child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadAll,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInfoCard(),
                              const SizedBox(height: 12),
                              _buildActionRow(),
                              const SizedBox(height: 12),
                              _buildTimelineSection(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.leadName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Lead Details',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildStatusChip(),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = (_lead['status'] ?? 'OPEN').toString();
    Color color;
    switch (status.toUpperCase()) {
      case 'CONVERTED':
        color = AppColors.success;
        break;
      case 'LOST':
        color = AppColors.error;
        break;
      default:
        color = AppColors.accent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final lead = _lead;
    final priority = lead['priority']?.toString() ?? '';
    final source = lead['source']?.toString() ?? '';
    final phone = lead['phone']?.toString() ?? '';
    final model = lead['interestedModel']?.toString() ?? '';
    final buyerType = lead['buyerType']?.toString() ?? '';

    String assignedName = 'Unassigned';
    final assignedTo = lead['assignedTo'];
    if (assignedTo is Map) {
      assignedName = '${assignedTo['firstName'] ?? ''} ${assignedTo['lastName'] ?? ''}'.trim();
    }

    String stageName = '';
    final stage = lead['stage'];
    if (stage is Map) stageName = stage['name']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead['customerName'] ?? widget.leadName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (priority.isNotEmpty) _priorityBadge(priority),
            ],
          ),
          const Divider(height: 24),
          _infoRow(Icons.person_outline_rounded, 'Assigned to', assignedName),
          if (stageName.isNotEmpty) _infoRow(Icons.flag_outlined, 'Stage', stageName),
          if (source.isNotEmpty) _infoRow(Icons.source_outlined, 'Source', source),
          if (model.isNotEmpty) _infoRow(Icons.directions_car_outlined, 'Model', model),
          if (buyerType.isNotEmpty) _infoRow(Icons.category_outlined, 'Buyer Type', buyerType),
        ],
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    Color c;
    switch (priority.toUpperCase()) {
      case 'HOT':
        c = AppColors.error;
        break;
      case 'WARM':
        c = AppColors.warning;
        break;
      case 'COLD':
        c = AppColors.accent;
        break;
      default:
        c = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final status = (_lead['status'] ?? 'OPEN').toString().toUpperCase();
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            'Assign',
            Icons.person_add_alt_1_rounded,
            AppColors.primary,
            _assignLead,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            'Follow-up',
            Icons.calendar_today_rounded,
            AppColors.warning,
            _addFollowUp,
          ),
        ),
        if (status == 'OPEN') ...[
          const SizedBox(width: 10),
          Expanded(
            child: _actionBtn(
              'Mark Lost',
              Icons.cancel_outlined,
              AppColors.error,
              _markLost,
            ),
          ),
        ],
        if (status == 'LOST') ...[
          const SizedBox(width: 10),
          Expanded(
            child: _actionBtn(
              'Reopen',
              Icons.refresh_rounded,
              AppColors.success,
              () async {
                try {
                  await _api.reopenLead(widget.leadId);
                  _loadDetail();
                } catch (_) {}
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timeline',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_timelineLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_timeline.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No activity yet',
                style: TextStyle(color: AppColors.textHint, fontSize: 13),
              ),
            ),
          )
        else
          ..._timeline.map((event) => _buildTimelineItem(event)),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? 'NOTE';
    final notes = event['notes']?.toString() ?? '';
    final createdAt = event['createdAt']?.toString() ?? '';

    IconData icon;
    Color color;
    switch (type.toUpperCase()) {
      case 'CALL':
        icon = Icons.phone_rounded;
        color = AppColors.primary;
        break;
      case 'FOLLOW_UP':
        icon = Icons.calendar_today_rounded;
        color = AppColors.warning;
        break;
      case 'VISIT':
        icon = Icons.directions_car_rounded;
        color = AppColors.accent;
        break;
      case 'STATUS_CHANGE':
        icon = Icons.swap_horiz_rounded;
        color = AppColors.success;
        break;
      default:
        icon = Icons.note_outlined;
        color = AppColors.textSecondary;
    }

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'Failed to load lead details',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }
}
