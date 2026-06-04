import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class CallReportScreen extends StatefulWidget {
  const CallReportScreen({super.key});
  @override
  State<CallReportScreen> createState() => _CallReportScreenState();
}

class _CallReportScreenState extends State<CallReportScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _dailyReport = [];
  List<Map<String, dynamic>> _companies = [];
  String? _selectedCompanyId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  int get _totalCalls => _dailyReport.fold(0, (s, d) => s + ((d['callCount'] as num?)?.toInt() ?? 0));
  double get _totalMinutes => _dailyReport.fold(0.0, (s, d) => s + ((d['totalMinutes'] as num?)?.toDouble() ?? 0.0));
  double get _avgMinutes => _totalCalls > 0 ? _totalMinutes / _totalCalls : 0.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUser = await _auth.getUser();
    if (_currentUser?.isSuperAdmin == true) {
      try {
        final res = await _api.getCompanies();
        _companies = _parseList(res.data);
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCallReportDaily(
        fromDate: _fromDate.toIso8601String().split('T').first,
        toDate: _toDate.toIso8601String().split('T').first,
        companyId: _selectedCompanyId,
      );
      _dailyReport = _parseList(res.data);
    } catch (_) { _dailyReport = []; }
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
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) {
      setState(() { _fromDate = picked.start; _toDate = picked.end; });
      _load();
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filters
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          // Date range
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('${_fmtDate(_fromDate)} — ${_fmtDate(_toDate)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: AppColors.textHint),
              ]),
            ),
          ),
          if (_currentUser?.isSuperAdmin == true && _companies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCompanyId,
                  isExpanded: true,
                  hint: const Text('All Companies', style: TextStyle(fontSize: 14)),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Companies', style: TextStyle(fontSize: 14))),
                    ..._companies.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text('${c['name']}', style: const TextStyle(fontSize: 14)))),
                  ],
                  onChanged: (v) { setState(() => _selectedCompanyId = v); _load(); },
                ),
              ),
            ),
          ],
        ]),
      ),
      // Summary cards
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(child: _summaryCard('Total Calls', '$_totalCalls', Icons.call_rounded, AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('Total Min', _totalMinutes.toStringAsFixed(0), Icons.timer_rounded, AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('Avg Min', _avgMinutes.toStringAsFixed(1), Icons.analytics_rounded, AppColors.accent)),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text('${_dailyReport.length} days', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _dailyReport.isEmpty
            ? const Center(child: Text('No data for selected range', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _dailyReport.length,
                  itemBuilder: (_, i) => _dayTile(_dailyReport[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _dayTile(Map<String, dynamic> day) {
    final callCount = (day['callCount'] as num?)?.toInt() ?? 0;
    final totalMin = (day['totalMinutes'] as num?)?.toDouble() ?? 0.0;
    final avgMin = (day['avgMinutes'] as num?)?.toDouble() ?? 0.0;
    final date = '${day['date'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('$callCount calls • ${totalMin.toStringAsFixed(0)} min total • ${avgMin.toStringAsFixed(1)} avg', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$callCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
      ]),
    );
  }
}
