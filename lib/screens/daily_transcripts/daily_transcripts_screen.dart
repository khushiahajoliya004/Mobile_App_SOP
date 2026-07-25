import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class DailyTranscriptsScreen extends StatefulWidget {
  const DailyTranscriptsScreen({super.key});
  @override
  State<DailyTranscriptsScreen> createState() => _DailyTranscriptsScreenState();
}

class _DailyTranscriptsScreenState extends State<DailyTranscriptsScreen> {
  final _api = ApiService();
  bool _loadingDates = true;
  bool _loadingCalls = false;
  bool _loadingDetail = false;

  List<Map<String, dynamic>> _dates = [];
  List<Map<String, dynamic>> _calls = [];
  Map<String, dynamic>? _selectedInsight;
  String? _selectedDate;
  String? _selectedCallId;
  int _detailTab = 0; // 0=Transcription, 1=Summary, 2=Score

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    setState(() => _loadingDates = true);
    try {
      final from = DateTime.now().subtract(const Duration(days: 365));
      final res = await _api.getCallReportDaily(
        fromDate: from.toIso8601String().split('T').first,
        toDate: DateTime.now().toIso8601String().split('T').first,
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? ((raw['data'] ?? raw['dates'] ?? []) as List) : []);
      _dates = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _dates = [];
    }
    if (mounted) setState(() => _loadingDates = false);
  }

  Future<void> _loadCallsForDate(String date) async {
    setState(() {
      _selectedDate = date;
      _loadingCalls = true;
      _selectedInsight = null;
      _selectedCallId = null;
    });
    try {
      final res = await _api.getCallReportDailyDetail(date);
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? ((raw['data'] ?? raw['calls'] ?? []) as List) : []);
      _calls = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _calls = [];
    }
    if (mounted) setState(() => _loadingCalls = false);
  }

  Future<void> _loadInsight(String callId) async {
    setState(() {
      _selectedCallId = callId;
      _loadingDetail = true;
      _detailTab = 0;
    });
    try {
      final res = await _api.getAiInsightDetail(callId);
      final raw = res.data;
      _selectedInsight = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : null;
    } catch (_) {
      _selectedInsight = null;
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  num _toNum(dynamic v) =>
      v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

  String _fmtDate(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedInsight != null || _loadingDetail) {
      return _detailView();
    }
    if (_selectedDate != null) {
      return _callsView();
    }
    return _datesView();
  }

  Widget _datesView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: _loadDates,
                child: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingDates
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _dates.isEmpty
              ? const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dates.length,
                  itemBuilder: (_, i) {
                    final d = _dates[i];
                    final date = d['date'] as String? ?? '';
                    final count = _toNum(
                      d['callCount'] ?? d['count'] ?? d['total'] ?? 0,
                    );
                    return GestureDetector(
                      onTap: () => _loadCallsForDate(date),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.today_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fmtDate(date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${count.toInt()} calls',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _callsView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = null;
                  _calls = [];
                }),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fmtDate(_selectedDate!),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_calls.length} calls',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingCalls
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _calls.isEmpty
              ? const Center(
                  child: Text(
                    'No calls for this date',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  itemBuilder: (_, i) {
                    final c = _calls[i];
                    final id = c['id'] ?? c['callId'] ?? '';
                    final customer =
                        c['customerName'] ?? c['customer'] ?? 'Unknown';
                    final duration = _toNum(
                      c['duration'] ?? c['durationMinutes'] ?? 0,
                    );
                    final score = _toNum(
                      c['sopScore'] ?? c['score'] ?? c['overallScore'] ?? 0,
                    );
                    final scoreColor = score >= 80
                        ? AppColors.success
                        : score >= 50
                        ? AppColors.warning
                        : AppColors.error;
                    return GestureDetector(
                      onTap: () =>
                          id.isNotEmpty ? _loadInsight(id.toString()) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$customer',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${duration.toStringAsFixed(1)} min',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${score.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: scoreColor,
                                  ),
                                ),
                                const Text(
                                  'SOP score',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detailView() {
    if (_loadingDetail)
      return const Material(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    final insight = _selectedInsight!;
    final tabs = ['Transcription', 'Summary', 'Score'];
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedInsight = null;
                      _selectedCallId = null;
                    }),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight['customerName'] ?? 'Call Detail',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: tabs.asMap().entries.map((e) {
                  final selected = _detailTab == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _detailTab = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _detailTab == 0
                ? _transcriptionTab(insight)
                : _detailTab == 1
                ? _summaryTab(insight)
                : _scoreTab(insight),
          ),
        ),
      ],
    );
  }

  Widget _transcriptionTab(Map<String, dynamic> insight) {
    final transcript = insight['transcript'] ?? insight['transcription'] ?? '';
    if (transcript.toString().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No transcription available',
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Text(
        '$transcript',
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _summaryTab(Map<String, dynamic> insight) {
    final rawSummary =
        insight['summary'] ??
        insight['callSummary'] ??
        insight['aiAnalysis']?['callSummary'];
    final keyPoints =
        (insight['keyPoints'] ?? insight['highlights'] ?? []) as List;

    // If summary is a Q&A list, render each item
    if (rawSummary is List && rawSummary.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...rawSummary.map((item) {
            final m = item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{};
            final q = m['question']?.toString() ?? '';
            final a = m['answer']?.toString() ?? '';
            if (a.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.isNotEmpty) ...[
                    Text(
                      q,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(a, style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            );
          }),
          if (keyPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Key Points',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...keyPoints.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text('$p', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    final summary = rawSummary?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) ...[
          const Text(
            'Summary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Text(
              '$summary',
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ],
        if (keyPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Key Points',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...keyPoints.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text('$p', style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (summary.toString().isEmpty && keyPoints.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No summary available',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          ),
      ],
    );
  }

  Widget _scoreTab(Map<String, dynamic> insight) {
    final sections =
        (insight['sectionScores'] ??
                insight['aiAnalysis']?['sectionScores'] ??
                insight['sections'] ??
                insight['sopSections'] ??
                insight['evaluation']?['sections'] ??
                [])
            as List;
    final overallScore = _toNum(
      insight['overallScore'] ?? insight['sopScore'] ?? insight['score'] ?? 0,
    );
    final scoreColor = overallScore >= 80
        ? AppColors.success
        : overallScore >= 50
        ? AppColors.warning
        : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Text(
                '${overallScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall SOP Score',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Based on evaluation criteria',
                      style: TextStyle(
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
        if (sections.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Section Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...sections.map((s) {
            final sec = s is Map
                ? Map<String, dynamic>.from(s)
                : <String, dynamic>{};
            final name =
                sec['title'] ?? sec['name'] ?? sec['sectionName'] ?? '';
            final score = _toNum(sec['score'] ?? sec['percentage'] ?? 0);
            final c = score >= 80
                ? AppColors.success
                : score >= 50
                ? AppColors.warning
                : AppColors.error;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
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
                    children: [
                      Expanded(
                        child: Text(
                          '$name',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                ],
              ),
            );
          }),
        ] else
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No score breakdown available',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          ),
      ],
    );
  }
}
