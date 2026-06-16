import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = ApiService();
  int _tab = 0;
  String _period = '30d';
  bool _loading = false;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _scoreDist = {'totalScored': 0, 'buckets': []};
  List<dynamic> _catBreakdown = [];
  List<dynamic> _stageBreakdown = [];
  List<dynamic> _userPerf = [];
  List<dynamic> _userCallAnalysis = [];
  List<dynamic> _sopMatrix = [];
  List<dynamic> _userSopMatrix = [];

  final Set<String> _expandedSops = {};
  final Set<String> _expandedSections = {};
  final Set<String> _expandedTrainSops = {};
  final Set<String> _expandedTrainUsers = {};

  static const _periods = ['3d', '7d', '30d', '90d', '365d', 'all'];
  static const _periodLabels = ['3 Days', 'Weekly', 'Monthly', 'Quarterly', 'Yearly', 'All Time'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final d = raw['data'];
      if (d is List) return d;
    }
    return [];
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      final d = raw['data'];
      if (d is Map) return Map<String, dynamic>.from(d);
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _api.getAnalyticsOverview(period: _period).then((r) {
        _overview = _asMap(r.data);
      }).catchError((_) { _overview = {}; }),
      _api.getAnalyticsScoreDistribution(period: _period).then((r) {
        _scoreDist = _asMap(r.data).isNotEmpty ? _asMap(r.data) : {'totalScored': 0, 'buckets': []};
      }).catchError((_) { _scoreDist = {'totalScored': 0, 'buckets': []}; }),
      _api.getAnalyticsCategoryBreakdown(period: _period).then((r) {
        _catBreakdown = _asList(r.data);
      }).catchError((_) { _catBreakdown = []; }),
      _api.getAnalyticsSalesStageBreakdown(period: _period).then((r) {
        _stageBreakdown = _asList(r.data);
      }).catchError((_) { _stageBreakdown = []; }),
      _api.getAnalyticsUserPerformance(period: _period).then((r) {
        _userPerf = _asList(r.data);
      }).catchError((_) { _userPerf = []; }),
      _api.getAnalyticsUserCallAnalysis(period: _period).then((r) {
        _userCallAnalysis = _asList(r.data);
      }).catchError((_) { _userCallAnalysis = []; }),
      _api.getAnalyticsSopMatrix(period: _period).then((r) {
        _sopMatrix = _asList(r.data);
      }).catchError((_) { _sopMatrix = []; }),
      _api.getAnalyticsUserSopMatrix(period: _period).then((r) {
        _userSopMatrix = _asList(r.data);
      }).catchError((_) { _userSopMatrix = []; }),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Color _scoreColor(num score) {
    if (score >= 80) return const Color(0xFF14B8A6);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _scoreBadge(num? score) {
    final s = score ?? 0;
    final c = _scoreColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text('$s%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _countBadge(dynamic val, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text('$val', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _perfBar(num? pct) {
    final v = (pct ?? 0).clamp(0, 100).toDouble();
    return SizedBox(
      width: 70,
      child: LinearProgressIndicator(
        value: v / 100,
        backgroundColor: AppColors.surfaceLight,
        color: _scoreColor(v),
        minHeight: 6,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildPeriodBar(),
      _buildTabBar(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: _tabContent(),
                ),
              ),
      ),
    ]);
  }

  Widget _buildPeriodBar() {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _periods.length,
        itemBuilder: (_, i) {
          final sel = _period == _periods[i];
          return GestureDetector(
            onTap: () { setState(() { _period = _periods[i]; _expandedSops.clear(); _expandedSections.clear(); _expandedTrainSops.clear(); _expandedTrainUsers.clear(); }); _loadAll(); },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_periodLabels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Overview', 'Breakdowns', 'Users', 'SOP Matrix', 'Training'];
    final icons = [Icons.dashboard_rounded, Icons.pie_chart_rounded, Icons.people_rounded, Icons.grid_view_rounded, Icons.school_rounded];
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final sel = _tab == i;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: sel ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
              ),
              child: Row(children: [
                Icon(icons[i], size: 14, color: sel ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(tabs[i], style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppColors.primary : AppColors.textSecondary)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 0: return _buildOverview();
      case 1: return _buildBreakdowns();
      case 2: return _buildUsers();
      case 3: return _buildSopMatrix();
      case 4: return _buildTrainingMatrix();
      default: return const SizedBox();
    }
  }

  // ─── OVERVIEW ────────────────────────────────────────────────────────────────

  Widget _buildOverview() {
    final o = _overview;
    final buckets = (_scoreDist['buckets'] as List? ?? []);
    final totalScored = _scoreDist['totalScored'] ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('PERFORMANCE METRICS', Icons.insights_rounded),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          _overviewCard('Total Calls', '${o['totalCalls'] ?? 0}', Icons.phone_in_talk_rounded, AppColors.primary, change: o['callsChange']),
          _overviewCard('Analyzed', '${o['analyzedCalls'] ?? 0}', Icons.check_circle_rounded, const Color(0xFF14B8A6)),
          _overviewCard('Avg Score', '${o['avgScore'] ?? 0}%', Icons.star_rounded, const Color(0xFF3B82F6)),
          _overviewCard('High Performers', '${o['highPerformers'] ?? 0}', Icons.thumb_up_rounded, const Color(0xFF10B981)),
          _overviewCard('Needs Improvement', '${o['needsImprovement'] ?? 0}', Icons.warning_rounded, const Color(0xFFF59E0B)),
          _overviewCard('Active Users', '${o['uniqueUsers'] ?? 0}', Icons.people_rounded, const Color(0xFF8B5CF6)),
        ],
      ),
      const SizedBox(height: 20),
      _sectionLabel('SCORE DISTRIBUTION', Icons.bar_chart_rounded),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Score Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text('$totalScored scored calls', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 14),
        if (buckets.isEmpty)
          const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint, fontSize: 13)))
        else
          ...buckets.map<Widget>((b) {
            final pct = (b['percentage'] as num? ?? 0).toDouble();
            final color = b['color'] != null ? _hexColor(b['color']) : _scoreColor(pct);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${b['label'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  Text('${b['count'] ?? 0} (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: AppColors.surfaceLight,
                  color: color,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
              ]),
            );
          }),
      ])),
    ]);
  }

  Widget _overviewCard(String label, String value, IconData icon, Color color, {dynamic change}) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
        if (change != null) ...[
          const Spacer(),
          _changeChip(change),
        ],
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]),
    ]));
  }

  Widget _changeChip(dynamic change) {
    final v = (change as num? ?? 0);
    final up = v > 0;
    final color = up ? const Color(0xFF10B981) : (v < 0 ? const Color(0xFFEF4444) : AppColors.textHint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : (v < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded), size: 10, color: color),
        const SizedBox(width: 2),
        Text('${up ? '+' : ''}$v%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ─── BREAKDOWNS ──────────────────────────────────────────────────────────────

  Widget _buildBreakdowns() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('BY CATEGORY', Icons.category_rounded),
      const SizedBox(height: 10),
      _card(_breakdownList(_catBreakdown, 'No category data')),
      const SizedBox(height: 16),
      _sectionLabel('BY SALES STAGE', Icons.filter_list_rounded),
      const SizedBox(height: 10),
      _card(_breakdownList(_stageBreakdown, 'No sales stage data')),
    ]);
  }

  Widget _breakdownList(List<dynamic> items, String emptyMsg) {
    if (items.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(emptyMsg, style: const TextStyle(color: AppColors.textHint, fontSize: 13))));
    }
    return Column(children: items.map<Widget>((item) {
      final score = (item['avgScore'] as num? ?? 0).toDouble();
      final pct = (item['percentage'] as num? ?? 0).toDouble();
      final barColor = _scoreColor(score);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${item['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            _scoreBadge(score),
            const SizedBox(width: 6),
            Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]),
          const SizedBox(height: 2),
          Text('${item['totalCalls'] ?? 0} calls', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppColors.surfaceLight,
            color: barColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ]),
      );
    }).toList());
  }

  // ─── USERS ───────────────────────────────────────────────────────────────────

  Widget _buildUsers() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('USER PERFORMANCE LEADERBOARD', Icons.emoji_events_rounded),
      const SizedBox(height: 10),
      _card(_userPerfTable()),
      const SizedBox(height: 16),
      _sectionLabel('CALL UPLOAD & QUESTION ANALYSIS', Icons.analytics_rounded),
      const SizedBox(height: 10),
      _card(_userCallTable()),
    ]);
  }

  Widget _userPerfTable() {
    if (_userPerf.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No user data', style: TextStyle(color: AppColors.textHint, fontSize: 13))));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        horizontalMargin: 0,
        columnSpacing: 16,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint),
        columns: const [
          DataColumn(label: Text('Rank')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Calls'), numeric: true),
          DataColumn(label: Text('Analyzed'), numeric: true),
          DataColumn(label: Text('Avg Score')),
          DataColumn(label: Text('High ≥80'), numeric: true),
          DataColumn(label: Text('Low <50'), numeric: true),
          DataColumn(label: Text('Performance')),
        ],
        rows: _userPerf.asMap().entries.map<DataRow>((e) {
          final i = e.key;
          final u = e.value as Map;
          final name = '${u['name'] ?? ''}';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          return DataRow(cells: [
            DataCell(_rankBadge(i)),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            DataCell(Text('${u['totalCalls'] ?? 0}', style: const TextStyle(fontSize: 12))),
            DataCell(Text('${u['analyzedCalls'] ?? 0}', style: const TextStyle(fontSize: 12))),
            DataCell(_scoreBadge(u['avgScore'] as num? ?? 0)),
            DataCell(_countBadge(u['highPerformance'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46))),
            DataCell(_countBadge(u['needsImprovement'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B))),
            DataCell(_perfBar(u['avgScore'] as num?)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _userCallTable() {
    if (_userCallAnalysis.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No data', style: TextStyle(color: AppColors.textHint, fontSize: 13))));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        horizontalMargin: 0,
        columnSpacing: 14,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint),
        columns: const [
          DataColumn(label: Text('#'), numeric: true),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Uploaded'), numeric: true),
          DataColumn(label: Text('Analyzed'), numeric: true),
          DataColumn(label: Text('Pending'), numeric: true),
          DataColumn(label: Text('Failed'), numeric: true),
          DataColumn(label: Text('Avg Score')),
          DataColumn(label: Text('Total Qs'), numeric: true),
          DataColumn(label: Text('Answered'), numeric: true),
          DataColumn(label: Text('Unanswered'), numeric: true),
          DataColumn(label: Text('Answer Rate')),
        ],
        rows: _userCallAnalysis.asMap().entries.map<DataRow>((e) {
          final i = e.key;
          final u = e.value as Map;
          final name = '${u['name'] ?? ''}';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          return DataRow(cells: [
            DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 13, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(initial, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            DataCell(_countBadge(u['totalUploaded'] ?? 0, const Color(0xFFDBEAFE), const Color(0xFF1E40AF))),
            DataCell(_countBadge(u['analyzed'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46))),
            DataCell(_countBadge(u['pending'] ?? 0, const Color(0xFFFEF3C7), const Color(0xFF92400E))),
            DataCell(_countBadge(u['failed'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B))),
            DataCell(_scoreBadge(u['avgScore'] as num? ?? 0)),
            DataCell(Text('${u['totalQuestions'] ?? 0}', style: const TextStyle(fontSize: 12))),
            DataCell(_countBadge(u['answeredQuestions'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46))),
            DataCell(_countBadge(u['unansweredQuestions'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B))),
            DataCell(Row(children: [_perfBar(u['answerRate'] as num?), const SizedBox(width: 4), Text('${u['answerRate'] ?? 0}%', style: const TextStyle(fontSize: 10, color: AppColors.textHint))])),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _rankBadge(int index) {
    if (index == 0) return const Text('🥇', style: TextStyle(fontSize: 18));
    if (index == 1) return const Text('🥈', style: TextStyle(fontSize: 18));
    if (index == 2) return const Text('🥉', style: TextStyle(fontSize: 18));
    return Text('#${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }

  // ─── SOP MATRIX ──────────────────────────────────────────────────────────────

  Widget _buildSopMatrix() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('SOP QUESTION MATRIX', Icons.grid_view_rounded),
      const SizedBox(height: 10),
      if (_sopMatrix.isEmpty)
        _card(const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No SOP matrix data', style: TextStyle(color: AppColors.textHint, fontSize: 13)))))
      else
        ..._sopMatrix.map<Widget>((sop) => _sopBlock(sop)),
    ]);
  }

  Widget _sopBlock(Map sop) {
    final sopId = '${sop['sopId'] ?? sop['id'] ?? ''}';
    final expanded = _expandedSops.contains(sopId);
    final sections = (sop['sections'] as List? ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() { if (expanded) _expandedSops.remove(sopId); else _expandedSops.add(sopId); }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${sop['sopName'] ?? 'SOP'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if ((sop['category'] ?? '').toString().isNotEmpty || (sop['salesStage'] ?? '').toString().isNotEmpty)
                  Text('${sop['category'] ?? ''} · ${sop['salesStage'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              const SizedBox(width: 8),
              Wrap(spacing: 6, children: [
                _countBadge('${sop['totalCalls'] ?? 0} calls', const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                _countBadge('${sop['analyzedCalls'] ?? 0} analyzed', const Color(0xFFD1FAE5), const Color(0xFF065F46)),
                _scoreBadge(sop['avgScore'] as num? ?? 0),
              ]),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1),
          ...sections.map<Widget>((sec) => _sectionBlock(sec)),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }

  Widget _sectionBlock(Map sec) {
    final secId = '${sec['sectionId'] ?? sec['id'] ?? sec['title'] ?? ''}';
    final expanded = _expandedSections.contains(secId);
    final questions = (sec['questions'] as List? ?? []);
    return Column(children: [
      InkWell(
        onTap: () => setState(() { if (expanded) _expandedSections.remove(secId); else _expandedSections.add(secId); }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const SizedBox(width: 24),
            Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, size: 16, color: AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${sec['title'] ?? 'Section'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${sec['totalQuestions'] ?? 0} questions · ${sec['weightage'] ?? 0}% weight', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ])),
            Wrap(spacing: 6, children: [
              _countBadge(sec['totalAnswered'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46)),
              _countBadge(sec['totalUnanswered'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
              _perfBar(sec['sectionAnswerRate'] as num?),
              Text('${sec['sectionAnswerRate'] ?? 0}%', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          ]),
        ),
      ),
      if (expanded) Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        child: _questionsTable(questions),
      ),
      const Divider(height: 1, indent: 14),
    ]);
  }

  Widget _questionsTable(List<dynamic> questions) {
    if (questions.isEmpty) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        horizontalMargin: 4,
        columnSpacing: 12,
        headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint),
        columns: const [
          DataColumn(label: Text('#'), numeric: true),
          DataColumn(label: Text('Question')),
          DataColumn(label: Text('Asked'), numeric: true),
          DataColumn(label: Text('Answered'), numeric: true),
          DataColumn(label: Text('Missed'), numeric: true),
          DataColumn(label: Text('Confidence')),
          DataColumn(label: Text('Answer Rate')),
        ],
        rows: questions.asMap().entries.map<DataRow>((e) {
          final qi = e.key;
          final q = e.value as Map;
          return DataRow(cells: [
            DataCell(Text('${qi + 1}', style: const TextStyle(fontSize: 11))),
            DataCell(SizedBox(width: 180, child: Text('${q['question'] ?? ''}', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis))),
            DataCell(Text('${q['timesAsked'] ?? 0}', style: const TextStyle(fontSize: 11))),
            DataCell(_countBadge(q['timesAnswered'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46))),
            DataCell(_countBadge(q['timesUnanswered'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B))),
            DataCell(_scoreBadge(q['avgConfidence'] as num? ?? 0)),
            DataCell(Row(children: [_perfBar(q['answerRate'] as num?), const SizedBox(width: 4), Text('${q['answerRate'] ?? 0}%', style: const TextStyle(fontSize: 10, color: AppColors.textHint))])),
          ]);
        }).toList(),
      ),
    );
  }

  // ─── TRAINING MATRIX ─────────────────────────────────────────────────────────

  Widget _buildTrainingMatrix() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('USER × SOP TRAINING MATRIX', Icons.school_rounded),
      const SizedBox(height: 10),
      if (_userSopMatrix.isEmpty)
        _card(const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No training matrix data', style: TextStyle(color: AppColors.textHint, fontSize: 13)))))
      else
        ..._userSopMatrix.map<Widget>((sop) => _trainSopBlock(sop)),
    ]);
  }

  Widget _trainSopBlock(Map sop) {
    final sopId = '${sop['sopId'] ?? sop['id'] ?? ''}';
    final expanded = _expandedTrainSops.contains(sopId);
    final sections = (sop['sections'] as List? ?? []);
    final users = (sop['users'] as List? ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() { if (expanded) _expandedTrainSops.remove(sopId); else _expandedTrainSops.add(sopId); }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${sop['sopName'] ?? 'SOP'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('${users.length} users · ${sections.length} sections', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                horizontalMargin: 4,
                columnSpacing: 10,
                headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint),
                columns: [
                  const DataColumn(label: SizedBox(width: 120, child: Text('User'))),
                  const DataColumn(label: Text('Score')),
                  const DataColumn(label: Text('Calls'), numeric: true),
                  ...sections.map<DataColumn>((sec) => DataColumn(label: SizedBox(width: 80, child: Text('${sec['title'] ?? ''}', style: const TextStyle(fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis)))),
                ],
                rows: users.map<DataRow>((u) {
                  final uMap = u as Map;
                  final userId = '${uMap['userId'] ?? uMap['id'] ?? ''}';
                  final name = '${uMap['name'] ?? ''}';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  final sectionScores = (uMap['sectionScores'] as List? ?? []);
                  final userExpanded = _expandedTrainUsers.contains('$sopId-$userId');
                  return DataRow(
                    onSelectChanged: (_) => setState(() { final k = '$sopId-$userId'; if (userExpanded) _expandedTrainUsers.remove(k); else _expandedTrainUsers.add(k); }),
                    cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(radius: 13, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(initial, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                        const SizedBox(width: 6),
                        SizedBox(width: 80, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ])),
                      DataCell(_scoreBadge(uMap['avgScore'] as num? ?? 0)),
                      DataCell(Text('${uMap['totalCalls'] ?? 0}', style: const TextStyle(fontSize: 12))),
                      ...sectionScores.map<DataCell>((sec) => DataCell(
                        _heatmapCell(sec['answerRate'] as num? ?? 0),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          // Expanded user detail
          ...users.map<Widget>((u) {
            final uMap = u as Map;
            final userId = '${uMap['userId'] ?? uMap['id'] ?? ''}';
            final name = '${uMap['name'] ?? ''}';
            final userExpanded = _expandedTrainUsers.contains('$sopId-$userId');
            if (!userExpanded) return const SizedBox.shrink();
            final sectionScores = (uMap['sectionScores'] as List? ?? []);
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.surfaceLight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$name — Question Detail', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                ...sectionScores.map<Widget>((sec) {
                  final secMap = sec as Map;
                  final questions = (secMap['questions'] as List? ?? []);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${secMap['title'] ?? 'Section'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                      _heatmapCell(secMap['answerRate'] as num? ?? 0),
                    ]),
                    const SizedBox(height: 6),
                    if (questions.isNotEmpty) SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 28,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 44,
                        horizontalMargin: 0,
                        columnSpacing: 12,
                        headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint),
                        columns: const [
                          DataColumn(label: Text('#'), numeric: true),
                          DataColumn(label: Text('Question')),
                          DataColumn(label: Text('Asked'), numeric: true),
                          DataColumn(label: Text('Answered'), numeric: true),
                          DataColumn(label: Text('Missed'), numeric: true),
                          DataColumn(label: Text('Rate')),
                        ],
                        rows: questions.asMap().entries.map<DataRow>((e) {
                          final qi = e.key;
                          final q = e.value as Map;
                          final rate = (q['answerRate'] as num? ?? 0).toDouble();
                          return DataRow(
                            color: WidgetStateProperty.all(rate < 50 ? const Color(0xFFFEF2F2) : null),
                            cells: [
                              DataCell(Text('${qi + 1}', style: const TextStyle(fontSize: 10))),
                              DataCell(SizedBox(width: 160, child: Text('${q['question'] ?? ''}', style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis))),
                              DataCell(Text('${q['asked'] ?? 0}', style: const TextStyle(fontSize: 10))),
                              DataCell(_countBadge(q['answered'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF065F46))),
                              DataCell(_countBadge(q['missed'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFF991B1B))),
                              DataCell(_heatmapCell(q['answerRate'] as num? ?? 0)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ]);
                }),
              ]),
            );
          }),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }

  Widget _heatmapCell(num rate) {
    final r = rate.toDouble();
    final color = _scoreColor(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text('$rate%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 12, color: AppColors.textHint),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.8)),
    ]);
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
