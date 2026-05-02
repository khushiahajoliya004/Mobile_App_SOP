import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../call_recorder_screen.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});
  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  bool _loading = true;

  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadDashboard(),
      _loadLeads(),
      _loadFollowUps(),
      _loadVisits(),
      _loadBranches(),
      _loadPipelines(),
      _loadUsers(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDashboard() async {
    try {
      final r = await _api.getCrmDashboard();
      _dashboard = Map<String, dynamic>.from(r.data['data'] ?? {});
    } catch (_) {}
  }

  Future<void> _loadLeads() async {
    try {
      final r = await _api.getLeads();
      _leads = _p(r.data);
    } catch (_) {
      _leads = [];
    }
  }

  Future<void> _loadFollowUps() async {
    try {
      final r = await _api.getFollowUps();
      _followUps = _p(r.data);
    } catch (_) {
      _followUps = [];
    }
  }

  Future<void> _loadVisits() async {
    try {
      final r = await _api.getVisits();
      _visits = _p(r.data);
    } catch (_) {
      _visits = [];
    }
  }

  Future<void> _loadBranches() async {
    try {
      final r = await _api.genericGet('/branches');
      _branches = _p(r.data);
    } catch (_) {
      _branches = [];
    }
  }

  Future<void> _loadPipelines() async {
    try {
      final r = await _api.genericGet('/lead-pipelines');
      _pipelines = _p(r.data);
    } catch (_) {
      _pipelines = [];
    }
  }

  Future<void> _loadUsers() async {
    try {
      final r = await _api.getAssignableUsers();
      _users = _p(r.data);
    } catch (_) {
      _users = [];
    }
  }

  List<Map<String, dynamic>> _p(dynamic raw) {
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map)
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    return [];
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Leads'),
              Tab(text: 'Follow-ups'),
              Tab(text: 'Visits'),
              Tab(text: 'Branches'),
              Tab(text: 'Pipelines'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _overviewTab(),
                    _leadsTab(),
                    _followUpsTab(),
                    _visitsTab(),
                    _branchesTab(),
                    _pipelinesTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // ═══ OVERVIEW TAB ═══════════════════════════════════════════════════════

  Widget _overviewTab() {
    final stats = Map<String, dynamic>.from(_dashboard['stats'] ?? {});
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _stat(
                'Total Leads',
                '${stats['totalLeads'] ?? 0}',
                Icons.people,
                AppColors.primary,
              ),
              _stat(
                'Open',
                '${stats['openLeads'] ?? 0}',
                Icons.lock_open,
                AppColors.warning,
              ),
              _stat(
                'Converted',
                '${stats['convertedLeads'] ?? 0}',
                Icons.check_circle,
                AppColors.success,
              ),
              _stat(
                'Follow-ups',
                '${stats['pendingFollowUps'] ?? 0}',
                Icons.calendar_today,
                AppColors.accent,
              ),
              _stat(
                'Overdue',
                '${stats['overdueFollowUps'] ?? 0}',
                Icons.warning,
                AppColors.error,
              ),
              _stat(
                'Conversion',
                '${stats['conversionRate'] ?? 0}%',
                Icons.trending_up,
                AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Salesperson stats
          if ((_dashboard['salespersonStats'] ?? []).isNotEmpty) ...[
            const Text(
              'Salesperson Performance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...(_dashboard['salespersonStats'] as List).map((s) {
              final sp = Map<String, dynamic>.from(s);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySurface,
                      child: Text(
                        '${sp['name'] ?? '?'}'.isNotEmpty
                            ? '${sp['name']}'[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sp['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _chip('${sp['totalLeads'] ?? 0} leads', AppColors.primary),
                    const SizedBox(width: 6),
                    _chip(
                      '${sp['convertedLeads'] ?? 0} won',
                      AppColors.success,
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      );

  // ═══ LEADS TAB ════════════════════════════════════════════════════════════

  Widget _leadsTab() {
    return Column(
      children: [
        // Create lead + search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_leads.length} leads',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCreateLead,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New Lead',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadLeads,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _leads.length,
              itemBuilder: (_, i) => _leadCard(_leads[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final name = lead['customerName'] ?? 'Unknown';
    final status = lead['status'] ?? 'OPEN';
    final phone = lead['phone'] ?? '';
    final assignedTo = lead['assignedTo'];
    final assignedName = assignedTo != null
        ? '${assignedTo['firstName'] ?? ''} ${assignedTo['lastName'] ?? ''}'
              .trim()
        : '';
    final stage = lead['leadStage']?['name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          if (phone.isNotEmpty || assignedName.isNotEmpty || stage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (phone.isNotEmpty) _chip(phone, AppColors.textSecondary),
                  if (assignedName.isNotEmpty)
                    _chip(assignedName, AppColors.primary),
                  if (stage.isNotEmpty) _chip(stage, AppColors.accent),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _smallBtn(
                  Icons.person_add,
                  'Assign',
                  () => _showAssignLead(lead),
                ),
                const SizedBox(width: 6),
                _smallBtn(
                  Icons.mic,
                  'Record',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallRecorderScreen(
                        leadId: lead['id'],
                        leadCustomerName: name,
                      ),
                    ),
                  ).then((_) => _loadLeads()),
                ),
                const SizedBox(width: 6),
                _smallBtn(
                  Icons.event,
                  'Booking',
                  () => _setDate(lead, 'bookingDate', 'Booking'),
                ),
                const SizedBox(width: 6),
                _smallBtn(
                  Icons.local_shipping,
                  'Delivery',
                  () => _setDate(lead, 'deliveryDate', 'Delivery'),
                ),
                const SizedBox(width: 6),
                _smallBtn(Icons.close, 'Lost', () async {
                  await _api.updateLeadStatus(lead['id'], {
                    'status': 'LOST',
                    'lostReason': 'Marked lost',
                  });
                  _msg('Marked lost');
                  _loadLeads();
                }, color: AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateLead() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
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
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Lead',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _input(nameCtrl, 'Customer Name *'),
            const SizedBox(height: 10),
            _input(phoneCtrl, 'Phone', type: TextInputType.phone),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await _api.createLead(
                      customerName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                    _msg('Lead created');
                    _loadAll();
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
                child: const Text('Create Lead'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignLead(Map<String, dynamic> lead) {
    if (_users.isEmpty) {
      _msg('No users available');
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign "${lead['customerName']}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                      .trim();
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySurface,
                      child: Text(
                        n.isNotEmpty ? n[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(n, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      u['email'] ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.assignLead(lead['id'], u['id']);
                        _msg('Assigned');
                        _loadLeads();
                      } catch (e) {
                        _msg('Failed: $e', error: true);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setDate(
    Map<String, dynamic> lead,
    String field,
    String label,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _api.updateLeadStatus(lead['id'], {
      field: dt.toUtc().toIso8601String(),
    });
    _msg('$label updated');
    _loadLeads();
  }

  // ═══ FOLLOW-UPS TAB ════════════════════════════════════════════════════

  Widget _followUpsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_followUps.length} follow-ups',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCreateFollowUp,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadFollowUps,
            child: _followUps.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'No follow-ups',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _followUps.length,
                    itemBuilder: (_, i) {
                      final f = _followUps[i];
                      final leadName = f['lead']?['customerName'] ?? 'Lead';
                      final status = f['status'] ?? '';
                      final type = f['type'] ?? 'CALL';
                      final scheduled = f['scheduledAt'];
                      final isOverdue =
                          status == 'PENDING' &&
                          scheduled != null &&
                          DateTime.tryParse(
                                '$scheduled',
                              )?.isBefore(DateTime.now()) ==
                              true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOverdue
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.surfaceLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color:
                                    (isOverdue
                                            ? AppColors.error
                                            : AppColors.primary)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                type == 'CALL'
                                    ? Icons.phone
                                    : type == 'VISIT'
                                    ? Icons.directions_car
                                    : Icons.handshake,
                                size: 18,
                                color: isOverdue
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leadName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$type · ${_fmtDate(scheduled)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOverdue
                                          ? AppColors.error
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusChip(isOverdue ? 'OVERDUE' : status),
                            if (status == 'PENDING') ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  await _api.genericPatch(
                                    '/follow-ups/${f['id']}/complete',
                                    {'outcome': 'Completed'},
                                  );
                                  _msg('Completed');
                                  _loadFollowUps();
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showCreateFollowUp() {
    String? leadId;
    String type = 'CALL';
    DateTime? scheduled;
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
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Follow-up',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              // Lead picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: leadId,
                    isExpanded: true,
                    hint: const Text('Select Lead'),
                    items: _leads
                        .map(
                          (l) => DropdownMenuItem(
                            value: l['id'] as String,
                            child: Text(
                              '${l['customerName']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => leadId = v),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Type
              Wrap(
                spacing: 8,
                children: ['CALL', 'MEETING', 'VISIT']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            color: type == t
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: type == t,
                        selectedColor: AppColors.primary,
                        onSelected: (_) => setSheet(() => type = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              // Date picker
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null)
                    setSheet(
                      () => scheduled = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scheduled != null
                            ? '${scheduled!.day}/${scheduled!.month}/${scheduled!.year} ${scheduled!.hour}:${scheduled!.minute.toString().padLeft(2, '0')}'
                            : 'Pick date & time',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (leadId == null || scheduled == null) {
                      _msg('Select lead and date', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await _api.createFollowUp(
                        leadId: leadId!,
                        scheduledAt: scheduled!,
                        type: type,
                      );
                      _msg('Follow-up created');
                      _loadAll();
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
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ VISITS TAB ═══════════════════════════════════════════════════════════

  Widget _visitsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_visits.length} visits',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCreateVisit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadVisits,
            child: _visits.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'No visits',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _visits.length,
                    itemBuilder: (_, i) {
                      final v = _visits[i];
                      final leadName = v['lead']?['customerName'] ?? 'Lead';
                      final status = v['status'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 18,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leadName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _fmtDate(v['scheduledAt']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showCreateVisit() {
    String? leadId;
    DateTime? scheduled;
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
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Visit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: leadId,
                    isExpanded: true,
                    hint: const Text('Select Lead'),
                    items: _leads
                        .map(
                          (l) => DropdownMenuItem(
                            value: l['id'] as String,
                            child: Text(
                              '${l['customerName']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => leadId = v),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null)
                    setSheet(
                      () => scheduled = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scheduled != null
                            ? '${scheduled!.day}/${scheduled!.month}/${scheduled!.year} ${scheduled!.hour}:${scheduled!.minute.toString().padLeft(2, '0')}'
                            : 'Pick date & time',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (leadId == null || scheduled == null) {
                      _msg('Select lead and date', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await _api.genericPost('/visits', {
                        'leadId': leadId,
                        'scheduledAt': scheduled!.toUtc().toIso8601String(),
                      });
                      _msg('Visit created');
                      _loadAll();
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
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ BRANCHES TAB ══════════════════════════════════════════════════════

  Widget _branchesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_branches.length} branches',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCreateBranch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadBranches,
            child: _branches.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'No branches',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _branches.length,
                    itemBuilder: (_, i) {
                      final b = _branches[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.business,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if ((b['city'] ?? '').toString().isNotEmpty)
                                    Text(
                                      b['city'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  if ((b['code'] ?? '').toString().isNotEmpty)
                                    Text(
                                      'Code: ${b['code']}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showBranchTeam(b),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Team',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showCreateBranch() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
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
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Branch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _input(nameCtrl, 'Branch Name *'),
            const SizedBox(height: 10),
            _input(codeCtrl, 'Code'),
            const SizedBox(height: 10),
            _input(cityCtrl, 'City'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await _api.genericPost('/branches', {
                      'name': nameCtrl.text.trim(),
                      'code': codeCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                    });
                    _msg('Branch created');
                    _loadBranches();
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
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBranchTeam(Map<String, dynamic> branch) async {
    List<Map<String, dynamic>> team = [];
    try {
      final r = await _api.genericGet('/branches/${branch['id']}/team');
      team = _p(r.data);
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${branch['name']} — Team',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (team.isEmpty)
                const Text(
                  'No team members',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ...team.map((m) {
                final u = m['user'];
                final n = u != null
                    ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
                    : 'Unknown';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          n.isNotEmpty ? n[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              m['branchRole'] ?? '',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          try {
                            await _api.genericDelete(
                              '/branches/${branch['id']}/users/${m['userId']}',
                            );
                            final r = await _api.genericGet(
                              '/branches/${branch['id']}/team',
                            );
                            setSheet(() => team = _p(r.data));
                            _msg('Removed');
                          } catch (e) {
                            _msg('Failed: $e', error: true);
                          }
                        },
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Add user
              GestureDetector(
                onTap: () => _showAssignToBranch(branch['id'], () async {
                  final r = await _api.genericGet(
                    '/branches/${branch['id']}/team',
                  );
                  setSheet(() => team = _p(r.data));
                }),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Add Team Member',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignToBranch(String branchId, VoidCallback onDone) {
    String? userId;
    String role = 'SALES_MANAGER';
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
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Team Member',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: userId,
                    isExpanded: true,
                    hint: const Text('Select User'),
                    items: _users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u['id'] as String,
                            child: Text(
                              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                                  .trim(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => userId = v),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children:
                    [
                          'BRANCH_MANAGER',
                          'TEAM_LEADER',
                          'SALES_MANAGER',
                          'RECEPTIONIST',
                        ]
                        .map(
                          (r) => ChoiceChip(
                            label: Text(
                              r.replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 10,
                                color: role == r
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: role == r,
                            selectedColor: AppColors.primary,
                            onSelected: (_) => setSheet(() => role = r),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (userId == null) return;
                    Navigator.pop(ctx);
                    try {
                      await _api.genericPost('/branches/$branchId/users', {
                        'userId': userId,
                        'branchRole': role,
                      });
                      _msg('Added');
                      onDone();
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
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ PIPELINES TAB ════════════════════════════════════════════════════════

  Widget _pipelinesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_pipelines.length} pipelines',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCreatePipeline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadPipelines,
            child: _pipelines.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'No pipelines',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pipelines.length,
                    itemBuilder: (_, i) {
                      final p = _pipelines[i];
                      final stages = (p['stages'] ?? []) as List;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_tree_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                _chip(
                                  '${stages.length} stages',
                                  AppColors.primary,
                                ),
                              ],
                            ),
                            if (stages.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: stages.map((s) {
                                  final st = Map<String, dynamic>.from(s);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      st['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showCreatePipeline() {
    final nameCtrl = TextEditingController();
    final stagesCtrl = TextEditingController(
      text: 'New Lead\nContacted\nFollow-up\nConverted',
    );
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
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Pipeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _input(nameCtrl, 'Pipeline Name *'),
            const SizedBox(height: 10),
            TextField(
              controller: stagesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Stages (one per line)',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final stages = stagesCtrl.text
                      .split('\n')
                      .where((l) => l.trim().isNotEmpty)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (e) => {
                          'name': e.value.trim(),
                          'sortOrder': e.key + 1,
                          'isWon': e.value.toLowerCase().contains('converted'),
                          'isLost': e.value.toLowerCase().contains('lost'),
                        },
                      )
                      .toList();
                  try {
                    await _api.genericPost('/lead-pipelines', {
                      'name': nameCtrl.text.trim(),
                      'stages': stages,
                    });
                    _msg('Pipeline created');
                    _loadPipelines();
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
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ HELPERS ══════════════════════════════════════════════════════════════

  Widget _input(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
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

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _statusChip(String status) {
    Color c;
    switch (status.toUpperCase()) {
      case 'OPEN':
      case 'PENDING':
      case 'PLANNED':
        c = AppColors.warning;
        break;
      case 'CONVERTED':
      case 'COMPLETED':
      case 'REVIEWED':
        c = AppColors.success;
        break;
      case 'LOST':
      case 'OVERDUE':
        c = AppColors.error;
        break;
      default:
        c = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }

  Widget _smallBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = AppColors.primary,
  }) => GestureDetector(
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  String _fmtDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse('$date').toLocal();
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
      return '${d.day} ${m[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '$date';
    }
  }
}
