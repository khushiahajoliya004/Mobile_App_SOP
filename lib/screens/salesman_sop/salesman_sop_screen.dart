import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class SalesmanSopScreen extends StatefulWidget {
  const SalesmanSopScreen({super.key});
  @override
  State<SalesmanSopScreen> createState() => _SalesmanSopScreenState();
}

class _SalesmanSopScreenState extends State<SalesmanSopScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _sops = [];
  Map<String, dynamic>? _selectedSop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSops();
      final raw = res.data;
      _sops = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _sops = []; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDetail(String id) async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSop(id);
      final raw = res.data;
      _selectedSop = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
    } catch (_) { _selectedSop = null; }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSop != null) return _detailView();
    return _listView();
  }

  Widget _listView() {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('SOP Checklist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 18, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _sops.isEmpty
            ? const Center(child: Text('No SOPs assigned', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sops.length,
                  itemBuilder: (_, i) => _sopTile(_sops[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _sopTile(Map<String, dynamic> sop) {
    final name = sop['name'] ?? 'SOP';
    final industry = sop['industry'] ?? sop['industryName'] ?? '';
    final customerType = sop['customerType'] ?? '';
    final sections = (sop['sections'] as List?)?.length ?? 0;
    final status = sop['status'] ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';

    return GestureDetector(
      onTap: () => _loadDetail(sop['id'].toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primarySurface : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_rounded, color: isActive ? AppColors.primary : AppColors.textHint, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (industry.isNotEmpty || customerType.isNotEmpty)
              Text([industry, customerType].where((s) => s.isNotEmpty).join(' • '), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('$sections sections', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.textHint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.textHint)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textHint),
          ]),
        ]),
      ),
    );
  }

  Widget _detailView() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final sop = _selectedSop!;
    final sections = (sop['sections'] as List?)?.map((s) => Map<String, dynamic>.from(s)).toList() ?? [];
    final name = sop['name'] ?? 'SOP';
    final industry = sop['industry'] ?? sop['industryName'] ?? '';
    final extractionGoal = sop['extractionGoal'] ?? sop['description'] ?? '';

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _selectedSop = null)),
          Expanded(child: Text('$name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          if (industry.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
              child: Text(industry, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (extractionGoal.toString().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('$extractionGoal', style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.5))),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (sections.isEmpty)
            const Center(child: Text('No sections defined', style: TextStyle(color: AppColors.textHint)))
          else ...[
            Text('${sections.length} Sections', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...sections.asMap().entries.map((entry) {
              final s = entry.value;
              final sectionName = s['name'] ?? s['title'] ?? 'Section ${entry.key + 1}';
              final weightage = (s['weightage'] ?? s['weight'] ?? 0) as num;
              final questions = (s['questions'] ?? s['extractionPoints'] ?? []) as List;
              final actions = (s['requiredActions'] ?? s['actions'] ?? []) as List;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: CircleAvatar(radius: 14, backgroundColor: AppColors.primarySurface, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                    title: Text('$sectionName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: weightage > 0 ? Text('${weightage.toStringAsFixed(0)}% weight', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
                    children: [
                      if (questions.isNotEmpty) ...[
                        const Text('Questions / Extraction Points', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        ...questions.map((q) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              q is Map ? (q['question'] ?? q['text'] ?? q['extractionPoint'] ?? '') : '$q',
                              style: const TextStyle(fontSize: 12),
                            )),
                          ]),
                        )),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Required Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        ...actions.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.arrow_right_rounded, size: 16, color: AppColors.accent),
                            Expanded(child: Text(
                              a is Map ? (a['action'] ?? a['text'] ?? a['description'] ?? '') : '$a',
                              style: const TextStyle(fontSize: 12),
                            )),
                          ]),
                        )),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ]),
      )),
    ]);
  }
}
