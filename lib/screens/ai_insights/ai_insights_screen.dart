import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});
  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _api = ApiService();

  // Loading
  bool _loading = true;
  bool _detailLoading = false;
  bool _bulkDownloading = false;
  bool _mergedPdfDownloading = false;

  // Data
  List<Map<String, dynamic>> _calls = [];
  Map<String, dynamic>? _selected; // individual call detail
  Map<String, dynamic>? _selectedGroup; // customer group for merged view

  // UI state
  String _activeTab = 'analysis';
  String _listView = 'calls'; // 'calls' or 'byCustomer'

  // Calls tab: drill into a customer's individual calls
  List<Map<String, dynamic>>? _callsCustomerCalls;
  Map<String, dynamic>? _callsCustomerGroup;

  // Filters / Pagination
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

  // Bulk selection
  final Set<String> _selectedCallIds = {};

  // Audio player
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double _audioVolume = 1.0;

  // ─── Lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
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
    _completedCount =
        _calls.where((c) => c['analysisStatus'] == 'COMPLETED').length;
    final scored = _calls.where((c) => c['sopScore'] != null).toList();
    _avgScore = scored.isNotEmpty
        ? (scored
                    .map((c) =>
                        num.tryParse(c['sopScore'].toString())?.toDouble() ??
                        0.0)
                    .reduce((a, b) => a + b) /
                scored.length)
            .round()
        : 0;
    _successRate = scored.isNotEmpty
        ? ((scored
                        .where((c) =>
                            (num.tryParse(c['sopScore'].toString()) ?? 0) >= 70)
                        .length /
                    scored.length) *
                100)
            .round()
        : 0;
  }

  Future<void> _selectCall(Map<String, dynamic> call) async {
    await _stopAudio();
    setState(() {
      _selected = call;
      _selectedGroup = null;
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
      // Init audio if available
      final audioUrl = _selected!['audioUrl'] as String?;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _initAudioPlayer(audioUrl);
      }
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

  // ─── Audio Player ─────────────────────────────────────────────────────

  Future<void> _initAudioPlayer(String url) async {
    await _stopAudio();
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    _audioPlayer!.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });
    _audioPlayer!.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() => _isAudioPlaying = s == PlayerState.playing);
      }
    });
    await _audioPlayer!.setVolume(_audioVolume);
    await _audioPlayer!.setSource(UrlSource(url));
    setState(() {
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
      _isAudioPlaying = false;
    });
  }

  Future<void> _stopAudio() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
        _audioPosition = Duration.zero;
        _audioDuration = Duration.zero;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioPlayer == null) return;
    if (_isAudioPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.resume();
    }
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Bulk Download ────────────────────────────────────────────────────

  Future<void> _bulkDownload() async {
    if (_selectedCallIds.isEmpty || _bulkDownloading) return;
    setState(() => _bulkDownloading = true);
    try {
      final res =
          await _api.bulkDownloadRecordings(_selectedCallIds.toList());
      final bytes = res.data;
      if (bytes is List<int> && bytes.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final isSingle = _selectedCallIds.length == 1;
        final ext = isSingle ? 'wav' : 'zip';
        final ts = DateTime.now().millisecondsSinceEpoch;
        final name = isSingle ? 'recording_$ts.$ext' : 'recordings_$ts.$ext';
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        _msg('Saved: $name');
        setState(() => _selectedCallIds.clear());
      } else {
        _msg('No data received', error: true);
      }
    } catch (e) {
      _msg('Download failed', error: true);
    }
    if (mounted) setState(() => _bulkDownloading = false);
  }

  // ─── Merged PDF Download ──────────────────────────────────────────────

  Future<void> _downloadMergedPdf() async {
    if (_selectedGroup == null || _mergedPdfDownloading) return;
    setState(() => _mergedPdfDownloading = true);
    try {
      final calls = _selectedGroup!['calls'] as List<Map<String, dynamic>>;
      final ids = calls.map((c) => c['id'].toString()).toList();
      final res = await _api.downloadMergedPdf(ids, includeAnalysis: true);
      final bytes = res.data;
      if (bytes is List<int> && bytes.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final name =
            (_selectedGroup!['customerName'] as String? ?? 'customer')
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final file = File('${dir.path}/merged_$name.pdf');
        await file.writeAsBytes(bytes);
        _msg('PDF saved: merged_$name.pdf');
      } else {
        _msg('No PDF data received', error: true);
      }
    } catch (e) {
      _msg('PDF download failed', error: true);
    }
    if (mounted) setState(() => _mergedPdfDownloading = false);
  }

  // ─── Customer Grouping (Merge) ────────────────────────────────────────

  List<Map<String, dynamic>> _groupByCustomer() {
    final groups = <String, Map<String, dynamic>>{};
    for (final call in _calls) {
      final name = (call['aiAnalysis']?['customerName'] ??
              call['customerName'] ??
              'Unknown')
          .toString();
      final phone = (call['phoneNumber'] ?? '').toString();
      final key = phone.isNotEmpty ? phone : name;
      if (!groups.containsKey(key)) {
        groups[key] = {
          'customerName': name,
          'phoneNumber': phone,
          'calls': <Map<String, dynamic>>[],
        };
      }
      (groups[key]!['calls'] as List<Map<String, dynamic>>).add(call);
    }
    for (final g in groups.values) {
      final calls = g['calls'] as List<Map<String, dynamic>>;
      final scored = calls.where((c) => c['sopScore'] != null).toList();
      g['avgScore'] = scored.isNotEmpty
          ? (scored
                      .map((c) =>
                          num.tryParse(c['sopScore'].toString()) ?? 0.0)
                      .reduce((a, b) => a + b) /
                  scored.length)
              .round()
          : null;
      g['callCount'] = calls.length;
    }
    return groups.values.toList();
  }

  List<Map<String, dynamic>> _getMergedSections(
      List<Map<String, dynamic>> calls) {
    final sectionMap = <String, Map<String, dynamic>>{};
    for (final call in calls) {
      final sections = (call['sectionScores'] ??
          call['aiAnalysis']?['sectionScores'] ??
          []) as List;
      for (final s in sections) {
        final sm = Map<String, dynamic>.from(s);
        final key = (sm['title'] ?? '').toString().toLowerCase().trim();
        if (!sectionMap.containsKey(key)) {
          sectionMap[key] = {
            'title': sm['title'],
            'weightage': sm['weightage'] ?? 0,
            'scores': <num>[],
            'feedbacks': <String>[],
            'questionMap': <String, Map<String, dynamic>>{},
          };
        }
        (sectionMap[key]!['scores'] as List<num>)
            .add(num.tryParse(sm['score'].toString()) ?? 0);
        if ((sm['feedback'] ?? '').toString().isNotEmpty) {
          (sectionMap[key]!['feedbacks'] as List<String>)
              .add(sm['feedback'].toString());
        }
        for (final q in (sm['questions'] ?? []) as List) {
          final qm = Map<String, dynamic>.from(q);
          final qKey = (qm['question'] ?? '').toString().toLowerCase().trim();
          final qMap = sectionMap[key]!['questionMap']
              as Map<String, Map<String, dynamic>>;
          if (!qMap.containsKey(qKey)) {
            qMap[qKey] = {
              'question': qm['question'],
              'coveredCount': 0,
              'totalCount': 0,
              'bestAnswer': null,
              'confidence': <num>[],
            };
          }
          qMap[qKey]!['totalCount'] =
              (qMap[qKey]!['totalCount'] as int) + 1;
          if (qm['answered'] == true) {
            qMap[qKey]!['coveredCount'] =
                (qMap[qKey]!['coveredCount'] as int) + 1;
            if (qm['answer'] != null &&
                qm['answer'] != 'Not found in transcript') {
              qMap[qKey]!['bestAnswer'] ??= qm['answer'];
            }
            if (qm['confidence'] != null) {
              (qMap[qKey]!['confidence'] as List<num>)
                  .add(num.tryParse(qm['confidence'].toString()) ?? 0);
            }
          }
        }
      }
    }
    return sectionMap.values.map((sec) {
      final scores = sec['scores'] as List<num>;
      final avg = scores.isNotEmpty
          ? (scores.reduce((a, b) => a + b) / scores.length).round()
          : 0;
      final qMap =
          sec['questionMap'] as Map<String, Map<String, dynamic>>;
      return {
        'title': sec['title'],
        'score': avg,
        'weightage': sec['weightage'],
        'feedback': (sec['feedbacks'] as List<String>).isNotEmpty
            ? (sec['feedbacks'] as List<String>).first
            : '',
        'questions': qMap.values.map((q) {
          final confs = q['confidence'] as List<num>;
          return {
            'question': q['question'],
            'answered': (q['coveredCount'] as int) > 0,
            'answer': q['bestAnswer'],
            'confidence': confs.isNotEmpty
                ? (confs.reduce((a, b) => a + b) / confs.length).round()
                : 0,
            'matchingLine': null,
          };
        }).toList(),
      };
    }).toList();
  }

  String _getMergedTranscription(List<Map<String, dynamic>> calls) {
    return calls
        .where((c) => (c['transcription'] ?? '').toString().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map((e) =>
            '── Call ${e.key + 1} (${_formatDate(e.value['createdAt'])}) ──\n${e.value['transcription']}')
        .join('\n\n');
  }

  List<dynamic> _getMergedSummary(List<Map<String, dynamic>> calls) {
    final List<dynamic> items = [];
    for (final call in calls) {
      final summary =
          call['callSummary'] ?? call['aiAnalysis']?['callSummary'];
      if (summary is List && summary.isNotEmpty) {
        items.addAll(summary);
      }
    }
    return items;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
    if (_selectedGroup != null) return _mergedDetailScreen();
    if (_callsCustomerCalls != null) return _callsCustomerScreen();

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _miniStat(Icons.phone, '$_totalCalls', 'calls',
                  AppColors.textSecondary),
              _miniStat(Icons.check_circle, '$_completedCount', 'analyzed',
                  AppColors.success),
              _miniStat(
                  Icons.bar_chart, '$_avgScore%', 'avg', AppColors.primary),
              _miniStat(
                  Icons.star, '$_successRate%', 'success', AppColors.warning),
            ],
          ),
        ),
        // Search + Refresh
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.surfaceLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.surfaceLight),
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
                  child: const Icon(Icons.refresh,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        // Status chips + View toggle
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
              const SizedBox(width: 12),
              _viewToggle(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Bulk download bar
        if (_selectedCallIds.isNotEmpty && _listView == 'calls')
          _bulkBar(),
        // Call list
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : _calls.isEmpty
                  ? const Center(
                      child: Text('No calls found',
                          style:
                              TextStyle(color: AppColors.textHint)))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: _listView == 'calls'
                          ? ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _groupByCustomer().length,
                              itemBuilder: (_, i) =>
                                  _callsGroupTile(
                                      _groupByCustomer()[i]),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _groupByCustomer().length,
                              itemBuilder: (_, i) =>
                                  _customerGroupTile(
                                      _groupByCustomer()[i]),
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
                Text('$_page / $_totalPages',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
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

  // ─── View Toggle ───────────────────────────────────────────────────────

  Widget _viewToggle() => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleBtn('Calls', Icons.list, 'calls'),
            _toggleBtn('By Customer', Icons.people, 'byCustomer'),
          ],
        ),
      );

  Widget _toggleBtn(String label, IconData icon, String view) {
    final active = _listView == view;
    return GestureDetector(
      onTap: () => setState(() {
        _listView = view;
        _selectedCallIds.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: active ? Colors.white : AppColors.textHint),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textHint,
                )),
          ],
        ),
      ),
    );
  }

  // ─── Bulk Bar ──────────────────────────────────────────────────────────

  Widget _bulkBar() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text('${_selectedCallIds.length} selected',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            const Spacer(),
            GestureDetector(
              onTap: _bulkDownloading ? null : _bulkDownload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bulkDownloading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download,
                            color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                        _bulkDownloading
                            ? 'Downloading...'
                            : 'Download ZIP',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _selectedCallIds.clear()),
              child: const Icon(Icons.close,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  // ─── List Widgets ──────────────────────────────────────────────────────

  Widget _miniStat(
          IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(width: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textHint)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.surfaceLight),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _callTile(Map<String, dynamic> call) {
    final score = call['sopScore'] != null
        ? num.tryParse(call['sopScore'].toString())
        : null;
    final status = call['analysisStatus'] ?? '';
    final name = call['aiAnalysis']?['customerName'] ??
        call['customerName'] ??
        'Unknown';
    final user = call['user'];
    final userName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : '';
    final category = call['category']?['name'] ?? '';
    final isSelected = _selectedCallIds.contains(call['id']);

    return GestureDetector(
      onTap: () => _selectCall(call),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCallIds.remove(call['id'].toString());
                  } else {
                    _selectedCallIds.add(call['id'].toString());
                  }
                });
              },
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      width: 1.5),
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        size: 12, color: Colors.white)
                    : null,
              ),
            ),
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
                    ? Text('$score',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor(score)))
                    : Icon(
                        status == 'PROCESSING'
                            ? Icons.hourglass_top
                            : Icons.schedule,
                        size: 18,
                        color: AppColors.textHint),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Row(
                    children: [
                      if (userName.isNotEmpty)
                        Text(userName,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      if (category.isNotEmpty)
                        Text(' · $category',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint)),
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
                Text(_formatDate(call['createdAt']),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Calls tab: grouped tile that drills into individual calls
  Widget _callsGroupTile(Map<String, dynamic> group) {
    final calls = group['calls'] as List<Map<String, dynamic>>;
    final score = group['avgScore'] as int?;
    final name = group['customerName'] as String;
    final count = group['callCount'] as int;

    return GestureDetector(
      onTap: () => setState(() {
        _callsCustomerCalls = calls;
        _callsCustomerGroup = group;
        _selectedCallIds.clear();
      }),
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
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('$count call${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('$score%',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor(score))),
                    Text(_scoreLabel(score),
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: _scoreColor(score))),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    '${calls.where((c) => c['analysisStatus'] == 'COMPLETED').length}/$count done',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  // Calls tab: individual calls for a selected customer
  Widget _callsCustomerScreen() {
    final calls = _callsCustomerCalls!;
    final group = _callsCustomerGroup!;
    final name = group['customerName'] as String;
    final count = group['callCount'] as int;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _callsCustomerCalls = null;
                  _callsCustomerGroup = null;
                  _selectedCallIds.clear();
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('$count call${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Bulk download bar
        if (_selectedCallIds.isNotEmpty) _bulkBar(),
        // Individual calls
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: calls.length,
            itemBuilder: (_, i) => _callTile(calls[i]),
          ),
        ),
      ],
    );
  }

  Widget _customerGroupTile(Map<String, dynamic> group) {
    final calls = group['calls'] as List<Map<String, dynamic>>;
    final score = group['avgScore'] as int?;
    final name = group['customerName'] as String;
    final count = group['callCount'] as int;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGroup = group;
          _activeTab = 'analysis';
        });
      },
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
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('$count call${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _scoreColor(score).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('$score%',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor(score))),
                    Text(_scoreLabel(score),
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: _scoreColor(score))),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('${calls.where((c) => c['analysisStatus'] == 'COMPLETED').length}/${count} done',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint)),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textHint),
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
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status == 'APPROVAL_PENDING' ? 'PENDING' : status,
        style: TextStyle(
            fontSize: 8, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ─── Detail Screen (Individual Call) ──────────────────────────────────

  Widget _detailScreen() {
    final c = _selected!;
    final score =
        c['sopScore'] != null ? num.tryParse(c['sopScore'].toString()) : null;
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
    final audioUrl = c['audioUrl'] as String?;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await _stopAudio();
                  setState(() => _selected = null);
                },
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    if (company != null)
                      Text(company,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary)),
                    Text('$category · $stage · $userName',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _scoreColor(score).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('$score%',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _scoreColor(score))),
                      Text(_scoreLabel(score),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _scoreColor(score))),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Audio Player
        if (audioUrl != null && audioUrl.isNotEmpty && !_detailLoading)
          _audioPlayerWidget(),

        // Status banners
        if (status == 'PROCESSING')
          _banner(Icons.hourglass_top, 'Analysis in progress...',
              AppColors.primary),
        if (status == 'PENDING')
          _bannerWithAction(Icons.schedule, 'Waiting to be analyzed',
              'Trigger', () => _reanalyze(c['id']), AppColors.warning),
        if (status == 'FAILED')
          _bannerWithAction(Icons.error_outline, 'Analysis failed',
              'Retry', () => _reanalyze(c['id']), AppColors.error),
        if (status == 'APPROVAL_PENDING')
          _banner(Icons.schedule, 'Awaiting admin approval',
              AppColors.warning),
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
                child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else
          Expanded(child: _tabContent()),
      ],
    );
  }

  // ─── Audio Player Widget ───────────────────────────────────────────────

  Widget _audioPlayerWidget() {
    final totalSec = _audioDuration.inSeconds.toDouble();
    final curSec = _audioPosition.inSeconds.toDouble().clamp(0.0, totalSec > 0 ? totalSec : 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          // Play/Pause
          GestureDetector(
            onTap: _toggleAudio,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Progress + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceLight,
                    thumbColor: AppColors.primary,
                    overlayColor:
                        AppColors.primary.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: curSec,
                    min: 0,
                    max: totalSec > 0 ? totalSec : 1.0,
                    onChanged: (v) async {
                      await _audioPlayer
                          ?.seek(Duration(seconds: v.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmtDur(_audioPosition),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                      Text(_fmtDur(_audioDuration),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Volume
          GestureDetector(
            onTap: () async {
              final newVol = _audioVolume > 0 ? 0.0 : 1.0;
              setState(() => _audioVolume = newVol);
              await _audioPlayer?.setVolume(newVol);
            },
            child: Icon(
              _audioVolume == 0
                  ? Icons.volume_off
                  : _audioVolume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Merged Detail Screen (By Customer) ───────────────────────────────

  Widget _mergedDetailScreen() {
    final g = _selectedGroup!;
    final calls = g['calls'] as List<Map<String, dynamic>>;
    final score = g['avgScore'] as int?;
    final name = g['customerName'] as String;
    final count = g['callCount'] as int;

    final mergedSections = _getMergedSections(calls);
    final mergedTranscription = _getMergedTranscription(calls);
    final mergedSummary = _getMergedSummary(calls);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedGroup = null),
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('$count call${count > 1 ? 's' : ''} · Merged View',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // PDF download
              GestureDetector(
                onTap: _mergedPdfDownloading ? null : _downloadMergedPdf,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _mergedPdfDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf,
                          size: 18, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$score%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _scoreColor(score))),
                      Text(_scoreLabel(score),
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _scoreColor(score))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Tabs
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
        Expanded(
          child: _activeTab == 'analysis'
              ? _analysisTab({'sectionScores': mergedSections})
              : _activeTab == 'transcription'
                  ? _mergedTranscriptionTab(mergedTranscription, calls)
                  : _summaryTab({'callSummary': mergedSummary}),
        ),
      ],
    );
  }

  Widget _mergedTranscriptionTab(
      String merged, List<Map<String, dynamic>> calls) {
    if (merged.isEmpty) {
      return const Center(
          child: Text('No transcriptions available',
              style: TextStyle(color: AppColors.textHint)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Individual call chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: calls
              .asMap()
              .entries
              .map((e) => Chip(
                    label: Text(
                        'Call ${e.key + 1} · ${_formatDate(e.value['createdAt'])}',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.08),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.mic, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            const Text('Merged Transcription',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${merged.split(' ').length} words',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textHint)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Text(merged,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.6)),
        ),
      ],
    );
  }

  // ─── Shared Detail Widgets ─────────────────────────────────────────────

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
            Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _bannerWithAction(
    IconData icon,
    String text,
    String action,
    VoidCallback onTap,
    Color color,
  ) =>
      Container(
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
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: onTap,
              child: Text(action,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline)),
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
              Icon(icon,
                  size: 14,
                  color: active ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? AppColors.primary
                          : AppColors.textHint)),
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
        (c['sectionScores'] ?? c['aiAnalysis']?['sectionScores'] ?? [])
            as List;
    final mistakes =
        (c['aiAnalysis']?['commonMistakes'] ?? []) as List;

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
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              const Text('Areas to Improve',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning)),
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
                    color: AppColors.error.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(mm['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${mm['severity'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error)),
                      ),
                    ],
                  ),
                  if (mm['recommendation'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(mm['recommendation'],
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))),
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
          Row(
            children: [
              Expanded(
                child: Text(section['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$score%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score))),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
              Text('Weight: $weightage%',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          if (feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(feedback,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ),
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
                        answered
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 15,
                        color: answered
                            ? AppColors.success
                            : AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(qm['question'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)),
                          if (qm['answer'] != null &&
                              qm['answer'] !=
                                  'Not found in transcript')
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(qm['answer'],
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ),
                          if (qm['matchingLine'] != null &&
                              (qm['matchingLine'] as String).isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                                border: const Border(
                                    left: BorderSide(
                                        color: AppColors.primary,
                                        width: 2)),
                              ),
                              child: Text(
                                  '"${qm['matchingLine']}"',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic)),
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
                                      : AppColors.error)),
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

  // ─── Transcription Tab ─────────────────────────────────────────────────

  Widget _transcriptionTab(Map<String, dynamic> c) {
    final text = c['transcription'] ?? '';
    final customerName = c['aiAnalysis']?['customerName'];
    final customerCompany = c['aiAnalysis']?['customerCompany'];

    if (text.isEmpty)
      return const Center(
        child: Text('No transcription available',
            style: TextStyle(color: AppColors.textHint)),
      );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                const Text('Detected from transcript',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (customerName != null)
                      Chip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: Text(customerName,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.primarySurface,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (customerCompany != null)
                      Chip(
                        avatar: const Icon(Icons.business, size: 14),
                        label: Text(customerCompany,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.surfaceLight,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        Row(
          children: [
            const Icon(Icons.mic, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            const Text('Transcription',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${text.split(' ').length} words',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textHint)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.6)),
        ),
      ],
    );
  }

  // ─── Summary Tab ───────────────────────────────────────────────────────

  Widget _summaryTab(Map<String, dynamic> c) {
    final items =
        (c['callSummary'] ?? c['aiAnalysis']?['callSummary'] ?? []) as List;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.summarize_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 8),
            const Text('No summary generated yet',
                style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('AI-Generated Call Summary',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
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
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item['question'] ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(left: 30),
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: AppColors.primaryLight, width: 2)),
                  ),
                  child: Text(item['answer'] ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
