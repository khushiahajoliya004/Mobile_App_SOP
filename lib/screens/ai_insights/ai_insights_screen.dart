import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});
  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _calls = [];
  Map<String, dynamic>? _selected;
  bool _detailLoading = false;
  String _activeTab = 'analysis'; // analysis, transcription, summary
  String _search = '';
  String _statusFilter = '';
  int _page = 1;
  int _total = 0;
  int _totalPages = 0;

  // Stats
  int _totalCalls = 0;
  int _completedCount = 0;
  int _avgScore = 0;
  int _successRate = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'page': _page, 'limit': 20};
      if (_search.isNotEmpty) params['search'] = _search;
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      final res = await _api.getAiInsights(page: _page, limit: 20);
      final raw = res.data;
      if (raw is Map) {
        _calls = ((raw['data'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _total = raw['pagination']?['total'] ?? _calls.length;
        _totalPages = raw['pagination']?['totalPages'] ?? 1;
      }
      _computeStats();
    } catch (_) {
      _calls = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _computeStats() {
    _totalCalls = _total;
    _completedCount = _calls
        .where((c) => c['analysisStatus'] == 'COMPLETED')
        .length;
    final scored = _calls.where((c) => c['sopScore'] != null).toList();
    _avgScore = scored.isNotEmpty
        ? (scored
                      .map((c) => (c['sopScore'] as num).toDouble())
                      .reduce((a, b) => a + b) /
                  scored.length)
              .round()
        : 0;
    _successRate = scored.isNotEmpty
        ? ((scored.where((c) => (c['sopScore'] as num) >= 70).length /
                      scored.length) *
                  100)
              .round()
        : 0;
  }

  Future<void> _selectCall(Map<String, dynamic> call) async {
    setState(() {
      _selected = call;
      _activeTab = 'analysis';
      _detailLoading = true;
    });
    try {
      final res = await _api.getAiInsightDetail(call['id']);
      final raw = res.data;
      final detail = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : <String, dynamic>{};
      setState(() {
        _selected = {...call, ...detail};
        _detailLoading = false;
      });
    } catch (_) {
      setState(() => _detailLoading = false);
    }
  }

  Future<void> _reanalyze(String callId) async {
    try {
      await _api.genericPost('/ai-insights/analyze/$callId', {});
      _msg('Analysis triggered');
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  String _scoreLabel(num score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Poor';
  }

  Color _scoreColor(num score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
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
      return '${d.day} ${m[d.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _detailScreen();

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _miniStat(
                Icons.phone,
                '$_totalCalls',
                'calls',
                AppColors.textSecondary,
              ),
              _miniStat(
                Icons.check_circle,
                '$_completedCount',
                'analyzed',
                AppColors.success,
              ),
              _miniStat(
                Icons.bar_chart,
                '$_avgScore%',
                'avg',
                AppColors.primary,
              ),
              _miniStat(
                Icons.star,
                '$_successRate%',
                'success',
                AppColors.warning,
              ),
            ],
          ),
        ),
        // Search + Status filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _page = 1;
                    _load();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Status chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _statusChip('All', ''),
              _statusChip('Completed', 'COMPLETED'),
              _statusChip('Processing', 'PROCESSING'),
              _statusChip('Pending', 'PENDING'),
              _statusChip('Failed', 'FAILED'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Call list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _calls.isEmpty
              ? const Center(
                  child: Text(
                    'No calls found',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _calls.length,
                    itemBuilder: (_, i) => _callTile(_calls[i]),
                  ),
                ),
        ),
        // Pagination
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _load();
                        }
                      : null,
                ),
                Text(
                  '$_page / $_totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _page < _totalPages
                      ? () {
                          _page++;
                          _load();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      );

  Widget _statusChip(String label, String value) {
    final active = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _page = 1;
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
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
    final user = call['user'];
    final userName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : '';
    final category = call['category']?['name'] ?? '';

    return GestureDetector(
      onTap: () => _selectCall(call),
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
                  Row(
                    children: [
                      if (userName.isNotEmpty)
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (category.isNotEmpty)
                        Text(
                          ' · $category',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(status),
                const SizedBox(height: 4),
                Text(
                  _formatDate(call['createdAt']),
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
      case 'APPROVAL_PENDING':
        bg = AppColors.warning.withValues(alpha: 0.1);
        fg = AppColors.warning;
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
        status == 'APPROVAL_PENDING' ? 'PENDING' : status,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ─── Detail Screen ─────────────────────────────────────────────────────

  Widget _detailScreen() {
    final c = _selected!;
    final score = c['sopScore'];
    final status = c['analysisStatus'] ?? '';
    final name =
        c['aiAnalysis']?['customerName'] ?? c['customerName'] ?? 'Unknown';
    final company = c['aiAnalysis']?['customerCompany'];
    final category = c['category']?['name'] ?? '';
    final stage = c['salesStage']?['name'] ?? '';
    final user = c['user'];
    final userName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selected = null),
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
                    if (company != null)
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    Text(
                      '$category · $stage · $userName',
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

        // Status banners
        if (status == 'PROCESSING')
          _banner(
            Icons.hourglass_top,
            'Analysis in progress...',
            AppColors.primary,
          ),
        if (status == 'PENDING')
          _bannerWithAction(
            Icons.schedule,
            'Waiting to be analyzed',
            'Trigger',
            () => _reanalyze(c['id']),
            AppColors.warning,
          ),
        if (status == 'FAILED')
          _bannerWithAction(
            Icons.error_outline,
            'Analysis failed',
            'Retry',
            () => _reanalyze(c['id']),
            AppColors.error,
          ),
        if (status == 'APPROVAL_PENDING')
          _banner(Icons.schedule, 'Awaiting admin approval', AppColors.warning),
        if (status == 'REJECTED')
          _banner(Icons.block, 'This call was rejected', AppColors.error),

        // Tabs
        if (status == 'COMPLETED' && !_detailLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _tabBtn('SOP Analysis', Icons.pie_chart_outline, 'analysis'),
                const SizedBox(width: 8),
                _tabBtn('Transcript', Icons.subject, 'transcription'),
                const SizedBox(width: 8),
                _tabBtn('Summary', Icons.summarize_outlined, 'summary'),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Tab content
        if (_detailLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          Expanded(child: _tabContent()),
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

  Widget _bannerWithAction(
    IconData icon,
    String text,
    String action,
    VoidCallback onTap,
    Color color,
  ) => Container(
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tabBtn(String label, IconData icon, String tab) {
    final active = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabContent() {
    final c = _selected!;
    if (_activeTab == 'analysis') return _analysisTab(c);
    if (_activeTab == 'transcription') return _transcriptionTab(c);
    return _summaryTab(c);
  }

  // ─── SOP Analysis Tab ──────────────────────────────────────────────────

  Widget _analysisTab(Map<String, dynamic> c) {
    final sections =
        (c['sectionScores'] ?? c['aiAnalysis']?['sectionScores'] ?? []) as List;
    final mistakes = (c['aiAnalysis']?['commonMistakes'] ?? []) as List;

    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching SOP found. Create a SOP for this category and sales stage to enable scoring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ...sections.map((s) => _sectionCard(Map<String, dynamic>.from(s))),
        if (mistakes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              const Text(
                'Areas to Improve',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...mistakes.map((m) {
            final mm = Map<String, dynamic>.from(m);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mm['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${mm['severity'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (mm['recommendation'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
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
                    ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionCard(Map<String, dynamic> section) {
    final score = (section['score'] ?? 0) as num;
    final questions = (section['questions'] ?? []) as List;
    final weightage = section['weightage'] ?? 0;
    final feedback = section['feedback'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Score
          Row(
            children: [
              Expanded(
                child: Text(
                  section['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(score),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceLight,
                    color: _scoreColor(score),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Weight: $weightage%',
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ],
          ),
          if (feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                feedback,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Questions
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...questions.map((q) {
              final qm = Map<String, dynamic>.from(q);
              final answered = qm['answered'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      answered ? Icons.check_circle : Icons.cancel,
                      size: 15,
                      color: answered ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qm['question'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (qm['answer'] != null &&
                              qm['answer'] != 'Not found in transcript')
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                qm['answer'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          if (qm['matchingLine'] != null &&
                              (qm['matchingLine'] as String).isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                '"${qm['matchingLine']}"',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          Text(
                            answered
                                ? 'Covered · ${qm['confidence'] ?? 0}%'
                                : 'Not addressed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: answered
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Transcription Tab ────────────────────────────────────────────────────

  Widget _transcriptionTab(Map<String, dynamic> c) {
    final text = c['transcription'] ?? '';
    final customerName = c['aiAnalysis']?['customerName'];
    final customerCompany = c['aiAnalysis']?['customerCompany'];

    if (text.isEmpty)
      return const Center(
        child: Text(
          'No transcription available',
          style: TextStyle(color: AppColors.textHint),
        ),
      );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Detected participants
        if (customerName != null || customerCompany != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected from transcript',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (customerName != null)
                      Chip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: Text(
                          customerName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppColors.primarySurface,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (customerCompany != null)
                      Chip(
                        avatar: const Icon(Icons.business, size: 14),
                        label: Text(
                          customerCompany,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppColors.surfaceLight,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        // Word count
        Row(
          children: [
            const Icon(Icons.mic, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            const Text(
              'Transcription',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${text.split(' ').length} words',
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Summary Tab ──────────────────────────────────────────────────────────

  Widget _summaryTab(Map<String, dynamic> c) {
    final items =
        (c['callSummary'] ?? c['aiAnalysis']?['callSummary'] ?? []) as List;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.summarize_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 8),
            const Text(
              'No summary generated yet',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text(
              'AI-Generated Call Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((e) {
          final i = e.key;
          final item = Map<String, dynamic>.from(e.value);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['question'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(left: 30),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.primaryLight, width: 2),
                    ),
                  ),
                  child: Text(
                    item['answer'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
