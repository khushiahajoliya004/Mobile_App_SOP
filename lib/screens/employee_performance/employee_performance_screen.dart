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
  List<Map<String, dynamic>> _employees = [];
  String _search = '';
  String _period = '30d';
  Map<String, dynamic>? _detail;
  String? _detailName;

  static const _periods = {'7d': '7 Days', '30d': '30 Days', '90d': '90 Days', '365d': '1 Year'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _fromDate {
    final days = int.tryParse(_period.replaceAll('d', '')) ?? 30;
    return DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T').first;
  }

  String get _toDate => DateTime.now().toIso8601String().split('T').first;

  Future<void> _load() async {
    setState(() { _loading = true; _detail = null; });
    try {
      final res = await _api.getEmployeePerformance(fromDate: _fromDate, toDate: _toDate, search: _search.isNotEmpty ? _search : null);
      final raw = res.data;
      if (raw is Map && raw['data'] is List) {
        _employees = (raw['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _employees = _parseList(raw);
      }
    } catch (_) { _employees = []; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDetail(String userId, String name) async {
    setState(() { _loading = true; _detailName = name; });
    try {
      final res = await _api.getEmployeePerformanceDetail(userId, fromDate: _fromDate, toDate: _toDate);
      _detail = res.data is Map ? Map<String, dynamic>.from(res.data['data'] ?? res.data) : null;
    } catch (_) { _detail = null; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) return _detailView();
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
                    child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(children: [
          Text('${_employees.length} employees', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
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
                  itemCount: _employees.length,
                  itemBuilder: (_, i) => _empTile(_employees[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _empTile(Map<String, dynamic> emp) {
    final firstName = emp['firstName'] ?? emp['user']?['firstName'] ?? '';
    final lastName = emp['lastName'] ?? emp['user']?['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = emp['email'] ?? emp['user']?['email'] ?? '';
    final totalCalls = (emp['totalCalls'] as num?)?.toInt() ?? 0;
    final avgScore = (emp['averageScore'] as num?)?.toDouble() ?? 0.0;
    final successRate = (emp['successRate'] as num?)?.toDouble() ?? 0.0;
    final userId = emp['userId'] ?? emp['user']?['id'] ?? emp['id'];
    final scoreColor = avgScore >= 80 ? AppColors.success : avgScore >= 50 ? AppColors.warning : AppColors.error;
    return GestureDetector(
      onTap: () => _loadDetail(userId, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySurface,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              _badge('$totalCalls calls', AppColors.primary),
              const SizedBox(width: 6),
              _badge('${successRate.toStringAsFixed(0)}% success', AppColors.accent),
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

  Widget _detailView() {
    final d = _detail!;
    final strengths = (d['topStrengths'] as List?)?.cast<String>() ?? [];
    final weaknesses = (d['commonWeaknesses'] as List?)?.cast<String>() ?? [];
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          GestureDetector(onTap: () => setState(() { _detail = null; _detailName = null; }), child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary)),
          const SizedBox(width: 12),
          Expanded(child: Text(_detailName ?? 'Employee Detail', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Summary
                  Row(children: [
                    Expanded(child: _metricCard('Total Calls', '${d['totalCalls'] ?? 0}', AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard('Avg Score', '${(d['averageScore'] as num?)?.toStringAsFixed(1) ?? '0'}', AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _metricCard('Success', '${(d['successRate'] as num?)?.toStringAsFixed(0) ?? '0'}%', AppColors.accent)),
                  ]),
                  if (strengths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Top Strengths', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...strengths.map((s) => _listItem(s, Icons.thumb_up_rounded, AppColors.success)),
                  ],
                  if (weaknesses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Improvement Areas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...weaknesses.map((w) => _listItem(w, Icons.trending_up_rounded, AppColors.warning)),
                  ],
                ]),
              ),
      ),
    ]);
  }

  Widget _metricCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
