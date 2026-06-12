import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../call_recorder_screen.dart';
import '../call_upload_screen.dart';
import 'crm_lead_detail_screen.dart';

class CrmLeadsScreen extends StatefulWidget {
  final String? highlightDealId;
  const CrmLeadsScreen({super.key, this.highlightDealId});

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _assignableUsers = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _pipelines = [];
  String? _selectedPipelineId;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.highlightDealId;
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    if (mounted) setState(() => _currentUser = user);

    // Load pipelines first — backend requires pipelineId to return deals
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      final pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (mounted) {
        setState(() {
          _pipelines = pipelines;
          if (pipelines.isNotEmpty) _selectedPipelineId = pipelines.first['id']?.toString();
        });
      }
    } catch (_) {}

    await _load();
    _loadFormData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final user = _currentUser ?? await _auth.getUser();
      final isTeamLeader = user?.branchRole == 'TEAM_LEADER';

      final results = await Future.wait([
        _api.getBranches(),
        // Team leaders see only their direct salesmen in the assignee dropdown
        isTeamLeader && user?.id != null
            ? _api.getUsersByReportingTo(user!.id)
            : _api.getAssignableUsers(),
      ]);
      final bRaw = results[0].data;
      final uRaw = results[1].data;
      if (mounted) {
        setState(() {
          _branches = _toList(bRaw);
          _assignableUsers = _toList(uRaw);
        });
      }
    } catch (e) {
      debugPrint('_loadFormData error: $e');
    }
  }

  void _scrollToHighlight() {
    if (_highlightedId == null) return;
    final idx = _leads.indexWhere((l) => (l['id'] ?? l['leadId'] ?? '').toString() == _highlightedId);
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          idx * 140.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getCrmDeals(
        pipelineId: _selectedPipelineId,
        branchId: _currentUser?.branchId,
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) : []);
      final safeList = list is List ? list : [];
      setState(() {
        _leads = safeList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
      if (_highlightedId != null) {
        _scrollToHighlight();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _highlightedId = null);
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final expectedValueCtrl = TextEditingController();
    String source = 'Walk-in';
    // Auto-select branch from user profile, matching web frontend logic
    String? branchId = _currentUser?.branchId;
    final bool branchLocked = branchId != null;
    // Auto-select first pipeline — backend requires pipelineId when createDeal=true
    String? pipelineId = _pipelines.isNotEmpty ? _pipelines.first['id']?.toString() : null;
    Map<String, dynamic>? assignedUser;
    List<Map<String, dynamic>> sheetUsers = List.from(_assignableUsers);
    bool sheetUsersLoading = false;

    // Pre-fetch branch team if user has a branch (same as web onBranchChange on init)
    if (branchId != null) {
      try {
        final res = await _api.getCrmUsersByBranch(branchId);
        final raw = res.data;
        final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
        final users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        sheetUsers = users.map((u) => {...u, 'id': u['userId'] ?? u['id']}).toList();
        if (sheetUsers.isEmpty) sheetUsers = List.from(_assignableUsers);
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> onBranchChanged(String? selectedBranchId) async {
            setSheetState(() {
              branchId = selectedBranchId;
              assignedUser = null; // reset selected user when branch changes
              sheetUsersLoading = selectedBranchId != null;
              if (selectedBranchId == null) sheetUsers = List.from(_assignableUsers);
            });
            if (selectedBranchId == null) return;
            try {
              final res = await _api.getCrmUsersByBranch(selectedBranchId);
              final raw = res.data;
              final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
              final users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              setSheetState(() {
                // getCrmUsersByBranch returns userId field, normalize to also have id
                sheetUsers = users.map((u) => {...u, 'id': u['userId'] ?? u['id']}).toList();
                sheetUsersLoading = false;
              });
            } catch (_) {
              setSheetState(() {
                sheetUsers = List.from(_assignableUsers);
                sheetUsersLoading = false;
              });
            }
          }

          Future<void> pickAssignedUser() async {
            final searchCtrl = TextEditingController();
            List<Map<String, dynamic>> filtered = List.from(sheetUsers);
            final picked = await showModalBottomSheet<Map<String, dynamic>>(
              context: ctx,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (sCtx) => StatefulBuilder(
                builder: (sCtx, setSub) => SizedBox(
                  height: MediaQuery.of(sCtx).size.height * 0.6,
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 10),
                    const Text('Assign Salesperson', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                        onChanged: (q) {
                          final lower = q.toLowerCase();
                          setSub(() {
                            filtered = sheetUsers.where((u) {
                              final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
                              return n.contains(lower) || (u['email'] ?? '').toString().toLowerCase().contains(lower);
                            }).toList();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(name.isNotEmpty ? name : (u['email'] ?? ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            onTap: () => Navigator.pop(sCtx, u),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            );
            if (picked != null) setSheetState(() => assignedUser = picked);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Create New Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Customer Name ──
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person_outline_rounded)),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // ── Phone * ──
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 15,
                    decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // ── Email ──
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),

                  // ── Source ──
                  DropdownButtonFormField<String>(
                    value: source,
                    decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source_outlined)),
                    items: ['Walk-in', 'Call', 'Website', 'Facebook', 'Instagram', 'Google Ads', 'Reference', 'Event', 'Other']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setSheetState(() => source = v!),
                  ),
                  const SizedBox(height: 12),

                  // ── Branch ──
                  if (_branches.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: branchId,
                      decoration: InputDecoration(
                        labelText: 'Branch',
                        prefixIcon: const Icon(Icons.business_outlined),
                        suffixIcon: branchLocked ? const Icon(Icons.lock_outline, size: 16, color: AppColors.primary) : null,
                      ),
                      hint: const Text('Select branch'),
                      items: [
                        if (!branchLocked)
                          const DropdownMenuItem<String>(value: null, child: Text('All Branches')),
                        ..._branches.map((b) => DropdownMenuItem<String>(
                          value: b['id']?.toString(),
                          child: Text(b['name']?.toString() ?? ''),
                        )),
                      ],
                      onChanged: branchLocked ? null : (v) => onBranchChanged(v),
                    ),
                    if (branchLocked) ...[
                      const SizedBox(height: 4),
                      const Row(children: [
                        SizedBox(width: 4),
                        Icon(Icons.info_outline, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Auto-assigned from your branch', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                  ],

                  // ── Pipeline ──
                  if (_pipelines.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: pipelineId,
                      decoration: const InputDecoration(labelText: 'Pipeline', prefixIcon: Icon(Icons.account_tree_outlined)),
                      hint: const Text('Select pipeline'),
                      items: _pipelines.map((p) => DropdownMenuItem<String>(
                        value: p['id']?.toString(),
                        child: Text(p['name']?.toString() ?? ''),
                      )).toList(),
                      onChanged: (v) => setSheetState(() => pipelineId = v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Expected Value ──
                  TextField(
                    controller: expectedValueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Expected Value (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                      hintText: 'e.g. 500000',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Assign Salesperson ──
                  Row(children: [
                    const Text('Assign Salesperson', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    if (branchId != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          _branches.firstWhere((b) => b['id']?.toString() == branchId, orElse: () => {'name': ''})['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: (sheetUsersLoading || sheetUsers.isEmpty) ? null : pickAssignedUser,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: assignedUser != null ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: assignedUser != null ? AppColors.primarySurface : Colors.white,
                      ),
                      child: Row(children: [
                        if (sheetUsersLoading)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        else
                          Icon(Icons.person_search_rounded, size: 18, color: assignedUser != null ? AppColors.primary : AppColors.textHint),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          sheetUsersLoading
                              ? 'Loading salespersons…'
                              : (assignedUser != null
                                  ? '${assignedUser!['firstName'] ?? ''} ${assignedUser!['lastName'] ?? ''}'.trim()
                                  : (sheetUsers.isEmpty ? 'No salespersons found' : 'Select salesperson')),
                          style: TextStyle(fontSize: 14, color: assignedUser != null ? AppColors.textPrimary : AppColors.textHint),
                        )),
                        if (assignedUser != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => assignedUser = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textHint),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Notes ──
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'Any initial notes...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Submit ──
                  FilledButton(
                    onPressed: (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || (_pipelines.isNotEmpty && pipelineId == null)) ? null : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      if (phone.isNotEmpty) {
                        try {
                          final dupRes = await _api.checkDuplicateCrmContact(phone);
                          final raw = dupRes.data;
                          final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? raw['contacts'] ?? []) : []);
                          final isDuplicate = list is List && (list as List).isNotEmpty;
                          if (isDuplicate && ctx.mounted) {
                            final first = (list as List).first;
                            final existingName = first is Map ? (first['name'] ?? 'another contact') : 'another contact';
                            final proceed = await showDialog<bool>(
                              context: ctx,
                              builder: (dlgCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Duplicate Phone'),
                                content: Text('Phone $phone already exists as "$existingName". Create anyway?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dlgCtx, true),
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                                    child: const Text('Create Anyway'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }
                        } catch (_) {}
                      }

                      try {
                        final evText = expectedValueCtrl.text.trim();
                        final notes = notesCtrl.text.trim();
                        final res = await _api.createCrmQuickLead(
                          name: name,
                          phone: phone.isEmpty ? null : phone,
                          email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                          source: source,
                          branchId: branchId,
                          pipelineId: pipelineId,
                          ownerUserId: assignedUser?['id']?.toString(),
                          expectedValue: evText.isNotEmpty ? double.tryParse(evText) : null,
                          notes: notes.isNotEmpty ? notes : null,
                        );
                        // Extract new lead ID from response
                        String? newLeadId;
                        final resData = res.data;
                        if (resData is Map) {
                          final inner = resData['data'] ?? resData['deal'] ?? resData['lead'] ?? resData;
                          if (inner is Map) {
                            newLeadId = (inner['id'] ?? inner['dealId'] ?? inner['leadId'])?.toString();
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                        if (mounted && newLeadId != null) {
                          _showNewLeadRecordingSheet(newLeadId, name, phone);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          String msg = 'Failed to create lead';
                          if (e is DioException) {
                            final body = e.response?.data;
                            final serverMsg = body is Map
                                ? (body['message'] ?? body['error'] ?? body['msg'])?.toString()
                                : null;
                            msg = serverMsg ?? msg;
                          }
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Create Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAssignDialog(Map<String, dynamic> lead) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Lead'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _assignableUsers.length,
            itemBuilder: (_, i) {
              final user = _assignableUsers[i];
              return ListTile(
                title: Text(
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                ),
                onTap: () async {
                  try {
                    await _api.updateCrmDeal((lead['id'] ?? lead['leadId']).toString(), {'ownerUserId': user['id']});
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to assign: $e')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _markLost(Map<String, dynamic> lead) async {
    try {
      await _api.markDealLost((lead['id'] ?? lead['leadId']).toString());
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark lost: $e')),
        );
      }
    }
  }

  Widget _wrapped(String title, Widget child) => Material(
    color: AppColors.scaffoldBg,
    child: Column(
      children: [
        Builder(
          builder: (ctx) => Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 8,
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
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(width: 4),
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
        ),
        Expanded(child: child),
      ],
    ),
  );

  void _navigateToRecorder(String leadId, String leadName, [String? phone]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _wrapped(
          leadName,
          CallRecorderScreen(leadId: leadId, leadCustomerName: leadName, leadPhone: phone),
        ),
      ),
    ).then((_) => _load());
  }

  void _navigateToUpload(String leadId, String leadName, String phone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _wrapped(
          'Upload Call',
          CallUploadScreen(leadId: leadId, leadName: leadName, leadPhone: phone),
        ),
      ),
    ).then((_) => _load());
  }

  void _navigateToDetail(String leadId, String leadName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => CrmLeadDetailScreen(
          leadId: leadId,
          leadName: leadName,
          isDeal: true,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ).then((_) => _load());
  }

  // Shown after a new lead is created
  void _showNewLeadRecordingSheet(String leadId, String leadName, String phone) {
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
              Text(
                'Lead created!',
                style: const TextStyle(fontSize: 13, color: AppColors.textHint),
              ),
              Text(
                leadName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Do you want to start a recording?',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToUpload(leadId, leadName, phone);
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Upload Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToRecorder(leadId, leadName, phone);
                      },
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('Start Recording'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Center(
                  child: Text('Skip for now', style: TextStyle(color: AppColors.textHint)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shown when tapping an existing lead
  void _showLeadActionSheet(String leadId, String leadName, String phone) {
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
              Text(
                leadName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Do you want to add a recording?',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _sheetTile(
                ctx: ctx,
                icon: Icons.mic_rounded,
                color: AppColors.primary,
                label: 'Start Recording',
                subtitle: 'Record a new call for this lead',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToRecorder(leadId, leadName, phone);
                },
              ),
              const SizedBox(height: 8),
              _sheetTile(
                ctx: ctx,
                icon: Icons.upload_file_rounded,
                color: const Color(0xFF0EA5E9),
                label: 'Upload Call',
                subtitle: 'Upload an existing audio file',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToUpload(leadId, leadName, phone);
                },
              ),
              const SizedBox(height: 8),
              _sheetTile(
                ctx: ctx,
                icon: Icons.person_outline_rounded,
                color: AppColors.textSecondary,
                label: 'Open Lead',
                subtitle: 'View lead details',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToDetail(leadId, leadName);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
        ],
      ),
    ),
  );

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textHint,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textHint),
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              Expanded(
                child: _leads.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _leads.length,
                          itemBuilder: (_, i) => _buildLeadCard(_leads[i]),
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

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final leadId = (lead['id'] ?? lead['leadId'] ?? '').toString();
    final status = (lead['status'] ?? lead['leadStatus'] ?? 'OPEN').toString();
    final stageName = (lead['stage'] is Map ? lead['stage']['name'] : null)
        ?? lead['stageName']?.toString()
        ?? lead['currentStage']?.toString()
        ?? (lead['leadStage'] is Map ? lead['leadStage']['name'] : null)
        ?? '';
    final contact = lead['contact'] is Map ? lead['contact'] as Map : null;
    final phone = contact?['phone']?.toString()
        ?? (lead['mobileNumber'] ?? lead['phone'] ?? '').toString();
    final customerName = contact?['name']?.toString()
        ?? lead['customerName']?.toString()
        ?? lead['name']?.toString()
        ?? 'Unknown';
    final owner = lead['owner'] is Map ? lead['owner'] as Map : null;
    final assignedTo = owner != null
        ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
        : (lead['assignedDse']?.toString().isNotEmpty == true
            ? lead['assignedDse'].toString()
            : (lead['assignedTo'] is Map
                ? '${lead['assignedTo']['firstName'] ?? ''} ${lead['assignedTo']['lastName'] ?? ''}'.trim()
                : (lead['assignedToName'] ?? '')));
    final displayAssigned = assignedTo.isNotEmpty ? assignedTo : 'Unassigned';

    final isHighlighted = _highlightedId != null && leadId == _highlightedId;
    return GestureDetector(
      onTap: () => _showLeadActionSheet(leadId, customerName, phone),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isHighlighted ? 12 : 8,
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
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? phone : 'N/A',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayAssigned,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (stageName.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  stageName.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                'Assign',
                Icons.person_add_alt,
                AppColors.primary,
                () => _showAssignDialog(lead),
              ),
              const SizedBox(width: 8),
              if (status != 'LOST')
                _buildActionButton(
                  'Mark Lost',
                  Icons.cancel_outlined,
                  AppColors.error,
                  () => _markLost(lead),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status.toUpperCase()) {
      case 'OPEN':
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        break;
      case 'CONVERTED':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'LOST':
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
          Icon(Icons.people_outline, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'No leads found',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to create a new lead',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
