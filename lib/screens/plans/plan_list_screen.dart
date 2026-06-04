import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class PlanListScreen extends StatefulWidget {
  const PlanListScreen({super.key});
  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getPlans();
      _plans = _parseList(res.data);
    } catch (_) {
      _plans = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _plans;
    final q = _search.toLowerCase();
    return _plans.where((p) => '${p['name'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name'] ?? '');
    final description = TextEditingController(text: existing?['description'] ?? '');
    final price = TextEditingController(text: existing?['price']?.toString() ?? '');
    final credits = TextEditingController(text: existing?['credits']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(isEdit ? 'Edit Plan' : 'New Plan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              _field(name, 'Plan Name *'),
              const SizedBox(height: 10),
              _field(description, 'Description'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(price, 'Price (₹) *', type: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(child: _field(credits, 'Credits *', type: TextInputType.number)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _save(ctx, isEdit: isEdit, id: existing?['id'], name: name.text, description: description.text, price: price.text, credits: credits.text),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(isEdit ? 'Update Plan' : 'Create Plan'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _save(BuildContext ctx, {required bool isEdit, String? id, required String name, required String description, required String price, required String credits}) async {
    if (name.trim().isEmpty) { _msg('Name is required', error: true); return; }
    final priceVal = double.tryParse(price);
    final creditsVal = int.tryParse(credits);
    if (priceVal == null) { _msg('Enter a valid price', error: true); return; }
    if (creditsVal == null) { _msg('Enter valid credits', error: true); return; }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        await _api.updatePlan(id, {'name': name.trim(), if (description.trim().isNotEmpty) 'description': description.trim(), 'price': priceVal, 'credits': creditsVal});
        _msg('Plan updated');
      } else {
        await _api.createPlan(name: name.trim(), description: description.trim().isNotEmpty ? description.trim() : null, price: priceVal, credits: creditsVal);
        _msg('Plan created');
      }
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
      setState(() => _loading = false);
    }
  }

  void _confirmDelete(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${plan['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deletePlan(plan['id']); _msg('Plan deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(Map<String, dynamic> plan) async {
    final isActive = plan['status'] == 'ACTIVE';
    try {
      await _api.updatePlanStatus(plan['id'], isActive ? 'INACTIVE' : 'ACTIVE');
      _msg('Status updated');
      _load();
    } catch (e) { _msg('Failed: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search plans...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.surfaceLight)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showForm(),
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text('${_filtered.length} plans', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
            ? const Center(child: Text('No plans found', style: TextStyle(color: AppColors.textHint)))
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
    ]);
  }

  Widget _tile(Map<String, dynamic> plan) {
    final isActive = plan['status'] == 'ACTIVE';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: isActive ? AppColors.primarySurface : AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_rounded, color: isActive ? AppColors.primary : AppColors.textHint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${plan['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (plan['description'] != null && '${plan['description']}'.isNotEmpty)
              Text('${plan['description']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${plan['status'] ?? ''}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.error)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _badge('₹${plan['price'] ?? 0}', AppColors.success),
          const SizedBox(width: 8),
          _badge('${plan['credits'] ?? 0} credits', AppColors.primary),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: plan)),
          const SizedBox(width: 8),
          _actionBtn(isActive ? Icons.block_rounded : Icons.check_circle_outline, isActive ? AppColors.warning : AppColors.success, () => _toggleStatus(plan)),
          const SizedBox(width: 8),
          _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(plan)),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
