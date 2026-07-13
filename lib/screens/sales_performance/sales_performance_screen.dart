import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class SalesPerformanceScreen extends StatefulWidget {
  const SalesPerformanceScreen({super.key});
  @override
  State<SalesPerformanceScreen> createState() => _SalesPerformanceScreenState();
}

class _SalesPerformanceScreenState extends State<SalesPerformanceScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  bool _loading = true;
  List<Map<String, dynamic>> _summary = [];
  Map<String, dynamic>? _funnel;
  Map<String, dynamic>? _callMetrics;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String _search = '';
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) _loadForTab(); });
    _init();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _init() async {
    try {
      final res = await _api.getBranches();
      _branches = _parseList(res.data);
    } catch (_) {}
    await _loadForTab();
  }

  Future<void> _loadForTab() async {
    setState(() => _loading = true);
    final from = _fromDate.toIso8601String().split('T').first;
    final to = _toDate.toIso8601String().split('T').first;
    try {
      switch (_tab.index) {
        case 0:
          final res = await _api.getSalesPerformanceSummary(fromDate: from, toDate: to, branchId: _selectedBranchId, search: _search.isNotEmpty ? _search : null);
          final raw = res.data;
          _summary = raw is Map ? _parseList(raw['data']) : _parseList(raw);
          break;
        case 1:
          final res = await _api.getSalesPerformanceFunnel(fromDate: from, toDate: to, branchId: _selectedBranchId);
          final fRaw = res.data;
          if (fRaw is Map) {
            final inner = fRaw['data'] ?? fRaw;
            _funnel = inner is List
                ? {'stages': inner}
                : Map<String, dynamic>.from(inner as Map);
          } else if (fRaw is List) {
            _funnel = {'stages': fRaw};
          }
          break;
        case 2:
          final res = await _api.getSalesPerformanceCallMetrics(fromDate: from, toDate: to, branchId: _selectedBranchId);
          _callMetrics = res.data is Map ? Map<String, dynamic>.from(res.data['data'] ?? res.data) : null;
          break;
      }
    } catch (_) {}
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
    if (picked != null) { setState(() { _fromDate = picked.start; _toDate = picked.end; }); _loadForTab(); }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    Flexible(child: Text('${_fmtDate(_fromDate)} — ${_fmtDate(_toDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
                      onChanged: (v) { setState(() => _selectedBranchId = v); _loadForTab(); },
                    ),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Summary'), Tab(text: 'Funnel'), Tab(text: 'Calls')],
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(controller: _tab, children: [
                _summaryTab(),
                _funnelTab(),
                _callMetricsTab(),
              ]),
      ),
    ]);
  }

  Widget _summaryTab() {
    if (_summary.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _summary.length,
      itemBuilder: (_, i) {
        final emp = _summary[i];
        final firstName = emp['firstName'] ?? emp['user']?['firstName'] ?? '';
        final lastName = emp['lastName'] ?? emp['user']?['lastName'] ?? '';
        final email = emp['email'] ?? emp['user']?['email'] ?? emp['userEmail'] ?? '';
        final name = '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : (emp['userName'] ?? '').toString().trim().isNotEmpty
                ? (emp['userName'] ?? '').toString().trim()
                : email.isNotEmpty ? email.split('@').first : 'U';
        final totalLeads = (emp['totalLeadsAssigned'] ?? emp['totalLeads'] ?? emp['leadsAssigned'] ?? emp['leads'] as num?)?.toInt() ?? 0;
        final converted = (emp['leadsConverted'] ?? emp['converted'] ?? emp['convertedLeads'] as num?)?.toInt() ?? 0;
        final convRate = (emp['conversionRate'] ?? emp['conversion'] as num?)?.toDouble() ?? 0.0;
        final avgScore = (emp['avgCallScore'] ?? emp['averageCallScore'] ?? emp['averageScore'] ?? emp['avgScore'] as num?)?.toDouble() ?? 0.0;
        final scoreColor = avgScore >= 80 ? AppColors.success : avgScore >= 50 ? AppColors.warning : AppColors.error;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primarySurface, child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Text(avgScore.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scoreColor)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _badge('$totalLeads leads', AppColors.primary),
              const SizedBox(width: 6),
              _badge('$converted converted', AppColors.success),
              const SizedBox(width: 6),
              _badge('${convRate.toStringAsFixed(0)}%', AppColors.accent),
            ]),
          ]),
        );
      },
    );
  }

  Widget _funnelTab() {
    if (_funnel == null) return const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    final stages = (_funnel!['stages'] as List?)?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Lead Conversion Funnel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...stages.asMap().entries.map((entry) {
          final s = entry.value;
          final total = (s['totalLeads'] as num?)?.toInt() ?? 0;
          final converted = (s['converted'] as num?)?.toInt() ?? 0;
          final rate = (s['conversionRate'] as num?)?.toDouble() ?? 0.0;
          final width = rate / 100;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${s['stage'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: width.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text('$total leads • $converted converted', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          );
        }),
      ],
    );
  }

  Widget _callMetricsTab() {
    if (_callMetrics == null) return const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    final m = _callMetrics!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _metricCard('Total Calls', '${m['totalCalls'] ?? 0}', AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: _metricCard('Recorded', '${m['recordedCalls'] ?? 0}', AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: _metricCard('Recording Rate', '${(m['recordingRate'] as num?)?.toStringAsFixed(0) ?? '0'}%', AppColors.accent)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _metricCard('Avg Duration', _formatDuration((m['averageDuration'] as num?)?.toInt() ?? 0), AppColors.warning)),
          const SizedBox(width: 8),
          Expanded(child: _metricCard('Total Duration', _formatDuration((m['totalDuration'] as num?)?.toInt() ?? 0), AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: _metricCard('Uploaded', '${m['uploadedCalls'] ?? 0}', AppColors.success)),
        ]),
      ]),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  Widget _metricCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
