import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmDailyTranscriptsScreen extends StatefulWidget {
  const CrmDailyTranscriptsScreen({super.key});

  @override
  State<CrmDailyTranscriptsScreen> createState() => _CrmDailyTranscriptsScreenState();
}

class _CrmDailyTranscriptsScreenState extends State<CrmDailyTranscriptsScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<String> _dates = [];
  Set<String> _expandedDates = {};
  Set<String> _expandedCalls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCalls();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      final calls = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Only calls with transcription or callSummary
      final transcribed = calls.where((c) {
        final t = c['transcription'];
        final s = c['callSummary'];
        final status = c['analysisStatus']?.toString() ?? '';
        return (t != null && t.toString().isNotEmpty) ||
            (s != null) ||
            status == 'COMPLETED';
      }).toList();

      // Group by date
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final call in transcribed) {
        final createdAt = call['createdAt']?.toString() ?? '';
        String dateKey = 'Unknown';
        if (createdAt.isNotEmpty) {
          try {
            final dt = DateTime.parse(createdAt).toLocal();
            dateKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          } catch (_) {}
        }
        grouped.putIfAbsent(dateKey, () => []).add(call);
      }

      // Sort dates descending
      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        _grouped = grouped;
        _dates = sortedDates;
        if (sortedDates.isNotEmpty) _expandedDates = {sortedDates.first};
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      if (dt == today) return 'Today';
      if (dt == yesterday) return 'Yesterday';
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateKey;
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '';
    final s = int.tryParse(seconds.toString()) ?? 0;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m}m ${rem}s';
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
          : _dates.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dates.length,
                    itemBuilder: (_, i) => _buildDateGroup(_dates[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.transcribe_outlined,
            size: 56,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transcripts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Analysed calls with transcriptions\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateKey) {
    final calls = _grouped[dateKey] ?? [];
    final expanded = _expandedDates.contains(dateKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Date header
          GestureDetector(
            onTap: () => setState(() {
              if (expanded) {
                _expandedDates.remove(dateKey);
              } else {
                _expandedDates.add(dateKey);
              }
            }),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: expanded
                    ? const BorderRadius.vertical(top: Radius.circular(18))
                    : BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(dateKey),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${calls.length} call${calls.length == 1 ? '' : 's'} with transcripts',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${calls.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          // Calls list
          if (expanded)
            ...calls.asMap().entries.map((entry) {
              final isLast = entry.key == calls.length - 1;
              return _buildCallItem(entry.value, isLast);
            }),
        ],
      ),
    );
  }

  Widget _buildCallItem(Map<String, dynamic> call, bool isLast) {
    final callId = call['id']?.toString() ?? '';
    final expanded = _expandedCalls.contains(callId);
    final customerName = call['customerName']?.toString() ?? 'Unknown';
    final duration = _formatDuration(call['durationSeconds']);
    final sopScore = call['sopScore'];
    final analysisStatus = call['analysisStatus']?.toString() ?? '';
    final transcription = call['transcription']?.toString() ?? '';
    final summary = call['callSummary'];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, isLast ? 12 : 0),
      child: Column(
        children: [
          Container(
            height: 1,
            color: AppColors.surfaceLight,
            margin: const EdgeInsets.symmetric(vertical: 6),
          ),
          GestureDetector(
            onTap: () => setState(() {
              if (expanded) {
                _expandedCalls.remove(callId);
              } else {
                _expandedCalls.add(callId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _scoreColor(sopScore).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: _scoreColor(sopScore),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            if (duration.isNotEmpty) ...[
                              const Icon(Icons.timer_outlined, size: 12, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(
                                duration,
                                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (sopScore != null) ...[
                              Text(
                                'Score: ${double.tryParse(sopScore.toString())?.toStringAsFixed(0) ?? sopScore}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _scoreColor(sopScore),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _statusChip(analysisStatus),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _buildTranscriptPanel(transcription, summary),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel(String transcription, dynamic summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          if (summary != null && summary is Map) ...[
            const Text(
              'AI Summary',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            if (summary['overview'] != null)
              Text(
                summary['overview'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            if (summary['keyPoints'] is List) ...[
              const SizedBox(height: 8),
              ...((summary['keyPoints'] as List).take(3).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.primary)),
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
                  ))),
            ],
            const Divider(height: 16),
          ],
          // Transcription
          if (transcription.isNotEmpty) ...[
            const Text(
              'Transcription',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              transcription.length > 600
                  ? '${transcription.substring(0, 600)}...'
                  : transcription,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ] else ...[
            const Center(
              child: Text(
                'No transcription available',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(dynamic score) {
    if (score == null) return AppColors.textHint;
    final s = double.tryParse(score.toString()) ?? 0;
    if (s >= 75) return AppColors.success;
    if (s >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        c = AppColors.success;
        break;
      case 'PROCESSING':
        c = AppColors.warning;
        break;
      case 'FAILED':
        c = AppColors.error;
        break;
      default:
        c = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.isEmpty ? 'PENDING' : status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}
