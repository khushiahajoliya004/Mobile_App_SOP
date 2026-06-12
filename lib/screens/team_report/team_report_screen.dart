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

  // Hierarchy tree from API
  List<Map<String, dynamic>> _hierarchy = [];

  // Summary stats
  int _totalMembers = 0;
  int _totalCalls = 0;
  double _avgScore = 0;
  double _totalMinutes = 0;

  // Expand/collapse state
  final Set<String> _expandedIds = {};

  // Filters
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
      final raw = res.data;
      if (raw is Map) {
        final list = raw['data'] ?? raw['branches'] ?? raw;
        if (list is List) {
          _branches = list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
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
      final raw = res.data is Map ? res.data as Map : {};
      final d = raw['data'] as Map? ?? {};
      final hierarchyList = (d['hierarchy'] as List?) ?? [];
      _hierarchy =
          hierarchyList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final sum = (d['summary'] as Map?) ?? {};
      _totalMembers = (sum['totalMembers'] ?? 0) as int;
      _totalCalls = (sum['totalCalls'] ?? 0) as int;
      _avgScore = double.tryParse((sum['avgScore'] ?? 0).toString()) ?? 0;
      _totalMinutes =
          double.tryParse((sum['totalMinutes'] ?? 0).toString()) ?? 0;
    } catch (_) {
      _hierarchy = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _load();
    }
  }

  // Flatten hierarchy tree for ListView
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

  // Collect all node IDs that have children (for expand/collapse all)
  List<String> _allParentIds() {
    final result = <String>[];
    void collect(dynamic node) {
      final children = (node['children'] as List?) ?? [];
      if (children.isNotEmpty) {
        result.add((node['userId'] as String?) ?? '');
        for (final c in children) {
          collect(c);
        }
      }
    }
    for (final r in _hierarchy) {
      collect(r);
    }
    return result;
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

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

  Color _scoreColor(num score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
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
      case 'RECEPTIONIST':
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
      case 'RECEPTIONIST':
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
    return Column(
      children: [
        // Filters row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // Date range picker
              Expanded(
                child: GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_fmtDate(_fromDate)} — ${_fmtDate(_toDate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_branches.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        hint: const Text(
                          'All Branches',
                          style: TextStyle(fontSize: 11),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Branches',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          ..._branches.map(
                            (b) => DropdownMenuItem<String>(
                              value: b['id'] as String?,
                              child: Text(
                                '${b['name']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedBranchId = v);
                          _load();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Summary stats
        if (!_loading && _hierarchy.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _summaryCard(
                  'Members',
                  '$_totalMembers',
                  AppColors.primary,
                ),
                const SizedBox(width: 8),
                _summaryCard(
                  'Total Calls',
                  '$_totalCalls',
                  AppColors.success,
                ),
                const SizedBox(width: 8),
                _summaryCard(
                  'Avg Score',
                  '${_avgScore.toStringAsFixed(0)}%',
                  AppColors.accent,
                ),
                const SizedBox(width: 8),
                _summaryCard(
                  'Minutes',
                  _totalMinutes.toStringAsFixed(0),
                  const Color(0xFF0EA5E9),
                ),
              ],
            ),
          ),
        // Expand/Collapse controls
        if (!_loading && _allParentIds().isNotEmpty) _expandControls(),
        // Members count + refresh
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text(
                '$_totalMembers members',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        // Hierarchy list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _hierarchy.isEmpty
              ? const Center(
                  child: Text(
                    'No team data',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _hierarchyListView(),
                ),
        ),
      ],
    );
  }

  Widget _expandControls() {
    final parentIds = _allParentIds();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedIds.addAll(parentIds)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.unfold_more_rounded,
                      size: 13, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text(
                    'Expand All',
                    style: TextStyle(
                      fontSize: 10,
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
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.unfold_less_rounded,
                      size: 13, color: AppColors.textSecondary),
                  SizedBox(width: 3),
                  Text(
                    'Collapse All',
                    style: TextStyle(
                      fontSize: 10,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (node, depth) = items[i];
        return _memberTile(node, depth, i);
      },
    );
  }

  Widget _memberTile(Map<String, dynamic> m, int depth, int index) {
    // The backend returns `name` as full name and `metrics` as nested object
    final name = (m['name'] as String?) ??
        '${m['firstName'] ?? m['user']?['firstName'] ?? ''} '
            '${m['lastName'] ?? m['user']?['lastName'] ?? ''}'.trim();
    final email =
        (m['email'] as String?) ?? m['user']?['email'] as String? ?? '';
    final branchRole = (m['branchRole'] as String?) ?? '';
    final userId = (m['userId'] as String?) ?? '';
    final children = (m['children'] as List?) ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(userId);

    // Metrics are nested under `metrics` object
    final metrics = (m['metrics'] as Map?) ?? {};
    final totalCalls = (metrics['totalCalls'] ?? 0) as int;
    final avgScore =
        double.tryParse((metrics['avgScore'] ?? 0).toString()) ?? 0.0;
    final totalMinutes =
        double.tryParse((metrics['totalMinutes'] ?? 0).toString()) ?? 0.0;
    final excellentCalls = (metrics['excellentCalls'] ?? 0) as int;
    final goodCalls = (metrics['goodCalls'] ?? 0) as int;
    final poorCalls = (metrics['poorCalls'] ?? 0) as int;
    final lastCallDate = metrics['lastCallDate'];

    final roleColor = _roleColor(branchRole);
    final roleName = _roleName(branchRole);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final scoreColor =
        avgScore > 0 ? _scoreColor(avgScore) : AppColors.textHint;

    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              depth > 0 ? Border.all(color: AppColors.surfaceLight) : null,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name row
            Row(
              children: [
                // Expand/collapse toggle
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
                        name.isNotEmpty ? name : email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (name.isNotEmpty && email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (branchRole.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
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
                    ],
                  ),
                ),
                // Calls + score
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
                  scoreColor,
                ),
                _metricBox(
                  totalMinutes.toStringAsFixed(1),
                  'Min',
                  const Color(0xFF0EA5E9),
                ),
                _metricBox(
                  '$excellentCalls',
                  'Excellent',
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
                  'Last Call',
                  AppColors.textSecondary,
                ),
              ],
            ),
          ],
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

  Widget _summaryCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
