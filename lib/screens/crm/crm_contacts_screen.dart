import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../call_recorder_screen.dart';
import '../call_upload_screen.dart';
import 'crm_screen.dart';

class CrmContactsScreen extends StatefulWidget {
  const CrmContactsScreen({super.key});
  @override
  State<CrmContactsScreen> createState() => _CrmContactsScreenState();
}

class _CrmContactsScreenState extends State<CrmContactsScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  UserModel? _currentUser;
  List<Map<String, dynamic>> _assignableUsers = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _pipelines = [];

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _owners = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;

  String? _stageFilter;
  String? _sourceFilter;
  String? _ownerFilter;

  Timer? _debounce;

  static const _stages = ['LEAD', 'PROSPECT', 'QUALIFIED', 'CUSTOMER', 'CHURNED'];
  static const _sources = ['WALK_IN', 'WEBSITE', 'REFERRAL', 'PHONE', 'SOCIAL', 'ADVERTISEMENT'];

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadOwners();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _initUser() async {
    _currentUser = await _auth.getUser();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final isTeamLeader = _currentUser?.branchRole == 'TEAM_LEADER';
      final results = await Future.wait([
        _api.getBranches(),
        isTeamLeader && _currentUser?.id != null
            ? _api.getUsersByReportingTo(_currentUser!.id)
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
    } catch (_) {}
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      final pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (mounted) setState(() => _pipelines = pipelines);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    try {
      final res = await _api.getUsers();
      final raw = res.data;
      List items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        final inner = raw['data'];
        if (inner is List) items = inner;
        else if (inner is Map) items = inner['data'] ?? inner['users'] ?? [];
        else items = raw['users'] ?? [];
      }
      if (mounted) {
        setState(() {
          _owners = items.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            // normalise display name
            if (m['name'] == null || m['name'].toString().isEmpty) {
              final fn = m['firstName']?.toString() ?? '';
              final ln = m['lastName']?.toString() ?? '';
              m['_displayName'] = '$fn $ln'.trim();
            } else {
              m['_displayName'] = m['name'].toString();
            }
            return m;
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      if (mounted) setState(() { _loading = true; _contacts = []; _page = 1; _hasMore = true; });
    } else {
      if (!_hasMore || _loadingMore) return;
      if (mounted) setState(() => _loadingMore = true);
    }

    try {
      final res = await _api.getCrmContacts(
        search: _searchCtrl.text.trim(),
        page: reset ? 1 : _page,
        limit: 20,
        lifecycleStage: _stageFilter,
        source: _sourceFilter,
        ownerUserId: _ownerFilter,
      );
      final raw = res.data;
      List items = [];
      int total = 0;
      if (raw is Map) {
        final data = raw['data'] ?? raw['contacts'] ?? raw;
        if (data is List) {
          items = data;
          total = (raw['total'] ?? raw['count'] ?? items.length) as int;
        } else if (data is Map) {
          items = (data['data'] ?? data['contacts'] ?? []) as List;
          total = (data['total'] ?? data['count'] ?? items.length) as int;
        }
      } else if (raw is List) {
        items = raw;
        total = raw.length;
      }
      final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          if (reset) {
            _contacts = parsed;
            _page = 2;
          } else {
            _contacts.addAll(parsed);
            _page++;
          }
          _total = total;
          _hasMore = _contacts.length < total && parsed.length == 20;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _showQuickLead() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final expectedValueCtrl = TextEditingController();
    String source = 'Walk-in';
    String? branchId = _currentUser?.branchId;
    final bool branchLocked = branchId != null;
    String? pipelineId = _pipelines.isNotEmpty ? _pipelines.first['id']?.toString() : null;
    Map<String, dynamic>? assignedUser;
    List<Map<String, dynamic>> sheetUsers = List.from(_assignableUsers);
    bool sheetUsersLoading = false;

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
              assignedUser = null;
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

          // ── helpers scoped to the sheet ──────────────────────────────
          Widget sectionLabel(String label) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.8)),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: AppColors.textHint.withValues(alpha: 0.2), height: 1)),
            ]),
          );

          Widget styledField({
            required TextEditingController ctrl,
            required String label,
            required IconData icon,
            Color iconColor = AppColors.primary,
            TextInputType? keyboard,
            int maxLines = 1,
            int? maxLength,
            bool alignLabelWithHint = false,
            ValueChanged<String>? onChanged,
          }) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAFF)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              maxLines: maxLines,
              maxLength: maxLength,
              textCapitalization: label.contains('Name') ? TextCapitalization.words : TextCapitalization.none,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: Icon(icon, size: 18, color: iconColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 14 : 0, horizontal: maxLines > 1 ? 16 : 0),
                counterText: '',
                alignLabelWithHint: alignLabelWithHint,
              ),
            ),
          );

          Widget styledDropdown<T>({
            required T? value,
            required String label,
            required IconData icon,
            required List<DropdownMenuItem<T>> items,
            required ValueChanged<T?> onChanged,
            Widget? suffixIcon,
            bool enabled = true,
          }) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAFF)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonFormField<T>(
              value: value,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
                suffixIcon: suffixIcon,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              items: items,
              onChanged: enabled ? onChanged : null,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── drag handle ───────────────────────────────────────────
              const SizedBox(height: 10),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDE1F0), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              // ── gradient header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Create New Lead', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Fill in the details below', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              // ── scrollable form body ──────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─ Contact Info ─────────────────────────────────
                      sectionLabel('CONTACT INFO'),
                      styledField(ctrl: nameCtrl, label: 'Customer Name *', icon: Icons.person_outline_rounded, onChanged: (_) => setSheetState(() {})),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: styledField(ctrl: phoneCtrl, label: 'Phone *', icon: Icons.phone_outlined, keyboard: TextInputType.phone, maxLength: 15, onChanged: (_) => setSheetState(() {}))),
                        const SizedBox(width: 10),
                        Expanded(child: styledField(ctrl: emailCtrl, label: 'Email', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress)),
                      ]),
                      const SizedBox(height: 14),
                      // ─ Source chips ──────────────────────────────────
                      Text('Source', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Walk-in', 'Call', 'Website', 'Facebook', 'Instagram', 'Google Ads', 'Reference', 'Event', 'Other'].map((s) {
                          final selected = source == s;
                          return GestureDetector(
                            onTap: () => setSheetState(() => source = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : const Color(0xFFF0F1FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE0E2F5)),
                                boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : [],
                              ),
                              child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      // ─ Deal Details ──────────────────────────────────
                      sectionLabel('DEAL DETAILS'),
                      if (_branches.isNotEmpty) ...[
                        styledDropdown<String>(
                          value: branchId,
                          label: 'Branch',
                          icon: Icons.business_outlined,
                          enabled: !branchLocked,
                          suffixIcon: branchLocked ? const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary)) : null,
                          items: [
                            if (!branchLocked) const DropdownMenuItem<String>(value: null, child: Text('All Branches')),
                            ..._branches.map((b) => DropdownMenuItem<String>(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? ''))),
                          ],
                          onChanged: (v) => onBranchChanged(v),
                        ),
                        if (branchLocked) ...[
                          const SizedBox(height: 4),
                          Row(children: const [
                            SizedBox(width: 4),
                            Icon(Icons.info_outline_rounded, size: 11, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Auto-assigned from your branch', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ]),
                        ],
                        const SizedBox(height: 10),
                      ],
                      if (_pipelines.isNotEmpty) ...[
                        styledDropdown<String>(
                          value: pipelineId,
                          label: 'Pipeline',
                          icon: Icons.account_tree_outlined,
                          items: _pipelines.map((p) => DropdownMenuItem<String>(value: p['id']?.toString(), child: Text(p['name']?.toString() ?? ''))).toList(),
                          onChanged: (v) => setSheetState(() => pipelineId = v),
                        ),
                        const SizedBox(height: 10),
                      ],
                      styledField(
                        ctrl: expectedValueCtrl,
                        label: 'Expected Value (₹)',
                        icon: Icons.currency_rupee_rounded,
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      // ─ Assign Salesperson ────────────────────────────
                      GestureDetector(
                        onTap: (sheetUsersLoading || sheetUsers.isEmpty) ? null : pickAssignedUser,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: assignedUser != null ? AppColors.primary.withValues(alpha: 0.06) : const Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: assignedUser != null ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFE8EAFF)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: assignedUser != null ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFEEEFF8),
                                shape: BoxShape.circle,
                              ),
                              child: sheetUsersLoading
                                  ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                  : Icon(assignedUser != null ? Icons.person_rounded : Icons.person_search_rounded, size: 17, color: assignedUser != null ? AppColors.primary : AppColors.textHint),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Assign Salesperson', style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                              Text(
                                sheetUsersLoading ? 'Loading…'
                                    : assignedUser != null ? '${assignedUser!['firstName'] ?? ''} ${assignedUser!['lastName'] ?? ''}'.trim()
                                    : sheetUsers.isEmpty ? 'No salespersons found' : 'Tap to select',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: assignedUser != null ? AppColors.textPrimary : AppColors.textSecondary),
                              ),
                            ])),
                            if (assignedUser != null)
                              GestureDetector(
                                onTap: () => setSheetState(() => assignedUser = null),
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                                ),
                              )
                            else
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textHint),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ─ Notes ─────────────────────────────────────────
                      styledField(
                        ctrl: notesCtrl,
                        label: 'Notes (optional)',
                        icon: Icons.notes_rounded,
                        maxLines: 3,
                        alignLabelWithHint: true,
                      ),
                      const SizedBox(height: 20),
                      // ─ Submit ─────────────────────────────────────────
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
                        String? newLeadId;
                        final resData = res.data;
                        if (resData is Map) {
                          final inner = resData['data'] ?? resData['deal'] ?? resData['lead'] ?? resData;
                          if (inner is Map) {
                            newLeadId = (inner['id'] ?? inner['dealId'] ?? inner['leadId'])?.toString();
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load(reset: true);
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
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: const Color(0xFFDDE1F0),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Create Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
              const Text('Lead created!', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              Text(leadName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Do you want to start a recording?', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _navigateToUpload(leadId, leadName, phone); },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Upload Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () { Navigator.pop(ctx); _navigateToRecorder(leadId, leadName, phone); },
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('Start Recording'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                ],
              ),
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

  void _navigateToRecorder(String leadId, String leadName, [String? phone]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrmSubWrapper(
          title: leadName,
          child: CallRecorderScreen(leadId: leadId, leadCustomerName: leadName, leadPhone: phone),
        ),
      ),
    ).then((_) => _load(reset: true));
  }

  void _navigateToUpload(String leadId, String leadName, String phone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrmSubWrapper(
          title: 'Upload Call',
          child: CallUploadScreen(leadId: leadId, leadName: leadName, leadPhone: phone),
        ),
      ),
    ).then((_) => _load(reset: true));
  }

  bool get _hasActiveFilter => _stageFilter != null || _sourceFilter != null || _ownerFilter != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(child: _searchBar()),
              const SizedBox(width: 8),
              _quickLeadBtn(),
            ],
          ),
        ),
        // Filter dropdowns row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: _stageDropdown()),
              const SizedBox(width: 6),
              Expanded(child: _sourceDropdown()),
              const SizedBox(width: 6),
              Expanded(child: _ownerDropdown()),
              if (_hasActiveFilter) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() { _stageFilter = null; _sourceFilter = null; _ownerFilter = null; });
                    _load(reset: true);
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Count row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text(
                '$_total contact${_total == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _load(reset: true),
                  child: _contacts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Icon(Icons.people_outline_rounded, size: 60, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            const Text('No contacts found', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Try adjusting your search or filters', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _contacts.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _contacts.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                              );
                            }
                            return _ContactCard(contact: _contacts[i]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, phone, email...',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 18),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
                  onPressed: () { _searchCtrl.clear(); _load(reset: true); },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _quickLeadBtn() {
    return GestureDetector(
      onTap: _showQuickLead,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Quick Lead', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _stageDropdown() {
    return _compactDropdown<String>(
      value: _stageFilter,
      hint: 'All Stages',
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All Stages')),
        ..._stages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))),
      ],
      onChanged: (v) { setState(() => _stageFilter = v); _load(reset: true); },
      activeColor: _stageFilter != null ? AppColors.primary : null,
    );
  }

  Widget _sourceDropdown() {
    return _compactDropdown<String>(
      value: _sourceFilter,
      hint: 'All Sources',
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All Sources')),
        ..._sources.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))),
      ],
      onChanged: (v) { setState(() => _sourceFilter = v); _load(reset: true); },
      activeColor: _sourceFilter != null ? const Color(0xFF0EA5E9) : null,
    );
  }

  Widget _ownerDropdown() {
    final ownerItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('All Owners')),
      ..._owners.map((u) {
        final id = u['id']?.toString() ?? '';
        final name = (u['_displayName']?.toString() ?? '').isNotEmpty
            ? u['_displayName'].toString()
            : id;
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }),
    ];
    return _compactDropdown<String>(
      value: _ownerFilter,
      hint: _owners.isEmpty ? 'Loading...' : 'All Owners',
      items: ownerItems,
      onChanged: (v) { setState(() => _ownerFilter = v); _load(reset: true); },
      activeColor: _ownerFilter != null ? AppColors.warning : null,
    );
  }

  Widget _compactDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    Color? activeColor,
  }) {
    final active = activeColor != null;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? activeColor : AppColors.textHint.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 10, color: active ? activeColor : AppColors.textHint, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          isExpanded: true,
          style: TextStyle(fontSize: 10, color: active ? activeColor : AppColors.textPrimary, fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: active ? activeColor : AppColors.textHint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  const _ContactCard({required this.contact});

  Color _stageColor(String? stage) {
    switch (stage?.toUpperCase()) {
      case 'LEAD': return AppColors.primary;
      case 'PROSPECT': return const Color(0xFF8B5CF6);
      case 'QUALIFIED': return AppColors.accent;
      case 'CUSTOMER': return AppColors.success;
      case 'CHURNED': return AppColors.error;
      default: return AppColors.textHint;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final name = contact['name']?.toString() ?? 'Unknown';
    final phone = contact['phone']?.toString() ?? '';
    final email = contact['email']?.toString() ?? '';
    final stage = contact['lifecycleStage']?.toString();
    final source = contact['source']?.toString() ?? '';
    final city = contact['city']?.toString() ?? '';
    final owner = contact['owner'];
    final ownerName = owner is Map
        ? (owner['name'] ?? owner['firstName'] ?? '').toString()
        : '';
    final stageColor = _stageColor(stage);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stageColor.withValues(alpha: 0.7), stageColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(name),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (stage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: stageColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: stageColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(stage,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stageColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (phone.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.phone_rounded, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.email_rounded, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(email,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (city.isNotEmpty || source.isNotEmpty || ownerName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (source.isNotEmpty) _chip(Icons.source_rounded, source),
                        if (city.isNotEmpty) _chip(Icons.location_on_rounded, city),
                        if (ownerName.isNotEmpty) _chip(Icons.person_rounded, ownerName),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: AppColors.textHint),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
