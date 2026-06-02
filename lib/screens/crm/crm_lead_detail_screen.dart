import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmLeadDetailScreen extends StatefulWidget {
  final String leadId;
  final String leadName;
  final bool isDeal; // true = CRM v2 deal, false = v1 lead

  const CrmLeadDetailScreen({super.key, required this.leadId, required this.leadName, this.isDeal = false});

  @override
  State<CrmLeadDetailScreen> createState() => _CrmLeadDetailScreenState();
}

class _CrmLeadDetailScreenState extends State<CrmLeadDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;

  bool _loading = true;
  String? _error;

  // From getLeadDetails response
  Map<String, dynamic> _lead = {};
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _testDrives = [];
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic> _stats = {};

  // Requirement form
  final Map<String, dynamic> _reqForm = {};
  bool _reqSaving = false;

  // Reassign DSE popup
  bool _showReassignPopup = false;
  List<Map<String, dynamic>> _branchTeam = [];
  List<Map<String, dynamic>> _reassignBranches = [];
  String? _selectedDseId;
  String? _reassignBranchId;
  final _reassignReasonCtrl = TextEditingController();
  bool _teamLoading = false;
  bool _reassignLoading = false;
  bool _reassignSuccess = false;

  static const _tabLabels = [
    'Overview', 'Requirement', 'Timeline', 'Follow-ups',
    'Visits', 'Test Drives', 'Quotations', 'Bookings', 'Delivery'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabLabels.length, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _reassignReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      Map<String, dynamic> data;
      if (widget.isDeal) {
        // CRM v2 deal
        final dealRes = await _api.getCrmDeal(widget.leadId);
        final raw = dealRes.data;
        final deal = raw is Map ? Map<String, dynamic>.from((raw['data'] ?? raw) as Map) : {};
        final contact = deal['contact'] is Map ? deal['contact'] as Map : {};

        // Fetch v2 follow-ups for this deal
        List followUpsList = [];
        try {
          final fuRes = await _api.getCrmFollowUpsByDeal(widget.leadId);
          final fuRaw = fuRes.data;
          final fuData = fuRaw is Map ? (fuRaw['data'] ?? fuRaw) : fuRaw;
          followUpsList = fuData is List ? fuData : (fuData is Map ? (fuData['items'] ?? fuData['followUps'] ?? []) : []);
        } catch (_) {}

        // Normalize deal → lead shape so the existing UI still works
        data = {
          'lead': {
            'id': deal['id'],
            'customerName': contact['name'] ?? deal['name'] ?? '',
            'phone': contact['phone'] ?? '',
            'email': contact['email'] ?? '',
            'status': deal['status'] ?? 'OPEN',
            'priority': deal['priority'] ?? 'MEDIUM',
            'source': contact['source'] ?? '',
            'branchId': deal['branchId'],
            'branch': deal['branch'],
            'assignedToUserId': deal['ownerUserId'],
            'assignedTo': deal['owner'],
            'notes': deal['notes'] ?? '',
            'createdAt': deal['createdAt'],
          },
          'activities': deal['activities'] ?? [],
          'followUps': followUpsList,
          'visits': [],
          'testDrives': [],
          'quotations': [],
          'bookings': [],
          'deliveries': [],
          'tasks': [],
          'stats': { 'daysOld': 0, 'followUps': followUpsList.length, 'completed': 0, 'pending': 0 },
        };
      } else {
        // CRM v1 lead
        final res = await _api.getLeadDetails(widget.leadId);
        final raw = res.data;
        data = raw is Map ? Map<String, dynamic>.from((raw['data'] ?? raw) as Map) : {};
      }
      if (mounted) {
        setState(() {
          _lead = Map<String, dynamic>.from((data['lead'] ?? data) as Map);
          _activities = _toList(data['activities']);
          _followUps = _toList(data['followUps']);
          _visits = _toList(data['visits']);
          _testDrives = _toList(data['testDrives']);
          _quotations = _toList(data['quotations']);
          _bookings = _toList(data['bookings']);
          _deliveries = _toList(data['deliveries']);
          _tasks = _toList(data['tasks']);
          _stats = data['stats'] is Map ? Map<String, dynamic>.from(data['stats'] as Map) : {};
          // Pre-fill requirement form
          _reqForm.addAll({
            'interestedModel': _lead['interestedModel'] ?? '',
            'interestedVariant': _lead['interestedVariant'] ?? '',
            'fuelType': _lead['fuelType'] ?? '',
            'transmission': _lead['transmission'] ?? '',
            'colorPreference': _lead['colorPreference'] ?? '',
            'budgetRange': _lead['budgetRange'] ?? '',
            'expectedPurchaseTime': _lead['expectedPurchaseTime'] ?? '',
            'financeRequired': _lead['financeRequired'] ?? '',
            'exchangeRequired': _lead['exchangeRequired'] ?? '',
            'currentVehicleBrand': _lead['currentVehicleBrand'] ?? '',
            'currentVehicleModel': _lead['currentVehicleModel'] ?? '',
            'currentVehicleYear': _lead['currentVehicleYear'] ?? '',
            'currentVehicleNumber': _lead['currentVehicleNumber'] ?? '',
            'expectedExchangeValue': _lead['expectedExchangeValue'],
            'customerProfession': _lead['customerProfession'] ?? '',
            'customerAddress': _lead['customerAddress'] ?? '',
            'customerCity': _lead['customerCity'] ?? '',
            'customerState': _lead['customerState'] ?? '',
            'customerPincode': _lead['customerPincode'] ?? '',
            'buyerType': _lead['buyerType'] ?? '',
            'notes': _lead['notes'] ?? '',
            'nextAction': '',
          });
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  // ── Reassign DSE ──────────────────────────────────────────────────────────

  Future<void> _openReassignPopup() async {
    final leadBranchId = _lead['branchId']?.toString() ??
        (_lead['branch'] is Map ? _lead['branch']['id']?.toString() : null);
    setState(() {
      _selectedDseId = _lead['assignedToUserId']?.toString();
      _reassignReasonCtrl.clear();
      _reassignSuccess = false;
      _branchTeam = [];
      _reassignBranches = [];
      _reassignBranchId = leadBranchId;
      _showReassignPopup = true;
      _teamLoading = true;
    });
    try {
      // Load branches list
      final branchRes = await _api.getBranches();
      final branchRaw = branchRes.data;
      final branchList = branchRaw is List
          ? branchRaw
          : (branchRaw is Map ? (branchRaw['data'] ?? []) as List : []);
      final branches = branchList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _reassignBranches = branches);

      // Load users for the pre-selected branch
      await _loadReassignUsers(leadBranchId);
    } catch (_) {
      if (mounted) setState(() => _teamLoading = false);
    }
  }

  Future<void> _loadReassignUsers(String? branchId) async {
    if (mounted) setState(() { _teamLoading = true; _branchTeam = []; _selectedDseId = null; });
    try {
      List<Map<String, dynamic>> team = [];
      if (branchId != null && branchId.isNotEmpty) {
        final res = await _api.getCrmUsersByBranch(branchId);
        final raw = res.data;
        final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
        team = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        final res = await _api.getAssignableUsers();
        final raw = res.data;
        final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
        team = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (mounted) setState(() { _branchTeam = team; _teamLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _teamLoading = false);
    }
  }

  Future<void> _confirmReassign() async {
    if (_selectedDseId == null) return;
    setState(() => _reassignLoading = true);
    try {
      await _api.reassignDse(widget.leadId, _selectedDseId!,
          reason: _reassignReasonCtrl.text.trim().isEmpty ? null : _reassignReasonCtrl.text.trim());
      if (mounted) {
        setState(() { _reassignLoading = false; _reassignSuccess = true; });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) { setState(() => _showReassignPopup = false); _loadDetails(); }
      }
    } catch (e) {
      if (mounted) { setState(() => _reassignLoading = false); _showSnack('Failed: $e'); }
    }
  }

  // ── Mark Lost / Reopen ────────────────────────────────────────────────────

  Future<void> _markLost() async {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Lost'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(labelText: 'Lost reason?', hintText: 'Why is this lead lost?'),
            maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.markLeadLost(widget.leadId,
                    reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDetails();
                _showSnack('Lead marked as lost', success: true);
              } catch (e) { _showSnack('Failed: $e'); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ── Requirement ───────────────────────────────────────────────────────────

  Future<void> _saveRequirement() async {
    if (_reqSaving) return;
    setState(() => _reqSaving = true);
    try {
      await _api.saveLeadRequirement(widget.leadId, Map<String, dynamic>.from(_reqForm));
      _showSnack('Requirement saved', success: true);
      _loadDetails();
    } catch (e) { _showSnack('Failed: $e'); }
    finally { if (mounted) setState(() => _reqSaving = false); }
  }

  // ── Follow-up ─────────────────────────────────────────────────────────────

  void _openFollowUpForm() {
    final scheduledCtrl = TextEditingController();
    String type = 'CALL';
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Schedule Follow-up'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'CALL', child: Text('Call')),
                  DropdownMenuItem(value: 'MEETING', child: Text('Meeting')),
                  DropdownMenuItem(value: 'VISIT', child: Text('Visit')),
                ],
                onChanged: (v) => ss(() => type = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scheduledCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Scheduled Date & Time *',
                  prefixIcon: Icon(Icons.calendar_today),
                  hintText: 'Tap to pick',
                ),
                onTap: () async {
                  final date = await showDatePicker(context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  scheduledCtrl.text = '${date.day}/${date.month}/${date.year} ${time.format(ctx)}';
                  scheduledCtrl.selection = TextSelection.collapsed(offset: scheduledCtrl.text.length);
                  ss(() {});
                  (ctx as Element).markNeedsBuild();
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: scheduledCtrl.text.isEmpty ? null : () async {
                try {
                  final parts = scheduledCtrl.text.split(' ')[0].split('/');
                  final timeParts = scheduledCtrl.text.split(' ');
                  DateTime dt;
                  if (timeParts.length > 1) {
                    dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                  } else {
                    dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                  }
                  if (widget.isDeal) {
                    await _api.createCrmFollowUp(
                      dealId: widget.leadId,
                      scheduledAt: dt,
                      type: type,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                  } else {
                    await _api.createFollowUp(
                      leadId: widget.leadId,
                      scheduledAt: dt,
                      type: type,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Follow-up scheduled', success: true);
                  _loadDetails();
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompleteFollowUp(Map<String, dynamic> fu) {
    String outcome = '';
    final notesCtrl = TextEditingController();
    String nextAction = '';
    final nextFuDateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Complete Follow-up'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: outcome.isEmpty ? null : outcome,
                decoration: const InputDecoration(labelText: 'Outcome *'),
                hint: const Text('Select outcome...'),
                items: const [
                  DropdownMenuItem(value: 'INTERESTED', child: Text('Interested')),
                  DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                  DropdownMenuItem(value: 'CALLBACK_REQUESTED', child: Text('Callback Requested')),
                  DropdownMenuItem(value: 'NOT_REACHABLE', child: Text('Not Reachable')),
                  DropdownMenuItem(value: 'VISIT_PLANNED', child: Text('Visit Planned')),
                  DropdownMenuItem(value: 'CONVERTED', child: Text('Converted')),
                ],
                onChanged: (v) => ss(() => outcome = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'What happened...')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: nextAction.isEmpty ? null : nextAction,
                decoration: const InputDecoration(labelText: 'Next Action'),
                hint: const Text('None'),
                items: const [
                  DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Schedule Another Follow-up')),
                  DropdownMenuItem(value: 'VISIT', child: Text('Schedule Visit')),
                  DropdownMenuItem(value: 'TEST_DRIVE', child: Text('Schedule Test Drive')),
                  DropdownMenuItem(value: 'QUOTATION', child: Text('Create Quotation')),
                ],
                onChanged: (v) => ss(() => nextAction = v ?? ''),
              ),
              if (nextAction == 'FOLLOW_UP') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: nextFuDateCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Next Follow-up Date & Time', prefixIcon: Icon(Icons.calendar_today)),
                  onTap: () async {
                    final date = await showDatePicker(context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (time == null) return;
                    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    ss(() => nextFuDateCtrl.text = dt.toIso8601String());
                  },
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: outcome.isEmpty ? null : () async {
                try {
                  if (widget.isDeal) {
                    await _api.completeCrmFollowUp(
                      fu['id'].toString(),
                      outcome: outcome,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      nextFollowUpDate: nextFuDateCtrl.text.isEmpty ? null : nextFuDateCtrl.text,
                    );
                  } else {
                    await _api.completeFollowUpWithWorkflow(fu['id'].toString(),
                      outcome: outcome,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      nextFollowUpDateTime: nextFuDateCtrl.text.isEmpty ? null : nextFuDateCtrl.text,
                      nextAction: nextAction.isEmpty ? null : nextAction,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Follow-up completed', success: true);
                  _loadDetails();
                  if (nextAction == 'VISIT') Future.delayed(const Duration(milliseconds: 300), _openVisitForm);
                  else if (nextAction == 'TEST_DRIVE') Future.delayed(const Duration(milliseconds: 300), _openTestDriveForm);
                  else if (nextAction == 'QUOTATION') Future.delayed(const Duration(milliseconds: 300), _openQuotationForm);
                  else if (nextAction == 'FOLLOW_UP') Future.delayed(const Duration(milliseconds: 300), _openFollowUpForm);
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Visit ─────────────────────────────────────────────────────────────────

  void _openVisitForm() {
    final scheduledCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Schedule Visit'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: scheduledCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Visit Date & Time *', prefixIcon: Icon(Icons.store_rounded)),
              onTap: () async {
                final date = await showDatePicker(context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                if (time == null) return;
                ss(() => scheduledCtrl.text = '${date.day}/${date.month}/${date.year} ${time.format(ctx)}');
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', hintText: 'Purpose of visit...')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: scheduledCtrl.text.isEmpty ? null : () async {
                try {
                  final parts = scheduledCtrl.text.split(' ')[0].split('/');
                  await _api.createVisit(
                    leadId: widget.leadId,
                    scheduledAt: DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Visit scheduled', success: true);
                  _loadDetails();
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompleteVisit(Map<String, dynamic> visit) {
    final feedbackCtrl = TextEditingController();
    String nextStep = '';
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Complete Visit'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: feedbackCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Customer Feedback', hintText: 'What did the customer say?')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: nextStep.isEmpty ? null : nextStep,
              decoration: const InputDecoration(labelText: 'Next Step'),
              hint: const Text('Select...'),
              items: const [
                DropdownMenuItem(value: 'TEST_DRIVE', child: Text('Test Drive')),
                DropdownMenuItem(value: 'QUOTATION', child: Text('Quotation')),
                DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow-up')),
                DropdownMenuItem(value: 'BOOKING', child: Text('Booking')),
                DropdownMenuItem(value: 'LOST', child: Text('Mark Lost')),
              ],
              onChanged: (v) => ss(() => nextStep = v ?? ''),
            ),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', hintText: 'Internal notes...')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.completeVisit(visit['id'].toString(),
                    customerFeedback: feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
                    nextStep: nextStep.isEmpty ? null : nextStep,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Visit completed', success: true);
                  _loadDetails();
                  if (nextStep == 'TEST_DRIVE') Future.delayed(const Duration(milliseconds: 300), _openTestDriveForm);
                  else if (nextStep == 'QUOTATION') Future.delayed(const Duration(milliseconds: 300), _openQuotationForm);
                  else if (nextStep == 'FOLLOW_UP') Future.delayed(const Duration(milliseconds: 300), _openFollowUpForm);
                  else if (nextStep == 'BOOKING') Future.delayed(const Duration(milliseconds: 300), _openBookingForm);
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Test Drive ────────────────────────────────────────────────────────────

  void _openTestDriveForm() {
    final modelCtrl = TextEditingController(text: _lead['interestedModel']?.toString() ?? '');
    final variantCtrl = TextEditingController();
    final scheduledCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Schedule Test Drive'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle Model', hintText: 'e.g. Tata Nexon'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: variantCtrl,
                    decoration: const InputDecoration(labelText: 'Variant', hintText: 'e.g. XZ+'))),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: scheduledCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Scheduled Date & Time *', prefixIcon: Icon(Icons.directions_car_rounded)),
                onTap: () async {
                  final date = await showDatePicker(context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  ss(() => scheduledCtrl.text = '${date.day}/${date.month}/${date.year} ${time.format(ctx)}');
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'Any special instructions...')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: scheduledCtrl.text.isEmpty ? null : () async {
                try {
                  final parts = scheduledCtrl.text.split(' ')[0].split('/');
                  await _api.createTestDrive(
                    leadId: widget.leadId,
                    scheduledAt: DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])),
                    vehicleModel: modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
                    variant: variantCtrl.text.trim().isEmpty ? null : variantCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Test drive scheduled', success: true);
                  _loadDetails();
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompleteTestDrive(Map<String, dynamic> td) {
    final feedbackCtrl = TextEditingController();
    String rating = '';
    String nextAction = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Complete Test Drive'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: feedbackCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Customer Feedback',
                    hintText: 'Customer\'s reaction after test drive...')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: rating.isEmpty ? null : rating,
              decoration: const InputDecoration(labelText: 'Rating (1–5)'),
              hint: const Text('Select rating...'),
              items: const [
                DropdownMenuItem(value: '5', child: Text('5 — Excellent')),
                DropdownMenuItem(value: '4', child: Text('4 — Good')),
                DropdownMenuItem(value: '3', child: Text('3 — Average')),
                DropdownMenuItem(value: '2', child: Text('2 — Below Average')),
                DropdownMenuItem(value: '1', child: Text('1 — Poor')),
              ],
              onChanged: (v) => ss(() => rating = v ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: nextAction.isEmpty ? null : nextAction,
              decoration: const InputDecoration(labelText: 'Next Action'),
              hint: const Text('Select...'),
              items: const [
                DropdownMenuItem(value: 'QUOTATION', child: Text('Create Quotation')),
                DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Schedule Follow-up')),
                DropdownMenuItem(value: 'BOOKING', child: Text('Proceed to Booking')),
                DropdownMenuItem(value: 'LOST', child: Text('Mark Lost')),
              ],
              onChanged: (v) => ss(() => nextAction = v ?? ''),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.completeTestDrive(td['id'].toString(),
                    feedback: feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
                    rating: rating.isEmpty ? null : int.tryParse(rating),
                    nextAction: nextAction.isEmpty ? null : nextAction,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Test drive completed', success: true);
                  _loadDetails();
                  if (nextAction == 'QUOTATION') Future.delayed(const Duration(milliseconds: 300), _openQuotationForm);
                  else if (nextAction == 'FOLLOW_UP') Future.delayed(const Duration(milliseconds: 300), _openFollowUpForm);
                  else if (nextAction == 'BOOKING') Future.delayed(const Duration(milliseconds: 300), _openBookingForm);
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quotation ─────────────────────────────────────────────────────────────

  void _openQuotationForm() {
    final modelCtrl = TextEditingController(text: _lead['interestedModel']?.toString() ?? '');
    final variantCtrl = TextEditingController(text: _lead['interestedVariant']?.toString() ?? '');
    final exShowCtrl = TextEditingController();
    final discCtrl = TextEditingController();
    final onRoadCtrl = TextEditingController();
    final validTillCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Create Quotation'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle Model', hintText: 'e.g. Tata Nexon'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: variantCtrl,
                    decoration: const InputDecoration(labelText: 'Variant', hintText: 'e.g. XZ+'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: exShowCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ex-Showroom (₹)', hintText: '0'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: discCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Discount (₹)', hintText: '0'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: onRoadCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'On-Road Price (₹)', hintText: '0'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: validTillCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Valid Till', hintText: 'Pick date'),
                  onTap: () async {
                    final date = await showDatePicker(context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date != null) {
                      ss(() => validTillCtrl.text = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}');
                    }
                  },
                )),
              ]),
              const SizedBox(height: 12),
              TextField(controller: remarksCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Remarks', hintText: 'Additional terms...')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.createQuotation({
                    'leadId': widget.leadId,
                    'model': modelCtrl.text.trim(),
                    'variant': variantCtrl.text.trim(),
                    if (exShowCtrl.text.trim().isNotEmpty) 'exShowroomPrice': double.tryParse(exShowCtrl.text.trim()),
                    if (discCtrl.text.trim().isNotEmpty) 'discount': double.tryParse(discCtrl.text.trim()),
                    if (onRoadCtrl.text.trim().isNotEmpty) 'finalOnRoadPrice': double.tryParse(onRoadCtrl.text.trim()),
                    if (validTillCtrl.text.isNotEmpty) 'validTillDate': validTillCtrl.text,
                    if (remarksCtrl.text.trim().isNotEmpty) 'remarks': remarksCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Quotation created', success: true);
                  _loadDetails();
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Create Quotation'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Booking ───────────────────────────────────────────────────────────────

  void _openBookingForm() {
    final modelCtrl = TextEditingController(text: _lead['interestedModel']?.toString() ?? '');
    final variantCtrl = TextEditingController(text: _lead['interestedVariant']?.toString() ?? '');
    final amountCtrl = TextEditingController();
    String paymentMode = 'CASH';
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Create Booking'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle Model', hintText: 'e.g. Tata Nexon'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: variantCtrl,
                    decoration: const InputDecoration(labelText: 'Variant', hintText: 'e.g. XZ+'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Booking Amount (₹) *', hintText: 'e.g. 25000',
                      prefixIcon: Icon(Icons.currency_rupee_outlined))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card')),
                ],
                onChanged: (v) => ss(() => paymentMode = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: remarksCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Remarks', hintText: 'Any special requests...')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: amountCtrl.text.trim().isEmpty ? null : () async {
                try {
                  await _api.createBooking({
                    'leadId': widget.leadId,
                    'model': modelCtrl.text.trim(),
                    'variant': variantCtrl.text.trim(),
                    'bookingAmount': double.tryParse(amountCtrl.text.trim()),
                    'paymentMode': paymentMode,
                    if (remarksCtrl.text.trim().isNotEmpty) 'remarks': remarksCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Booking created', success: true);
                  _loadDetails();
                } catch (e) { _showSnack('Failed: $e'); }
              },
              child: const Text('Create Booking'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
  }

  // ─────────────────────────── BUILD ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Stack(
        children: [
          SizedBox.expand(
            child: Column(
              children: [
                _buildHeader(),
                if (!_loading && _error == null) ...[
                  _buildStats(),
                  _buildTabBar(),
                ],
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
                      : _error != null
                          ? _buildError()
                          : TabBarView(
                              controller: _tabCtrl,
                              children: [
                                _buildOverviewTab(),
                                _buildRequirementTab(),
                                _buildTimelineTab(),
                                _buildFollowUpsTab(),
                                _buildVisitsTab(),
                                _buildTestDrivesTab(),
                                _buildQuotationsTab(),
                                _buildBookingsTab(),
                                _buildDeliveryTab(),
                              ],
                            ),
                ),
              ],
            ),
          ),
          if (_showReassignPopup) _buildReassignOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final status = (_lead['status'] ?? 'OPEN').toString();
    Color statusColor;
    switch (status.toUpperCase()) {
      case 'CONVERTED': case 'DELIVERED': statusColor = AppColors.success; break;
      case 'LOST': statusColor = AppColors.error; break;
      case 'BOOKED': statusColor = AppColors.warning; break;
      default: statusColor = AppColors.accent;
    }
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8, left: 4, right: 16, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.leadName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (_lead['phone'] != null) ...[
                      const Icon(Icons.phone, size: 11, color: Colors.white54),
                      const SizedBox(width: 3),
                      Text(_lead['phone']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (_lead['branch'] is Map) ...[
                      const Icon(Icons.store_outlined, size: 11, color: Colors.white54),
                      const SizedBox(width: 3),
                      Text(_lead['branch']['name']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Priority
          if (_lead['priority'] != null) ...[
            _priorityChip(_lead['priority'].toString()),
            const SizedBox(width: 6),
          ],
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          // Mark Lost / Reopen
          if (status.toUpperCase() != 'LOST')
            _headerBtn('Lost', AppColors.error, _markLost)
          else
            _headerBtn('Reopen', AppColors.success, () async {
              try { await _api.reopenLead(widget.leadId); _loadDetails(); _showSnack('Lead reopened', success: true); }
              catch (e) { _showSnack('Failed: $e'); }
            }),
        ],
      ),
    );
  }

  Widget _headerBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _priorityChip(String p) {
    Color c;
    switch (p.toUpperCase()) {
      case 'HOT': c = AppColors.error; break;
      case 'WARM': c = AppColors.warning; break;
      case 'COLD': c = AppColors.accent; break;
      default: c = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(p, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStats() {
    final items = [
      {'val': _stats['leadAge']?.toString() ?? '0', 'lbl': 'Days Old'},
      {'val': _stats['totalFollowUps']?.toString() ?? '${_followUps.length}', 'lbl': 'Follow-ups'},
      {'val': _stats['completedTasks']?.toString() ?? '0', 'lbl': 'Completed'},
      {'val': _stats['pendingTasks']?.toString() ?? '0', 'lbl': 'Pending'},
    ];
    return Container(
      color: const Color(0xFF1E1B4B),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((s) => Column(
          children: [
            Text(s['val']!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(s['lbl']!, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF312E81),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ─── Overview Tab ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final assigned = _lead['assignedTo'];
    final assignedName = assigned is Map
        ? '${assigned['firstName'] ?? ''} ${assigned['lastName'] ?? ''}'.trim()
        : 'Unassigned';
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Info
            _sectionCard('Customer Info', Icons.person_rounded, [
              _infoRow('Name', _lead['customerName']?.toString() ?? ''),
              _infoRow('Phone', _lead['phone']?.toString() ?? '-'),
              _infoRow('Email', _lead['email']?.toString() ?? '-'),
              _infoRow('Alternate Mobile', _lead['alternateMobile']?.toString() ?? '-'),
              _infoRow('Profession', _lead['customerProfession']?.toString() ?? '-'),
              _infoRow('City', _lead['customerCity']?.toString() ?? '-'),
              _infoRow('Buyer Type', _lead['buyerType']?.toString() ?? '-'),
            ]),
            const SizedBox(height: 12),
            // Requirement summary
            _sectionCard('Requirement', Icons.directions_car_rounded, [
              _infoRow('Interested Model', _lead['interestedModel']?.toString() ?? '-'),
              _infoRow('Variant', _lead['interestedVariant']?.toString() ?? '-'),
              _infoRow('Fuel Type', _lead['fuelType']?.toString() ?? '-'),
              _infoRow('Transmission', _lead['transmission']?.toString() ?? '-'),
              _infoRow('Color', _lead['colorPreference']?.toString() ?? '-'),
              _infoRow('Budget', _lead['budgetRange']?.toString() ?? '-'),
              _infoRow('Finance', _lead['financeRequired']?.toString() ?? '-'),
              _infoRow('Exchange', _lead['exchangeRequired']?.toString() ?? '-'),
              _infoRow('Purchase Time', _lead['expectedPurchaseTime']?.toString() ?? '-'),
              _infoRow('Source', _lead['source']?.toString() ?? '-'),
            ]),
            const SizedBox(height: 12),
            // Assigned DSE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Assigned DSE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openReassignPopup,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(assigned != null ? 'Change' : 'Assign',
                            style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (assigned is Map) ...[
                    _infoRow('Name', assignedName),
                    _infoRow('Email', assigned['email']?.toString() ?? '-'),
                    _infoRow('Phone', assigned['phone']?.toString() ?? '-'),
                  ] else
                    const Text('No salesman assigned yet.',
                        style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          const Divider(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ─── Requirement Tab ──────────────────────────────────────────────────────

  Widget _buildRequirementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Interest', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 12),
                _reqRow2(
                  _reqTextField('Interested Model', 'interestedModel', 'e.g. Tata Nexon'),
                  _reqTextField('Variant', 'interestedVariant', 'e.g. XZ+ Dark'),
                ),
                const SizedBox(height: 10),
                _reqRow2(
                  _reqDropdown('Fuel Type', 'fuelType', ['', 'Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid']),
                  _reqDropdown('Transmission', 'transmission', ['', 'Manual', 'Automatic', 'AMT', 'CVT']),
                ),
                const SizedBox(height: 10),
                _reqRow2(
                  _reqTextField('Color Preference', 'colorPreference', 'e.g. White'),
                  _reqTextField('Budget Range', 'budgetRange', 'e.g. 10-15 Lakhs'),
                ),

                const SizedBox(height: 18),
                const Text('Purchase Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 12),
                _reqRow2(
                  _reqDropdown('Purchase Timeline', 'expectedPurchaseTime',
                      ['', 'IMMEDIATE', '7_DAYS', '15_DAYS', '30_DAYS', 'LATER']),
                  _reqDropdown('Finance Required', 'financeRequired', ['', 'YES', 'NO', 'NOT_DECIDED']),
                ),
                const SizedBox(height: 10),
                _reqDropdown('Exchange Required', 'exchangeRequired', ['', 'YES', 'NO', 'NOT_DECIDED']),

                if (_reqForm['exchangeRequired'] == 'YES') ...[
                  const SizedBox(height: 18),
                  const Text('Exchange Vehicle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  _reqRow2(
                    _reqTextField('Current Brand', 'currentVehicleBrand', ''),
                    _reqTextField('Current Model', 'currentVehicleModel', ''),
                  ),
                  const SizedBox(height: 10),
                  _reqRow2(
                    _reqTextField('Year', 'currentVehicleYear', ''),
                    _reqTextField('Vehicle Number', 'currentVehicleNumber', ''),
                  ),
                  const SizedBox(height: 10),
                  _reqTextField('Expected Exchange Value (₹)', 'expectedExchangeValue', ''),
                ],

                const SizedBox(height: 18),
                const Text('Customer Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 12),
                _reqRow2(
                  _reqTextField('Profession', 'customerProfession', ''),
                  _reqTextField('City', 'customerCity', ''),
                ),
                const SizedBox(height: 10),
                _reqRow2(
                  _reqTextField('State', 'customerState', ''),
                  _reqTextField('Pincode', 'customerPincode', ''),
                ),
                const SizedBox(height: 10),
                _reqTextField('Address', 'customerAddress', ''),

                const SizedBox(height: 18),
                const Text('Next Action', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 12),
                _reqDropdown('Next Action', 'nextAction', [
                  '', 'FOLLOW_UP', 'VISIT_PLANNED', 'TEST_DRIVE_PLANNED',
                  'QUOTATION_REQUIRED', 'BOOKING_EXPECTED', 'MARK_LOST'
                ]),

                const SizedBox(height: 12),
                _reqTextAreaField('Remarks', 'notes', 'Additional notes...'),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _reqSaving ? null : _saveRequirement,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _reqSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Requirement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _reqRow2(Widget a, Widget b) => Row(
    children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
  );

  Widget _reqTextField(String label, String key, String hint) {
    return StatefulBuilder(
      builder: (ctx, ss) => TextField(
        controller: TextEditingController(text: _reqForm[key]?.toString() ?? ''),
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
        onChanged: (v) => _reqForm[key] = v,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _reqTextAreaField(String label, String key, String hint) {
    return TextField(
      controller: TextEditingController(text: _reqForm[key]?.toString() ?? ''),
      decoration: InputDecoration(labelText: label, hintText: hint),
      maxLines: 3,
      onChanged: (v) => _reqForm[key] = v,
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _reqDropdown(String label, String key, List<String> options) {
    final val = _reqForm[key]?.toString() ?? '';
    final safeVal = options.contains(val) ? val : '';
    return StatefulBuilder(
      builder: (ctx, ss) => DropdownButtonFormField<String>(
        value: safeVal,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'Select' : o, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) {
          _reqForm[key] = v ?? '';
          ss(() {});
          if (key == 'exchangeRequired') setState(() {});
        },
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }

  // ─── Timeline Tab ─────────────────────────────────────────────────────────

  Widget _buildTimelineTab() {
    if (_activities.isEmpty) {
      return const Center(child: Text('No activity recorded.', style: TextStyle(color: AppColors.textHint)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTimelineItem(_activities[i]),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'NOTE';
    final notes = item['notes']?.toString() ?? '';
    final createdAt = item['createdAt']?.toString() ?? '';
    final iconMap = <String, IconData>{
      'LEAD_CREATED': Icons.person_add_rounded, 'FOLLOW_UP_COMPLETED': Icons.phone_rounded,
      'VISIT_COMPLETED': Icons.store_rounded, 'TEST_DRIVE_COMPLETED': Icons.directions_car_rounded,
      'QUOTATION_SENT': Icons.receipt_outlined, 'BOOKING_CONFIRMED': Icons.bookmark_rounded,
      'VEHICLE_DELIVERED': Icons.local_shipping_rounded, 'NOTE': Icons.note_outlined,
      'CALL': Icons.phone_rounded, 'FOLLOW_UP': Icons.calendar_today_rounded,
    };
    final colorMap = <String, Color>{
      'LEAD_CREATED': AppColors.primary, 'FOLLOW_UP_COMPLETED': AppColors.warning,
      'VISIT_COMPLETED': AppColors.accent, 'TEST_DRIVE_COMPLETED': const Color(0xFF0891B2),
      'QUOTATION_SENT': const Color(0xFF7C3AED), 'BOOKING_CONFIRMED': AppColors.success,
      'VEHICLE_DELIVERED': AppColors.success,
    };
    final icon = iconMap[type] ?? Icons.circle_outlined;
    final color = colorMap[type] ?? AppColors.textSecondary;
    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month-1]}, ${_pad(dt.hour)}:${_pad(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(type.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                if (dateStr.isNotEmpty) Text(dateStr,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ─── Follow-ups Tab ───────────────────────────────────────────────────────

  Widget _buildFollowUpsTab() {
    return _buildTabList(
      title: 'Follow-ups',
      icon: Icons.calendar_today_rounded,
      color: AppColors.warning,
      items: _followUps,
      onAdd: _openFollowUpForm,
      emptyText: 'No follow-ups yet. Schedule the first one!',
      itemBuilder: (f) => _buildFollowUpRow(f),
      headers: const ['Scheduled', 'Type', 'Status', 'Notes', ''],
    );
  }

  Widget _buildFollowUpRow(Map<String, dynamic> f) {
    final scheduled = _fmtDate(f['scheduledAt']?.toString() ?? '');
    final type = f['type']?.toString() ?? '';
    final status = f['status']?.toString() ?? 'PENDING';
    final notes = f['notes']?.toString() ?? '-';
    final isPending = status == 'PENDING' || status == 'SCHEDULED';
    return _tableRow([
      Text(scheduled, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      _chip(type, AppColors.primary),
      _statusChip(status),
      Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2),
      if (isPending)
        GestureDetector(
          onTap: () => _openCompleteFollowUp(f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Complete', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        )
      else const SizedBox.shrink(),
    ]);
  }

  // ─── Visits Tab ───────────────────────────────────────────────────────────

  Widget _buildVisitsTab() {
    return _buildTabList(
      title: 'Visits',
      icon: Icons.store_rounded,
      color: AppColors.accent,
      items: _visits,
      onAdd: _openVisitForm,
      emptyText: 'No visits yet. Schedule the first one!',
      itemBuilder: (v) => _buildVisitRow(v),
      headers: const ['Visit Date', 'Status', 'Notes', 'Next Step', ''],
    );
  }

  Widget _buildVisitRow(Map<String, dynamic> v) {
    final scheduled = _fmtDate(v['scheduledAt']?.toString() ?? '');
    final status = v['status']?.toString() ?? '';
    final notes = v['notes']?.toString() ?? '-';
    final nextStep = v['nextStep']?.toString() ?? '';
    final isActive = ['PLANNED', 'SCHEDULED', 'PENDING'].contains(status.toUpperCase());
    return _tableRow([
      Text(scheduled, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      _statusChip(status),
      Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2),
      nextStep.isNotEmpty
          ? _chip(nextStep, AppColors.accent)
          : const Text('-', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
      if (isActive)
        GestureDetector(
          onTap: () => _openCompleteVisit(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(8)),
            child: const Text('Complete', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        )
      else const SizedBox.shrink(),
    ]);
  }

  // ─── Test Drives Tab ──────────────────────────────────────────────────────

  Widget _buildTestDrivesTab() {
    return _buildTabList(
      title: 'Test Drives',
      icon: Icons.directions_car_rounded,
      color: const Color(0xFF0891B2),
      items: _testDrives,
      onAdd: _openTestDriveForm,
      emptyText: 'No test drives yet.',
      itemBuilder: (td) => _buildTestDriveRow(td),
      headers: const ['Scheduled', 'Vehicle', 'Status', 'Next Action', ''],
    );
  }

  Widget _buildTestDriveRow(Map<String, dynamic> td) {
    final scheduled = _fmtDate(td['scheduledAt']?.toString() ?? '');
    final model = '${td['vehicleModel'] ?? '-'} ${td['vehicleVariant'] ?? td['variant'] ?? ''}'.trim();
    final status = td['status']?.toString() ?? '';
    final nextAction = td['nextAction']?.toString() ?? '';
    final isActive = ['PLANNED', 'SCHEDULED', 'IN_PROGRESS'].contains(status.toUpperCase());
    return _tableRow([
      Text(scheduled, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(model, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      _statusChip(status),
      nextAction.isNotEmpty
          ? _chip(nextAction, const Color(0xFF0891B2))
          : const Text('-', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
      if (isActive)
        GestureDetector(
          onTap: () => _openCompleteTestDrive(td),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF0891B2)), borderRadius: BorderRadius.circular(8)),
            child: const Text('Complete', style: TextStyle(fontSize: 11, color: Color(0xFF0891B2), fontWeight: FontWeight.w600)),
          ),
        )
      else const SizedBox.shrink(),
    ]);
  }

  // ─── Quotations Tab ───────────────────────────────────────────────────────

  Widget _buildQuotationsTab() {
    return _buildTabList(
      title: 'Quotations',
      icon: Icons.receipt_outlined,
      color: const Color(0xFF7C3AED),
      items: _quotations,
      onAdd: _openQuotationForm,
      emptyText: 'No quotations yet.',
      itemBuilder: (q) => _buildQuotationRow(q),
      headers: const ['Vehicle', 'Ex-Show', 'Discount', 'On-Road', 'Valid Till', 'Status'],
    );
  }

  Widget _buildQuotationRow(Map<String, dynamic> q) {
    final model = '${q['model'] ?? '-'} ${q['variant'] ?? ''}'.trim();
    final exShow = q['exShowroomPrice'] != null ? '₹${_fmt(q['exShowroomPrice'])}' : '-';
    final disc = q['discount'] != null ? '₹${_fmt(q['discount'])}' : '-';
    final onRoad = q['finalOnRoadPrice'] != null ? '₹${_fmt(q['finalOnRoadPrice'])}' : '-';
    final valid = q['validTillDate'] != null ? _fmtDateShort(q['validTillDate'].toString()) : '-';
    final status = q['status']?.toString() ?? '';
    return _tableRow([
      Text(model, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(exShow, style: const TextStyle(fontSize: 12)),
      Text(disc, style: const TextStyle(fontSize: 12)),
      Text(onRoad, style: const TextStyle(fontSize: 12)),
      Text(valid, style: const TextStyle(fontSize: 12)),
      _statusChip(status),
    ]);
  }

  // ─── Bookings Tab ─────────────────────────────────────────────────────────

  Widget _buildBookingsTab() {
    return _buildTabList(
      title: 'Bookings',
      icon: Icons.bookmark_rounded,
      color: AppColors.success,
      items: _bookings,
      onAdd: _openBookingForm,
      emptyText: 'No bookings yet.',
      itemBuilder: (b) => _buildBookingRow(b),
      headers: const ['Vehicle', 'Amount', 'Payment Mode', 'Status'],
    );
  }

  Widget _buildBookingRow(Map<String, dynamic> b) {
    final model = '${b['model'] ?? '-'} ${b['variant'] ?? ''}'.trim();
    final amount = b['bookingAmount'] != null ? '₹${_fmt(b['bookingAmount'])}' : '-';
    final payment = b['paymentMode']?.toString() ?? '-';
    final status = b['status']?.toString() ?? '';
    return _tableRow([
      Text(model, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(amount, style: const TextStyle(fontSize: 12)),
      _chip(payment, AppColors.textSecondary),
      _statusChip(status),
    ]);
  }

  // ─── Delivery Tab ─────────────────────────────────────────────────────────

  Widget _buildDeliveryTab() {
    if (_deliveries.isEmpty) {
      return const Center(child: Text('No delivery records yet.', style: TextStyle(color: AppColors.textHint)));
    }
    return _buildTabList(
      title: 'Delivery',
      icon: Icons.local_shipping_rounded,
      color: AppColors.success,
      items: _deliveries,
      emptyText: 'No delivery records yet.',
      itemBuilder: (d) => _buildDeliveryRow(d),
      headers: const ['Delivery Date', 'Vehicle', 'Status', 'Notes'],
    );
  }

  Widget _buildDeliveryRow(Map<String, dynamic> d) {
    final date = _fmtDateShort(d['deliveryDate']?.toString() ?? '');
    final model = d['vehicleModel']?.toString() ?? '-';
    final status = d['status']?.toString() ?? '';
    final notes = d['notes']?.toString() ?? '-';
    return _tableRow([
      Text(date, style: const TextStyle(fontSize: 12)),
      Text(model, style: const TextStyle(fontSize: 12)),
      _statusChip(status),
      Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  // ─── Generic Tab List ─────────────────────────────────────────────────────

  Widget _buildTabList({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    VoidCallback? onAdd,
    required String emptyText,
    required Widget Function(Map<String, dynamic>) itemBuilder,
    required List<String> headers,
  }) {
    return RefreshIndicator(
      color: color,
      onRefresh: _loadDetails,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                  const Spacer(),
                  if (onAdd != null)
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Schedule', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(icon, size: 40, color: color.withValues(alpha: 0.3)),
                  const SizedBox(height: 10),
                  Text(emptyText, style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
                ]),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Row(
                          children: headers.map((h) => Expanded(
                            child: Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                          )).toList(),
                        ),
                      ),
                      ...items.asMap().entries.map((e) => Column(
                        children: [
                          if (e.key > 0) Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: itemBuilder(e.value),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _tableRow(List<Widget> cells) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cells.map((c) => Expanded(child: c)).toList(),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'COMPLETED': case 'CONFIRMED': case 'DELIVERED': color = AppColors.success; break;
      case 'PENDING': case 'SCHEDULED': case 'PLANNED': color = AppColors.warning; break;
      case 'LOST': case 'CANCELLED': color = AppColors.error; break;
      case 'DRAFT': color = AppColors.textHint; break;
      default: color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.isNotEmpty ? status : '-',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _fmtDate(String s) {
    if (s.isEmpty) return '-';
    try {
      final dt = DateTime.parse(s).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month-1]}, ${_pad(dt.hour)}:${_pad(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';
    } catch (_) { return s; }
  }

  String _fmtDateShort(String s) {
    if (s.isEmpty) return '-';
    try {
      final dt = DateTime.parse(s).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month-1]} ${dt.year}';
    } catch (_) { return s; }
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
      const SizedBox(height: 12),
      const Text('Failed to load lead details', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      TextButton(onPressed: _loadDetails, child: const Text('Retry')),
    ]));
  }

  // ─── Reassign DSE Overlay ─────────────────────────────────────────────────

  Widget _buildReassignOverlay() {
    final assigned = _lead['assignedTo'];
    final hasAssigned = assigned is Map;
    return GestureDetector(
      onTap: () => setState(() => _showReassignPopup = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF312E81), AppColors.primary]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          hasAssigned ? 'Change Salesman' : 'Assign Salesman',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        )),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => setState(() => _showReassignPopup = false),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(spacing: 8, children: [
                      _chip(widget.leadName, AppColors.primary),
                      if (hasAssigned) _chip(
                        'Current: ${assigned['firstName']} ${assigned['lastName']}',
                        AppColors.textSecondary,
                      ),
                    ]),
                  ),
                  if (_reassignSuccess)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: const [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                        SizedBox(height: 10),
                        Text('Salesman assigned successfully!',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  else ...[
                    // Branch filter dropdown
                    if (_reassignBranches.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DropdownButtonFormField<String>(
                          value: _reassignBranchId,
                          decoration: InputDecoration(
                            labelText: 'Filter by Branch',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Branches')),
                            ..._reassignBranches.map((b) => DropdownMenuItem<String>(
                              value: b['id']?.toString(),
                              child: Text(b['name']?.toString() ?? ''),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _reassignBranchId = v);
                            _loadReassignUsers(v);
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (_teamLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      )
                    else if (_branchTeam.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No salesmen found.', style: TextStyle(color: AppColors.textHint)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(top: 12),
                          itemCount: _branchTeam.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (_, i) {
                            final m = _branchTeam[i];
                            final id = m['userId']?.toString() ?? m['id']?.toString();
                            final user = m['user'] is Map ? m['user'] as Map : m;
                            final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                            final role = m['branchRole']?.toString() ?? user['email']?.toString() ?? '';
                            final isSelected = _selectedDseId == id;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                                child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                    style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                              onTap: () => setState(() => _selectedDseId = id),
                            );
                          },
                        ),
                      ),
                    if (hasAssigned && !_teamLoading && _branchTeam.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          controller: _reassignReasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Reason for change (optional)',
                            hintText: 'e.g. Previous DSE on leave',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _showReassignPopup = false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.textHint.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: (_selectedDseId == null || _reassignLoading) ? null : _confirmReassign,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: _reassignLoading
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
