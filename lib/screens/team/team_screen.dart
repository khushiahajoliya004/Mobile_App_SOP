import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _api = ApiService();
  bool _loading = true;

  // Hierarchy tree from /employee-performance/team-report
  List<Map<String, dynamic>> _hierarchy = [];

  // Summary stats
  int _totalMembers = 0;
  int _totalCalls = 0;
  double _avgScore = 0;
  double _totalMinutes = 0;

  // Which team leaders are expanded
  final Set<String> _expandedIds = {};

  // Member calls view
  Map<String, dynamic>? _selectedMember;
  List<Map<String, dynamic>> _memberCalls = [];
  bool _callsLoading = false;
  int _memberCallCount = 0;
  int _memberAnalyzedCount = 0;
  int _memberAvgScore = 0;

  // Call detail view
  Map<String, dynamic>? _selectedCall;
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTeamReport();
      final raw = res.data;
      if (raw is Map && raw['data'] != null) {
        final d = raw['data'] as Map;
        final hierarchyList = (d['hierarchy'] as List?) ?? [];
        _hierarchy = hierarchyList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final sum = (d['summary'] as Map?) ?? {};
        _totalMembers = (sum['totalMembers'] ?? 0) as int;
        _totalCalls = (sum['totalCalls'] ?? 0) as int;
        _avgScore =
            double.tryParse((sum['avgScore'] ?? 0).toString()) ?? 0;
        _totalMinutes =
            double.tryParse((sum['totalMinutes'] ?? 0).toString()) ?? 0;
      }
    } catch (_) {
      _hierarchy = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  // Flatten hierarchy tree for ListView, each entry carries its depth
  List<(Map<String, dynamic>, int)> _buildDisplayList() {
    final result = <(Map<String, dynamic>, int)>[];

    void visit(dynamic rawNode, int depth) {
      final node = Map<String, dynamic>.from(rawNode as Map);
      result.add((node, depth));
      final children = (rawNode['children'] as List?) ?? [];
      final uid = (rawNode['userId'] as String?) ?? '';
      if (children.isNotEmpty && _expandedIds.contains(uid)) {
        for (final child in children) {
          visit(child, depth + 1);
        }
      }
    }

    for (final root in _hierarchy) {
      visit(root, 0);
    }
    return result;
  }

  Future<void> _loadMemberCalls(Map<String, dynamic> member) async {
    final memberId = (member['userId'] ?? member['id'] ?? '') as String;
    setState(() {
      _selectedMember = {...member, 'id': memberId};
      _callsLoading = true;
      _selectedCall = null;
      _memberCalls = [];
    });
    try {
      final res = await _api.getTeamMemberCalls(memberId, page: 1, limit: 50);
      final raw = res.data;
      if (raw is Map && raw['data'] != null) {
        _memberCalls = (raw['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      _computeMemberStats();
    } catch (_) {
      _memberCalls = [];
    }
    if (mounted) setState(() => _callsLoading = false);
  }

  void _computeMemberStats() {
    _memberCallCount = _memberCalls.length;
    _memberAnalyzedCount = _memberCalls
        .where((c) => c['analysisStatus'] == 'COMPLETED')
        .length;
    final scored =
        _memberCalls.where((c) => c['sopScore'] != null).toList();
    _memberAvgScore = scored.isNotEmpty
        ? (scored
                  .map(
                    (c) =>
                        double.tryParse(c['sopScore'].toString()) ?? 0.0,
                  )
                  .reduce((a, b) => a + b) /
              scored.length)
          .round()
        : 0;
  }

  Future<void> _loadCallDetail(Map<String, dynamic> call) async {
    setState(() {
      _selectedCall = call;
      _detailLoading = true;
    });
    try {
      final res = await _api.getAiInsightDetail(call['id']);
      final raw = res.data;
      final detail = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : <String, dynamic>{};
      setState(() {
        _selectedCall = {...call, ...detail};
        _detailLoading = false;
      });
    } catch (_) {
      setState(() => _detailLoading = false);
    }
  }

  // Short date for "last call" column (e.g. "11 Jun")
  String _shortDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse('$date').toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${d.day} ${m[d.month - 1]}';
    } catch (_) {
      return '-';
    }
  }

  String _fullDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse('$date').toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  Color _scoreColor(num score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _scoreLabel(num score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Poor';
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'TEAM_LEADER':
        return const Color(0xFF6366F1);
      case 'SALES_MANAGER':
        return const Color(0xFF8B5CF6);
      case 'BRANCH_MANAGER':
        return const Color(0xFF0EA5E9);
      case 'RECEPTION':
        return const Color(0xFFF97316);
      default:
        return AppColors.success;
    }
  }

  String _roleName(String role) {
    switch (role.toUpperCase()) {
      case 'TEAM_LEADER':
        return 'Team Leader';
      case 'SALES_MANAGER':
        return 'Sales Manager';
      case 'BRANCH_MANAGER':
        return 'Branch Manager';
      case 'RECEPTION':
        return 'Reception';
      case 'SALES':
        return 'Sales';
      default:
        return role;
    }
  }

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEC4899), Color(0xFF0EA5E9), Color(0xFF8B5CF6),
      Color(0xFFF97316), Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selectedCall != null) return _callDetailView();
    if (_selectedMember != null) return _memberCallsView();
    return _teamListView();
  }

  // ─── Team Hierarchy List ───────────────────────────────────────────────

  Widget _teamListView() {
    return Column(
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Hierarchy-based performance report',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _loadTeam,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Summary stat cards
        if (!_loading) _summaryStats(),
        // Expand / Collapse All
        if (!_loading && _hierarchy.isNotEmpty) _expandControls(),
        // Hierarchy list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _hierarchy.isEmpty
              ? _emptyState(
                  'No team members found',
                  Icons.group_off_rounded,
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadTeam,
                  child: _hierarchyListView(),
                ),
        ),
      ],
    );
  }

  Widget _summaryStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _summaryCard(
            Icons.people_alt_rounded,
            '$_totalMembers',
            'Members',
            AppColors.primary,
          ),
          const SizedBox(width: 8),
          _summaryCard(
            Icons.phone_rounded,
            '$_totalCalls',
            'Total Calls',
            AppColors.success,
          ),
          const SizedBox(width: 8),
          _summaryCard(
            Icons.bar_chart_rounded,
            '${_avgScore.toStringAsFixed(0)}%',
            'Avg Score',
            AppColors.warning,
          ),
          const SizedBox(width: 8),
          _summaryCard(
            Icons.timer_rounded,
            _totalMinutes.toStringAsFixed(0),
            'Minutes',
            const Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandControls() {
    // Collect IDs of nodes that have children
    final withChildren = <String>[];
    void collect(dynamic node) {
      final children = (node['children'] as List?) ?? [];
      if (children.isNotEmpty) {
        withChildren.add((node['userId'] as String?) ?? '');
        for (final c in children) {
          collect(c);
        }
      }
    }
    for (final r in _hierarchy) {
      collect(r);
    }
    if (withChildren.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedIds.addAll(withChildren)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.unfold_more_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Expand All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _expandedIds.clear()),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.unfold_less_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  const Text(
                    'Collapse All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hierarchyListView() {
    final items = _buildDisplayList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (node, depth) = items[i];
        return _memberCard(node, depth, i);
      },
    );
  }

  Widget _memberCard(Map<String, dynamic> member, int depth, int index) {
    final name = (member['name'] as String?) ?? '';
    final role = (member['branchRole'] as String?) ?? 'SALES';
    final userId = (member['userId'] as String?) ?? '';
    final children = (member['children'] as List?) ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(userId);

    final metrics = (member['metrics'] as Map?) ?? {};
    final totalCalls = (metrics['totalCalls'] ?? 0) as int;
    final avgScore =
        double.tryParse((metrics['avgScore'] ?? 0).toString()) ?? 0;
    final totalMinutes =
        double.tryParse((metrics['totalMinutes'] ?? 0).toString()) ?? 0;
    final excellentCalls = (metrics['excellentCalls'] ?? 0) as int;
    final goodCalls = (metrics['goodCalls'] ?? 0) as int;
    final poorCalls = (metrics['poorCalls'] ?? 0) as int;
    final lastCallDate = metrics['lastCallDate'];

    final roleColor = _roleColor(role);
    final roleName = _roleName(role);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, bottom: 8),
      child: GestureDetector(
        onTap: () => _loadMemberCalls(member),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: depth > 0
                ? Border.all(color: AppColors.surfaceLight)
                : null,
            boxShadow: depth == 0
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    // Expand / collapse toggle
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hasChildren
                          ? () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedIds.remove(userId);
                                } else {
                                  _expandedIds.add(userId);
                                }
                              });
                            }
                          : null,
                      child: SizedBox(
                        width: 22,
                        child: hasChildren
                            ? Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_right_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _avatarColor(index),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              roleName,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Total calls badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalCalls',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: totalCalls > 0
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ),
                        const Text(
                          'calls',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Metrics row
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 26),
                    _metricBox(
                      '${avgScore.toStringAsFixed(0)}%',
                      'Score',
                      avgScore > 0 ? _scoreColor(avgScore) : AppColors.textHint,
                    ),
                    _metricBox(
                      totalMinutes.toStringAsFixed(1),
                      'Min',
                      const Color(0xFF0EA5E9),
                    ),
                    _metricBox(
                      '$excellentCalls',
                      'Exc',
                      AppColors.success,
                    ),
                    _metricBox(
                      '$goodCalls',
                      'Good',
                      AppColors.warning,
                    ),
                    _metricBox(
                      '$poorCalls',
                      'Poor',
                      AppColors.error,
                    ),
                    _metricBox(
                      _shortDate(lastCallDate),
                      'Last',
                      AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBox(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Member Calls View ─────────────────────────────────────────────────

  Widget _memberCallsView() {
    final member = _selectedMember!;
    final name = (member['name'] as String?) ??
        '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'.trim();

    return Column(
      children: [
        // Back + Member info header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedMember = null;
                  _memberCalls = [];
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      member['phone'] ?? member['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Stats row
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Row(
            children: [
              _statChip(
                Icons.phone_rounded,
                '$_memberCallCount',
                'Calls',
                AppColors.primary,
              ),
              _statChip(
                Icons.check_circle_rounded,
                '$_memberAnalyzedCount',
                'Analyzed',
                AppColors.success,
              ),
              _statChip(
                Icons.bar_chart_rounded,
                '$_memberAvgScore%',
                'Avg Score',
                AppColors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Calls list
        Expanded(
          child: _callsLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _memberCalls.isEmpty
              ? _emptyState(
                  'No calls uploaded yet',
                  Icons.phone_disabled_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _memberCalls.length,
                  itemBuilder: (_, i) => _callTile(_memberCalls[i]),
                ),
        ),
      ],
    );
  }

  Widget _statChip(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _callTile(Map<String, dynamic> call) {
    final score = call['sopScore'];
    final status = call['analysisStatus'] ?? '';
    final name =
        call['aiAnalysis']?['customerName'] ??
        call['customerName'] ??
        'Unknown';
    final category = call['category']?['name'] ?? '';
    final date = _fullDate(call['createdAt']);

    return GestureDetector(
      onTap: () => _loadCallDetail(call),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: score != null
                    ? _scoreColor(score).withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: score != null
                    ? Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor(score),
                        ),
                      )
                    : Icon(
                        status == 'PROCESSING'
                            ? Icons.hourglass_top
                            : Icons.schedule,
                        size: 18,
                        color: AppColors.textHint,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(status),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'COMPLETED':
        bg = AppColors.success.withValues(alpha: 0.1);
        fg = AppColors.success;
        break;
      case 'PROCESSING':
        bg = AppColors.primary.withValues(alpha: 0.1);
        fg = AppColors.primary;
        break;
      case 'FAILED':
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.surfaceLight;
        fg = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ─── Call Detail View (AI Insight) ─────────────────────────────────────

  Widget _callDetailView() {
    final c = _selectedCall!;
    final score = c['sopScore'];
    final status = c['analysisStatus'] ?? '';
    final name =
        c['aiAnalysis']?['customerName'] ??
        c['customerName'] ??
        'Unknown';
    final category = c['category']?['name'] ?? '';
    final stage = c['salesStage']?['name'] ?? '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedCall = null),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$category${stage.isNotEmpty ? " · $stage" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor(score),
                        ),
                      ),
                      Text(
                        _scoreLabel(score),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _scoreColor(score),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (status == 'PROCESSING')
          _banner(
            Icons.hourglass_top,
            'Analysis in progress...',
            AppColors.primary,
          ),
        if (status == 'PENDING')
          _banner(
            Icons.schedule,
            'Waiting to be analyzed',
            AppColors.warning,
          ),
        if (status == 'FAILED')
          _banner(Icons.error_outline, 'Analysis failed', AppColors.error),
        if (_detailLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (status == 'COMPLETED')
          Expanded(child: _insightContent(c))
        else
          Expanded(
            child: _emptyState(
              'Analysis not available',
              Icons.analytics_outlined,
            ),
          ),
      ],
    );
  }

  Widget _banner(IconData icon, String text, Color color) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ─── AI Insight Content ────────────────────────────────────────────────

  Widget _insightContent(Map<String, dynamic> c) {
    final ai = c['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final sections =
        (c['sectionScores'] ?? ai['sectionScores'] ?? []) as List;
    final summary = ai['summary'] ?? ai['callSummary'] ?? '';
    final keyPoints =
        (ai['keyDiscussionPoints'] ?? ai['keyPoints'] ?? []) as List;
    final mistakes = (ai['commonMistakes'] ?? []) as List;
    final suggestion = ai['suggestion'] ?? ai['suggestions'] ?? '';
    final nextAction = ai['nextAction'] ?? '';
    final conversionProb = ai['conversionProbability'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (summary.toString().isNotEmpty) ...[
          _sectionHeader(
            Icons.summarize_rounded,
            'Call Summary',
            AppColors.primary,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Text(
              summary.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (keyPoints.isNotEmpty) ...[
          _sectionHeader(
            Icons.list_alt_rounded,
            'Key Discussion Points',
            AppColors.success,
          ),
          ...keyPoints.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (sections.isNotEmpty) ...[
          _sectionHeader(
            Icons.pie_chart_outline,
            'SOP Analysis',
            AppColors.primary,
          ),
          ...sections.map((s) {
            final sec = Map<String, dynamic>.from(s);
            final secScore =
                double.tryParse((sec['score'] ?? 0).toString()) ?? 0.0;
            final secName = sec['sectionName'] ?? sec['name'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          secName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: secScore / 100,
                            backgroundColor: AppColors.surfaceLight,
                            color: _scoreColor(secScore),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${secScore.toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor(secScore),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],
        if (mistakes.isNotEmpty) ...[
          _sectionHeader(
            Icons.warning_amber_rounded,
            'Areas to Improve',
            AppColors.error,
          ),
          ...mistakes.map((m) {
            final mm = m is Map
                ? Map<String, dynamic>.from(m)
                : {'title': m.toString()};
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mm['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (mm['recommendation'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        mm['recommendation'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],
        if (suggestion.toString().isNotEmpty) ...[
          _sectionHeader(
            Icons.lightbulb_outline,
            'Suggestion',
            AppColors.warning,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              suggestion.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (nextAction.toString().isNotEmpty) ...[
          _sectionHeader(
            Icons.next_plan_outlined,
            'Next Action',
            AppColors.primary,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              nextAction.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (conversionProb != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.success.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Conversion Probability',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$conversionProb%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.textHint.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
