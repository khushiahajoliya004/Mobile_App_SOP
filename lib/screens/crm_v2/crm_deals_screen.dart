import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'crm_deal_detail_screen.dart';
import '../call_recorder_screen.dart';
import '../call_upload_screen.dart';

const _leadSources = [
  {'value': 'WALK_IN', 'label': 'Walk-in'},
  {'value': 'WEBSITE', 'label': 'Website'},
  {'value': 'REFERRAL', 'label': 'Referral'},
  {'value': 'PHONE', 'label': 'Phone Call'},
  {'value': 'SOCIAL', 'label': 'Social Media'},
  {'value': 'ADVERTISEMENT', 'label': 'Advertisement'},
  {'value': 'PARTNER', 'label': 'Partner'},
  {'value': 'EVENT', 'label': 'Event'},
];

class CrmDealsScreen extends StatefulWidget {
  final String? initialStatus;
  final String? initialDatePreset;
  const CrmDealsScreen({super.key, this.initialStatus, this.initialDatePreset});
  @override
  State<CrmDealsScreen> createState() => _CrmDealsScreenState();
}

class _CrmDealsScreenState extends State<CrmDealsScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _deals = [];
  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _assignableUsers = [];
  String? _selectedPipelineId;
  String _search = '';
  String? _filterBranchId;
  String? _filterOwnerUserId;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  late String _datePreset; // 'all','today','yesterday','week','month','custom'
  late String _statusFilter; // 'OPEN','WON','LOST'
  bool get _hasActiveFilters => _filterBranchId != null || _filterOwnerUserId != null || _datePreset != 'all';

  @override
  void initState() {
    super.initState();
    _datePreset = widget.initialDatePreset ?? 'today';
    _statusFilter = widget.initialStatus ?? 'OPEN';
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    debugPrint('[CrmDeals] user=${user?.email}, branchId=${user?.branchId}, branchName=${user?.branchName}');
    if (mounted) setState(() => _currentUser = user);
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      _pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (_pipelines.isNotEmpty && _selectedPipelineId == null) {
        _selectedPipelineId = _pipelines.first['id'] as String?;
      }
    } catch (_) {}
    try {
      final res = await _api.getBranches();
      final raw = res.data;
      _branches = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    // Load users: branch team if user has a branch, otherwise all assignable users
    if (user?.branchId != null && user!.branchId!.isNotEmpty) {
      try {
        final res = await _api.getBranchTeam(user.branchId!);
        _assignableUsers = _normalizeBranchTeam(res.data);
      } catch (_) {}
    } else {
      try {
        final res = await _api.getAssignableUsers();
        _assignableUsers = _normalizeUsers(res.data);
      } catch (_) {}
    }
    await _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String?, String?) get _resolvedDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case 'today':
        return (_fmt(today), _fmt(today));
      case 'yesterday':
        final y = today.subtract(const Duration(days: 1));
        return (_fmt(y), _fmt(y));
      case 'week':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (_fmt(start), _fmt(today));
      case 'month':
        return (_fmt(DateTime(now.year, now.month, 1)), _fmt(today));
      case 'custom':
        return (
          _filterFromDate != null ? _fmt(_filterFromDate!) : null,
          _filterToDate != null ? _fmt(_filterToDate!) : null,
        );
      default:
        return (null, null);
    }
  }

  String get _presetLabel {
    switch (_datePreset) {
      case 'today': return 'Today';
      case 'yesterday': return 'Yesterday';
      case 'week': return 'This Week';
      case 'month': return 'This Month';
      case 'custom':
        if (_filterFromDate != null && _filterToDate != null) {
          return '${_filterFromDate!.day}/${_filterFromDate!.month} – ${_filterToDate!.day}/${_filterToDate!.month}';
        }
        return 'Custom';
      default: return 'All Time';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (fromDate, toDate) = _resolvedDates;
    try {
      // Team leaders must NOT pass branchId — backend uses reportingToUserId hierarchy to scope deals.
      // Passing branchId would bypass team-leader visibility and show all branch deals instead.
      final isTeamLeader = _currentUser?.branchRole == 'TEAM_LEADER';
      debugPrint('[CrmDeals] calling getCrmDeals isTeamLeader=$isTeamLeader branchId=${isTeamLeader ? 'skipped' : _currentUser?.branchId}, pipelineId=$_selectedPipelineId');
      final res = await _api.getCrmDeals(
        pipelineId: _selectedPipelineId,
        search: _search.isNotEmpty ? _search : null,
        status: _statusFilter,
        branchId: _filterBranchId ?? (isTeamLeader ? null : _currentUser?.branchId),
        ownerUserId: _filterOwnerUserId,
        fromDate: fromDate,
        toDate: toDate,
      );
      final raw = res.data;
      _deals = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _deals = []; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _normalizeBranchTeam(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
    return (list as List).map((u) {
      final fn = u['user']?['firstName'] ?? u['firstName'] ?? '';
      final ln = u['user']?['lastName'] ?? u['lastName'] ?? '';
      final full = '$fn $ln'.trim();
      return <String, dynamic>{
        'id': u['userId'] ?? u['user']?['id'] ?? u['id'] ?? '',
        'name': full.isNotEmpty ? full : (u['name'] ?? ''),
        'roleName': u['branchRole'] ?? u['role'] ?? '',
      };
    }).where((u) => u['id'].toString().isNotEmpty && u['name'].toString().isNotEmpty).toList();
  }

  List<Map<String, dynamic>> _normalizeUsers(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
    return (list as List).map((u) {
      final fn = '${u['firstName'] ?? ''}';
      final ln = '${u['lastName'] ?? ''}';
      final full = '$fn $ln'.trim();
      return <String, dynamic>{
        'id': u['id'] ?? '',
        'name': full.isNotEmpty ? full : (u['name'] ?? ''),
        'branchName': u['branchName'] ?? '',
        'roleName': u['branchRole'] ?? u['userType'] ?? '',
      };
    }).where((u) => u['id'].toString().isNotEmpty && u['name'].toString().isNotEmpty).toList();
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  List<Map<String, dynamic>> get _currentPipelineStages {
    if (_selectedPipelineId == null) return [];
    try {
      final pipeline = _pipelines.firstWhere((p) => p['id'] == _selectedPipelineId);
      final stages = pipeline['stages'];
      if (stages is List) return stages.map((s) => Map<String, dynamic>.from(s)).toList();
    } catch (_) {}
    return [];
  }

  void _showCreateLeadForm() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String? selectedSource = 'WALK_IN';
    // Branch lock: single-branch users get auto-selected locked branch
    final branchLocked = _currentUser?.branchId != null && (_currentUser?.branchId?.isNotEmpty == true);
    String? selectedBranchId = branchLocked ? _currentUser!.branchId : null;
    String? selectedPipelineId = _pipelines.isNotEmpty
        ? (_pipelines.firstWhere((p) => p['isDefault'] == true, orElse: () => _pipelines.first)['id'] as String?)
        : null;
    Map<String, dynamic>? selectedOwner;
    bool createDeal = true;
    List<Map<String, dynamic>> branchUsers = List.from(_assignableUsers);
    String ownerSearch = '';
    bool showOwnerDropdown = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> reloadBranchUsers(String? branchId) async {
            try {
              if (branchId != null) {
                final res = await _api.getBranchTeam(branchId);
                setSheet(() { branchUsers = _normalizeBranchTeam(res.data); selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; });
              } else {
                final res = await _api.getAssignableUsers();
                setSheet(() { branchUsers = _normalizeUsers(res.data); selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; });
              }
            } catch (_) {}
          }

          Widget sectionHeader(String label) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
          );

          Widget formField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text, bool required = false}) => TextField(
            controller: ctrl, keyboardType: type,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          );

          Widget sourceDropdown() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSource,
                isExpanded: true,
                hint: const Text('Source', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                items: _leadSources.map((s) => DropdownMenuItem<String>(value: s['value'], child: Text(s['label']!, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setSheet(() => selectedSource = v),
              ),
            ),
          );

          Widget branchWidget() {
            if (branchLocked) {
              final branchName = _branches.firstWhere(
                (b) => b['id'] == selectedBranchId,
                orElse: () => {'name': _currentUser?.branchName ?? selectedBranchId ?? 'Branch'},
              )['name'] as String? ?? 'Branch';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(branchName, style: const TextStyle(fontSize: 14, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
                ]),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedBranchId,
                  isExpanded: true,
                  hint: const Text('All Branches', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Branches', style: TextStyle(fontSize: 14))),
                    ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'] as String?, child: Text('${b['name']}', style: const TextStyle(fontSize: 14)))),
                  ],
                  onChanged: (v) { setSheet(() => selectedBranchId = v); reloadBranchUsers(v); },
                ),
              ),
            );
          }

          Widget pipelineDropdown() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPipelineId,
                isExpanded: true,
                hint: const Text('Pipeline', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                items: _pipelines.map((p) => DropdownMenuItem<String>(value: p['id'] as String?, child: Text('${p['name']}', style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setSheet(() => selectedPipelineId = v),
              ),
            ),
          );

          final filteredUsers = ownerSearch.isEmpty
              ? branchUsers
              : branchUsers.where((u) => '${u['name']}'.toLowerCase().contains(ownerSearch.toLowerCase())).toList();
          final dropdownVisible = showOwnerDropdown && selectedOwner == null;

          return Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  // Header
                  Row(children: [
                    const Expanded(child: Text('Create Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary))),
                  ]),
                  const SizedBox(height: 18),
                  // ── CONTACT INFORMATION ──
                  sectionHeader('CONTACT INFORMATION'),
                  formField(nameCtrl, 'Customer name *'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: formField(phoneCtrl, 'Phone number *', type: TextInputType.phone)),
                    const SizedBox(width: 10),
                    Expanded(child: formField(emailCtrl, 'Email address', type: TextInputType.emailAddress)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: sourceDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: branchWidget()),
                  ]),
                  const SizedBox(height: 10),
                  // Assign To
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      onChanged: (v) => setSheet(() => ownerSearch = v),
                      onTap: () => setSheet(() => showOwnerDropdown = true),
                      decoration: InputDecoration(
                        hintText: selectedOwner != null ? '${selectedOwner!['name']}' : 'Search team member by name...',
                        hintStyle: TextStyle(fontSize: 14, color: selectedOwner != null ? AppColors.textPrimary : AppColors.textHint, fontWeight: selectedOwner != null ? FontWeight.w600 : FontWeight.normal),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
                        suffixIcon: selectedOwner != null
                            ? GestureDetector(onTap: () => setSheet(() { selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; }), child: const Icon(Icons.clear, size: 16, color: AppColors.textHint))
                            : (showOwnerDropdown ? GestureDetector(onTap: () => setSheet(() { showOwnerDropdown = false; ownerSearch = ''; }), child: const Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.textHint)) : null),
                        filled: true, fillColor: const Color(0xFFF5F6FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                    if (dropdownVisible) Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.surfaceLight), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: filteredUsers.isEmpty
                            ? [Padding(padding: const EdgeInsets.all(12), child: Text(branchUsers.isEmpty ? 'No team members in this branch' : 'No members found', style: const TextStyle(color: AppColors.textHint, fontSize: 13)))]
                            : filteredUsers.take(10).map((u) => InkWell(
                                onTap: () => setSheet(() { selectedOwner = u; ownerSearch = ''; showOwnerDropdown = false; }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(children: [
                                    CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text('${u['name']}'[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${u['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      if ((u['branchName'] ?? u['roleName'] ?? '').toString().isNotEmpty)
                                        Text('${u['branchName'] ?? ''}${u['roleName'] != null ? ' · ${u['roleName']}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                    ])),
                                  ]),
                                ),
                              )).toList(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // ── CREATE DEAL toggle ──
                  GestureDetector(
                    onTap: () => setSheet(() => createDeal = !createDeal),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: createDeal ? AppColors.primary : Colors.transparent,
                          border: Border.all(color: createDeal ? AppColors.primary : AppColors.textHint, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: createDeal ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 10),
                      const Text('CREATE DEAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.5)),
                    ]),
                  ),
                  if (createDeal) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: pipelineDropdown()),
                      const SizedBox(width: 10),
                      Expanded(child: formField(valueCtrl, 'Expected Value (₹)', type: TextInputType.number)),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Any initial notes...',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                      filled: true, fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Buttons ──
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.surfaceLight)),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) { _msg('Name is required', error: true); return; }
                        if (phoneCtrl.text.trim().isEmpty) { _msg('Phone is required', error: true); return; }
                        Navigator.pop(ctx);
                        setState(() => _loading = true);
                        try {
                          final res = await _api.createCrmQuickLead(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                            source: selectedSource,
                            branchId: selectedBranchId,
                            pipelineId: createDeal ? selectedPipelineId : null,
                            expectedValue: createDeal ? double.tryParse(valueCtrl.text) : null,
                            ownerUserId: selectedOwner?['id'] as String?,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            createDeal: createDeal,
                          );
                          _msg('Lead created');
                          _load();
                          // Show recording sheet if a deal was created
                          if (createDeal) {
                            final resData = res.data;
                            String? newDealId;
                            if (resData is Map) {
                              final inner = resData['data'] ?? resData;
                              if (inner is Map) {
                                final deal = inner['deal'];
                                if (deal is Map) newDealId = deal['id']?.toString();
                              }
                            }
                            if (mounted && newDealId != null) {
                              _showRecordingSheet(newDealId, nameCtrl.text.trim(), phoneCtrl.text.trim(), isNew: true);
                            }
                          }
                        } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
                      },
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Create Lead', style: TextStyle(fontWeight: FontWeight.w700)),
                    )),
                  ]),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  void _showMoveStage(Map<String, dynamic> deal) {
    final stages = _currentPipelineStages;
    if (stages.isEmpty) { _msg('No stages available', error: true); return; }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Move to Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12),
            ...stages.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['name']}', style: const TextStyle(fontSize: 14)),
              trailing: deal['stageId'] == s['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _api.moveCrmDealStage(deal['id'] as String, s['id'] as String);
                  _msg('Stage updated');
                  _load();
                } catch (e) { _msg('Failed: $e', error: true); }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showMarkLost(Map<String, dynamic> deal) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Mark as Lost', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Lost Reason (optional)',
                alignLabelWithHint: true,
                filled: true, fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.markDealLost(deal['id'] as String, lostReason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null);
                    _msg('Deal marked as lost');
                    _load();
                  } catch (e) { _msg('Failed: $e', error: true); }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Mark as Lost'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  void _showBranchFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Filter by Branch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All Branches'),
              trailing: _filterBranchId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () { setState(() => _filterBranchId = null); Navigator.pop(ctx); _load(); },
            ),
            ..._branches.map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${b['name']}'),
              trailing: _filterBranchId == b['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () { setState(() => _filterBranchId = b['id'] as String?); Navigator.pop(ctx); _load(); },
            )),
          ],
        ),
      ),
    );
  }

  void _showOwnerFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Filter by Owner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All Owners'),
                      trailing: _filterOwnerUserId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () { setState(() => _filterOwnerUserId = null); Navigator.pop(ctx); _load(); },
                    ),
                    ..._assignableUsers.map((u) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${u['name']}'),
                      subtitle: (u['branchName'] ?? u['roleName'] ?? '').toString().isNotEmpty
                          ? Text('${u['branchName'] ?? ''}${u['roleName'] != null ? ' · ${u['roleName']}' : ''}', style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: _filterOwnerUserId == u['id'] ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () { setState(() => _filterOwnerUserId = u['id'] as String?); Navigator.pop(ctx); _load(); },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDatePresetSheet() {
    const presets = [
      ('all', 'All Time', Icons.all_inclusive_rounded),
      ('today', 'Today', Icons.today_rounded),
      ('yesterday', 'Yesterday', Icons.history_rounded),
      ('week', 'This Week', Icons.view_week_rounded),
      ('month', 'This Month', Icons.calendar_month_rounded),
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              const Text('Filter by Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              ...presets.map((p) {
                final sel = _datePreset == p.$1;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: Icon(p.$3, size: 17, color: sel ? Colors.white : AppColors.textHint),
                  ),
                  title: Text(p.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : AppColors.textPrimary)),
                  trailing: sel ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() { _datePreset = p.$1; _filterFromDate = null; _filterToDate = null; });
                    _load();
                  },
                );
              }),
              // Custom range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _datePreset == 'custom' ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.date_range_rounded, size: 17, color: _datePreset == 'custom' ? Colors.white : AppColors.textHint),
                ),
                title: Text(
                  _datePreset == 'custom' && _filterFromDate != null && _filterToDate != null
                      ? '${_filterFromDate!.day}/${_filterFromDate!.month}/${_filterFromDate!.year} – ${_filterToDate!.day}/${_filterToDate!.month}/${_filterToDate!.year}'
                      : 'Custom Range',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _datePreset == 'custom' ? AppColors.primary : AppColors.textPrimary),
                ),
                trailing: _datePreset == 'custom' ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final from = await showDatePicker(
                    context: context,
                    initialDate: _filterFromDate ?? now,
                    firstDate: DateTime(2020),
                    lastDate: now,
                    helpText: 'Select start date',
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                  );
                  if (from == null || !mounted) return;
                  final to = await showDatePicker(
                    context: context,
                    initialDate: _filterToDate ?? from,
                    firstDate: from,
                    lastDate: now,
                    helpText: 'Select end date',
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                  );
                  if (to == null || !mounted) return;
                  setState(() { _datePreset = 'custom'; _filterFromDate = from; _filterToDate = to; });
                  _load();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : AppColors.surfaceLight),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: active ? Colors.white : AppColors.textSecondary),
        ]),
      ),
    );
  }

  void _navigateToRecorder(String dealId, String dealName, String phone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CrmV2Wrapper(
          title: dealName,
          child: CallRecorderScreen(
            dealId: dealId,
            leadCustomerName: dealName,
            leadPhone: phone,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  void _navigateToUpload(String dealId, String dealName, String phone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CrmV2Wrapper(
          title: 'Upload Call',
          child: CallUploadScreen(
            dealId: dealId,
            leadName: dealName,
            leadPhone: phone,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  void _showRecordingSheet(String dealId, String dealName, String phone, {bool isNew = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNew) const Text('Lead created!', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              Text(dealName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                isNew ? 'Do you want to start a recording?' : 'Add a recording for this lead',
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _navigateToUpload(dealId, dealName, phone); },
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Upload Call'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () { Navigator.pop(ctx); _navigateToRecorder(dealId, dealName, phone); },
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Start Recording'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
              ]),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Center(child: Text('Skip for now', style: TextStyle(color: AppColors.textHint))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _stageColor(String? status) {
    switch (status) {
      case 'WON': return AppColors.success;
      case 'LOST': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeamLeader = _currentUser?.branchRole == 'TEAM_LEADER';
    final branchLocked = !isTeamLeader && _currentUser?.branchId != null && (_currentUser?.branchId?.isNotEmpty == true);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) { _search = v; _load(); },
              decoration: InputDecoration(
                hintText: 'Search deals...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showCreateLeadForm,
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      if (_pipelines.isNotEmpty)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _pipelines.map((p) {
              final selected = _selectedPipelineId == p['id'];
              return GestureDetector(
                onTap: () { setState(() => _selectedPipelineId = p['id'] as String?); _load(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${p['name']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),
      // Filter row
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          children: [
            // Branch filter — hidden for team leaders and single-branch locked users
            if (!isTeamLeader && !branchLocked) ...[
              _buildFilterChip(
                label: _filterBranchId != null
                    ? (_branches.firstWhere((b) => b['id'] == _filterBranchId, orElse: () => {'name': 'Branch'})['name'] as String? ?? 'Branch')
                    : 'Branch',
                active: _filterBranchId != null,
                onTap: _showBranchFilter,
              ),
              const SizedBox(width: 8),
            ],
            // Owner filter
            _buildFilterChip(
              label: _filterOwnerUserId != null
                  ? (_assignableUsers.firstWhere((u) => u['id'] == _filterOwnerUserId, orElse: () => {'name': 'Owner'})['name'] as String? ?? 'Owner')
                  : 'Owner',
              active: _filterOwnerUserId != null,
              onTap: _showOwnerFilter,
            ),
            const SizedBox(width: 8),
            // Date preset dropdown
            _buildFilterChip(
              label: _presetLabel,
              active: _datePreset != 'all',
              onTap: _showDatePresetSheet,
            ),
            // Clear all filters
            if (_hasActiveFilters) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filterBranchId = null;
                    _filterOwnerUserId = null;
                    _filterFromDate = null;
                    _filterToDate = null;
                    _datePreset = 'all';
                  });
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.clear_rounded, size: 12, color: AppColors.error),
                    SizedBox(width: 4),
                    Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_deals.length} deals', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _deals.isEmpty
            ? const Center(child: Text('No deals found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _deals.length,
                  itemBuilder: (_, i) => _dealTile(_deals[i]),
                ),
              ),
      ),
    ]);
  }

  // Deterministic avatar color from name
  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0EA5E9),
      Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
      Color(0xFF06B6D4), Color(0xFF8B5CF6), Color(0xFFEC4899),
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % palette.length : 0;
    return palette[idx];
  }

  Widget _dealTile(Map<String, dynamic> deal) {
    final rawName = '${deal['name'] ?? ''}';
    final status = deal['status'] as String?;
    final rawValue = deal['expectedValue'] ?? deal['value'];
    final value = rawValue == null ? null : double.tryParse('$rawValue');
    final contactName = deal['contact']?['name'] ?? deal['contactName'] ?? '';
    final name = contactName.isNotEmpty ? contactName : rawName.split(' - ').first.trim();
    final phone = (deal['contact']?['phone'] ?? deal['phone'] ?? '').toString();
    final stageName = deal['stage']?['name'] ?? deal['stageName'] ?? '';
    final callCount = (deal['callCount'] ?? deal['totalCalls'] ?? (deal['calls'] is List ? (deal['calls'] as List).length : null) ?? 0) as num;
    final initials = name.trim().isEmpty ? '?' : name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final avatarColor = _avatarColor(name);
    final stageColor = _stageColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CrmDealDetailScreen(dealId: deal['id'].toString(), dealName: name)),
          ).then((_) => _load()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Initials avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              // Name + meta
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    if (stageName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(stageName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stageColor)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.call_rounded, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text('${callCount.toInt()} calls', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              // Right: value + actions
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (value != null && value > 0)
                  Text(
                    '₹${_formatValue(value)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  // Mic
                  _tinyAction(
                    icon: Icons.mic_rounded,
                    color: AppColors.primary,
                    onTap: () => _navigateToRecorder(deal['id'].toString(), name, phone),
                  ),
                  const SizedBox(width: 6),
                  // Upload
                  _tinyAction(
                    icon: Icons.cloud_upload_rounded,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => _navigateToUpload(deal['id'].toString(), name, phone),
                  ),
                  const SizedBox(width: 2),
                  // Three-dot
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 17, color: AppColors.textHint),
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      switch (val) {
                        case 'stage': _showMoveStage(deal); break;
                        case 'lost': _showMarkLost(deal); break;
                        case 'delete':
                          showDialog(
                            context: context,
                            builder: (d) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Delete Deal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                              content: Text('Delete "$name"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () async {
                                    Navigator.pop(d);
                                    try { await _api.deleteCrmDeal(deal['id'] as String); _msg('Deal deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
                                  },
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'stage', child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary), SizedBox(width: 10), Text('Move Stage')])),
                      const PopupMenuItem(value: 'lost', child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: AppColors.error), SizedBox(width: 10), Text('Mark Lost')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.error), SizedBox(width: 10), Text('Delete Deal', style: TextStyle(color: AppColors.error))])),
                    ],
                  ),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _tinyAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _CrmV2Wrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _CrmV2Wrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 4, right: 16, bottom: 14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(child: Scaffold(backgroundColor: AppColors.scaffoldBg, body: child)),
      ]),
    );
  }
}
