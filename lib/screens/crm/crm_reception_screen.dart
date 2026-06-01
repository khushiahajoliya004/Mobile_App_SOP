import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_lead_detail_screen.dart';

class CrmReceptionScreen extends StatefulWidget {
  const CrmReceptionScreen({super.key});

  @override
  State<CrmReceptionScreen> createState() => _CrmReceptionScreenState();
}

class _CrmReceptionScreenState extends State<CrmReceptionScreen> {
  final _api = ApiService();

  // ── Steps: form | duplicate | success ──
  String _step = 'form';

  // Form fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _source = 'Walk-in';
  String _priority = 'MEDIUM';
  bool _showMore = false;

  // Sources from API
  List<String> _sourceOptions = ['Walk-in', 'Call', 'Website', 'Facebook', 'Instagram', 'Google Ads', 'Reference', 'Event', 'Other'];

  // Duplicate check
  bool _dupChecking = false;
  bool? _dupClean; // null=not checked, true=clean, false=has dup
  List<Map<String, dynamic>> _dupLeads = [];

  // Submit
  bool _submitting = false;
  Map<String, dynamic>? _createdLead;

  // Assign popup
  bool _showAssignPopup = false;
  Map<String, dynamic>? _assigningLead;
  List<Map<String, dynamic>> _branchTeam = [];
  String? _selectedDseId;
  bool _teamLoading = false;
  bool _assignLoading = false;
  bool _assignSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _altMobileCtrl.dispose(); _modelCtrl.dispose(); _budgetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      final res = await _api.getMasterActiveList('LEAD_SOURCE');
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      if (mounted && list.isNotEmpty) {
        setState(() {
          _sourceOptions = list.map((d) => d['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _checkDuplicate() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) return;
    setState(() { _dupChecking = true; _dupClean = null; });
    try {
      final res = await _api.checkDuplicateLead(phone);
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      final exists = data['exists'] == true || data['isDuplicate'] == true;
      List<Map<String, dynamic>> leads = [];
      if (exists) {
        final leadsList = data['leads'] as List? ?? [];
        leads = leadsList
            .map((l) => Map<String, dynamic>.from(l as Map))
            .where((l) => l['status'] != 'LOST' && l['status'] != 'CONVERTED' && l['status'] != 'DELIVERED')
            .toList();
      }
      if (mounted) {
        setState(() {
          _dupChecking = false;
          if (leads.isNotEmpty) {
            _dupLeads = leads;
            _step = 'duplicate';
          } else {
            _dupClean = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dupChecking = false);
    }
  }

  Future<void> _submitEnquiry() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final res = await _api.createEnquiry({
        'customerName': name,
        'phone': phone,
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        'source': _source,
        'priority': _priority,
        if (_altMobileCtrl.text.trim().isNotEmpty) 'alternateMobile': _altMobileCtrl.text.trim(),
        if (_modelCtrl.text.trim().isNotEmpty) 'interestedModel': _modelCtrl.text.trim(),
        if (_budgetCtrl.text.trim().isNotEmpty) 'budgetRange': _budgetCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      if (mounted) {
        setState(() => _submitting = false);
        if (data['isDuplicate'] == true) {
          final existing = data['existingLeads'] as List? ?? (data['lead'] != null ? [data['lead']] : []);
          setState(() {
            _dupLeads = existing.map((l) => Map<String, dynamic>.from(l as Map)).toList();
            _step = 'duplicate';
          });
        } else {
          final lead = Map<String, dynamic>.from((data['lead'] ?? data) as Map);
          setState(() { _createdLead = lead; _step = 'success'; });
          if (lead['assignedToUserId'] == null) {
            _openAssignPopup(lead);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('Failed: $e');
      }
    }
  }

  Future<void> _openAssignPopup(Map<String, dynamic> lead) async {
    setState(() {
      _assigningLead = lead;
      _selectedDseId = lead['assignedToUserId']?.toString();
      _assignSuccess = false;
      _branchTeam = [];
      _showAssignPopup = true;
      _teamLoading = true;
    });
    try {
      final branchId = lead['branchId']?.toString() ?? (lead['branch'] is Map ? lead['branch']['id']?.toString() : null);
      List<Map<String, dynamic>> team = [];
      if (branchId != null && branchId.isNotEmpty) {
        final res = await _api.getCrmUsersByBranch(branchId);
        final raw = res.data;
        final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
        team = list.map((e) => Map<String, dynamic>.from(e as Map)).where((m) {
          final role = (m['branchRole'] ?? '').toString().toUpperCase();
          return ['DSE', 'SALES_MANAGER', 'TEAM_LEADER', 'SALESMAN', 'SALES'].any((r) => role.contains(r));
        }).toList();
      }
      if (team.isEmpty) {
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

  Future<void> _confirmAssign() async {
    if (_selectedDseId == null || _assigningLead == null) return;
    setState(() => _assignLoading = true);
    try {
      await _api.assignLead(_assigningLead!['id'].toString(), _selectedDseId!);
      if (mounted) {
        setState(() { _assignLoading = false; _assignSuccess = true; });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) setState(() => _showAssignPopup = false);
      }
    } catch (e) {
      if (mounted) { setState(() => _assignLoading = false); _showSnack('Failed: $e'); }
    }
  }

  void _resetForm() {
    setState(() {
      _step = 'form';
      _nameCtrl.clear(); _phoneCtrl.clear(); _emailCtrl.clear();
      _altMobileCtrl.clear(); _modelCtrl.clear(); _budgetCtrl.clear(); _notesCtrl.clear();
      _source = 'Walk-in'; _priority = 'MEDIUM'; _showMore = false;
      _dupClean = null; _dupLeads = []; _createdLead = null;
      _showAssignPopup = false; _assigningLead = null; _branchTeam = [];
    });
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_step == 'duplicate') _buildDuplicateStep(),
              if (_step == 'success') _buildSuccessStep(),
              if (_step == 'form') _buildFormStep(),
            ],
          ),
        ),
        if (_showAssignPopup) _buildAssignOverlay(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Create or look up a customer', style: TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ),
          if (_step != 'form')
            TextButton(
              onPressed: _resetForm,
              child: const Text('+ New Lead', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─── Duplicate Step ───

  Widget _buildDuplicateStep() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 8),
              const Text('Customer Already Exists', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('An active lead with this mobile number is already in the system.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ..._dupLeads.map((lead) => _buildDupLeadCard(lead)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _step = 'form'; _dupLeads = []; }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Create Anyway\n(Different Person)', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textHint.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Go Back', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDupLeadCard(Map<String, dynamic> lead) {
    final assigned = lead['assignedTo'];
    final assignedName = assigned is Map
        ? '${assigned['firstName'] ?? ''} ${assigned['lastName'] ?? ''}'.trim()
        : 'Unassigned';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead['customerName']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${lead['phone'] ?? ''} · ${lead['source'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Status: ${lead['status'] ?? ''} · DSE: $assignedName',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(lead['status']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(context, PageRouteBuilder(
                      opaque: true,
                      pageBuilder: (_, __, ___) => CrmLeadDetailScreen(
                        leadId: lead['id'].toString(),
                        leadName: lead['customerName']?.toString() ?? 'Lead',
                      ),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                    ));
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Lead', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openAssignPopup(lead),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Assign DSE', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Success Step ───

  Widget _buildSuccessStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('Lead Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            '${_createdLead?['customerName'] ?? ''} · ${_createdLead?['phone'] ?? ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (_createdLead?['assignedToUserId'] != null)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 14, color: AppColors.success),
                SizedBox(width: 4),
                Text('DSE assigned & notified.', style: TextStyle(fontSize: 12, color: AppColors.success)),
              ],
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                SizedBox(width: 4),
                Text('No DSE assigned — assign manually.', style: TextStyle(fontSize: 12, color: AppColors.warning)),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openAssignPopup(_createdLead!),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(_createdLead?['assignedToUserId'] != null ? 'Change DSE' : 'Assign DSE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                  label: const Text('Create Another', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                if (_createdLead?['id'] != null) {
                  Navigator.push(context, PageRouteBuilder(
                    opaque: true,
                    pageBuilder: (_, __, ___) => CrmLeadDetailScreen(
                      leadId: _createdLead!['id'].toString(),
                      leadName: _createdLead!['customerName']?.toString() ?? 'Lead',
                    ),
                    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                  ));
                }
              },
              child: const Text('Open Lead Details →', style: TextStyle(color: AppColors.accent, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Step ───

  Widget _buildFormStep() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer Name
          _fieldLabel('Customer Name', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter customer name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),

          // Mobile Number + Check Duplicate
          _fieldLabel('Mobile Number', required: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  decoration: InputDecoration(
                    hintText: '10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    counterText: '',
                    suffixIcon: _dupClean == true
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                        : null,
                  ),
                  onChanged: (_) => setState(() => _dupClean = null),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _dupChecking ? null : _checkDuplicate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _dupChecking
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          if (_dupClean == true) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                SizedBox(width: 4),
                Text('No duplicate found', style: TextStyle(fontSize: 12, color: AppColors.success)),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Email
          _fieldLabel('Email', optional: true),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'customer@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Source
          _fieldLabel('Source'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _sourceOptions.contains(_source) ? _source : _sourceOptions.first,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.source_outlined)),
            items: _sourceOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _source = v!),
          ),
          const SizedBox(height: 20),

          // Submit button
          FilledButton(
            onPressed: (_submitting || _nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty)
                ? null
                : _submitEnquiry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),

          // More Details toggle
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _showMore = !_showMore),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_showMore ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${_showMore ? 'Hide' : 'More'} Details (optional)',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),

          if (_showMore) ...[
            const SizedBox(height: 16),
            _buildMoreFields(),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Just name + phone is enough. Branch & DSE are auto-assigned. Details can be added later.',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Priority'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    items: const [
                      DropdownMenuItem(value: 'HOT', child: Text('🔥 Hot')),
                      DropdownMenuItem(value: 'WARM', child: Text('🌡 Warm')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('📋 Medium')),
                      DropdownMenuItem(value: 'COLD', child: Text('❄ Cold')),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Alternate Mobile'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _altMobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Alternate number'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Interested Model'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Tata Nexon'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Budget Range'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _budgetCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. 10-15 Lakhs'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fieldLabel('Notes'),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any quick notes...'),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false, bool optional = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        if (required) const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 13)),
        if (optional) const Text(' (optional)', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
      ],
    );
  }

  // ─── Assign Popup Overlay ───

  Widget _buildAssignOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showAssignPopup = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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
                        const Expanded(
                          child: Text('Assign Salesman',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => setState(() => _showAssignPopup = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  if (_assigningLead != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          _chip(_assigningLead!['customerName']?.toString() ?? '', AppColors.primary),
                          const SizedBox(width: 8),
                          _chip(_assigningLead!['phone']?.toString() ?? '', AppColors.textSecondary),
                        ],
                      ),
                    ),

                  if (_assignSuccess)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                          const SizedBox(height: 10),
                          const Text('Salesman assigned successfully!',
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  else ...[
                    if (_teamLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                            SizedBox(height: 10),
                            Text('Loading team...', style: TextStyle(color: AppColors.textHint)),
                          ],
                        ),
                      )
                    else if (_branchTeam.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No salesmen found.', style: TextStyle(color: AppColors.textHint)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
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
                                backgroundColor: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                  : null,
                              onTap: () => setState(() => _selectedDseId = id),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _showAssignPopup = false),
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
                              onPressed: (_selectedDseId == null || _assignLoading) ? null : _confirmAssign,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: _assignLoading
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Assign', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
