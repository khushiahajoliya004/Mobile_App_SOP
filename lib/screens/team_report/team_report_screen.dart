import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class TeamReportScreen extends StatefulWidget {
  const TeamReportScreen({super.key});
  @override
  State<TeamReportScreen> createState() => _TeamReportScreenState();
}

class _TeamReportScreenState extends State<TeamReportScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _reportData;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final res = await _api.getBranches();
      _branches = _parseList(res.data);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTeamReport(
        branchId: _selectedBranchId,
        fromDate: _fromDate.toIso8601String().split('T').first,
        toDate: _toDate.toIso8601String().split('T').first,
      );
      final raw = res.data is Map ? res.data : {};
      _reportData = Map<String, dynamic>.from(raw['data'] ?? raw);
      _members = _parseList(_reportData?['members'] ?? _reportData?['team'] ?? []);
    } catch (_) { _members = []; _reportData = null; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) { setState(() { _fromDate = picked.start; _toDate = picked.end; }); _load(); }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final totalMembers = _members.length;
    final totalCalls = _members.fold<int>(0, (s, m) => s + ((m['totalCalls'] as num?)?.toInt() ?? 0));
    final avgScore = _members.isEmpty ? 0.0 : _members.fold<double>(0, (s, m) => s + ((m['averageScore'] as num?)?.toDouble() ?? 0.0)) / _members.length;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${_fmtDate(_fromDate)} — ${_fmtDate(_toDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            if (_branches.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranchId,
                      isExpanded: true,
                      hint: const Text('All Branches', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Branches', style: TextStyle(fontSize: 12))),
                        ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'] as String, child: Text('${b['name']}', style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (v) { setState(() => _selectedBranchId = v); _load(); },
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
      if (!_loading && _members.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: _summaryCard('Members', '$totalMembers', AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('Total Calls', '$totalCalls', AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('Avg Score', avgScore.toStringAsFixed(1), AppColors.accent)),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Text('${_members.length} members', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _members.isEmpty
            ? const Center(child: Text('No team data', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _members.length,
                  itemBuilder: (_, i) => _memberTile(_members[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final firstName = m['firstName'] ?? m['user']?['firstName'] ?? '';
    final lastName = m['lastName'] ?? m['user']?['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = m['email'] ?? m['user']?['email'] ?? '';
    final branchRole = m['branchRole'] ?? '';
    final totalCalls = (m['totalCalls'] as num?)?.toInt() ?? 0;
    final avgScore = (m['averageScore'] as num?)?.toDouble() ?? 0.0;
    final totalMinutes = (m['totalMinutes'] as num?)?.toDouble() ?? 0.0;
    final scoreColor = avgScore >= 80 ? AppColors.success : avgScore >= 50 ? AppColors.warning : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: AppColors.primarySurface, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (branchRole.isNotEmpty) Text(branchRole, style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            _badge('$totalCalls calls', AppColors.primary),
            const SizedBox(width: 6),
            _badge('${totalMinutes.toStringAsFixed(0)} min', AppColors.success),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(avgScore.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scoreColor)),
          Text('score', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ]),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
