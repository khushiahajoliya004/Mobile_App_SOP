import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class SalesStagesScreen extends StatefulWidget {
  const SalesStagesScreen({super.key});
  @override
  State<SalesStagesScreen> createState() => _SalesStagesScreenState();
}

class _SalesStagesScreenState extends State<SalesStagesScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _search = '';
  String _companyId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    _companyId = user?.companyId ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSalesStages();
      _items = _parse(res.data);
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parse(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((i) => '${i['name'] ?? ''}'.toLowerCase().contains(q))
        .toList();
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

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(
      text: existing?['description'] ?? '',
    );
    final sortCtrl = TextEditingController(
      text: '${existing?['sortOrder'] ?? 0}',
    );
    final newQCtrl = TextEditingController();
    List<String> summaryQuestions = [];
    if (existing?['summaryQuestions'] != null) {
      final sq = existing!['summaryQuestions'];
      if (sq is List) summaryQuestions = sq.map((e) => '$e').toList();
      if (sq is String) {
        try {
          summaryQuestions = (List<dynamic>.from(
            summaryQuestions,
          )).map((e) => '$e').toList();
        } catch (_) {}
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Sales Stage' : 'New Sales Stage',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isEdit
                                ? 'Update stage details'
                                : 'Add a new sales stage',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _field(nameCtrl, 'Stage Name', Icons.flag_rounded),
                const SizedBox(height: 14),
                _field(descCtrl, 'Description (optional)', Icons.notes_rounded),
                const SizedBox(height: 14),
                _field(
                  sortCtrl,
                  'Sort Order',
                  Icons.sort_rounded,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Summary Questions section
                Row(
                  children: [
                    const Icon(
                      Icons.quiz_rounded,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SUMMARY QUESTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Questions for call summary',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...summaryQuestions.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setSheet(() => summaryQuestions.removeAt(e.key)),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newQCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a question...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (newQCtrl.text.trim().isNotEmpty) {
                          setSheet(
                            () => summaryQuestions.add(newQCtrl.text.trim()),
                          );
                          newQCtrl.clear();
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          _msg('Name is required', error: true);
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          if (isEdit) {
                            await _api.updateSalesStage(
                              existing['id'],
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              sortOrder: int.tryParse(sortCtrl.text) ?? 0,
                              summaryQuestions: summaryQuestions,
                            );
                            _msg('Stage updated');
                          } else {
                            await _api.createSalesStage(
                              name: nameCtrl.text.trim(),
                              companyId: _companyId,
                              description: descCtrl.text.trim(),
                              sortOrder: int.tryParse(sortCtrl.text) ?? 0,
                              summaryQuestions: summaryQuestions,
                            );
                            _msg('Stage created');
                          }
                          _load();
                        } catch (e) {
                          _msg('Failed: $e', error: true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'Update Stage' : 'Create Stage',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Stage',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteSalesStage(item['id']);
                _msg('Deleted');
                _load();
              } catch (e) {
                _msg('Failed: $e', error: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> item) async {
    final newStatus = item['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await _api.updateSalesStageStatus(item['id'], newStatus);
      _msg('Status updated');
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar + create button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search stages...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.surfaceLight,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.surfaceLight,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showForm(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                size: 12,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                '${_filtered.length} STAGES',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: AppColors.primary,
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
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                )
              : _filtered.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _tile(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
              Icons.flag_outlined,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No stages found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create your first sales stage to get started',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    final status = item['status'] ?? '';
    final isActive = status == 'ACTIVE';
    final sqCount = (item['summaryQuestions'] is List)
        ? (item['summaryQuestions'] as List).length
        : 0;
    return Container(
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
          // Icon container
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if ((item['description'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item['description'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (sqCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.quiz_rounded,
                          size: 10,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$sqCount summary questions',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.textHint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.success : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          _actionBtn(
            icon: isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            color: AppColors.warning,
            onTap: () => _toggleStatus(item),
          ),
          const SizedBox(width: 6),
          _actionBtn(
            icon: Icons.edit_outlined,
            color: AppColors.primary,
            onTap: () => _showForm(existing: item),
          ),
          const SizedBox(width: 6),
          _actionBtn(
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            onTap: () => _confirmDelete(item),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
