import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class EmployeePerformanceScreen extends StatefulWidget {
  const EmployeePerformanceScreen({super.key});
  @override
  State<EmployeePerformanceScreen> createState() => _EmployeePerformanceScreenState();
}

class _EmployeePerformanceScreenState extends State<EmployeePerformanceScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _loadingMore = false;
  List<Map<String, dynamic>> _employees = [];
  String _search = '';
  String _period = '30d';
  String _sortBy = 'score';
  String _sortOrder = 'desc';
  String? _statusFilter;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  Map<String, dynamic>? _detail;
  String? _detailName;
  String? _detailUserId;
  Map<String, dynamic>? _aiTrend;
  bool _loadingAi = false;

  static const _periods = {
    'all': 'All Time',
    '7d': '7 Days',
    '30d': '30 Days',
    '90d': '90 Days',
    '365d': '1 Year',
  };

  static const _statusOptions = ['COMPLETED', 'PROCESSING', 'FAILED'];

  static const _sortOptions = {
    'score': 'Score',
    'name': 'Name',
    'calls': 'Calls',
    'successRate': 'Success',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _fromDate {
    if (_period == 'all') return null;
    final days = int.tryParse(_period.replaceAll('d', '')) ?? 30;
    return DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T').first;
  }

  String? get _toDate => _period == 'all' ? null : DateTime.now().toIso8601String().split('T').first;

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _loading = true; _detail = null; _page = 1; });
    }
    try {
      final res = await _api.getEmployeePerformance(
        page: _page,
        limit: 20,
        search: _search.isNotEmpty ? _search : null,
        fromDate: _fromDate,
        toDate: _toDate,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        status: _statusFilter,
      );
      final raw = res.data;
      final list = raw is Map && raw['data'] is List
          ? (raw['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final pagination = raw is Map ? raw['pagination'] : null;
      if (mounted) {
        setState(() {
          if (reset) {
            _employees = list;
          } else {
            _employees.addAll(list);
          }
          _total = (pagination?['total'] as num?)?.toInt() ?? _employees.length;
          _totalPages = (pagination?['totalPages'] as num?)?.toInt() ?? 1;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages || _loadingMore) return;
    setState(() { _loadingMore = true; _page++; });
    await _load(reset: false);
  }

  Future<void> _loadDetail(String userId, String name) async {
    setState(() { _loading = true; _detailName = name; _detailUserId = userId; _aiTrend = null; });
    try {
      final res = await _api.getEmployeePerformanceDetail(userId, fromDate: _fromDate, toDate: _toDate);
      _detail = res.data is Map ? Map<String, dynamic>.from(res.data['data'] ?? res.data) : null;
    } catch (_) { _detail = null; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAiTrend({bool refresh = false}) async {
    if (_detailUserId == null) return;
    setState(() => _loadingAi = true);
    try {
      final res = await _api.getEmployeeAiTrend(_detailUserId!, refresh: refresh);
      _aiTrend = res.data is Map ? Map<String, dynamic>.from(res.data['data'] ?? res.data) : null;
    } catch (_) { _aiTrend = null; }
    if (mounted) setState(() => _loadingAi = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) return _detailView();
    return Column(children: [
      _buildListHeader(),
      _buildFilterRow(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Text('$_total employees', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          _sortToggleBtn(),
          const SizedBox(width: 8),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _employees.isEmpty
            ? const Center(child: Text('No data found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _employees.length + (_page < _totalPages ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _employees.length) {
                      return _buildLoadMore();
                    }
                    return _empTile(_employees[i]);
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _buildListHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        TextField(
          onChanged: (v) { _search = v; _load(); },
          decoration: InputDecoration(
            hintText: 'Search employees...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true, fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _periods.entries.map((e) {
              final sel = _period == e.key;
              return GestureDetector(
                onTap: () { setState(() => _period = e.key); _load(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sort by', style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _sortOptions.entries.map((e) {
              final sel = _sortBy == e.key;
              return GestureDetector(
                onTap: () { setState(() => _sortBy = e.key); _load(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.primary : Colors.transparent),
                  ),
                  child: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Status', style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _statusChip(null, 'All'),
              ..._statusOptions.map((s) => _statusChip(s, s[0] + s.substring(1).toLowerCase())),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statusChip(String? value, String label) {
    final sel = _statusFilter == value;
    return GestureDetector(
      onTap: () { setState(() => _statusFilter = value); _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.accent : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? AppColors.accent : AppColors.textSecondary)),
      ),
    );
  }

  Widget _sortToggleBtn() {
    return GestureDetector(
      onTap: () {
        setState(() => _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc');
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(_sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(_sortOrder == 'desc' ? 'Desc' : 'Asc', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ]),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _loadingMore
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
          : TextButton(
              onPressed: _loadMore,
              child: const Text('Load more', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _empTile(Map<String, dynamic> emp) {
    final firstName = emp['firstName'] ?? emp['user']?['firstName'] ?? '';
    final lastName = emp['lastName'] ?? emp['user']?['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = emp['email'] ?? emp['user']?['email'] ?? '';
    final totalCalls = (emp['totalCalls'] as num?)?.toInt() ?? 0;
    final completedAnalysis = (emp['completedAnalysis'] as num?)?.toInt() ?? 0;
    final avgScore = (emp['averageScore'] as num?)?.toDouble() ?? 0.0;
    final successRate = (emp['successRate'] as num?)?.toDouble() ?? 0.0;
    final userId = emp['userId'] ?? emp['user']?['id'] ?? emp['id'];
    final scoreColor = avgScore >= 80 ? AppColors.success : avgScore >= 60 ? AppColors.warning : AppColors.error;
    return GestureDetector(
      onTap: () => _loadDetail(userId, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySurface,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _badge('$totalCalls calls', AppColors.primary),
              _badge('$completedAnalysis analyzed', AppColors.accent),
              _badge('${successRate.toStringAsFixed(0)}% success', AppColors.success),
            ]),
          ])),
          Column(children: [
            Text(avgScore.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor)),
            Text('score', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
        ]),
      ),
    );
  }

  // ─── Detail View ───

  Widget _detailView() {
    final d = _detail!;
    final strengths = (d['topStrengths'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final improvementAreas = (d['improvementAreas'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final weaknesses = (d['commonWeaknesses'] as List?) ?? [];
    final commonStrengths = (d['commonStrengths'] as List?) ?? [];
    final recentCalls = (d['recentCalls'] as List?) ?? [];
    final sectionPerf = (d['sectionPerformance'] as List?) ?? [];
    final dist = d['scoreDistribution'] as Map? ?? {};
    final excellent = (dist['excellent'] as num?)?.toInt() ?? 0;
    final good = (dist['good'] as num?)?.toInt() ?? 0;
    final average = (dist['average'] as num?)?.toInt() ?? 0;
    final poor = (dist['poor'] as num?)?.toInt() ?? 0;
    final distTotal = excellent + good + average + poor;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() { _detail = null; _detailName = null; _detailUserId = null; _aiTrend = null; }),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_detailName ?? 'Employee Detail', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          TextButton.icon(
            onPressed: _loadingAi ? null : () => _loadAiTrend(refresh: _aiTrend != null),
            icon: _loadingAi
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
            label: Text(_aiTrend == null ? 'AI Trend' : 'Refresh', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Summary metrics
                  Row(children: [
                    Expanded(child: _metricCard('Total Calls', '${d['totalCalls'] ?? 0}', AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard('Analyzed', '${d['completedAnalysis'] ?? 0}', AppColors.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard('Avg Score', (d['averageScore'] as num?)?.toStringAsFixed(1) ?? '0', AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard('Success', '${(d['successRate'] as num?)?.toStringAsFixed(0) ?? '0'}%', AppColors.warning)),
                  ]),

                  // AI Trend block
                  if (_aiTrend != null) ...[
                    const SizedBox(height: 16),
                    _buildAiTrendCard(),
                  ],

                  // Score Distribution
                  if (distTotal > 0) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Score Distribution'),
                    const SizedBox(height: 10),
                    _buildScoreDistribution(excellent, good, average, poor, distTotal),
                  ],

                  // Section Performance
                  if (sectionPerf.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Section Performance'),
                    const SizedBox(height: 8),
                    ...sectionPerf.map((s) => _sectionPerfRow(s)),
                  ],

                  // Top Strengths (simple strings)
                  if (strengths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Top Strengths'),
                    const SizedBox(height: 8),
                    ...strengths.map((s) => _listItem(s, Icons.thumb_up_rounded, AppColors.success)),
                  ],

                  // Common Strengths (objects with area + frequency)
                  if (commonStrengths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Common Strengths'),
                    const SizedBox(height: 8),
                    ...commonStrengths.map((s) => _strengthRow(s)),
                  ],

                  // Improvement Areas (simple strings)
                  if (improvementAreas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Improvement Areas'),
                    const SizedBox(height: 8),
                    ...improvementAreas.map((w) => _listItem(w, Icons.trending_up_rounded, AppColors.warning)),
                  ],

                  // Common Weaknesses (objects with area + frequency + recommendation)
                  if (weaknesses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Common Weaknesses'),
                    const SizedBox(height: 8),
                    ...weaknesses.map((w) => _weaknessCard(w)),
                  ],

                  // Recent Calls
                  if (recentCalls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Recent Calls'),
                    const SizedBox(height: 8),
                    ...recentCalls.map((c) => _recentCallRow(c)),
                  ],

                  const SizedBox(height: 24),
                ]),
              ),
      ),
    ]);
  }

  Widget _buildScoreDistribution(int excellent, int good, int average, int poor, int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(children: [
        _distBar('Excellent (≥80)', excellent, total, AppColors.success),
        const SizedBox(height: 8),
        _distBar('Good (≥60)', good, total, const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _distBar('Average (≥40)', average, total, AppColors.warning),
        const SizedBox(height: 8),
        _distBar('Poor (<40)', poor, total, AppColors.error),
      ]),
    );
  }

  Widget _distBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.surfaceLight,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 7,
        ),
      ),
    ]);
  }

  Widget _sectionPerfRow(dynamic s) {
    final title = s['sectionTitle']?.toString() ?? '';
    final score = (s['averageScore'] as num?)?.toDouble() ?? 0.0;
    final analyzed = (s['callsAnalyzed'] as num?)?.toInt() ?? 0;
    final color = score >= 80 ? AppColors.success : score >= 60 ? AppColors.warning : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('$analyzed calls analyzed', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Text(score.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _weaknessCard(dynamic w) {
    final area = w['area']?.toString() ?? '';
    final frequency = (w['frequency'] as num?)?.toInt() ?? 0;
    final recommendation = w['recommendation']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(area, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('$frequency×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ]),
        if (recommendation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(recommendation, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }

  Widget _strengthRow(dynamic s) {
    final area = s['area']?.toString() ?? '';
    final frequency = (s['frequency'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.star_rounded, size: 14, color: AppColors.success),
        const SizedBox(width: 8),
        Expanded(child: Text(area, style: const TextStyle(fontSize: 13))),
        Text('$frequency×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
      ]),
    );
  }

  Widget _recentCallRow(dynamic c) {
    final customer = c['customerName']?.toString() ?? 'Unknown';
    final score = (c['score'] as num?)?.toDouble() ?? 0.0;
    final status = c['status']?.toString() ?? '';
    final date = c['date']?.toString() ?? '';
    final scoreColor = score >= 80 ? AppColors.success : score >= 60 ? AppColors.warning : AppColors.error;
    final statusColor = status == 'COMPLETED' ? AppColors.success : status == 'PROCESSING' ? AppColors.warning : AppColors.textHint;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(children: [
        const Icon(Icons.call_rounded, size: 16, color: AppColors.textHint),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
            if (date.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(_shortDate(date), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ]),
        ])),
        Text(score.toStringAsFixed(1), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scoreColor)),
      ]),
    );
  }

  Widget _buildAiTrendCard() {
    final t = _aiTrend!;
    final summary = t['summary']?.toString() ?? t['trendSummary']?.toString() ?? '';
    final trajectory = t['trajectory']?.toString() ?? t['performanceTrajectory']?.toString() ?? '';
    final recs = (t['recommendations'] as List?) ?? [];
    final concerns = (t['keyInsights'] as List?) ?? (t['concerns'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.accent.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('AI Trend Analysis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _aiTrend = null),
            child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
          ),
        ]),
        if (trajectory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(trajectory, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ],
        if (concerns.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...concerns.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline, size: 13, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(child: Text(c.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
            ]),
          )),
        ],
        if (recs.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...recs.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.arrow_right_rounded, size: 16, color: AppColors.success),
              Expanded(child: Text(r.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            ]),
          )),
        ],
      ]),
    );
  }

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso.split('T').first;
    }
  }

  Widget _sectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));

  Widget _metricCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );

  Widget _listItem(String text, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
