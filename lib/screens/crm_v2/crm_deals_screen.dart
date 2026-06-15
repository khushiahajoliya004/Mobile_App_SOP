import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'crm_deal_detail_screen.dart';
import '../call_recorder_screen.dart';
import '../call_upload_screen.dart';
import '../crm/crm_screen.dart' show CrmSubWrapper;

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
  const CrmDealsScreen({super.key});
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Team leaders must NOT pass branchId — backend uses reportingToUserId hierarchy to scope deals.
      // Passing branchId would bypass team-leader visibility and show all branch deals instead.
      final isTeamLeader = _currentUser?.branchRole == 'TEAM_LEADER';
      debugPrint('[CrmDeals] calling getCrmDeals isTeamLeader=$isTeamLeader branchId=${isTeamLeader ? 'skipped' : _currentUser?.branchId}, pipelineId=$_selectedPipelineId');
      final res = await _api.getCrmDeals(
        pipelineId: _selectedPipelineId,
        search: _search.isNotEmpty ? _search : null,
        branchId: isTeamLeader ? null : _currentUser?.branchId,
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

  void _showDealActions(Map<String, dynamic> deal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${deal['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _actionTile(ctx, Icons.mic_rounded, 'Start Recording', AppColors.primary, () {
              final phone = deal['contact']?['phone']?.toString() ?? '';
              final name = deal['contact']?['name']?.toString() ?? deal['name']?.toString() ?? '';
              _showRecordingSheet(deal['id'].toString(), name, phone);
            }),
            _actionTile(ctx, Icons.upload_file_rounded, 'Upload Call', const Color(0xFF0EA5E9), () {
              final phone = deal['contact']?['phone']?.toString() ?? '';
              final name = deal['contact']?['name']?.toString() ?? deal['name']?.toString() ?? '';
              _navigateToUpload(deal['id'].toString(), name, phone);
            }),
            _actionTile(ctx, Icons.swap_horiz_rounded, 'Move Stage', AppColors.primary, () => _showMoveStage(deal)),
            _actionTile(ctx, Icons.check_circle_outline_rounded, 'Mark Won', AppColors.success, () async {
              try { await _api.markDealWon(deal['id'] as String); _msg('Deal marked as won'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            }),
            _actionTile(ctx, Icons.cancel_outlined, 'Mark Lost', AppColors.error, () {
              Navigator.pop(ctx);
              _showMarkLost(deal);
            }),
            _actionTile(ctx, Icons.delete_outline, 'Delete Deal', AppColors.error, () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (d) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Delete Deal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  content: Text('Delete "${deal['name']}"?'),
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
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      onTap: () { Navigator.pop(ctx); onTap(); },
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


  void _navigateToRecorder(String dealId, String dealName, String phone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrmSubWrapper(
          title: dealName,
          child: CallRecorderScreen(
            leadId: dealId,
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
        builder: (_) => CrmSubWrapper(
          title: 'Upload Call',
          child: CallUploadScreen(
            leadId: dealId,
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
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'WON': return AppColors.success;
      case 'LOST': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _dealTile(Map<String, dynamic> deal) {
    final rawName = '${deal['name'] ?? ''}';
    final status = deal['status'] as String?;
    final rawValue = deal['expectedValue'] ?? deal['value'];
    final value = rawValue == null ? null : double.tryParse('$rawValue');
    final contactName = deal['contact']?['name'] ?? deal['contactName'] ?? '';
    // Prefer contactName; strip " - <date>" suffix from deal name as fallback
    final name = contactName.isNotEmpty ? contactName : rawName.split(' - ').first.trim();
    final stageName = deal['stage']?['name'] ?? deal['stageName'] ?? '';
    final statusColor = _statusColor(status);
    return GestureDetector(
      onTap: () => _showDealActions(deal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(
                status == 'WON' ? Icons.emoji_events_rounded : status == 'LOST' ? Icons.cancel_rounded : Icons.handshake_rounded,
                color: statusColor, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if ((deal['contact']?['phone'] ?? deal['phone'] ?? '').toString().isNotEmpty) Text((deal['contact']?['phone'] ?? deal['phone'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (status != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ),
              if (value != null) ...[
                const SizedBox(height: 4),
                Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              ],
            ]),
          ]),
          if (stageName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: Text(stageName, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CrmDealDetailScreen(dealId: deal['id'].toString(), dealName: name))),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary), SizedBox(width: 4), Text('Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary))])),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDealActions(deal),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.more_horiz_rounded, size: 14, color: AppColors.textSecondary), SizedBox(width: 4), Text('Manage', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))])),
            ),
          ]),
        ]),
      ),
    );
  }
}
