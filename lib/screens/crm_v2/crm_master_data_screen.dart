import 'package:flutter/material.dart';
import '../../main.dart';

class CrmMasterDataScreen extends StatefulWidget {
  const CrmMasterDataScreen({super.key});
  @override
  State<CrmMasterDataScreen> createState() => _CrmMasterDataScreenState();
}

class _CrmMasterDataScreenState extends State<CrmMasterDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Local master data (same as website — these are reference items, no API)
  final Map<String, List<String>> _data = {
    'Lead Sources': ['Walk-in', 'Website', 'Referral', 'Phone', 'Social Media', 'Advertisement', 'Partner', 'Event'],
    'Lifecycle Stages': ['Lead', 'Qualified', 'Opportunity', 'Customer', 'Evangelist'],
    'Lost Reasons': ['Price too high', 'Competitor won', 'No budget', 'Bad timing', 'No response', 'Feature missing', 'Other'],
    'Activity Types': ['Note', 'Call', 'Email', 'Meeting', 'Task', 'Demo', 'Site Visit'],
    'Priorities': ['Low', 'Medium', 'High', 'Urgent'],
  };

  final Map<String, String> _helpText = {
    'Lead Sources': 'Track where your leads are coming from to measure marketing effectiveness.',
    'Lifecycle Stages': 'Define the stages a contact moves through from lead to customer.',
    'Lost Reasons': 'Capture why deals are lost to improve future conversions.',
    'Activity Types': 'Types of interactions you log with contacts and deals.',
    'Priorities': 'Priority levels used for deals, tasks, and follow-ups.',
  };

  final Map<String, TextEditingController> _controllers = {};

  static const _categories = ['Lead Sources', 'Lifecycle Stages', 'Lost Reasons', 'Activity Types', 'Priorities'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
    for (final cat in _categories) {
      _controllers[cat] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final ctrl in _controllers.values) { ctrl.dispose(); }
    super.dispose();
  }

  void _addItem(String category) {
    final ctrl = _controllers[category]!;
    final val = ctrl.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _data[category]!.add(val);
      ctrl.clear();
    });
  }

  void _removeItem(String category, int index) {
    setState(() => _data[category]!.removeAt(index));
  }

  Color _tabColor(int index) {
    const colors = [AppColors.primary, AppColors.success, AppColors.error, AppColors.accent, AppColors.warning];
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
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

  Widget _categoryTab(String category, int index) {
    final items = _data[category] ?? [];
    final ctrl = _controllers[category]!;
    final help = _helpText[category] ?? '';
    final color = _tabColor(index);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (help.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(help, style: TextStyle(fontSize: 12, color: color, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.asMap().entries.map((e) => Chip(
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () => _removeItem(category, e.key),
            backgroundColor: color.withValues(alpha: 0.1),
            deleteIconColor: color,
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          )).toList(),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Add new item...',
                filled: true, fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => _addItem(category),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _addItem(category),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${items.length} items', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
      ]),
    );
  }
}
