import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../call_upload_screen.dart';
import '../ai_insights/ai_insights_screen.dart';
import '../crm/crm_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  UserModel? _user;
  late AnimationController _fadeCtrl;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _user = await _auth.getUser();
    try {
      final res = await _api.getCompanyDashboard(period: '30d');
      final raw = res.data;
      // Handle: raw, raw['data'], or raw['data']['stats'] nesting
      final dataMap = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : <String, dynamic>{};
      // If backend wraps stats under a 'stats' key, unwrap it; otherwise use dataMap directly
      final stats = dataMap['stats'] is Map
          ? Map<String, dynamic>.from(dataMap['stats'] as Map)
          : dataMap;
      _data = {
        ...stats,
        'activeSops': stats['activeSops'] ?? stats['totalSops'],
        'credits': stats['credits'] ?? stats['creditsRemaining'],
        'recentCalls': dataMap['recentCalls'] ?? stats['recentCalls'],
      };
    } catch (e) {
      _data = {};
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _loading = false);
      _fadeCtrl.forward();
      _ringCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBg,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() { _error = null; });
                        _loadAll();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : FadeTransition(
              opacity: CurvedAnimation(
                parent: _fadeCtrl,
                curve: Curves.easeOut,
              ),
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadAll,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildScoreSection()),
                    SliverToBoxAdapter(child: _buildStatsGrid()),
                    SliverToBoxAdapter(child: _buildQuickActions()),
                    SliverToBoxAdapter(child: _buildCrmSection()),
                    SliverToBoxAdapter(child: _buildRecentCalls()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══ HEADER ═══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final name = _user?.firstName ?? 'User';
    final greeting = _getGreeting();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _loadAll,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats row inside header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                _headerStat(
                  '${_data['totalCalls'] ?? 0}',
                  'My Calls',
                  Icons.phone_rounded,
                ),
                _headerDivider(),
                _headerStat(
                  '${_data['analyzedCalls'] ?? 0}',
                  'Analyzed',
                  Icons.auto_awesome_rounded,
                ),
                _headerDivider(),
                _headerStat(
                  '${_data['avgScore'] ?? 0}%',
                  'Score',
                  Icons.trending_up_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(
    width: 1,
    height: 36,
    color: Colors.white.withValues(alpha: 0.1),
  );

  // ═══ SCORE SECTION ════════════════════════════════════════════════════════
  Widget _buildScoreSection() {
    final avgScore = (_data['avgScore'] ?? 0).toDouble();
    final scoreColor = avgScore >= 70
        ? AppColors.success
        : avgScore >= 40
        ? AppColors.warning
        : AppColors.error;
    final scoreLabel = avgScore >= 70
        ? 'Excellent'
        : avgScore >= 40
        ? 'Good'
        : 'Needs Work';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, __) {
                final progress =
                    Curves.easeOutCubic.transform(_ringCtrl.value) *
                    avgScore /
                    100;
                return SizedBox(
                  width: 90,
                  height: 90,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(
                      progress: progress,
                      color: scoreColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).round()}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                          Text(
                            '%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scoreColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'My Performance',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          scoreLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _miniProgress(
                    'Analyzed',
                    (_data['analyzedCalls'] ?? 0) /
                        math.max(1, _data['totalCalls'] ?? 1),
                    AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  _miniProgress(
                    'High Score',
                    (_data['highPerformers'] ?? 0) /
                        math.max(1, _data['totalCalls'] ?? 1),
                    AppColors.success,
                  ),
                  const SizedBox(height: 6),
                  _miniProgress(
                    'Pending',
                    (_data['pendingCalls'] ?? 0) /
                        math.max(1, _data['totalCalls'] ?? 1),
                    AppColors.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniProgress(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(value * 100).clamp(0, 100).round()}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═══ STATS GRID ═══════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Pending',
              '${_data['pendingCalls'] ?? 0}',
              Icons.hourglass_top_rounded,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              'Avg Duration',
              '${_data['avgDuration'] ?? '0:00'}',
              Icons.timer_rounded,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              'Credits',
              '${_data['creditsRemaining'] ?? 0}',
              Icons.toll_rounded,
              AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══ QUICK ACTIONS (WORKABLE) ═════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  'Upload',
                  Icons.cloud_upload_rounded,
                  const Color(0xFF0EA5E9),
                  const Color(0xFF38BDF8),
                  () => _navigateTo(const CallUploadScreen(), 'Upload'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  'Insights',
                  Icons.auto_awesome_rounded,
                  const Color(0xFFF59E0B),
                  const Color(0xFFFBBF24),
                  () => _navigateTo(const AiInsightsScreen(), 'AI Insights'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  'CRM',
                  Icons.groups_rounded,
                  const Color(0xFF10B981),
                  const Color(0xFF34D399),
                  () => _navigateTo(const CrmScreen(), 'CRM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ModuleWrapper(title: title, child: screen),
      ),
    );
  }

  Widget _actionTile(
    String label,
    IconData icon,
    Color c1,
    Color c2,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1, c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: c1.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ CRM SECTION ══════════════════════════════════════════════════════════
  Widget _buildCrmSection() {
    final crm = _data['crm'] as Map<String, dynamic>?;
    if (crm == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              const Text(
                'CRM OVERVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _navigateTo(const CrmScreen(), 'CRM'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _crmStat(
                        'Total Leads',
                        '${crm['totalLeads'] ?? 0}',
                        Icons.people_outline_rounded,
                        AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _crmStat(
                        'Open',
                        '${crm['openLeads'] ?? 0}',
                        Icons.folder_open_rounded,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    Expanded(
                      child: _crmStat(
                        'Converted',
                        '${crm['convertedLeads'] ?? 0}',
                        Icons.check_circle_outline,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _crmStat(
                        'Today F/U',
                        '${crm['todayFollowUps'] ?? 0}',
                        Icons.event_rounded,
                        AppColors.warning,
                      ),
                    ),
                    Expanded(
                      child: _crmStat(
                        'Overdue',
                        '${crm['overdueFollowUps'] ?? 0}',
                        Icons.warning_amber_rounded,
                        AppColors.error,
                      ),
                    ),
                    Expanded(
                      child: _crmStat(
                        'Conv. %',
                        '${crm['conversionRate'] ?? 0}%',
                        Icons.trending_up_rounded,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _crmStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ═══ RECENT CALLS (TAPPABLE WITH QUICK SUMMARY) ═══════════════════════════
  Widget _buildRecentCalls() {
    final recentCalls = (_data['recentCalls'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              const Text(
                'MY RECENT CALLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (recentCalls.isNotEmpty)
                Text(
                  '${recentCalls.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentCalls.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_missed_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No calls yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload a recording to see activity',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentCalls.take(10).map((c) {
              final call = Map<String, dynamic>.from(c);
              return _recentCallTile(call);
            }),
        ],
      ),
    );
  }

  Widget _recentCallTile(Map<String, dynamic> call) {
    final score = call['sopScore'];
    final status = call['analysisStatus'] ?? '';
    final name = call['customerName'] ?? 'Unknown';
    final duration = call['duration'] ?? '0:00';
    final category = call['category']?['name'] ?? '';
    final scoreColor = score != null
        ? (score >= 70
              ? AppColors.success
              : score >= 40
              ? AppColors.warning
              : AppColors.error)
        : AppColors.textHint;

    return GestureDetector(
      onTap: () => _showCallDetail(call),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: score != null
                    ? scoreColor.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: score != null
                    ? Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (category.isNotEmpty) ...[
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ],
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status + arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(status),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.textHint,
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
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ═══ CALL DETAIL BOTTOM SHEET (Quick Summary + Score) ═════════════════════
  void _showCallDetail(Map<String, dynamic> call) {
    final callId = call['id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallDetailSheet(callId: callId),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }
}

// ═══ CALL DETAIL BOTTOM SHEET ════════════════════════════════════════════════
class _CallDetailSheet extends StatefulWidget {
  final String callId;
  const _CallDetailSheet({required this.callId});
  @override
  State<_CallDetailSheet> createState() => _CallDetailSheetState();
}

class _CallDetailSheetState extends State<_CallDetailSheet> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _detail = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getAiInsightDetail(widget.callId);
      final raw = res.data;
      _detail = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : {};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSheetHeader(),
                    const SizedBox(height: 16),
                    _buildSectionScores(),
                    const SizedBox(height: 16),
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _buildKeyPoints(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSheetHeader() {
    final score = _detail['sopScore'] != null ? num.tryParse(_detail['sopScore'].toString()) : null;
    final name = _detail['customerName'] ?? 'Unknown';
    final status = _detail['analysisStatus'] ?? '';
    final category = _detail['category']?['name'] ?? '';
    final duration = _detail['durationSeconds'] != null
        ? '${(_detail['durationSeconds'] / 60).floor()}:${((_detail['durationSeconds'] as int) % 60).toString().padLeft(2, '0')}'
        : '';

    final scoreColor = score != null
        ? (score >= 70
              ? AppColors.success
              : score >= 40
              ? AppColors.warning
              : AppColors.error)
        : AppColors.textHint;

    return Row(
      children: [
        // Score circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: score != null
                ? scoreColor.withValues(alpha: 0.1)
                : AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: score != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score!.round()}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 10,
                          color: scoreColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  )
                : Icon(
                    status == 'PROCESSING'
                        ? Icons.hourglass_top
                        : Icons.schedule,
                    size: 24,
                    color: AppColors.textHint,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (duration.isNotEmpty)
                    Text(
                      '⏱ $duration',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionScores() {
    final sections = (_detail['sectionScores'] ?? []) as List;
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Section Scores',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...sections.map((s) {
          final sec = Map<String, dynamic>.from(s);
          final secScore = (sec['score'] ?? 0) as num;
          final secName = sec['title'] ?? sec['sectionName'] ?? '';
          final color = secScore >= 70
              ? AppColors.success
              : secScore >= 40
              ? AppColors.warning
              : AppColors.error;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: secScore / 100,
                          minHeight: 6,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${secScore.toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummary() {
    final ai = _detail['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final summary = ai['summary'] ?? ai['callSummary'] ?? '';
    if (summary.toString().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.summarize_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Quick Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
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
      ],
    );
  }

  Widget _buildKeyPoints() {
    final ai = _detail['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final keyPoints =
        (ai['keyDiscussionPoints'] ?? ai['keyPoints'] ?? []) as List;
    if (keyPoints.isEmpty) return const SizedBox.shrink();

    // Handle both list of strings and map format
    List<String> points = [];
    if (keyPoints.isNotEmpty && keyPoints.first is String) {
      points = keyPoints.map((e) => e.toString()).toList();
    } else if (keyPoints.isNotEmpty && keyPoints.first is Map) {
      // keyDiscussionPoints might be a map with sub-fields
      final kdp = ai['keyDiscussionPoints'];
      if (kdp is Map) {
        kdp.forEach((key, value) {
          if (value is List) {
            points.addAll(value.map((e) => e.toString()));
          } else if (value is String &&
              value.isNotEmpty &&
              value != 'N/A' &&
              value != 'Not Discussed') {
            points.add('$key: $value');
          }
        });
      }
    }

    if (points.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.list_alt_rounded,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            const Text(
              'Key Points',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...points
            .take(5)
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ═══ MODULE WRAPPER (for navigation from dashboard) ═════════════════════════
class _ModuleWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _ModuleWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 4,
              right: 16,
              bottom: 14,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  AppColors.primary,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ═══ CUSTOM SCORE RING PAINTER ══════════════════════════════════════════════
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
