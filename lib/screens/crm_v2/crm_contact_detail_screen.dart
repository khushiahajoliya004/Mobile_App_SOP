import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../utils/error_helper.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'crm_deal_detail_screen.dart';
import '../ai_sales_call/ai_call_bottom_sheet.dart';

class CrmContactDetailScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  const CrmContactDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });
  @override
  State<CrmContactDetailScreen> createState() => _CrmContactDetailScreenState();
}

class _CrmContactDetailScreenState extends State<CrmContactDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _contact;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _deals = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _pipelines = [];
  int _tab = 0; // 0=Timeline, 1=Deals, 2=Follow-ups

  static const _activityTypes = ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmContact(widget.contactId);
      final raw = res.data;
      _contact = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : null;
    } catch (_) {}
    await Future.wait([
      _api
          .getCrmActivities(contactId: widget.contactId, limit: 50)
          .then((res) {
            final raw = res.data;
            _activities = raw is List
                ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
                : ((raw is Map ? (raw['data'] ?? []) : []) as List)
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
          })
          .catchError((_) {
            _activities = [];
          }),
      _api
          .getCrmDeals(search: _contact?['phone'] as String?)
          .then((res) {
            final raw = res.data;
            _deals = raw is List
                ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
                : ((raw is Map ? (raw['data'] ?? []) : []) as List)
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
          })
          .catchError((_) {
            _deals = [];
          }),
      _api
          .getCrmFollowUpsByContact(widget.contactId)
          .then((res) {
            final raw = res.data;
            _followUps = raw is List
                ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
                : ((raw is Map ? (raw['data'] ?? []) : []) as List)
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
          })
          .catchError((_) {
            _followUps = [];
          }),
      _api
          .getCrmPipelines()
          .then((res) {
            final raw = res.data;
            _pipelines = raw is List
                ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
                : ((raw is Map ? (raw['data'] ?? []) : []) as List)
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
          })
          .catchError((_) {
            _pipelines = [];
          }),
    ]);
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

  Future<void> _createNewDeal() async {
    if (_pipelines.isEmpty) {
      _msg('No pipelines configured', error: true);
      return;
    }
    final pipeline = _pipelines.firstWhere(
      (p) => p['isDefault'] == true,
      orElse: () => _pipelines.first,
    );
    final contactName = _contact?['name'] ?? widget.contactName;
    final now = DateTime.now();
    final dealName = '$contactName - ${now.day}/${now.month}/${now.year}';
    setState(() => _loading = true);
    try {
      final res = await _api.createCrmDeal(
        name: dealName,
        contactId: widget.contactId,
        pipelineId: pipeline['id'] as String,
      );
      final raw = res.data;
      String? newDealId;
      if (raw is Map) {
        final inner = raw['data'] ?? raw;
        if (inner is Map) newDealId = inner['id']?.toString();
      }
      _msg('Deal created');
      await _load();
      if (mounted && newDealId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CrmDealDetailScreen(dealId: newDealId!, dealName: contactName),
          ),
        );
      }
    } catch (e) {
      _msg('Failed: $e', error: true);
      setState(() => _loading = false);
    }
  }

  void _showLogActivity() {
    String selectedType = _activityTypes.first;
    final notesCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

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
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _dropdown<String>(
                selectedType,
                'Type',
                [
                  ..._activityTypes.map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
                (v) => setSheet(() => selectedType = v ?? _activityTypes.first),
              ),
              const SizedBox(height: 10),
              _field(titleCtrl, 'Title (optional)'),
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
                        contactId: widget.contactId,
                        title: titleCtrl.text.trim().isNotEmpty
                            ? titleCtrl.text.trim()
                            : null,
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

  void _showScheduleFollowUp() {
    String selectedType = 'CALL';
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
    final notesCtrl = TextEditingController();
    const types = ['CALL', 'EMAIL', 'MEETING', 'TASK'];

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
                      'Schedule Follow-up',
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
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _dropdown<String>(selectedType, 'Type', [
                ...types.map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ], (v) => setSheet(() => selectedType = v ?? 'CALL')),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: scheduledAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setSheet(() => scheduledAt = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled: ${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
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
                      final currentUser = await AuthService().getUser();
                      await _api.createCrmFollowUp(
                        contactId: widget.contactId,
                        scheduledAt: scheduledAt,
                        type: selectedType,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                        assignedToUserId: currentUser?.id,
                      );
                      _msg('Follow-up scheduled');
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
                  child: const Text('Schedule Follow-up'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _dropdown<T>(
    T value,
    String hint,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(fontSize: 14)),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  String _stageLabel(String? stage) {
    switch (stage) {
      case 'LEAD':
        return 'Lead';
      case 'QUALIFIED':
        return 'Qualified';
      case 'OPPORTUNITY':
        return 'Opportunity';
      case 'CUSTOMER':
        return 'Customer';
      default:
        return stage ?? '';
    }
  }

  Color _stageColor(String? stage) {
    switch (stage) {
      case 'LEAD':
        return AppColors.primary;
      case 'QUALIFIED':
        return AppColors.accent;
      case 'OPPORTUNITY':
        return AppColors.warning;
      case 'CUSTOMER':
        return AppColors.success;
      default:
        return AppColors.textHint;
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
        return const Color(0xFF8B5CF6);
      case 'STAGE_CHANGE':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTypeName(String? type) {
    if (type == null) return 'Activity';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Material(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    final contact = _contact ?? {};
    final name = contact['name'] ?? widget.contactName;
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';
    final altPhone = contact['alternatePhone'] ?? '';
    final profession = contact['profession'] ?? '';
    final city = contact['city'] ?? '';
    final address = contact['address'] ?? '';
    final stage = contact['lifecycleStage'] as String?;
    final source = contact['source'] ?? '';
    final company = contact['companyName'] ?? '';
    final ownerFirst = contact['owner']?['firstName'] ?? '';
    final ownerLast = contact['owner']?['lastName'] ?? '';
    final ownerName = '$ownerFirst $ownerLast'.trim();
    final createdAt = contact['createdAt'] as String?;
    String createdStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        createdStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    final stageColor = _stageColor(stage);

    return Material(
      color: AppColors.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Name row + actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: stageColor.withValues(alpha: 0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: stageColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$name',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (company.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                '$company',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (profession.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                '$profession',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (stage != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stageColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _stageLabel(stage),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: stageColor,
                                      ),
                                    ),
                                  ),
                                if (ownerName.isNotEmpty) ...[
                                  if (stage != null) const SizedBox(width: 6),
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      ownerName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (createdStr.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Added $createdStr',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Action buttons
                      Column(
                        children: [
                          Row(
                            children: [
                              _headerBtn(
                                Icons.add_rounded,
                                AppColors.primarySurface,
                                AppColors.primary,
                                _showLogActivity,
                                tooltip: 'Log Activity',
                              ),
                              const SizedBox(width: 6),
                              _headerBtn(
                                Icons.calendar_today_rounded,
                                AppColors.surfaceLight,
                                AppColors.textSecondary,
                                _showScheduleFollowUp,
                                tooltip: 'Follow-up',
                              ),
                              const SizedBox(width: 6),
                              _headerBtn(
                                Icons.refresh,
                                AppColors.surfaceLight,
                                AppColors.textSecondary,
                                _load,
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _createNewDeal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.handshake_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'New Deal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Contact chips row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (phone.isNotEmpty)
                        _infoChip(
                          Icons.phone_rounded,
                          phone,
                          AppColors.success,
                        ),
                      if (email.isNotEmpty)
                        _infoChip(Icons.email_rounded, email, AppColors.accent),
                      if (altPhone.isNotEmpty)
                        _infoChip(
                          Icons.phone_outlined,
                          altPhone,
                          AppColors.textSecondary,
                        ),
                      if (source.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$source',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Address line
                  if (city.isNotEmpty || address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            [
                              address,
                              city,
                            ].where((s) => s.isNotEmpty).join(', '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Timeline', 'Deals', 'Follow-ups']
                          .asMap()
                          .entries
                          .map((e) {
                            final selected = _tab == e.key;
                            final counts = [
                              _activities.length,
                              _deals.length,
                              _followUps.length,
                            ];
                            return GestureDetector(
                              onTap: () => setState(() => _tab = e.key),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${e.value} (${counts[e.key]})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: _tab == 0
                    ? _timelineTab()
                    : _tab == 1
                    ? _dealsTab()
                    : _followUpsTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBtn(
    IconData icon,
    Color bg,
    Color fg,
    VoidCallback onTap, {
    String? tooltip,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 16, color: fg),
    ),
  );

  Widget _infoChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _timelineTab() {
    if (_activities.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (_, i) {
        final a = _activities[i];
        final type = a['type'] as String?;
        final notes = a['notes'] ?? a['description'] ?? '';
        final outcome = a['outcome'] ?? '';
        final date = a['createdAt'] as String?;
        final userName = '${a['user']?['firstName'] ?? ''}'.trim();
        String dateStr = '';
        if (date != null) {
          try {
            final dt = DateTime.parse(date).toLocal();
            dateStr = '${dt.day}/${dt.month}/${dt.year}';
          } catch (_) {}
        }
        final color = _activityColor(type);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatTypeName(type),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        if (userName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                    if (notes.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$notes',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (outcome.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '→ $outcome',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dealsTab() {
    return Column(
      children: [
        if (_deals.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_deals.length} deal${_deals.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _createNewDeal,
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
                          Icons.add_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'New Deal',
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
          ),
        ],
        Expanded(
          child: _deals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No deals linked',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createNewDeal,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Create Deal'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _deals.length,
                  itemBuilder: (_, i) {
                    final d = _deals[i];
                    final status = d['status'] as String?;
                    final value = ((d['expectedValue'] ?? d['value']) as num?)
                        ?.toDouble();
                    final stageName =
                        d['stage']?['name'] ?? d['stageName'] ?? '';
                    final contactName =
                        d['contact']?['name'] ?? d['name'] ?? '';
                    final color = status == 'WON'
                        ? AppColors.success
                        : status == 'LOST'
                        ? AppColors.error
                        : AppColors.primary;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CrmDealDetailScreen(
                            dealId: d['id'].toString(),
                            dealName: contactName,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.handshake_rounded,
                                size: 16,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d['name'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (stageName.isNotEmpty)
                                    Text(
                                      stageName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (status != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                if (value != null)
                                  Text(
                                    '₹${value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _cancelContactFollowUp(Map<String, dynamic> followUp) async {
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

  void _completeContactFollowUp(Map<String, dynamic> followUp) {
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
                const Text(
                  'Complete Follow-Up',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
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
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
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
                const SizedBox(height: 16),
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
                          final user = await AuthService().getUser();
                          await _api.createCall(
                            customerName:
                                _contact?['name']?.toString() ??
                                widget.contactName,
                            companyId: user?.companyId ?? '',
                            userId: user?.id ?? '',
                            audioFilePath: selectedFile!.path,
                            audioFileName: selectedFile!.name,
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
                            // Report error to backend
                            try {
                              await _api.reportUploadError(
                                errorCode: 'UPLOAD_FAILED',
                                errorMessage: uploadErrMsg,
                                customerName:
                                    _contact?['name']?.toString() ??
                                    widget.contactName,
                                audioFileName: selectedFile?.name,
                                uploadSource: 'FOLLOW_UP',
                              );
                            } catch (_) {}
                          }
                        }
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _msg('Follow-up completed');
                      _load();
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  Widget _followUpsTab() {
    if (_followUps.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No follow-ups scheduled',
              style: TextStyle(color: AppColors.textHint),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showScheduleFollowUp,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Schedule Follow-up'),
            ),
          ],
        ),
      );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                '${_followUps.length} follow-up${_followUps.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showScheduleFollowUp,
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
                        Icons.add_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add',
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _followUps.length,
            itemBuilder: (_, i) {
              final f = _followUps[i];
              final type = f['type'] ?? '';
              final status = f['status'] ?? 'PENDING';
              final scheduled = f['scheduledAt'] as String?;
              final notes = f['notes'] ?? '';
              String dateStr = '';
              bool isOverdue = false;
              if (scheduled != null) {
                try {
                  final dt = DateTime.parse(scheduled).toLocal();
                  dateStr = '${dt.day}/${dt.month}/${dt.year}';
                  isOverdue =
                      status == 'PENDING' && dt.isBefore(DateTime.now());
                } catch (_) {}
              }
              final isDone = status == 'COMPLETED' || status == 'DONE';
              final color = isDone
                  ? AppColors.success
                  : isOverdue
                  ? AppColors.error
                  : AppColors.warning;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverdue && !isDone
                      ? const Color(0xFFFEF2F2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOverdue && !isDone
                        ? const Color(0xFFFCA5A5)
                        : AppColors.surfaceLight,
                  ),
                ),
                child: Row(
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
                              Expanded(
                                child: Text(
                                  '$type Follow-up',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isOverdue && !isDone
                                      ? AppColors.error
                                      : AppColors.textHint,
                                  fontWeight: isOverdue && !isDone
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          if (notes.toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '$notes',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDone) ...[
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _completeContactFollowUp(f),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _cancelContactFollowUp(f),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
