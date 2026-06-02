import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_lead_detail_screen.dart';

class CrmLeadsScreen extends StatefulWidget {
  const CrmLeadsScreen({super.key});

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _assignableUsers = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _pipelines = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadFormData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        _api.getBranches(),
        _api.getLeadPipelines(),
        _api.getAssignableUsers(),
      ]);
      final bRaw = results[0].data;
      final pRaw = results[1].data;
      final uRaw = results[2].data;
      if (mounted) {
        setState(() {
          _branches = _toList(bRaw);
          _pipelines = _toList(pRaw);
          _assignableUsers = _toList(uRaw);
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getLeadBoard(
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      setState(() {
        _leads = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String source = 'Walk-in';
    String buyerType = '';
    String priority = 'MEDIUM';
    String? branchId;
    String? pipelineId;
    Map<String, dynamic>? assignedUser;
    // Reactive user list: all users when no branch, branch users when branch selected
    List<Map<String, dynamic>> sheetUsers = List.from(_assignableUsers);
    bool sheetUsersLoading = false;

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

                  // ── Phone ──
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 15,
                    decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
                  ),
                  const SizedBox(height: 12),

                  // ── Source ──
                  DropdownButtonFormField<String>(
                    initialValue: source,
                    decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source_outlined)),
                    items: ['Walk-in', 'Call', 'Website', 'Facebook', 'Instagram', 'Google Ads', 'Reference', 'Event', 'Other']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setSheetState(() => source = v!),
                  ),
                  const SizedBox(height: 12),

                  // ── Interested Model ──
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Interested Model', prefixIcon: Icon(Icons.directions_car_outlined)),
                  ),
                  const SizedBox(height: 12),

                  // ── Priority + Buyer Type (2-column) ──
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'HOT',    child: Text('🔥 Hot')),
                          DropdownMenuItem(value: 'WARM',   child: Text('🌡 Warm')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('📋 Medium')),
                          DropdownMenuItem(value: 'COLD',   child: Text('❄ Cold')),
                        ],
                        onChanged: (v) => setSheetState(() => priority = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: buyerType.isEmpty ? null : buyerType,
                        decoration: const InputDecoration(labelText: 'Buyer Type', isDense: true),
                        hint: const Text('Select'),
                        items: const [
                          DropdownMenuItem(value: 'FIRST_TIME',   child: Text('First Time')),
                          DropdownMenuItem(value: 'ADDITIONAL',   child: Text('Additional')),
                          DropdownMenuItem(value: 'REPLACEMENT',  child: Text('Replacement')),
                        ],
                        onChanged: (v) => setSheetState(() => buyerType = v ?? ''),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Branch ──
                  if (_branches.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Branch', prefixIcon: Icon(Icons.business_outlined)),
                      hint: const Text('Select branch'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Branches'),
                        ),
                        ..._branches.map((b) => DropdownMenuItem<String>(
                          value: b['id']?.toString(),
                          child: Text(b['name']?.toString() ?? ''),
                        )),
                      ],
                      onChanged: (v) => onBranchChanged(v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Pipeline ──
                  if (_pipelines.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: pipelineId,
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
                  const SizedBox(height: 20),

                  // ── Submit ──
                  FilledButton(
                    onPressed: nameCtrl.text.trim().isEmpty ? null : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      if (phone.isNotEmpty) {
                        try {
                          final dupRes = await _api.checkDuplicateLead(phone);
                          final raw = dupRes.data;
                          final data = raw is Map ? (raw['data'] ?? raw) : {};
                          final isDuplicate = data['isDuplicate'] == true || data['exists'] == true;
                          if (isDuplicate && ctx.mounted) {
                            final existingName = (data['lead'] ?? data['existingLead'] ?? {})['customerName'] ?? 'another lead';
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
                        await _api.createLead(
                          customerName: name,
                          phone: phone.isEmpty ? null : phone,
                          source: source,
                          interestedModel: modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
                          buyerType: buyerType.isEmpty ? null : buyerType,
                          priority: priority,
                          branchId: branchId,
                          pipelineId: pipelineId,
                          assignedToUserId: assignedUser?['id']?.toString(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to create lead: $e')),
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
                    await _api.assignLead((lead['leadId'] ?? lead['id']).toString(), user['id']);
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
      await _api.updateLeadStatus((lead['leadId'] ?? lead['id']).toString(), {'status': 'LOST'});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark lost: $e')),
        );
      }
    }
  }

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
    // /leads/board returns: leadId, mobileNumber, assignedDse (flat string),
    // leadStatus, currentStage
    final leadId = (lead['leadId'] ?? lead['id'] ?? '').toString();
    final status = (lead['leadStatus'] ?? lead['status'] ?? 'OPEN').toString();
    final stageName = lead['currentStage']?.toString().isNotEmpty == true
        ? lead['currentStage'].toString()
        : (lead['leadStage'] is Map ? lead['leadStage']['name'] : (lead['stageName'] ?? '')).toString();
    final phone = (lead['mobileNumber'] ?? lead['phone'] ?? '').toString();
    final assignedTo = lead['assignedDse']?.toString().isNotEmpty == true
        ? lead['assignedDse'].toString()
        : (lead['assignedTo'] is Map
            ? '${lead['assignedTo']['firstName'] ?? ''} ${lead['assignedTo']['lastName'] ?? ''}'.trim()
            : (lead['assignedToName'] ?? ''));
    final displayAssigned = assignedTo.isNotEmpty ? assignedTo : 'Unassigned';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, __, ___) => CrmLeadDetailScreen(
            leadId: leadId,
            leadName: lead['customerName'] ?? 'Lead',
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ).then((_) => _load()),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
                  lead['customerName'] ?? 'Unknown',
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
