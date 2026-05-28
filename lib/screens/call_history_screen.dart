import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _api = ApiService();
  List<dynamic> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getCalls();
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      setState(() {
        _calls = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load call history';
        _loading = false;
      });
    }
  }

  void _showCallDetail(Map<String, dynamic> call) {
    final callId = call['id'];
    if (callId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallQuickSummarySheet(callId: callId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check your connection and try again',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadCalls,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No calls found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your call history will appear here',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCalls,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _calls.length,
        itemBuilder: (context, index) {
          final call = _calls[index];
          final customerName = call['customerName'] ?? 'Unknown';
          final categoryName = call['category']?['name'] ?? '';
          final stageName = call['salesStage']?['name'] ?? '';
          final analysisStatus = call['analysisStatus'] ?? 'PENDING';
          final sopScore = call['sopScore'];
          final date = call['createdAt'] ?? '';
          final userName = call['user'] != null
              ? '${call['user']['firstName'] ?? ''} ${call['user']['lastName'] ?? ''}'
                    .trim()
              : '';

          return GestureDetector(
            onTap: () => _showCallDetail(Map<String, dynamic>.from(call)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              customerName.isNotEmpty
                                  ? customerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name + user
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (userName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'by $userName',
                                    style: const TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Status badge
                        _buildStatusBadge(analysisStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tags row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (sopScore != null) _buildScoreBadge(sopScore),
                        if (categoryName.isNotEmpty)
                          _buildTag(
                            Icons.label_rounded,
                            categoryName,
                            AppColors.primary,
                          ),
                        if (stageName.isNotEmpty)
                          _buildTag(
                            Icons.flag_rounded,
                            stageName,
                            AppColors.accent,
                          ),
                        _buildTag(
                          Icons.calendar_today_rounded,
                          _formatDate(date),
                          AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ); // close GestureDetector
        },
      ),
    );
  }

  Widget _buildScoreBadge(dynamic score) {
    final numScore = score is num ? score.toInt() : int.tryParse('$score') ?? 0;
    Color color;
    if (numScore >= 80) {
      color = AppColors.success;
    } else if (numScore >= 60) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.score_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$numScore%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'COMPLETED':
        color = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'PROCESSING':
        color = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'FAILED':
        color = AppColors.error;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = AppColors.textHint;
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ═══ CALL QUICK SUMMARY BOTTOM SHEET ════════════════════════════════════════
class _CallQuickSummarySheet extends StatefulWidget {
  final String callId;
  const _CallQuickSummarySheet({required this.callId});
  @override
  State<_CallQuickSummarySheet> createState() => _CallQuickSummarySheetState();
}

class _CallQuickSummarySheetState extends State<_CallQuickSummarySheet> {
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
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.35,
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
                    _buildHeader(),
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

  Widget _buildHeader() {
    final score = _detail['sopScore'];
    final name = _detail['customerName'] ?? 'Unknown';
    final status = _detail['analysisStatus'] ?? '';
    final category = _detail['category']?['name'] ?? '';
    final duration = _detail['durationSeconds'] != null
        ? '${((_detail['durationSeconds'] as num) / 60).floor()}:${((_detail['durationSeconds'] as num).toInt() % 60).toString().padLeft(2, '0')}'
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
                        '$score',
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
    final raw = ai['keyDiscussionPoints'] ?? ai['keyPoints'] ?? [];

    List<String> points = [];
    if (raw is List) {
      points = raw.map((e) => e.toString()).toList();
    } else if (raw is Map) {
      raw.forEach((key, value) {
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
