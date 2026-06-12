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
  String? _selectedCallId;
  Map<String, dynamic>? _selectedCallData;
  int _detailTab = 0;
  final Set<String> _fetchingCalls = {};
  final Set<String> _failedFetches = {};
  final Map<String, Map<String, dynamic>> _callDetails = {};

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

  Future<void> _fetchCallDetail(String callId) async {
    if (callId.isEmpty ||
        _fetchingCalls.contains(callId) ||
        _callDetails.containsKey(callId) ||
        _failedFetches.contains(callId)) return;
    if (mounted) setState(() => _fetchingCalls.add(callId));
    try {
      final res = await _api.getCall(callId);
      final raw = res.data;
      final detail = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
      if (detail != null && mounted) {
        setState(() {
          _callDetails[callId] = detail;
          _fetchingCalls.remove(callId);
        });
        return;
      }
    } catch (_) {}
    // Fallback: AI insight
    try {
      final res = await _api.getAiInsightDetail(callId);
      final raw = res.data;
      final detail = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
      if (detail != null && mounted) {
        setState(() => _callDetails[callId] = detail);
      }
    } catch (_) {}
    if (mounted) setState(() {
      _fetchingCalls.remove(callId);
      if (!_callDetails.containsKey(callId)) _failedFetches.add(callId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCallId != null) return _detailView();
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
    final customerName = call['customerName']?.toString() ?? 'Unknown';
    final duration = _formatDuration(call['durationSeconds']);
    final sopScore = call['sopScore'];
    final analysisStatus = call['analysisStatus']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, isLast ? 12 : 0),
      child: Column(children: [
        Container(height: 1, color: AppColors.surfaceLight, margin: const EdgeInsets.symmetric(vertical: 6)),
        GestureDetector(
          onTap: callId.isEmpty ? null : () {
            setState(() {
              _selectedCallId = callId;
              _selectedCallData = call;
              _detailTab = 0;
            });
            _fetchCallDetail(callId);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _scoreColor(sopScore).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.phone_rounded, size: 18, color: _scoreColor(sopScore)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Row(children: [
                  if (duration.isNotEmpty) ...[
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(duration, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    const SizedBox(width: 8),
                  ],
                  if (sopScore != null)
                    Text(
                      'Score: ${double.tryParse(sopScore.toString())?.toStringAsFixed(0) ?? sopScore}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _scoreColor(sopScore)),
                    ),
                ]),
              ])),
              _statusChip(analysisStatus),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _detailView() {
    final callId = _selectedCallId!;
    final base = _selectedCallData ?? {};
    final detail = _callDetails[callId];
    final isFetching = _fetchingCalls.contains(callId);
    final customerName = base['customerName']?.toString() ?? 'Call Detail';

    final transcription = detail?['transcription']?.toString() ??
        detail?['transcript']?.toString() ??
        (base['transcription']?.toString() ?? '');
    final summary = detail?['callSummary'] ?? base['callSummary'];
    final sections = ((detail?['sectionScores'] ?? detail?['aiAnalysis']?['sectionScores'] ?? []) as List);
    final overallScore = detail?['sopScore'] ?? base['sopScore'];

    const tabs = ['Transcription', 'Summary', 'Score'];

    return Container(
      color: AppColors.scaffoldBg,
      child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _selectedCallId = null;
                  _selectedCallData = null;
                  _detailTab = 0;
                }),
              ),
              Expanded(child: Text(customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
            Row(children: tabs.asMap().entries.map((e) {
              final selected = _detailTab == e.key;
              return GestureDetector(
                onTap: () => setState(() => _detailTab = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text(e.value, style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  )),
                ),
              );
            }).toList()),
          ]),
        ),
        Expanded(
          child: isFetching
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _detailTab == 0
                      ? _transcriptionContent(transcription)
                      : _detailTab == 1
                          ? _summaryContent(summary)
                          : _scoreContent(overallScore, sections),
                ),
        ),
      ]),
    );
  }

  Widget _transcriptionContent(String transcription) {
    if (transcription.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No transcription available', style: TextStyle(color: AppColors.textHint)),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Text(transcription, style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textPrimary)),
    );
  }

  Widget _summaryContent(dynamic summary) {
    if (summary is List && summary.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...summary.map((item) {
          final m = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
          final q = m['question']?.toString() ?? '';
          final a = m['answer']?.toString() ?? '';
          if (a.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (q.isNotEmpty) ...[
                Text(q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
              ],
              Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            ]),
          );
        }),
      ]);
    }
    if (summary is Map) {
      final overview = summary['overview']?.toString() ?? '';
      if (overview.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
          child: Text(overview, style: const TextStyle(fontSize: 13, height: 1.6)),
        );
      }
    }
    return const Center(child: Padding(
      padding: EdgeInsets.all(32),
      child: Text('No summary available', style: TextStyle(color: AppColors.textHint)),
    ));
  }

  Widget _scoreContent(dynamic overallScore, List sections) {
    final score = num.tryParse(overallScore?.toString() ?? '') ?? 0;
    final scoreColor = score >= 75 ? AppColors.success : score >= 50 ? AppColors.warning : AppColors.error;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: scoreColor)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overall SOP Score', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Based on evaluation criteria', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
        ]),
      ),
      if (sections.isNotEmpty) ...[
        const SizedBox(height: 16),
        ...sections.map((s) {
          final sec = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
          final name = sec['sectionName'] ?? sec['name'] ?? '';
          final secScore = num.tryParse((sec['score'] ?? sec['percentage'] ?? 0).toString()) ?? 0;
          final c = secScore >= 75 ? AppColors.success : secScore >= 50 ? AppColors.warning : AppColors.error;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('$name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text('${secScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (secScore / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                ),
              ),
            ]),
          );
        }),
      ] else
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No score breakdown available', style: TextStyle(color: AppColors.textHint)))),
    ]);
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
