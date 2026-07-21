import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'call_flow_builder_screen.dart';

class CallFlowListScreen extends StatefulWidget {
  const CallFlowListScreen({super.key});
  @override
  State<CallFlowListScreen> createState() => _CallFlowListScreenState();
}

class _CallFlowListScreenState extends State<CallFlowListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _flows = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCallQuestionFlows();
      final raw = res.data;
      List<dynamic> list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
      if (mounted) {
        setState(() {
          _flows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _flows;
    final q = _search.toLowerCase();
    return _flows.where((f) =>
      (f['categoryName'] ?? '').toString().toLowerCase().contains(q),
    ).toList();
  }

  void _openBuilder(String categoryId, String categoryName) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallFlowBuilderScreen(categoryId: categoryId, categoryName: categoryName),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(children: [
        // Header
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 4, right: 16, bottom: 14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Call Question Flows', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Yes/No question trees for AI call scripts', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
          ]),
        ),

        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by category name...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
              : filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.account_tree_rounded, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        const Text('No question flows found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        const Text('Flows are linked to categories', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> flow) {
    final name = flow['categoryName']?.toString() ?? 'Unnamed';
    final count = (flow['questionCount'] as num?)?.toInt() ?? 0;
    final updatedAt = flow['updatedAt'] as String?;
    String dateStr = 'Never saved';
    if (updatedAt != null) {
      try {
        final dt = DateTime.parse(updatedAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    final hasFlow = count > 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _openBuilder(flow['categoryId'].toString(), name),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.help_outline_rounded, size: 12, color: hasFlow ? AppColors.success : AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  hasFlow ? '$count question${count == 1 ? '' : 's'}' : 'No flow yet',
                  style: TextStyle(fontSize: 12, color: hasFlow ? AppColors.success : AppColors.textHint, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ]),
      ),
    );
  }
}
