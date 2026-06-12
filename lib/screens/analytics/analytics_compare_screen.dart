import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AnalyticsCompareScreen extends StatefulWidget {
  const AnalyticsCompareScreen({super.key});
  @override
  State<AnalyticsCompareScreen> createState() => _AnalyticsCompareScreenState();
}

class _AnalyticsCompareScreenState extends State<AnalyticsCompareScreen> {
  final _api = ApiService();
  bool _loadingUsers = true;
  bool _loadingData = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _selectedUserIds = [];
  String? _selectedCategoryId;
  String _period = '30d';
  Map<String, dynamic>? _data;
  String _searchUser = '';

  static const _periods = ['7d', '30d', '90d', '365d'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loadingUsers = true);
    try {
      final res = await _api.getUsers();
      final raw = res.data;
      _users = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _users = []; }
    try {
      final res = await _api.getCategories();
      final raw = res.data;
      _categories = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _categories = []; }
    if (mounted) setState(() => _loadingUsers = false);
  }

  Future<void> _compare() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one user')));
      return;
    }
    setState(() { _loadingData = true; _data = null; });
    try {
      final res = await _api.getAnalyticsUser360(
        userIds: _selectedUserIds,
        period: _period,
        categoryId: _selectedCategoryId,
      );
      final raw = res.data;
      // Store the full response so _buildResults can access raw['data'] (the array)
      _data = raw is Map ? Map<String, dynamic>.from(raw) : {'data': raw};
    } catch (_) { _data = null; }
    if (mounted) setState(() => _loadingData = false);
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchUser.isEmpty) return _users;
    return _users.where((u) {
      final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
      final email = '${u['email'] ?? ''}'.toLowerCase();
      return name.contains(_searchUser.toLowerCase()) || email.contains(_searchUser.toLowerCase());
    }).toList();
  }

  String _userName(Map<String, dynamic> u) => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

  Color _scoreColor(num score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.accent;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('360° User Compare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // Period chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _periods.map((p) {
                final sel = _period == p;
                return GestureDetector(
                  onTap: () => setState(() => _period = p),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)),
                    child: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Categories', style: TextStyle(fontSize: 12))),
                    ..._categories.map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text('${c['name']}', style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadingData ? null : _compare,
              icon: _loadingData ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text(_loadingData ? 'Loading...' : 'Compare (${_selectedUserIds.length} selected)'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ),
      Expanded(child: Row(children: [
        // User selector panel
        Container(
          width: 160,
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                onChanged: (v) => setState(() => _searchUser = v),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  filled: true, fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_selectedUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedUserIds.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: const Center(child: Text('Clear All', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
            Expanded(
              child: _loadingUsers
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (_, i) {
                        final u = _filteredUsers[i];
                        final id = u['id'].toString();
                        final name = _userName(u);
                        final selected = _selectedUserIds.contains(id);
                        return GestureDetector(
                          onTap: () => setState(() { if (selected) _selectedUserIds.remove(id); else _selectedUserIds.add(id); }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primarySurface : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
                            ),
                            child: Row(children: [
                              CircleAvatar(radius: 12, backgroundColor: selected ? AppColors.primary : AppColors.surfaceLight, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary))),
                              const SizedBox(width: 6),
                              Expanded(child: Text(name, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
        // Results panel
        Expanded(child: _buildResults()),
      ])),
    ]);
  }

  Widget _buildResults() {
    if (_loadingData) return const Material(color: Colors.white, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_data == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.compare_arrows_rounded, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('Select users and tap Compare', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ]),
      ));
    }

    // Backend returns: { data: [UserProfile] } where each UserProfile has:
    // userId, name, stats { totalCalls, analyzedCalls, avgScore, successRate, highPerformance, needsImprovement }
    // sopBreakdown [{ sopName, calls, avgScore, sections [{ title, weightage, answerRate }] }]
    // strengths [], weaknesses []
    final userProfiles = (_data!['data'] as List?)?.map((u) => Map<String, dynamic>.from(u)).toList()
        ?? (_data! is List ? (_data! as List).map((u) => Map<String, dynamic>.from(u)).toList() : []);

    if (userProfiles.isEmpty) {
      return const Center(child: Text('No data returned', style: TextStyle(color: AppColors.textHint)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Per-user summary cards
        ...userProfiles.map((u) {
          final name = '${u['name'] ?? ''}';
          final stats = u['stats'] is Map ? Map<String, dynamic>.from(u['stats'] as Map) : <String, dynamic>{};
          final totalCalls = (stats['totalCalls'] as num?)?.toInt() ?? 0;
          final avgScore = (stats['avgScore'] as num?)?.toDouble() ?? 0.0;
          final successRate = (stats['successRate'] as num?)?.toDouble() ?? 0.0;
          final scoreColor = _scoreColor(avgScore);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primarySurface, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('$totalCalls calls', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${avgScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scoreColor)),
                Text('${successRate.toStringAsFixed(0)}% success', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
            ]),
          );
        }),
        // Section breakdown heatmap (per user, per SOP section)
        ...userProfiles.map((u) {
          final name = '${u['name'] ?? ''}';
          final sopBreakdown = (u['sopBreakdown'] as List?)?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
          final strengths = (u['strengths'] as List?) ?? [];
          final weaknesses = (u['weaknesses'] as List?) ?? [];
          if (sopBreakdown.isEmpty && strengths.isEmpty && weaknesses.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 6),
            ...sopBreakdown.map((sop) {
              final sopName = sop['sopName'] ?? '';
              final sections = (sop['sections'] as List?)?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.surfaceLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$sopName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...sections.map((s) {
                    final title = s['title'] ?? '';
                    final answerRate = (s['answerRate'] as num?)?.toDouble() ?? 0.0;
                    final color = _scoreColor(answerRate);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(child: Text('$title', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        SizedBox(width: 80, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (answerRate / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: AppColors.surfaceLight, valueColor: AlwaysStoppedAnimation<Color>(color)))),
                        const SizedBox(width: 6),
                        Text('${answerRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ]),
                    );
                  }),
                ]),
              );
            }),
            if (strengths.isNotEmpty) ...[
              _strengthWeaknessRow('Strengths', strengths, AppColors.success),
            ],
            if (weaknesses.isNotEmpty) ...[
              _strengthWeaknessRow('Needs Work', weaknesses, AppColors.error),
            ],
          ]);
        }),
      ]),
    );
  }

  Widget _strengthWeaknessRow(String label, List items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(label == 'Strengths' ? Icons.thumb_up_rounded : Icons.trending_down_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: items.take(3).map((s) {
            final title = s is Map ? (s['title'] ?? s['sectionTitle'] ?? '$s') : '$s';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$title', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
      ]),
    );
  }
}
