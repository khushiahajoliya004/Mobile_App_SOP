import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CallApprovalsScreen extends StatefulWidget {
  const CallApprovalsScreen({super.key});
  @override
  State<CallApprovalsScreen> createState() => _CallApprovalsScreenState();
}

class _CallApprovalsScreenState extends State<CallApprovalsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _calls = [];
  final Set<String> _selected = {};
  final Map<String, bool> _actionLoading = {};
  String _search = '';
  String _statusFilter = 'all'; // all, pending, approved, rejected
  int _page = 1;
  int _total = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCallApprovals(
        page: _page,
        limit: 20,
        search: _search.isNotEmpty ? _search : null,
      );
      final raw = res.data;
      if (raw is Map) {
        _calls = ((raw['data'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _total = raw['pagination']?['total'] ?? _calls.length;
        _totalPages = raw['pagination']?['totalPages'] ?? 1;
      } else if (raw is List) {
        _calls = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        _total = _calls.length;
        _totalPages = 1;
      }
    } catch (_) {
      _calls = [];
    }
    _selected.clear();
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_statusFilter == 'all') return _calls;
    final map = {
      'pending': 'APPROVAL_PENDING',
      'approved': 'COMPLETED',
      'rejected': 'REJECTED',
    };
    final target = map[_statusFilter] ?? '';
    return _calls.where((c) => c['analysisStatus'] == target).toList();
  }

  List<Map<String, dynamic>> get _pendingCalls =>
      _calls.where((c) => c['analysisStatus'] == 'APPROVAL_PENDING').toList();

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  // ─── Approve / Reject ─────────────────────────────────────────────────────

  Future<void> _approve(Map<String, dynamic> call) async {
    final id = call['id'];
    setState(() => _actionLoading[id] = true);
    try {
      await _api.approveCall(id);
      _msg('Call approved — 1 credit deducted');
      _load();
    } catch (e) {
      _msg('Failed to approve: $e', error: true);
    }
    _actionLoading.remove(id);
  }

  Future<void> _reject(Map<String, dynamic> call) async {
    final id = call['id'];
    setState(() => _actionLoading[id] = true);
    try {
      await _api.rejectCall(id);
      _msg('Call rejected');
      _load();
    } catch (e) {
      _msg('Failed to reject: $e', error: true);
    }
    _actionLoading.remove(id);
  }

  Future<void> _approveSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        _actionLoading[id] = true;
      }
    });
    int succeeded = 0;
    int failed = 0;
    for (final id in ids) {
      try {
        await _api.approveCall(id);
        succeeded++;
      } catch (_) {
        failed++;
      }
    }
    if (failed == 0) {
      _msg('$succeeded call(s) approved');
    } else {
      _msg('$succeeded approved, $failed failed', error: failed > 0 && succeeded == 0);
    }
    _load();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  // ignore: unused_element
  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == _pendingCalls.length) {
        _selected.clear();
      } else {
        _selected.addAll(_pendingCalls.map((c) => c['id'] as String));
      }
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse('$date').toLocal();
      const months = [
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
      return '${d.day} ${months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '$date';
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    _search = v;
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
            ],
          ),
        ),
        // Status filter chips + bulk approve
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              ..._filterChip('All', 'all'),
              const SizedBox(width: 6),
              ..._filterChip('Pending', 'pending'),
              const SizedBox(width: 6),
              ..._filterChip('Approved', 'approved'),
              const SizedBox(width: 6),
              ..._filterChip('Rejected', 'rejected'),
              const Spacer(),
              Text(
                '$_total calls',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        // Bulk approve bar
        if (_selected.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _approveSelected,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Approve All',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : list.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No calls found',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _callTile(list[i]),
                  ),
                ),
        ),
        // Pagination
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(12),
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
                  'Page $_page of $_totalPages',
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

  List<Widget> _filterChip(String label, String value) {
    final active = _statusFilter == value;
    return [
      GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      ),
    ];
  }

  Widget _callTile(Map<String, dynamic> call) {
    final id = call['id'] ?? '';
    final name = call['customerName'] ?? 'Unknown';
    final user = call['user'];
    final userName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : '';
    final category = call['category']?['name'] ?? '';
    final stage = call['salesStage']?['name'] ?? '';
    final status = call['analysisStatus'] ?? '';
    final isPending = status == 'APPROVAL_PENDING';
    final isLoading = _actionLoading[id] == true;
    final hasAudio = call['audioUrl'] != null;
    final date = _formatDate(call['createdAt']);
    final aiEnabled = call['user']?['aiEnabled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _selected.contains(id)
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selected.contains(id)
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checkbox + Name + Status
          Row(
            children: [
              if (isPending)
                GestureDetector(
                  onTap: () => _toggleSelect(id),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _selected.contains(id)
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selected.contains(id)
                            ? AppColors.primary
                            : AppColors.textHint,
                        width: 1.5,
                      ),
                    ),
                    child: _selected.contains(id)
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (userName.isNotEmpty)
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Category + Stage + Date
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (category.isNotEmpty) _chip(category, AppColors.primary),
              if (stage.isNotEmpty) _chip(stage, AppColors.accent),
              _chip(date, AppColors.textSecondary),
              if (aiEnabled) _chip('AI ON', AppColors.success),
            ],
          ),

          // Row 3: Audio + Actions
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasAudio)
                GestureDetector(
                  onTap: () {
                    /* could open audio player */
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_filled,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Audio',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              // Actions
              if (isPending && !isLoading) ...[
                _actionBtn(
                  Icons.check_rounded,
                  AppColors.success,
                  'Approve',
                  () => _approve(call),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  Icons.close_rounded,
                  AppColors.error,
                  'Reject',
                  () => _reject(call),
                ),
              ],
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              if (!isPending && status == 'REJECTED')
                _chip('REJECTED', AppColors.error),
              if (!isPending && status == 'COMPLETED')
                _chip('APPROVED', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'APPROVAL_PENDING':
        bg = AppColors.warning.withValues(alpha: 0.1);
        fg = AppColors.warning;
        break;
      case 'COMPLETED':
        bg = AppColors.success.withValues(alpha: 0.1);
        fg = AppColors.success;
        break;
      case 'REJECTED':
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.surfaceLight;
        fg = AppColors.textHint;
    }
    final label = status == 'APPROVAL_PENDING' ? 'PENDING' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _actionBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
