import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class SopEvaluatorScreen extends StatefulWidget {
  const SopEvaluatorScreen({super.key});
  @override
  State<SopEvaluatorScreen> createState() => _SopEvaluatorScreenState();
}

class _SopEvaluatorScreenState extends State<SopEvaluatorScreen> {
  final _api = ApiService();
  bool _loadingSops = true;
  bool _loadingCalls = true;
  bool _loadingTranscript = false;
  bool _evaluating = false;

  List<Map<String, dynamic>> _sops = [];
  List<Map<String, dynamic>> _calls = [];
  String? _selectedSopId;
  String? _selectedCallId;
  String _transcript = '';
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load SOPs
    try {
      final res = await _api.getSops();
      _sops = _parseList(res.data);
    } catch (_) {
      _sops = [];
    }
    setState(() => _loadingSops = false);

    // Load calls (completed with audio)
    try {
      final res = await _api.getCalls();
      final all = _parseList(res.data);
      _calls = all
          .where(
            (c) => c['analysisStatus'] == 'COMPLETED' && c['audioUrl'] != null,
          )
          .toList();
    } catch (_) {
      _calls = [];
    }
    setState(() => _loadingCalls = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map)
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    return [];
  }

  Future<void> _onCallSelect(String callId) async {
    setState(() {
      _selectedCallId = callId;
      _loadingTranscript = true;
      _transcript = '';
    });
    try {
      final res = await _api.getCall(callId);
      final call = res.data is Map
          ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
          : <String, dynamic>{};
      _transcript = call['transcription'] ?? '';
      if (_transcript.isEmpty) {
        _msg('No transcription found for this call', error: true);
      }
    } catch (e) {
      _msg('Failed to load transcription', error: true);
    }
    if (mounted) setState(() => _loadingTranscript = false);
  }

  Future<void> _evaluate() async {
    if (_selectedSopId == null || _transcript.trim().length < 10) return;
    setState(() {
      _evaluating = true;
      _result = null;
    });
    try {
      final res = await _api.evaluateTranscript(
        sopId: _selectedSopId!,
        transcript: _transcript.trim(),
      );
      final raw = res.data;
      _result = raw is Map
          ? Map<String, dynamic>.from(raw['data'] ?? raw)
          : null;
    } catch (e) {
      _msg('Evaluation failed: $e', error: true);
    }
    if (mounted) setState(() => _evaluating = false);
  }

  void _reset() => setState(() {
    _result = null;
    _transcript = '';
    _selectedSopId = null;
    _selectedCallId = null;
  });

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Color _scoreColor(num score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _resultView();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Select Call
        const Text(
          'SELECT CALL RECORDING',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: _loadingCalls
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCallId,
                    isExpanded: true,
                    hint: const Text('Select a call...'),
                    items: _calls.map((c) {
                      final name = c['customerName'] ?? 'Unknown';
                      final user = c['user'];
                      final userName = user != null
                          ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim()
                          : '';
                      return DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(
                          '$name — $userName',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) _onCallSelect(v);
                    },
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Select SOP
        const Text(
          'SELECT SOP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: _loadingSops
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSopId,
                    isExpanded: true,
                    hint: const Text('Select a SOP...'),
                    items: _sops
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(
                              '${s['name']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSopId = v),
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Transcript preview
        if (_loadingTranscript)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_transcript.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'TRANSCRIPT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_transcript.length} characters',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: SingleChildScrollView(
              child: Text(
                _transcript,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Evaluate button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                (_selectedSopId != null &&
                    _transcript.trim().length >= 10 &&
                    !_evaluating)
                ? _evaluate
                : null,
            icon: _evaluating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_evaluating ? 'Evaluating...' : 'Evaluate with AI'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultView() {
    final sopName = _result!['sopName'] ?? '';
    final overallScore = _result!['overallScore'] ?? 0;
    final sections = (_result!['sectionScores'] ?? []) as List;
    final mistakes = (_result!['commonMistakes'] ?? []) as List;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _reset,
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
                      sopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Evaluation Result',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _scoreColor(overallScore).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$overallScore%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _scoreColor(overallScore),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Sections
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...sections.map((s) {
                final sec = Map<String, dynamic>.from(s);
                final score = (sec['score'] ?? 0) as num;
                final questions = (sec['questions'] ?? []) as List;
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
                            child: Text(
                              sec['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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
                      if (questions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...questions.map((q) {
                          final qm = Map<String, dynamic>.from(q);
                          final answered = qm['answered'] == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  answered ? Icons.check_circle : Icons.cancel,
                                  size: 14,
                                  color: answered
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    qm['question'] ?? '',
                                    style: const TextStyle(fontSize: 11),
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
              }),
              if (mistakes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Areas to Improve',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 6),
                ...mistakes.map((m) {
                  final mm = Map<String, dynamic>.from(m);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mm['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
