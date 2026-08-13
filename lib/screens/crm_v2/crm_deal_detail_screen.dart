import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../call_recorder_screen.dart';
import '../call_upload_screen.dart';
import '../ai_sales_call/ai_call_bottom_sheet.dart';

class CrmDealDetailScreen extends StatefulWidget {
  final String dealId;
  final String dealName;
  const CrmDealDetailScreen({
    super.key,
    required this.dealId,
    required this.dealName,
  });
  @override
  State<CrmDealDetailScreen> createState() => _CrmDealDetailScreenState();
}

class _CrmDealDetailScreenState extends State<CrmDealDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _auth = AuthService();
  UserModel? _currentUser;
  bool _loading = true;
  Map<String, dynamic>? _deal;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _stageHistory = [];
  List<Map<String, dynamic>> _pipelineStages = [];
  List<Map<String, dynamic>> _calls = [];
  late TabController _tabController;

  static const _activityTypes = ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _auth.getUser().then((u) {
      if (mounted) setState(() => _currentUser = u);
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmDeal(widget.dealId);
      final raw = res.data;
      _deal = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;

      final pipelineId = _deal?['pipelineId'] as String?;
      if (pipelineId != null) {
        try {
          final pRes = await _api.getCrmPipeline(pipelineId);
          final pRaw = pRes.data;
          final pData = pRaw is Map ? pRaw['data'] ?? pRaw : {};
          final stages = pData['stages'];
          if (stages is List) {
            _pipelineStages = stages
                .map((s) => Map<String, dynamic>.from(s))
                .toList();
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Activities (timeline)
    final contactId = _deal?['contactId'] as String?;
    if (contactId != null) {
      try {
        final res = await _api.getCrmActivities(
          contactId: contactId,
          limit: 50,
        );
        final raw = res.data;
        _activities =
            (raw is List
                    ? raw
                    : ((raw is Map ? raw['data'] ?? [] : []) as List))
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
      } catch (_) {
        _activities = [];
      }
    }

    // Follow-ups
    try {
      final res = await _api.getCrmFollowUpsByDeal(widget.dealId);
      final raw = res.data;
      _followUps =
          (raw is List ? raw : ((raw is Map ? raw['data'] ?? [] : []) as List))
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
    } catch (_) {
      _followUps = [];
    }

    // Stage history (activities of type STAGE_CHANGE for this deal)
    try {
      final res = await _api.getCrmActivities(dealId: widget.dealId, limit: 50);
      final raw = res.data;
      _stageHistory =
          (raw is List ? raw : ((raw is Map ? raw['data'] ?? [] : []) as List))
              .map((e) => Map<String, dynamic>.from(e))
              .where(
                (a) =>
                    a['type'] == 'STAGE_CHANGE' || a['type'] == 'stage_change',
              )
              .toList();
    } catch (_) {
      _stageHistory = [];
    }

    // Calls
    try {
      final res = await _api.getCallsByDeal(widget.dealId);
      final raw = res.data;
      _calls =
          (raw is List ? raw : ((raw is Map ? raw['data'] ?? [] : []) as List))
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
    } catch (_) {
      _calls = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigateToRecorder() {
    final deal = _deal ?? {};
    final name = _displayName(deal);
    final phone = (deal['contact']?['phone'] ?? '').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DealSubWrapper(
          title: name,
          child: CallRecorderScreen(
            dealId: widget.dealId,
            leadCustomerName: name,
            leadPhone: phone,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  void _navigateToUpload() {
    final deal = _deal ?? {};
    final name = _displayName(deal);
    final phone = (deal['contact']?['phone'] ?? '').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DealSubWrapper(
          title: 'Upload Call',
          child: CallUploadScreen(
            dealId: widget.dealId,
            leadName: name,
            leadPhone: phone,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showAssignPicker() async {
    List<Map<String, dynamic>> users = [];
    try {
      final branchId = _currentUser?.branchId;
      if (branchId != null && branchId.isNotEmpty) {
        final res = await _api.getBranchTeam(branchId);
        final raw = res.data;
        final list = raw is List
            ? raw
            : (raw is Map ? (raw['data'] ?? []) : []);
        users = (list as List)
            .map((u) {
              final fn = u['user']?['firstName'] ?? u['firstName'] ?? '';
              final ln = u['user']?['lastName'] ?? u['lastName'] ?? '';
              final id = u['user']?['id'] ?? u['userId'] ?? u['id'] ?? '';
              return {'id': id, 'name': '$fn $ln'.trim()};
            })
            .where((u) => (u['id'] as String).isNotEmpty)
            .toList();
      } else {
        final res = await _api.getUsers();
        final raw = res.data;
        final list = raw is List
            ? raw
            : (raw is Map ? (raw['data'] ?? []) : []);
        users = (list as List)
            .map((u) {
              final fn = u['firstName'] ?? '';
              final ln = u['lastName'] ?? '';
              return {'id': u['id'] ?? '', 'name': '$fn $ln'.trim()};
            })
            .where((u) => (u['id'] as String).isNotEmpty)
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;

    final branchName =
        _currentUser?.branchName ?? _deal?['branch']?['name'] ?? '';
    final currentOwnerId = _deal?['ownerUserId'] as String?;
    Map<String, dynamic>? selectedUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Reassign Lead',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Assign this lead to a different team member',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Branch locked field
                    if (branchName.isNotEmpty) ...[
                      const Text(
                        'Branch',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              branchName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New Owner label
                    Row(
                      children: [
                        const Text(
                          'New Owner',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),

              // User list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.35,
                ),
                child: users.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No users found',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final isCurrent = u['id'] == currentOwnerId;
                          final isSelected = selectedUser?['id'] == u['id'];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: (isSelected
                                  ? AppColors.primary
                                  : AppColors.primarySurface),
                              child: Text(
                                (u['name'] as String).isNotEmpty
                                    ? (u['name'] as String)[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              '${u['name']}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: isCurrent
                                ? const Text(
                                    'Current owner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => setSheet(() => selectedUser = u),
                          );
                        },
                      ),
              ),

              // Action buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.surfaceLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: selectedUser == null
                            ? null
                            : () async {
                                final picked = selectedUser!;
                                Navigator.pop(ctx);
                                try {
                                  await _api.updateCrmDeal(widget.dealId, {
                                    'ownerUserId': picked['id'],
                                  });
                                  _msg('Assigned to ${picked['name']}');
                                  _load();
                                } catch (e) {
                                  _msg('Failed: $e', error: true);
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Reassign',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoveStage() {
    if (_pipelineStages.isEmpty) {
      _msg('No stages available', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Move to Stage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            ..._pipelineStages.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${s['name']}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: _deal?['stageId'] == s['id']
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.moveCrmDealStage(
                      widget.dealId,
                      s['id'].toString(),
                    );
                    _msg('Stage updated');
                    _load();
                  } catch (e) {
                    _msg('Failed: $e', error: true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkLost() {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mark as Lost',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Lost Reason (optional)',
                alignLabelWithHint: true,
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.markDealLost(
                      widget.dealId,
                      lostReason: reasonCtrl.text.trim().isNotEmpty
                          ? reasonCtrl.text.trim()
                          : null,
                    );
                    _msg('Deal marked as lost');
                    _load();
                  } catch (e) {
                    _msg('Failed: $e', error: true);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Mark as Lost'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddFollowUp() {
    const followUpTypes = ['CALL', 'EMAIL', 'MEETING', 'TASK'];
    String selectedType = 'CALL';
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final notesCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Follow-up',
                      style: TextStyle(
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
              Row(
                children: followUpTypes.map((t) {
                  final sel = selectedType == t;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedType = t),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) setSheet(() => selectedDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                  : 'Pick date',
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (t != null) setSheet(() => selectedTime = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedTime != null
                                  ? selectedTime!.format(ctx)
                                  : 'Pick time',
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      _msg('Select a date', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      DateTime scheduled = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime?.hour ?? 9,
                        selectedTime?.minute ?? 0,
                      );
                      await _api.createCrmFollowUp(
                        dealId: widget.dealId,
                        contactId: _deal?['contactId']?.toString(),
                        type: selectedType,
                        scheduledAt: scheduled,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                        assignedToUserId: _currentUser?.id,
                      );
                      _msg('Follow-up added');
                      _load();
                    } catch (e) {
                      String errMsg = 'Failed to add follow-up';
                      if (e is DioException) {
                        final body = e.response?.data;
                        if (body is Map) {
                          final msg = body['message'];
                          errMsg =
                              (msg is List
                                  ? msg.join(', ')
                                  : msg?.toString()) ??
                              errMsg;
                        }
                      }
                      _msg(errMsg, error: true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add Follow-up'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogActivity() {
    String selectedType = _activityTypes.first;
    final notesCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Log Activity',
                      style: TextStyle(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: _activityTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(
                      () => selectedType = v ?? _activityTypes.first,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _api.createCrmActivityLog(
                        type: selectedType,
                        dealId: widget.dealId,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                      );
                      _msg('Activity logged');
                      _load();
                    } catch (e) {
                      _msg('Failed: $e', error: true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Log Activity'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _displayName(Map<String, dynamic> deal) {
    final contactName = deal['contact']?['name'] ?? deal['contactName'] ?? '';
    return contactName.isNotEmpty
        ? contactName
        : (deal['name'] ?? widget.dealName)
              .toString()
              .split(' - ')
              .first
              .trim();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _fmtDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day}/${dt.year % 100}, $h:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  int _daysInStage(Map<String, dynamic> deal) {
    final raw = deal['stageEnteredAt'];
    if (raw == null) return 0;
    try {
      return DateTime.now()
          .difference(DateTime.parse(raw.toString()).toLocal())
          .inDays;
    } catch (_) {
      return 0;
    }
  }

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'CALL':
        return Icons.phone_rounded;
      case 'EMAIL':
        return Icons.email_rounded;
      case 'MEETING':
        return Icons.groups_rounded;
      case 'TASK':
        return Icons.task_alt_rounded;
      case 'LEAD_CREATED':
        return Icons.person_add_rounded;
      case 'STAGE_CHANGE':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.notes_rounded;
    }
  }

  Color _activityColor(String? type) {
    switch (type) {
      case 'CALL':
        return AppColors.primary;
      case 'EMAIL':
        return AppColors.accent;
      case 'MEETING':
        return AppColors.success;
      case 'LEAD_CREATED':
        return AppColors.warning;
      case 'STAGE_CHANGE':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _scoreLabel(num? score) {
    if (score == null) return 'Pending';
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Average';
    return 'Poor';
  }

  Color _scoreColor(num? score) {
    if (score == null) return AppColors.textHint;
    if (score >= 80) return AppColors.success;
    if (score >= 60) return const Color(0xFF0EA5E9);
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Material(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final deal = _deal ?? {};
    final name = _displayName(deal);
    final status = deal['status'] as String?;
    final value = num.tryParse(
      (deal['expectedValue'] ?? deal['value'] ?? '').toString(),
    )?.toDouble();
    final contactPhone = deal['contact']?['phone'] ?? '';
    final contactEmail = deal['contact']?['email'] ?? '';
    final currentStageId = deal['stageId'] as String?;

    return Material(
      color: AppColors.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Gradient header ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back arrow aligned to name line
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Contact info column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (contactPhone.toString().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  contactPhone.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (contactEmail.toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_rounded,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    contactEmail.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Value badge top-right
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹${value.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── White section: stage bar + actions ───────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stage progress chips
                  if (_pipelineStages.isNotEmpty) ...[
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _pipelineStages.map((s) {
                          final isActive = s['id'] == currentStageId;
                          return GestureDetector(
                            onTap: isActive
                                ? null
                                : () async {
                                    try {
                                      await _api.moveCrmDealStage(
                                        widget.dealId,
                                        s['id'].toString(),
                                      );
                                      _msg('Moved to ${s['name']}');
                                      _load();
                                    } catch (e) {
                                      _msg('Failed: $e', error: true);
                                    }
                                  },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${s['name']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Action buttons row 1: Record | Upload | Log Activity | Follow-up
                  Row(
                    children: [
                      _actionBtn(
                        Icons.mic_rounded,
                        'Record',
                        AppColors.primary,
                        _navigateToRecorder,
                      ),
                      const SizedBox(width: 6),
                      _actionBtn(
                        Icons.cloud_upload_rounded,
                        'Upload Call',
                        const Color(0xFF0EA5E9),
                        _navigateToUpload,
                      ),
                      const SizedBox(width: 6),
                      _actionBtn(
                        Icons.edit_note_rounded,
                        'Log Activity',
                        AppColors.warning,
                        _showLogActivity,
                      ),
                      const SizedBox(width: 6),
                      _actionBtn(
                        Icons.calendar_month_rounded,
                        'Follow-up',
                        const Color(0xFF8B5CF6),
                        _showAddFollowUp,
                      ),
                      const SizedBox(width: 6),
                      _actionBtn(
                        Icons.smart_toy_rounded,
                        'AI Call',
                        const Color(0xFF6366F1),
                        () {
                          showAiCallBottomSheet(
                            context,
                            targetName: widget.dealName,
                            dealId: widget.dealId,
                            contactId: _deal?['contactId'] as String?,
                            onSuccess: _load,
                          );
                        },
                      ),
                    ],
                  ),
                  // Action buttons row 2 (OPEN deals): Move Stage | Won | Lost | Delete
                  if (status == 'OPEN') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _actionBtn(
                          Icons.swap_horiz_rounded,
                          'Move Stage',
                          AppColors.primary,
                          _showMoveStage,
                        ),
                        const SizedBox(width: 6),
                        _actionBtn(
                          Icons.check_circle_outline_rounded,
                          'Won',
                          AppColors.success,
                          () async {
                            try {
                              await _api.markDealWon(widget.dealId);
                              _msg('Marked as won');
                              _load();
                            } catch (e) {
                              _msg('Failed: $e', error: true);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        _actionBtn(
                          Icons.cancel_outlined,
                          'Lost',
                          AppColors.error,
                          _showMarkLost,
                        ),
                        const SizedBox(width: 6),
                        _actionBtn(
                          Icons.delete_outline_rounded,
                          'Delete',
                          AppColors.error,
                          () {
                            showDialog(
                              context: context,
                              builder: (d) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  'Delete Deal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                content: Text('Delete "$name"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      Navigator.pop(d);
                                      final nav = Navigator.of(context);
                                      try {
                                        await _api.deleteCrmDeal(widget.dealId);
                                        _msg('Deal deleted');
                                        if (mounted) nav.pop();
                                      } catch (e) {
                                        _msg('Failed: $e', error: true);
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    indicatorColor: AppColors.primary,
                    dividerColor: AppColors.surfaceLight,
                    tabs: [
                      _tab('Timeline', _activities.length),
                      _tab('Follow-ups', _followUps.length),
                      _tab('Calls & Analysis', _calls.length),
                      _tab('Stage History', _stageHistory.length),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tab content ──────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _timelineTab(),
                    _followUpsTab(),
                    _callsTab(),
                    _stageHistoryTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Tab _tab(String label, int count) => Tab(text: '$label ($count)');

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  // ── Contact + Deal Info (shown at top of each tab) ─────────────────────────

  Widget _infoSection(Map<String, dynamic> deal) {
    final value = num.tryParse(
      (deal['expectedValue'] ?? deal['value'] ?? '').toString(),
    )?.toDouble();
    final priority = (deal['priority'] ?? '').toString();
    final ownerFirst = deal['owner']?['firstName'] ?? '';
    final ownerLast = deal['owner']?['lastName'] ?? '';
    final assignedTo = '$ownerFirst $ownerLast'.trim();
    final daysInStage = _daysInStage(deal);
    final createdAt = _fmtDate(deal['createdAt']?.toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deal info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.work_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Deal Info',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (value != null)
                  _infoRow('Value', '₹${value.toStringAsFixed(2)}'),
                if (priority.isNotEmpty) _infoRow('Priority', priority),
                _assignRow(assignedTo),
                _infoRow('Days in Stage', '${daysInStage}d'),
                if (createdAt.isNotEmpty) _infoRow('Created', createdAt),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  Widget _assignRow(String currentName) => GestureDetector(
    onTap: _showAssignPicker,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Assigned To',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  currentName.isNotEmpty ? currentName : 'Unassigned',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: currentName.isNotEmpty
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ── Timeline tab ───────────────────────────────────────────────────────────

  Widget _timelineTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _infoSection(_deal ?? {}),
        if (_activities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'No activities yet',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _showLogActivity,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log Activity'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._activities.map((a) => _activityCard(a)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _activityCard(Map<String, dynamic> a) {
    final type = a['type'] as String?;
    final notes = a['notes'] ?? '';
    final dateStr = _fmtDateTime(a['createdAt']?.toString());
    final color = _activityColor(type);
    final userFirst = a['user']?['firstName'] ?? a['createdByName'] ?? '';
    final userLast = a['user']?['lastName'] ?? '';
    final actorName = '$userFirst $userLast'.trim();
    final typeLabel = (type ?? 'Activity').replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_activityIcon(type), size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    if (actorName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          actorName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                if (notes.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$notes',
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

  // ── Follow-ups tab ─────────────────────────────────────────────────────────

  Future<void> _cancelDealFollowUp(Map<String, dynamic> followUp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Follow-up'),
        content: const Text('Are you sure you want to cancel this follow-up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.cancelCrmFollowUp(followUp['id'].toString());
      _msg('Follow-up cancelled');
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
  }

  Future<void> _rescheduleDealFollowUp(Map<String, dynamic> followUp) async {
    DateTime selected = DateTime.now().add(const Duration(hours: 1));
    final existing = followUp['scheduledAt'];
    if (existing != null) {
      selected = DateTime.tryParse(existing.toString())?.toLocal() ?? selected;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reschedule Follow-Up',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null && ctx.mounted) {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(selected),
                    );
                    if (t != null) {
                      setSS(
                        () => selected = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${selected.day}/${selected.month}/${selected.year}  ${selected.hour}:${selected.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  try {
                    await _api.rescheduleCrmFollowUp(
                      followUp['id'].toString(),
                      selected.toUtc().toIso8601String(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _msg('Follow-up rescheduled');
                    _load();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  void _completeDealFollowUp(Map<String, dynamic> followUp) {
    String? selectedOutcome;
    final notesCtrl = TextEditingController();
    PlatformFile? selectedFile;
    bool scheduleNext = false;
    DateTime? nextDate;
    String nextType = 'CALL';
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
    const followUpTypes = ['CALL', 'MEETING', 'EMAIL', 'VISIT', 'WHATSAPP'];

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
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Complete Follow-Up',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Outcome *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                          onTap: () => setSheetState(() => selectedOutcome = o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selectedOutcome == o
                                  ? AppColors.primary
                                  : AppColors.scaffoldBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selectedOutcome == o
                                    ? AppColors.primary
                                    : AppColors.textHint.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              o.replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedOutcome == o
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add notes about this follow-up...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload call recording
                const Text(
                  'Upload Call Recording (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setSheetState(() => selectedFile = result.files.first);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.textHint.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFile != null
                                ? selectedFile!.name
                                : 'Choose audio file...',
                            style: TextStyle(
                              fontSize: 13,
                              color: selectedFile != null
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedFile != null)
                          GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedFile = null),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Schedule next follow-up
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Schedule Next Follow-up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: scheduleNext,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setSheetState(() => scheduleNext = v),
                    ),
                  ],
                ),
                if (scheduleNext) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setSheetState(() => nextDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            nextDate != null
                                ? '${nextDate!.day}/${nextDate!.month}/${nextDate!.year}'
                                : 'Pick next date',
                            style: TextStyle(
                              fontSize: 13,
                              color: nextDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: followUpTypes.map((t) {
                      final sel = nextType == t;
                      return GestureDetector(
                        onTap: () => setSheetState(() => nextType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : AppColors.scaffoldBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textHint.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (selectedOutcome == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an outcome'),
                        ),
                      );
                      return;
                    }
                    try {
                      await _api.completeCrmFollowUp(
                        followUp['id'].toString(),
                        outcome: selectedOutcome!,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        nextFollowUpDate: scheduleNext && nextDate != null
                            ? nextDate!.toIso8601String()
                            : null,
                        nextFollowUpType: scheduleNext ? nextType : null,
                      );
                      if (selectedFile != null) {
                        try {
                          final (audioUrl, audioFileType) = await _api
                              .uploadAudioFile(selectedFile!.path!);
                          await _api.createCall(
                            customerName: _displayName(_deal ?? {}),
                            companyId: _currentUser?.companyId ?? '',
                            userId: _currentUser?.id ?? '',
                            dealId: widget.dealId,
                            audioUrl: audioUrl,
                            audioFileType: audioFileType,
                            followUpId: followUp['id'].toString(),
                          );
                        } catch (uploadErr) {
                          if (ctx.mounted) {
                            String uploadErrMsg = 'Audio upload failed';
                            if (uploadErr is DioException) {
                              final data = uploadErr.response?.data;
                              if (data is Map && data['message'] is String) {
                                uploadErrMsg = data['message'];
                              } else if (uploadErr.type ==
                                      DioExceptionType.connectionTimeout ||
                                  uploadErr.type ==
                                      DioExceptionType.sendTimeout) {
                                uploadErrMsg =
                                    'Upload timed out. Check your internet.';
                              }
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(uploadErrMsg),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _msg('Follow-up completed');
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('Mark as Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _followUpsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _showAddFollowUp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Add Follow-up',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_followUps.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No follow-ups scheduled',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          )
        else
          ..._followUps.map((f) {
            final type = f['type'] ?? '';
            final fStatus = f['status'] ?? 'PENDING';
            final scheduled = _fmtDateTime(f['scheduledAt']?.toString());
            final isDone = fStatus == 'COMPLETED' || fStatus == 'DONE';
            final isCancelled = fStatus == 'CANCELLED';
            final scheduledDt = f['scheduledAt'] != null
                ? DateTime.tryParse(f['scheduledAt'].toString())?.toLocal()
                : null;
            final isOverdue =
                !isDone &&
                !isCancelled &&
                scheduledDt != null &&
                scheduledDt.isBefore(DateTime.now());
            final color = isDone
                ? AppColors.success
                : isOverdue
                ? AppColors.error
                : AppColors.warning;
            final notes = f['notes'] ?? '';
            final outcome = (f['outcome'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverdue ? const Color(0xFFFEF2F2) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isOverdue
                    ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$type',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    fStatus,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                                if (isOverdue) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'OVERDUE',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (scheduled.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                scheduled,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOverdue
                                      ? AppColors.error
                                      : AppColors.textHint,
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                            if (notes.toString().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '$notes',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (isDone && outcome.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '→ ${outcome.replaceAll('_', ' ')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isDone && !isCancelled) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _actionBtn(
                          Icons.check_rounded,
                          'Done',
                          AppColors.success,
                          () => _completeDealFollowUp(f),
                        ),
                        const SizedBox(width: 6),
                        _actionBtn(
                          Icons.schedule_rounded,
                          'Reschedule',
                          AppColors.primary,
                          () => _rescheduleDealFollowUp(f),
                        ),
                        const SizedBox(width: 6),
                        _actionBtn(
                          Icons.close_rounded,
                          'Cancel',
                          AppColors.error,
                          () => _cancelDealFollowUp(f),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Calls & Analysis tab ───────────────────────────────────────────────────

  void _showCallSummary(String callId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallSummarySheet(callId: callId),
    );
  }

  Widget _callsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              '${_calls.length} call${_calls.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _navigateToUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Upload Call',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _navigateToRecorder,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded, size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Record',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_calls.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No calls recorded yet',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          )
        else
          ..._calls.map((c) {
            final score = c['sopScore'] != null
                ? num.tryParse('${c['sopScore']}')
                : null;
            final analysisStatus = (c['analysisStatus'] ?? '').toString();
            final dateStr = _fmtDateTime(c['createdAt']?.toString());
            final customerName = c['customerName'] ?? '';
            final duration = c['durationSeconds'] ?? c['duration'];
            final durationStr = duration != null
                ? _fmtDuration(num.tryParse('$duration')?.toInt() ?? 0)
                : '';
            final scoreColor = _scoreColor(score);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: score != null
                          ? Text(
                              '${score.toInt()}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            )
                          : Icon(
                              Icons.mic_rounded,
                              size: 18,
                              color: scoreColor,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (score != null)
                              Text(
                                _scoreLabel(score),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (customerName.toString().isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    customerName.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            if (durationStr.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 11,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    durationStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                analysisStatus.isEmpty
                                    ? 'PENDING'
                                    : analysisStatus,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showCallSummary(c['id'].toString()),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.summarize_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Stage History tab ──────────────────────────────────────────────────────

  Widget _stageHistoryTab() {
    if (_stageHistory.isEmpty) {
      return const Center(
        child: Text(
          'No stage changes yet',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _stageHistory.map((a) => _activityCard(a)).toList(),
    );
  }
}

// ── Local wrapper widget (no old CRM dependency) ───────────────────────────

class _DealSubWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _DealSubWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(
        children: [
          Container(
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
                colors: [
                  AppColors.gradientStart,
                  AppColors.gradientMid,
                  AppColors.gradientEnd,
                ],
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Call Summary Bottom Sheet ──────────────────────────────────────────────

class _CallSummarySheet extends StatefulWidget {
  final String callId;
  const _CallSummarySheet({required this.callId});
  @override
  State<_CallSummarySheet> createState() => _CallSummarySheetState();
}

class _CallSummarySheetState extends State<_CallSummarySheet> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _detail = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getAiInsightDetail(widget.callId);
      final raw = res.data;
      _detail = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : {};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildSectionScores(),
                    _buildSummary(),
                    _buildKeyPoints(),
                    if (_noContent())
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.hourglass_empty_rounded,
                              size: 32,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _detail['analysisStatus'] == 'MANUAL' ||
                                      _detail['analysisStatus'] == 'SKIPPED'
                                  ? 'This call was marked as ${_detail['analysisStatus']?.toString().toLowerCase()}.\nNo summary available.'
                                  : 'Analysis not yet completed.\nStatus: ${_detail['analysisStatus'] ?? 'PENDING'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  bool _noContent() {
    final ai = _detail['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final hasSections = (_detail['sectionScores'] as List? ?? []).isNotEmpty;
    final rawSummary =
        _detail['callSummary'] ?? ai['summary'] ?? ai['callSummary'] ?? '';
    final hasSummary = rawSummary is List
        ? rawSummary.isNotEmpty
        : rawSummary.toString().isNotEmpty;
    final raw = ai['keyDiscussionPoints'] ?? ai['keyPoints'] ?? [];
    final hasPoints = raw is List ? raw.isNotEmpty : false;
    return !hasSections && !hasSummary && !hasPoints;
  }

  Widget _buildHeader() {
    final score = _detail['sopScore'] != null
        ? num.tryParse(_detail['sopScore'].toString())
        : null;
    final name = _detail['customerName'] ?? 'Unknown';
    final status = _detail['analysisStatus'] ?? '';
    final duration = _detail['durationSeconds'] != null
        ? '${((_detail['durationSeconds'] as num) / 60).floor()}:${((_detail['durationSeconds'] as num).toInt() % 60).toString().padLeft(2, '0')}'
        : '';
    final scoreColor = score != null
        ? (score >= 70
              ? AppColors.success
              : score >= 40
              ? AppColors.warning
              : AppColors.error)
        : AppColors.textHint;

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: score != null
                ? scoreColor.withValues(alpha: 0.1)
                : AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: score != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.round()}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 10,
                          color: scoreColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  )
                : Icon(
                    status == 'PROCESSING'
                        ? Icons.hourglass_top
                        : Icons.schedule,
                    size: 24,
                    color: AppColors.textHint,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (duration.isNotEmpty)
                    Text(
                      '⏱ $duration',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionScores() {
    final sections = (_detail['sectionScores'] ?? []) as List;
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Section Scores',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...sections.map((s) {
          final sec = Map<String, dynamic>.from(s);
          final secScore = (sec['score'] ?? 0) as num;
          final secName = sec['title'] ?? sec['sectionName'] ?? '';
          final color = secScore >= 70
              ? AppColors.success
              : secScore >= 40
              ? AppColors.warning
              : AppColors.error;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: secScore / 100,
                          minHeight: 6,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${secScore.toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummary() {
    final ai = _detail['aiAnalysis'] as Map<String, dynamic>? ?? {};
    // callSummary lives directly on the call OR inside aiAnalysis
    final rawSummary =
        _detail['callSummary'] ?? ai['summary'] ?? ai['callSummary'] ?? '';
    final isEmpty = rawSummary is List
        ? rawSummary.isEmpty
        : rawSummary.toString().isEmpty;
    if (isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.summarize_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Call Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: rawSummary is List
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rawSummary.asMap().entries.map((e) {
                    final item = e.value is Map
                        ? Map<String, dynamic>.from(e.value as Map)
                        : <String, dynamic>{};
                    final answer = item['answer']?.toString() ?? '';
                    final question = item['question']?.toString() ?? '';
                    if (answer.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: e.key < rawSummary.length - 1 ? 8 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (question.isNotEmpty) ...[
                            Text(
                              question,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            answer,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Text(
                  rawSummary.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildKeyPoints() {
    final ai = _detail['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final raw = ai['keyDiscussionPoints'] ?? ai['keyPoints'] ?? [];
    List<String> points = [];
    if (raw is List) {
      points = raw.map((e) => e.toString()).toList();
    } else if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          points.addAll(value.map((e) => e.toString()));
        } else if (value is String &&
            value.isNotEmpty &&
            value != 'N/A' &&
            value != 'Not Discussed') {
          points.add('$key: $value');
        }
      });
    }
    if (points.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.list_alt_rounded,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            const Text(
              'Key Points',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...points
            .take(5)
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
