import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class FollowUpTrackerScreen extends StatefulWidget {
  const FollowUpTrackerScreen({super.key});

  @override
  State<FollowUpTrackerScreen> createState() => _FollowUpTrackerScreenState();
}

class _FollowUpTrackerScreenState extends State<FollowUpTrackerScreen> {
  final _api = ApiService();
  final _auth = AuthService();

  UserModel? _user;
  bool _loading = true;
  String _errorMsg = '';

  // Date filter: 'yesterday' | 'today' | 'tomorrow' | 'custom'
  String _datePreset = 'today';
  DateTime _selectedDate = DateTime.now();

  // Role-based filter
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _users = [];
  String? _selectedBranchId;
  String? _selectedUserId;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _completed = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await _auth.getUser();
    await _loadBranchesIfNeeded();
    await _load();
  }

  Future<void> _loadBranchesIfNeeded() async {
    final type = _user?.userType ?? '';
    final isCompany = type == 'COMPANY' || _user?.isSuperAdmin == true;
    if (!isCompany) return;
    try {
      final res = await _api.getBranches();
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw is Map ? raw['data'] ?? [] : []) as List);
      _branches = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
  }

  Future<void> _loadUsersForBranch(String branchId) async {
    try {
      final res = await _api.getUsersByBranch(branchId);
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw is Map ? raw['data'] ?? [] : []) as List);
      setState(() {
        _users = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _selectedUserId = null;
      });
    } catch (_) {
      setState(() => _users = []);
    }
  }

  // Start of local day → UTC ISO string (e.g. IST midnight = prev day 18:30 UTC)
  String _dateToIso(DateTime d) =>
      DateTime(d.year, d.month, d.day, 0, 0, 0).toUtc().toIso8601String();

  // End of local day → UTC ISO string
  String _dateToDayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59).toUtc().toIso8601String();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    final dateStr = _dateToIso(_selectedDate);
    final dateEnd = _dateToDayEnd(_selectedDate);
    try {
      final results = await Future.wait([
        _api.getCrmFollowUpsFiltered(
          fromDate: dateStr,
          toDate: dateEnd,
          status: 'PENDING',
          userId: _selectedUserId,
          branchId: _selectedBranchId,
          limit: 200,
        ),
        _api.getCrmFollowUpsFiltered(
          fromDate: dateStr,
          toDate: dateEnd,
          status: 'COMPLETED',
          userId: _selectedUserId,
          branchId: _selectedBranchId,
          limit: 200,
        ),
      ]);

      List<Map<String, dynamic>> extractList(dynamic raw) {
        final list = raw is List
            ? raw
            : ((raw is Map ? (raw['data'] ?? raw['items'] ?? []) : []) as List);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final pending = extractList(results[0].data)
        ..sort((a, b) {
          final da =
              DateTime.tryParse(a['scheduledAt']?.toString() ?? '') ??
              DateTime(2099);
          final db =
              DateTime.tryParse(b['scheduledAt']?.toString() ?? '') ??
              DateTime(2099);
          return da.compareTo(db);
        });
      final completed = extractList(results[1].data);

      setState(() {
        _pending = pending;
        _completed = completed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  void _setPreset(String preset) async {
    DateTime date;
    final now = DateTime.now();
    switch (preset) {
      case 'yesterday':
        date = now.subtract(const Duration(days: 1));
        break;
      case 'tomorrow':
        date = now.add(const Duration(days: 1));
        break;
      case 'custom':
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        date = picked;
        break;
      default:
        date = now;
    }
    setState(() {
      _datePreset = preset;
      _selectedDate = date;
    });
    _load();
  }

  bool _isOverdue(Map<String, dynamic> f) {
    final s = (f['status'] ?? '').toString().toUpperCase();
    if (s == 'COMPLETED' || s == 'CANCELLED') return false;
    final dt = DateTime.tryParse(f['scheduledAt']?.toString() ?? '');
    return dt != null && dt.isBefore(DateTime.now());
  }

  IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CALL':
        return Icons.phone_rounded;
      case 'MEETING':
        return Icons.handshake_rounded;
      case 'EMAIL':
        return Icons.email_rounded;
      case 'VISIT':
        return Icons.home_rounded;
      case 'WHATSAPP':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _priorityColor(String? p) {
    switch ((p ?? '').toUpperCase()) {
      case 'LOW':
        return AppColors.textHint;
      case 'MEDIUM':
        return AppColors.accent;
      case 'HIGH':
        return AppColors.warning;
      case 'URGENT':
        return AppColors.error;
      default:
        return AppColors.textHint;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $ampm';
  }

  String _formatDateHeader(DateTime d) {
    const months = [
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
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = days[d.weekday - 1];
    return '$weekday, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _contactOrDeal(Map<String, dynamic> f) {
    final contact = f['contact'];
    if (contact is Map && contact['name'] != null)
      return contact['name'].toString();
    final deal = f['deal'];
    if (deal is Map && deal['title'] != null) return deal['title'].toString();
    if (deal is Map && deal['name'] != null) return deal['name'].toString();
    return 'Unknown';
  }

  String _assignedTo(Map<String, dynamic> f) {
    final a = f['assignedTo'];
    if (a is Map) {
      final first = a['firstName'] ?? '';
      final last = a['lastName'] ?? '';
      return '$first $last'.trim();
    }
    return '';
  }

  bool get _isCompanyRole {
    final t = _user?.userType ?? '';
    return t == 'COMPANY' || _user?.isSuperAdmin == true;
  }

  bool get _isBranchManagerOrLeader {
    final role = _user?.branchRole ?? '';
    return role == 'BRANCH_MANAGER' || role == 'TEAM_LEADER';
  }

  Future<void> _showCompleteSheet(Map<String, dynamic> f) async {
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
                      'Mark as Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
                          onTap: () => setSS(() => selectedOutcome = o),
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
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
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
                    if (result != null && result.files.isNotEmpty)
                      setSS(() => selectedFile = result.files.first);
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
                            onTap: () => setSS(() => selectedFile = null),
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Schedule Next Follow-up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: scheduleNext,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setSS(() => scheduleNext = v),
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
                      if (d != null) setSS(() => nextDate = d);
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
                        onTap: () => setSS(() => nextType = t),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                        f['id'].toString(),
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
                          await _api.createCall(
                            customerName: _contactOrDeal(f),
                            companyId: _user?.companyId ?? '',
                            userId: _user?.id ?? '',
                            audioFilePath: selectedFile!.path,
                            audioFileName: selectedFile!.name,
                            followUpId: f['id'].toString(),
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
                            // Report error to backend
                            try {
                              await _api.reportUploadError(
                                errorCode: 'UPLOAD_FAILED',
                                errorMessage: uploadErrMsg,
                                customerName: _contactOrDeal(f),
                                audioFileName: selectedFile?.name,
                                uploadSource: 'FOLLOW_UP',
                              );
                            } catch (_) {}
                          }
                        }
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  child: const Text('Mark as Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRescheduleSheet(Map<String, dynamic> f) async {
    DateTime selected =
        DateTime.tryParse(f['scheduledAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));

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
                'Reschedule',
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
                    if (t != null)
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
                        '${selected.day}/${selected.month}/${selected.year}  ${_formatTime(selected.toIso8601String())}',
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
                      f['id'].toString(),
                      selected.toUtc().toIso8601String(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted)
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  Future<void> _cancelFollowUp(Map<String, dynamic> f) async {
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
      await _api.cancelCrmFollowUp(f['id'].toString());
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildDatePills(),
        if (_isCompanyRole || _isBranchManagerOrLeader) _buildFilterDropdowns(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                )
              : _errorMsg.isNotEmpty
              ? _buildError(_errorMsg)
              : (_pending.isEmpty && _completed.isEmpty)
              ? _buildEmpty()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_pending.isNotEmpty) ...[
                        _sectionHeader(
                          'PENDING',
                          _pending.length,
                          AppColors.warning,
                        ),
                        const SizedBox(height: 8),
                        ..._pending.map(_buildPendingCard),
                        const SizedBox(height: 16),
                      ],
                      if (_completed.isNotEmpty) ...[
                        _sectionHeader(
                          'COMPLETED',
                          _completed.length,
                          AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        ..._completed.map(_buildCompletedCard),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final total = _pending.length + _completed.length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatDateHeader(_selectedDate),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (!_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$total total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePills() {
    final pills = [
      ('yesterday', 'Yesterday'),
      ('today', 'Today'),
      ('tomorrow', 'Tomorrow'),
      ('custom', 'Custom'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: pills.map((p) {
            final sel = _datePreset == p.$1;
            return GestureDetector(
              onTap: () => _setPreset(p.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterDropdowns() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          if (_isCompanyRole && _branches.isNotEmpty) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranchId,
                    hint: const Text(
                      'All Branches',
                      style: TextStyle(fontSize: 12),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Branches',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ..._branches.map(
                        (b) => DropdownMenuItem<String>(
                          value: b['id']?.toString(),
                          child: Text(
                            b['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedBranchId = v;
                        _selectedUserId = null;
                        _users = [];
                      });
                      if (v != null) _loadUsersForBranch(v);
                      _load();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_isCompanyRole || _isBranchManagerOrLeader)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedUserId,
                    hint: const Text(
                      'All People',
                      style: TextStyle(fontSize: 12),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All People',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ..._users.map(
                        (u) => DropdownMenuItem<String>(
                          value: u['id']?.toString(),
                          child: Text(
                            '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                                .trim(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedUserId = v);
                      _load();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> f) {
    final overdue = _isOverdue(f);
    final type = (f['type'] ?? 'CALL').toString();
    final name = _contactOrDeal(f);
    final subject = f['subject']?.toString() ?? '';
    final time = _formatTime(f['scheduledAt']?.toString());
    final assigned = _assignedTo(f);
    final priority = (f['priority'] ?? 'MEDIUM').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: overdue ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: overdue ? AppColors.error : AppColors.primary,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (overdue ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _typeIcon(type),
                    size: 18,
                    color: overdue ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subject.isNotEmpty)
                        Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                    color: _priorityColor(priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(priority),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: overdue ? AppColors.error : AppColors.textSecondary,
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (overdue) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (assigned.isNotEmpty) ...[
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 12,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    assigned,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionBtn(
                  'Done',
                  AppColors.success,
                  Icons.check_rounded,
                  () => _showCompleteSheet(f),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  'Reschedule',
                  AppColors.primary,
                  Icons.schedule_rounded,
                  () => _showRescheduleSheet(f),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  'Cancel',
                  AppColors.error,
                  Icons.close_rounded,
                  () => _cancelFollowUp(f),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> f) {
    final name = _contactOrDeal(f);
    final completedAt = _formatTime(f['completedAt']?.toString());
    final outcome = (f['outcome'] ?? '').toString().replaceAll('_', ' ');
    final completedBy = _assignedTo(f);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (completedAt.isNotEmpty)
                      Text(
                        completedAt,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                if (outcome.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    outcome,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (completedBy.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'By $completedBy',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
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

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load follow-ups',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    const months = [
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
    final d = _selectedDate;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 14),
          Text(
            'No follow-ups for ${d.day} ${months[d.month - 1]} ${d.year}',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
