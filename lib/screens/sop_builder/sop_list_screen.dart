import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'sop_builder_screen.dart';

class SopListScreen extends StatefulWidget {
  const SopListScreen({super.key});
  @override
  State<SopListScreen> createState() => _SopListScreenState();
}

class _SopListScreenState extends State<SopListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _sops = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSops();
      _sops = _parseList(res.data);
    } catch (_) {
      _sops = [];
    }
    if (mounted) setState(() => _loading = false);
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

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _sops;
    final q = _search.toLowerCase();
    return _sops
        .where(
          (s) =>
              '${s['name'] ?? ''}'.toLowerCase().contains(q) ||
              '${s['industry'] ?? ''}'.toLowerCase().contains(q),
        )
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

  void _confirmDelete(Map<String, dynamic> sop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete SOP',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${sop['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteSop(sop['id']);
                _msg('SOP deleted');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + Create
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search SOPs...',
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SopBuilderScreen()),
                ).then((_) => _load()),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_filtered.length} SOPs',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No SOPs found',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _sopTile(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sopTile(Map<String, dynamic> sop) {
    final name = sop['name'] ?? 'Unnamed';
    final industry = sop['industry'] ?? '';
    final status = sop['status'] ?? '';
    final sectionCount =
        sop['sectionCount'] ?? (sop['sections'] as List?)?.length ?? 0;
    final questionCount = sop['questionCount'] ?? 0;
    final category = sop['category']?['name'] ?? '';
    final stage = sop['interactionStage']?['name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      industry,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'ACTIVE'
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: status == 'ACTIVE'
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip('$sectionCount sections', AppColors.primary),
              _chip('$questionCount questions', AppColors.accent),
              if (category.isNotEmpty) _chip(category, AppColors.textSecondary),
              if (stage.isNotEmpty) _chip(stage, AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(Icons.edit_outlined, AppColors.primary, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SopBuilderScreen(editId: sop['id']),
                  ),
                ).then((_) => _load());
              }),
              const SizedBox(width: 8),
              _actionBtn(
                Icons.delete_outline,
                AppColors.error,
                () => _confirmDelete(sop),
              ),
            ],
          ),
        ],
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

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}
