import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'crm_contact_detail_screen.dart';

const _contactLeadSources = [
  {'value': 'WALK_IN', 'label': 'Walk-in'},
  {'value': 'WEBSITE', 'label': 'Website'},
  {'value': 'REFERRAL', 'label': 'Referral'},
  {'value': 'PHONE', 'label': 'Phone Call'},
  {'value': 'SOCIAL', 'label': 'Social Media'},
  {'value': 'ADVERTISEMENT', 'label': 'Advertisement'},
  {'value': 'PARTNER', 'label': 'Partner'},
  {'value': 'EVENT', 'label': 'Event'},
];

class CrmContactsScreen extends StatefulWidget {
  const CrmContactsScreen({super.key});
  @override
  State<CrmContactsScreen> createState() => _CrmContactsScreenState();
}

class _CrmContactsScreenState extends State<CrmContactsScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _assignableUsers = [];
  String _search = '';
  String? _filterStage;
  String? _currentUserBranchId;
  String? _currentUserBranchName;

  static const _stages = ['LEAD', 'QUALIFIED', 'OPPORTUNITY', 'CUSTOMER'];
  static const _sources = ['WALK_IN', 'WEBSITE', 'REFERRAL', 'PHONE', 'SOCIAL', 'ADVERTISEMENT'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    final user = await _auth.getUser();
    _currentUserBranchId = user?.branchId;
    _currentUserBranchName = user?.branchName;

    try {
      final res = await _api.getBranches();
      final raw = res.data;
      _branches = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    try {
      final res = await _api.getCrmPipelines();
      final raw = res.data;
      _pipelines = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}

    if (_currentUserBranchId != null && _currentUserBranchId!.isNotEmpty) {
      // Single branch user — load branch team directly
      try {
        final res = await _api.getBranchTeam(_currentUserBranchId!);
        _assignableUsers = _normalizeBranchTeam(res.data);
      } catch (_) {}
    } else {
      // Admin/no branch — load all assignable users
      try {
        final res = await _api.getAssignableUsers();
        _assignableUsers = _normalizeUsers(res.data);
      } catch (_) {}
    }
    if (mounted) setState(() {});
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmContacts(search: _search.isNotEmpty ? _search : null);
      _contacts = _parseList(res.data);
      if (_filterStage != null) {
        _contacts = _contacts.where((c) => c['lifecycleStage'] == _filterStage).toList();
      }
    } catch (_) { _contacts = []; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showCreateLeadForm() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String? selectedSource = 'WALK_IN';
    // Branch lock: single-branch users get auto-selected locked branch
    final branchLocked = _currentUserBranchId != null && _currentUserBranchId!.isNotEmpty;
    String? selectedBranchId = branchLocked ? _currentUserBranchId : null;
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
                setSheet(() { branchUsers = List.from(_assignableUsers); selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; });
              }
            } catch (_) {}
          }

          Widget sectionHeader(String label) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
          );

          Widget formField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) => TextField(
            controller: ctrl, keyboardType: type,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Expanded(child: Text('Create Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary))),
                  ]),
                  const SizedBox(height: 18),
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
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: selectedSource, isExpanded: true,
                        hint: const Text('Source', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                        items: _contactLeadSources.map((s) => DropdownMenuItem<String>(value: s['value'], child: Text(s['label']!, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (v) => setSheet(() => selectedSource = v),
                      )),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: branchLocked
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
                          child: Row(children: [
                            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF166534)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_currentUserBranchName ?? 'Your Branch', style: const TextStyle(fontSize: 14, color: Color(0xFF166534), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ]),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
                          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: selectedBranchId, isExpanded: true,
                            hint: const Text('All Branches', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('All Branches', style: TextStyle(fontSize: 14))),
                              ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'] as String?, child: Text('${b['name']}', style: const TextStyle(fontSize: 14)))),
                            ],
                            onChanged: (v) { setSheet(() => selectedBranchId = v); reloadBranchUsers(v); },
                          )),
                        )),
                  ]),
                  const SizedBox(height: 10),
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
                      Expanded(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                          value: selectedPipelineId, isExpanded: true,
                          hint: const Text('Pipeline', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                          items: _pipelines.map((p) => DropdownMenuItem<String>(value: p['id'] as String?, child: Text('${p['name']}', style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => setSheet(() => selectedPipelineId = v),
                        )),
                      )),
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
                          await _api.createCrmQuickLead(
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

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final email = TextEditingController(text: existing?['email'] ?? '');
    final companyName = TextEditingController(text: existing?['companyName'] ?? '');
    final city = TextEditingController(text: existing?['city'] ?? '');
    final state = TextEditingController(text: existing?['state'] ?? '');
    String? selectedSource = existing?['source'];
    String? selectedStage = existing?['lifecycleStage'] ?? 'LEAD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(isEdit ? 'Edit Contact' : 'New Contact', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                _field(name, 'Full Name *'),
                const SizedBox(height: 10),
                _field(phone, 'Phone', type: TextInputType.phone),
                const SizedBox(height: 10),
                _field(email, 'Email', type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(companyName, 'Company Name'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(city, 'City')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(state, 'State')),
                ]),
                const SizedBox(height: 10),
                const Text('Source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedSource, 'Select source', [
                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 14))),
                  ..._sources.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedSource = v)),
                const SizedBox(height: 10),
                const Text('Lifecycle Stage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedStage, 'Select stage', [
                  ..._stages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedStage = v)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _save(ctx, isEdit: isEdit, id: existing?['id'], name: name.text, phone: phone.text, email: email.text, companyName: companyName.text, city: city.text, state: state.text, source: selectedSource, lifecycleStage: selectedStage),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEdit ? 'Update Contact' : 'Create Contact'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdown<T>(T? value, String hint, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(value: value, isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 14)), items: items, onChanged: onChanged),
      ),
    );
  }

  Future<void> _save(BuildContext ctx, {required bool isEdit, String? id, required String name, required String phone, required String email, required String companyName, required String city, required String state, String? source, String? lifecycleStage}) async {
    if (name.trim().isEmpty) { _msg('Name is required', error: true); return; }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        await _api.updateCrmContact(id, {
          'name': name.trim(),
          if (phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (email.trim().isNotEmpty) 'email': email.trim(),
          if (companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
          if (city.trim().isNotEmpty) 'city': city.trim(),
          if (state.trim().isNotEmpty) 'state': state.trim(),
          if (source != null) 'source': source,
          if (lifecycleStage != null) 'lifecycleStage': lifecycleStage,
        });
        _msg('Contact updated');
      } else {
        await _api.createCrmContact(
          name: name.trim(),
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          email: email.trim().isNotEmpty ? email.trim() : null,
          companyName: companyName.trim().isNotEmpty ? companyName.trim() : null,
          city: city.trim().isNotEmpty ? city.trim() : null,
          state: state.trim().isNotEmpty ? state.trim() : null,
          source: source,
          lifecycleStage: lifecycleStage,
        );
        _msg('Contact created');
      }
      _load();
    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
  }

  void _confirmDelete(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${contact['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deleteCrmContact(contact['id']); _msg('Contact deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _stageColor(String? stage) {
    switch (stage) {
      case 'LEAD': return AppColors.primary;
      case 'QUALIFIED': return AppColors.accent;
      case 'OPPORTUNITY': return AppColors.warning;
      case 'CUSTOMER': return AppColors.success;
      default: return AppColors.textHint;
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
                hintText: 'Search contacts...',
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
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _stageChip('All', null),
            ..._stages.map((s) => _stageChip(s, s)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_contacts.length} contacts', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _contacts.isEmpty
            ? const Center(child: Text('No contacts found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) => _tile(_contacts[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _stageChip(String label, String? stage) {
    final selected = _filterStage == stage;
    return GestureDetector(
      onTap: () { setState(() => _filterStage = stage); _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> contact) {
    final name = '${contact['name'] ?? ''}';
    final phone = '${contact['phone'] ?? ''}';
    final email = '${contact['email'] ?? ''}';
    final stage = contact['lifecycleStage'];
    final source = contact['source'];
    final leadScore = (contact['leadScore'] as num?)?.toInt() ?? 0;
    final stageColor = _stageColor(stage);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: stageColor.withValues(alpha: 0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: stageColor, fontWeight: FontWeight.w700, fontSize: 14))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (phone.isNotEmpty) Text(phone, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (email.isNotEmpty && phone.isEmpty) Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (stage != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(stage, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stageColor)),
            ),
            if (leadScore > 0) ...[
              const SizedBox(height: 4),
              Text('Score: $leadScore', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ]),
        ]),
        if (source != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
            child: Text(source, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _actionBtn(Icons.open_in_new_rounded, AppColors.accent, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CrmContactDetailScreen(contactId: contact['id'].toString(), contactName: name)));
          }),
          const SizedBox(width: 8),
          _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: contact)),
          const SizedBox(width: 8),
          _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(contact)),
        ]),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
