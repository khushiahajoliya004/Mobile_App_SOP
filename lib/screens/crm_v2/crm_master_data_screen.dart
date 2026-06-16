import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmMasterDataScreen extends StatefulWidget {
  const CrmMasterDataScreen({super.key});
  @override
  State<CrmMasterDataScreen> createState() => _CrmMasterDataScreenState();
}

class _CrmMasterDataScreenState extends State<CrmMasterDataScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;

  // masterType key → display label, help text
  static const _categories = [
    _Cat('LEAD_SOURCE',       'Lead Sources',      'Track where your leads are coming from to measure marketing effectiveness.'),
    _Cat('LOST_REASON',       'Lost Reasons',      'Capture why deals are lost to improve future conversions.'),
    _Cat('FOLLOW_UP_TYPE',    'Follow-up Types',   'Types of follow-up interactions logged with contacts and deals.'),
    _Cat('BUYER_TYPE',        'Buyer Types',       'Classify buyers to tailor your sales approach.'),
    _Cat('FUEL_TYPE',         'Fuel Types',        'Fuel type options used in vehicle/product enquiries.'),
    _Cat('TRANSMISSION_TYPE', 'Transmission',      'Transmission type options for vehicle enquiries.'),
    _Cat('VEHICLE_COLOR',     'Vehicle Colors',    'Color options available for vehicle enquiries.'),
    _Cat('DOCUMENT_CHECKLIST','Document Checklist','Documents required during the deal closure process.'),
  ];

  // Loaded items per masterType
  final Map<String, List<Map<String, dynamic>>> _items = {};
  final Map<String, bool> _loading = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
    for (final cat in _categories) {
      _controllers[cat.type] = TextEditingController();
      _items[cat.type] = [];
      _loading[cat.type] = false;
    }
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _loadTab(_categories[_tab.index].type);
    });
    _loadTab(_categories[0].type);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadTab(String masterType) async {
    if (_loading[masterType] == true) return;
    setState(() => _loading[masterType] = true);
    try {
      final res = await _api.getMasters(masterType);
      final raw = res.data;
      final list = raw is Map ? (raw['data'] ?? []) as List : (raw is List ? raw : []);
      if (mounted) {
        setState(() {
          _items[masterType] = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading[masterType] = false);
  }

  Future<void> _addItem(String masterType) async {
    final ctrl = _controllers[masterType]!;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      final res = await _api.createMaster(masterType, name);
      final raw = res.data;
      final newItem = raw is Map ? (raw['data'] ?? raw) : null;
      if (newItem != null && mounted) {
        ctrl.clear();
        setState(() => _items[masterType]!.add(Map<String, dynamic>.from(newItem as Map)));
      }
    } catch (e) {
      _snack('Failed to add: $e');
    }
  }

  Future<void> _deleteItem(String masterType, String id) async {
    try {
      await _api.deleteMaster(id);
      if (mounted) {
        setState(() => _items[masterType]!.removeWhere((m) => m['id'].toString() == id));
      }
    } catch (e) {
      _snack('Failed to delete: $e');
    }
  }

  Future<void> _toggleStatus(String masterType, String id, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await _api.toggleMasterStatus(id, newStatus);
      if (mounted) {
        setState(() {
          final idx = _items[masterType]!.indexWhere((m) => m['id'].toString() == id);
          if (idx != -1) _items[masterType]![idx]['status'] = newStatus;
        });
      }
    } catch (e) {
      _snack('Failed to update: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Color _tabColor(int index) {
    const colors = [AppColors.primary, AppColors.success, AppColors.error, AppColors.accent, AppColors.warning, Color(0xFF0D9488), Color(0xFF8B5CF6), Color(0xFF0EA5E9)];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _categories.map((c) => Tab(text: c.label)).toList(),
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: _categories.asMap().entries.map((e) => _categoryTab(e.value, e.key)).toList(),
        ),
      ),
    ]);
  }

  Widget _categoryTab(_Cat cat, int index) {
    final color = _tabColor(index);
    final items = _items[cat.type] ?? [];
    final loading = _loading[cat.type] == true;
    final ctrl = _controllers[cat.type]!;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadTab(cat.type),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Help text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(cat.help, style: TextStyle(fontSize: 12, color: color, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),

          // Add field
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Add new ${cat.label.toLowerCase().replaceAll(RegExp(r's$'), '')}...',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _addItem(cat.type),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addItem(cat.type),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Items list
          if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ))
          else if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No ${cat.label} yet', style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Add one using the field above', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                ]),
              ),
            )
          else
            ...items.map((item) {
              final id = item['id'].toString();
              final name = item['name']?.toString() ?? '';
              final isActive = (item['status']?.toString() ?? 'ACTIVE') == 'ACTIVE';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? color.withValues(alpha: 0.2) : Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? color : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.textPrimary : AppColors.textHint,
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  // Toggle active/inactive
                  GestureDetector(
                    onTap: () => _toggleStatus(cat.type, id, item['status']?.toString() ?? 'ACTIVE'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? color : Colors.grey[500]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  GestureDetector(
                    onTap: () => _confirmDelete(cat.type, id, name),
                    child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  ),
                ]),
              );
            }),

          const SizedBox(height: 8),
          Text('${items.length} items · ${items.where((m) => (m['status']?.toString() ?? 'ACTIVE') == 'ACTIVE').length} active',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }

  void _confirmDelete(String masterType, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete "$name"? This may affect existing records that use this value.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deleteItem(masterType, id); },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _Cat {
  final String type, label, help;
  const _Cat(this.type, this.label, this.help);
}
