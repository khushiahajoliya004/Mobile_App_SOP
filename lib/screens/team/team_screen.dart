import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _teamMembers = [];
  Map<String, dynamic>? _selectedMember;
  List<Map<String, dynamic>> _memberCalls = [];
  bool _callsLoading = false;
  Map<String, dynamic>? _selectedCall;
  bool _detailLoading = false;

  // Stats
  int _totalMembers = 0;
  int _totalCalls = 0;
  int _analyzedCalls = 0;
  int _avgScore = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUser = await _auth.getUser();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _loading = true);
    try {
      final userId = _currentUser?.id ?? '';
      final res = await _api.getTeamUnderSenior(userId);
      final raw = res.data;
      if (raw is Map && raw['data'] != null) {
        _teamMembers = (raw['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      _totalMembers = _teamMembers.length;
    } catch (_) {
      _teamMembers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMemberCalls(Map<String, dynamic> member) async {
    setState(() {
      _selectedMember = member;
      _callsLoading = true;
      _selectedCall = null;
      _memberCalls = [];
    });
    try {
      final res = await _api.getTeamMemberCalls(
        member['id'],
        page: 1,
        limit: 50,
      );
      final raw = res.data;
      if (raw is Map && raw['data'] != null) {
        _memberCalls = (raw['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      _computeStats();
    } catch (_) {
      _memberCalls = [];
    }
    if (mounted) setState(() => _callsLoading = false);
  }

  void _computeStats() {
    _totalCalls = _memberCalls.length;
    _analyzedCalls = _memberCalls
        .where((c) => c['analysisStatus'] == 'COMPLETED')
        .length;
    final scored = _memberCalls.where((c) => c['sopScore'] != null).toList();
    _avgScore = scored.isNotEmpty
        ? (scored
                      .map((c) => (c['sopScore'] as num).toDouble())
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

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse('$date').toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
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

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selectedCall != null) return _callDetailView();
    if (_selectedMember != null) return _memberCallsView();
    return _teamListView();
  }

  // ─── Team Members List ─────────────────────────────────────────────────

  Widget _teamListView() {
    return Column(
      children: [
        // Header stats
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
                      'My Team',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$_totalMembers members',
                      style: TextStyle(
                        fontSize: 12,
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
        // Team list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _teamMembers.isEmpty
              ? _emptyState('No team members found', Icons.group_off_rounded)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadTeam,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _teamMembers.length,
                    itemBuilder: (_, i) => _memberTile(_teamMembers[i], i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _memberTile(Map<String, dynamic> member, int index) {
    final name = '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'
        .trim();
    final email = member['email'] ?? '';
    final phone = member['phone'] ?? '';
    final status = member['status'] ?? 'ACTIVE';

    return GestureDetector(
      onTap: () => _loadMemberCalls(member),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _avatarColor(index),
                    _avatarColor(index).withValues(alpha: 0.7),
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
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Status + Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'ACTIVE'
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: status == 'ACTIVE'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
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

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF0EA5E9),
      Color(0xFF8B5CF6),
      Color(0xFFF97316),
      Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  // ─── Member Calls View ─────────────────────────────────────────────────

  Widget _memberCallsView() {
    final member = _selectedMember!;
    final name = '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}'
        .trim();

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
                '$_totalCalls',
                'Calls',
                AppColors.primary,
              ),
              _statChip(
                Icons.check_circle_rounded,
                '$_analyzedCalls',
                'Analyzed',
                AppColors.success,
              ),
              _statChip(
                Icons.bar_chart_rounded,
                '$_avgScore%',
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

  Widget _statChip(IconData icon, String value, String label, Color color) {
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
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
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
    final date = _formatDate(call['createdAt']);

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
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ─── Call Detail View (AI Insight) ─────────────────────────────────────

  Widget _callDetailView() {
    final c = _selectedCall!;
    final score = c['sopScore'];
    final status = c['analysisStatus'] ?? '';
    final name =
        c['aiAnalysis']?['customerName'] ?? c['customerName'] ?? 'Unknown';
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
        // Status banner
        if (status == 'PROCESSING')
          _banner(
            Icons.hourglass_top,
            'Analysis in progress...',
            AppColors.primary,
          ),
        if (status == 'PENDING')
          _banner(Icons.schedule, 'Waiting to be analyzed', AppColors.warning),
        if (status == 'FAILED')
          _banner(Icons.error_outline, 'Analysis failed', AppColors.error),
        // Content
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
    final sections = (c['sectionScores'] ?? ai['sectionScores'] ?? []) as List;
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
        // Summary
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
        // Key Discussion Points
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
        // SOP Section Scores
        if (sections.isNotEmpty) ...[
          _sectionHeader(
            Icons.pie_chart_outline,
            'SOP Analysis',
            AppColors.primary,
          ),
          ...sections.map((s) {
            final sec = Map<String, dynamic>.from(s);
            final secScore = (sec['score'] ?? 0) as num;
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
        // Mistakes / What Went Wrong
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
        // Suggestion
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
        // Next Action
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
        // Conversion Probability
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
            style: const TextStyle(fontSize: 14, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
