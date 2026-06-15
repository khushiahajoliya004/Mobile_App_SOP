import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

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

/// Call QuickLeadSheet.show(context) from anywhere to open the CRM lead creation form.
class QuickLeadSheet {
  static Future<void> show(BuildContext context) async {
    final api = ApiService();
    final auth = AuthService();
    final user = await auth.getUser();

    List<Map<String, dynamic>> branches = [];
    List<Map<String, dynamic>> pipelines = [];
    List<Map<String, dynamic>> assignableUsers = [];

    try {
      final results = await Future.wait([
        api.getCrmPipelines(),
        api.getBranches(),
        (user?.branchId != null && user!.branchId!.isNotEmpty)
            ? api.getBranchTeam(user.branchId!)
            : (user?.branchRole == 'TEAM_LEADER' && user?.id != null
                ? api.getUsersByReportingTo(user!.id)
                : api.getAssignableUsers()),
      ]);

      final pRaw = results[0].data;
      pipelines = pRaw is List
          ? pRaw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((pRaw is Map ? (pRaw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();

      final bRaw = results[1].data;
      branches = bRaw is List
          ? bRaw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((bRaw is Map ? (bRaw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();

      final uRaw = results[2].data;
      assignableUsers = (user?.branchId != null && user!.branchId!.isNotEmpty)
          ? _normalizeBranchTeam(uRaw)
          : _normalizeUsers(uRaw);
    } catch (_) {}

    if (!context.mounted) return;

    final branchLocked = user?.branchId != null && (user?.branchId?.isNotEmpty == true);
    String? selectedBranchId = branchLocked ? user!.branchId : null;
    String? selectedPipelineId = pipelines.isNotEmpty
        ? (pipelines.firstWhere((p) => p['isDefault'] == true, orElse: () => pipelines.first)['id'] as String?)
        : null;
    String? selectedSource = 'WALK_IN';
    Map<String, dynamic>? selectedOwner;
    bool createDeal = true;
    List<Map<String, dynamic>> branchUsers = List.from(assignableUsers);
    String ownerSearch = '';
    bool showOwnerDropdown = false;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> reloadBranchUsers(String? branchId) async {
            try {
              if (branchId != null) {
                final res = await api.getBranchTeam(branchId);
                setSheet(() { branchUsers = _normalizeBranchTeam(res.data); selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; });
              } else {
                final res = await api.getAssignableUsers();
                setSheet(() { branchUsers = _normalizeUsers(res.data); selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; });
              }
            } catch (_) {}
          }

          Widget sectionHeader(String label) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
          );

          Widget formField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) => TextField(
            controller: ctrl,
            keyboardType: type,
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
              final branchName = branches.firstWhere(
                (b) => b['id'] == selectedBranchId,
                orElse: () => {'name': user?.branchName ?? selectedBranchId ?? 'Branch'},
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
                    ...branches.map((b) => DropdownMenuItem<String>(value: b['id'] as String?, child: Text('${b['name']}', style: const TextStyle(fontSize: 14)))),
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
                items: pipelines.map((p) => DropdownMenuItem<String>(value: p['id'] as String?, child: Text('${p['name']}', style: const TextStyle(fontSize: 14)))).toList(),
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
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Expanded(child: Text('Create Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                        ),
                      ),
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
                      Expanded(child: sourceDropdown()),
                      const SizedBox(width: 10),
                      Expanded(child: branchWidget()),
                    ]),
                    const SizedBox(height: 10),
                    // Assign To — inline searchable dropdown
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(
                        onChanged: (v) => setSheet(() => ownerSearch = v),
                        onTap: () => setSheet(() => showOwnerDropdown = true),
                        decoration: InputDecoration(
                          hintText: selectedOwner != null ? '${selectedOwner!['name']}' : 'Search team member by name...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: selectedOwner != null ? AppColors.textPrimary : AppColors.textHint,
                            fontWeight: selectedOwner != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
                          suffixIcon: selectedOwner != null
                              ? GestureDetector(
                                  onTap: () => setSheet(() { selectedOwner = null; ownerSearch = ''; showOwnerDropdown = false; }),
                                  child: const Icon(Icons.clear, size: 16, color: AppColors.textHint),
                                )
                              : (showOwnerDropdown
                                  ? GestureDetector(
                                      onTap: () => setSheet(() { showOwnerDropdown = false; ownerSearch = ''; }),
                                      child: const Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.textHint),
                                    )
                                  : null),
                          filled: true, fillColor: const Color(0xFFF5F6FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                      ),
                      if (dropdownVisible)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceLight),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: filteredUsers.isEmpty
                                ? [Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      branchUsers.isEmpty ? 'No team members in this branch' : 'No members found',
                                      style: const TextStyle(color: AppColors.textHint, fontSize: 13),
                                    ),
                                  )]
                                : filteredUsers.take(10).map((u) => InkWell(
                                    onTap: () => setSheet(() { selectedOwner = u; ownerSearch = ''; showOwnerDropdown = false; }),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                          child: Text('${u['name']}'[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('${u['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          if ((u['branchName'] ?? u['roleName'] ?? '').toString().isNotEmpty)
                                            Text(
                                              '${u['branchName'] ?? ''}${u['roleName'] != null ? ' · ${u['roleName']}' : ''}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                            ),
                                        ])),
                                      ]),
                                    ),
                                  )).toList(),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    // CREATE DEAL toggle
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
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppColors.surfaceLight),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name is required'), backgroundColor: AppColors.error));
                            return;
                          }
                          if (phoneCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Phone is required'), backgroundColor: AppColors.error));
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await api.createCrmQuickLead(
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lead "${nameCtrl.text.trim()}" created'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
}
