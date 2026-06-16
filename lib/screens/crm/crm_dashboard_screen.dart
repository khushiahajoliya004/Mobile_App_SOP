import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmDashboardSubScreen extends StatefulWidget {
  const CrmDashboardSubScreen({super.key});
  @override
  State<CrmDashboardSubScreen> createState() => _CrmDashboardSubScreenState();
}

class _CrmDashboardSubScreenState extends State<CrmDashboardSubScreen> {
  final _api = ApiService();
  bool _loading = true;

  Map<String, dynamic> _dash = {};
  List<Map<String, dynamic>> _userWise = [];
  List<Map<String, dynamic>> _stageWise = [];
  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> _recentDeals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await Future.wait([_loadDash(), _loadFollowUps(), _loadRecentDeals()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDash() async {
    try {
      final res = await _api.getCrmDashboard();
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      if (data is Map) {
        _dash = Map<String, dynamic>.from(data);
        final uw = data['userWiseStats'];
        _userWise = uw is List ? uw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
        final sw = data['stageWiseStats'];
        _stageWise = sw is List ? sw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      }
    } catch (_) {}
  }

  Future<void> _loadFollowUps() async {
    try {
      final res = await _api.getCrmFollowUps();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      _followUps = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  Future<void> _loadRecentDeals() async {
    try {
      final res = await _api.getCrmDeals();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      _recentDeals = list.map((e) => Map<String, dynamic>.from(e as Map)).take(8).toList();
    } catch (_) {}
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmtCurrency(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '') ?? 0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]}';
    } catch (_) { return ''; }
  }

  bool _isOverdue(Map f) {
    if (f['status'] != 'PENDING') return false;
    final dt = DateTime.tryParse(f['scheduledAt']?.toString() ?? '');
    return dt != null && dt.isBefore(DateTime.now());
  }

  bool _isToday(Map f) {
    if (f['status'] != 'PENDING') return false;
    final dt = DateTime.tryParse(f['scheduledAt']?.toString() ?? '');
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isThisWeek(Map f) {
    if (f['status'] != 'PENDING') return false;
    final dt = DateTime.tryParse(f['scheduledAt']?.toString() ?? '');
    if (dt == null) return false;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return !dt.isBefore(DateTime(start.year, start.month, start.day)) &&
        !dt.isAfter(DateTime(end.year, end.month, end.day, 23, 59));
  }

  String _followUpCustomer(Map f) {
    final c = f['contact'];
    if (c is Map && c['name'] != null) return c['name'].toString();
    final d = f['deal'];
    if (d is Map && d['name'] != null) return d['name'].toString();
    return f['subject']?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final now = DateTime.now();
    const dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${dayNames[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]} ${now.year}';

    final pending = _followUps.where((f) => f['status'] == 'PENDING').toList();
    final overdueCount = pending.where(_isOverdue).length;
    final todayCount = pending.where(_isToday).length;
    final weekCount = pending.where(_isThisWeek).length;

    final stageTotal = _stageWise.fold<int>(0, (s, e) => s + ((e['count'] as num?)?.toInt() ?? 0));

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(dateStr,
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── KPI Grid ────────────────────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _kpiCard('Leads Today', '${_dash['leadsToday'] ?? 0}',
                        Icons.today_rounded, AppColors.primary),
                    _kpiCard('Open Leads', '${_dash['openDeals'] ?? 0}',
                        Icons.folder_open_rounded, AppColors.accent),
                    _kpiCard('Pipeline Value', _fmtCurrency(_dash['pipelineValue']),
                        Icons.monetization_on_rounded, AppColors.warning),
                    _kpiCard('Total Leads', '${_dash['totalContacts'] ?? 0}',
                        Icons.people_rounded, AppColors.primary),
                    _kpiCard('Won This Month', '${_dash['wonThisMonth'] ?? 0}',
                        Icons.check_circle_rounded, AppColors.success,
                        highlight: AppColors.success),
                    _kpiCard('Lost This Month', '${_dash['lostThisMonth'] ?? 0}',
                        Icons.cancel_rounded, AppColors.error,
                        highlight: AppColors.error),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Today's Follow-ups ───────────────────────────────────────
                _sectionHeader('Today\'s Follow-ups & Calls', Icons.phone_callback_rounded),
                const SizedBox(height: 4),

                // Summary chips
                Row(
                  children: [
                    _summaryChip('$overdueCount Overdue', AppColors.error),
                    const SizedBox(width: 8),
                    _summaryChip('$todayCount Today', AppColors.primary),
                    const SizedBox(width: 8),
                    _summaryChip('$weekCount This Week', AppColors.textHint),
                  ],
                ),
                const SizedBox(height: 12),

                if (pending.isEmpty)
                  _emptyCard('No pending follow-ups', Icons.check_circle_outline_rounded)
                else
                  ...pending.map((f) => _followUpCard(f)),

                const SizedBox(height: 24),

                // ── Stage-wise Pipeline ──────────────────────────────────────
                _sectionHeader('Stage-wise Pipeline', Icons.stacked_bar_chart_rounded),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecor(),
                  child: _stageWise.isEmpty
                      ? _emptyState('No pipeline data')
                      : Column(
                          children: _stageWise.map((s) {
                            final count = (s['count'] as num?)?.toInt() ?? 0;
                            final pct = stageTotal > 0 ? count / stageTotal : 0.0;
                            return _stageBar(s['stageName']?.toString() ?? 'Stage', count, pct);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 24),

                // ── Team Performance ─────────────────────────────────────────
                _sectionHeader('Team Performance', Icons.leaderboard_rounded),
                const SizedBox(height: 12),

                if (_userWise.isEmpty)
                  _emptyCard('No team data', Icons.group_outlined)
                else
                  ..._userWise.map(_teamCard),

                const SizedBox(height: 24),

                // ── Recent Leads ─────────────────────────────────────────────
                _sectionHeader('Recent Leads', Icons.person_add_rounded),
                const SizedBox(height: 12),

                if (_recentDeals.isEmpty)
                  _emptyCard('No recent leads', Icons.inbox_outlined)
                else
                  ..._recentDeals.map(_recentLeadCard),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI Card ─────────────────────────────────────────────────────────────
  Widget _kpiCard(String label, String value, IconData icon, Color color, {Color? highlight}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight != null
            ? Border.all(color: highlight.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: highlight ?? AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Follow-up Card ────────────────────────────────────────────────────────
  Widget _followUpCard(Map<String, dynamic> f) {
    final overdue = _isOverdue(f);
    final today = _isToday(f);
    final name = _followUpCustomer(f);
    final type = f['type']?.toString() ?? 'CALL';
    final dateStr = _fmtDate(f['scheduledAt']?.toString());

    Color borderColor = AppColors.surfaceLight;
    Color bgColor = Colors.white;
    if (overdue) { borderColor = AppColors.error.withValues(alpha: 0.3); bgColor = AppColors.error.withValues(alpha: 0.03); }
    else if (today) { borderColor = AppColors.warning.withValues(alpha: 0.3); bgColor = AppColors.warning.withValues(alpha: 0.03); }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: overdue
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'MEETING'
                  ? Icons.people_rounded
                  : type == 'EMAIL'
                      ? Icons.email_rounded
                      : Icons.phone_rounded,
              color: overdue ? AppColors.error : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(type,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 6),
                    if (overdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Overdue',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.error)),
                      ),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _completeFollowUp(f['id']?.toString() ?? ''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeFollowUp(String id) async {
    try {
      await _api.completeCrmFollowUp(id, outcome: 'COMPLETED');
      await _loadFollowUps();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ── Stage Bar ─────────────────────────────────────────────────────────────
  Widget _stageBar(String name, int count, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('$count ${count == 1 ? 'lead' : 'leads'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Team Card ─────────────────────────────────────────────────────────────
  Widget _teamCard(Map<String, dynamic> u) {
    final name = u['name']?.toString() ?? 'Unknown';
    final total = (u['total'] as num?)?.toInt() ?? 0;
    final open = (u['open'] as num?)?.toInt() ?? 0;
    final won = (u['won'] as num?)?.toInt() ?? 0;
    final lost = (u['lost'] as num?)?.toInt() ?? 0;
    final winRate = total > 0 ? (won / total * 100).round() : 0;
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecor(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('$total total  •  $open open  •  $won won  •  $lost lost',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: winRate > 0
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$winRate%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: winRate > 0 ? AppColors.success : AppColors.textHint)),
          ),
        ],
      ),
    );
  }

  // ── Recent Lead Card ──────────────────────────────────────────────────────
  Widget _recentLeadCard(Map<String, dynamic> deal) {
    final contact = deal['contact'] is Map ? deal['contact'] as Map : null;
    final name = deal['name']?.toString() ?? contact?['name']?.toString() ?? 'Unknown';
    final phone = contact?['phone']?.toString() ?? '–';
    final stageName = _stageWise.firstWhere(
          (s) => s['stageId'] == deal['stageId'],
          orElse: () => {'stageName': 'New'},
        )['stageName']?.toString() ?? 'New';
    final ownerName = _userWise.firstWhere(
          (u) => u['userId'] == deal['ownerUserId'],
          orElse: () => {'name': '–'},
        )['name']?.toString() ?? '–';
    final date = _fmtDate(deal['createdAt']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecor(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(phone, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Icon(Icons.person_outline_rounded, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(ownerName,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(stageName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 17),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _emptyCard(String msg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: _cardDecor(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(msg, style: const TextStyle(fontSize: 13, color: AppColors.textHint))),
      );

  BoxDecoration _cardDecor() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      );
}
