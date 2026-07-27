import 'package:flutter/material.dart';
import '../../utils/error_helper.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmCustomPropertiesScreen extends StatefulWidget {
  const CrmCustomPropertiesScreen({super.key});
  @override
  State<CrmCustomPropertiesScreen> createState() => _CrmCustomPropertiesScreenState();
}

class _CrmCustomPropertiesScreenState extends State<CrmCustomPropertiesScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  bool _loading = true;
  List<Map<String, dynamic>> _properties = [];

  static const _objectTypes = ['CONTACT', 'DEAL', 'PRODUCT'];
  static const _fieldTypes = ['TEXT', 'NUMBER', 'DATE', 'BOOLEAN', 'SELECT', 'MULTI_SELECT', 'EMAIL', 'PHONE', 'URL'];

  String get _currentObjectType => _objectTypes[_tab.index];

  List<Map<String, dynamic>> get _filteredProperties =>
      _properties.where((p) => p['objectType'] == _currentObjectType).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _objectTypes.length, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) setState(() {}); });
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmProperties();
      final raw = res.data;
      _properties = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
          : ((raw is Map ? (raw['data'] ?? []) : []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { _properties = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['label'] ?? existing?['name'] ?? '');
    final keyCtrl = TextEditingController(text: existing?['fieldKey'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String selectedObjectType = existing?['objectType'] ?? _currentObjectType;
    String selectedFieldType = existing?['fieldType'] ?? _fieldTypes.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(isEdit ? 'Edit Property' : 'New Property', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                _field(nameCtrl, 'Label *'),
                const SizedBox(height: 10),
                _field(keyCtrl, 'Field Key *'),
                if (!isEdit) ...[
                  const SizedBox(height: 4),
                  const Text('Key must be unique, lowercase, no spaces (e.g. custom_field)', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                ],
                const SizedBox(height: 10),
                _field(descCtrl, 'Description (optional)'),
                const SizedBox(height: 10),
                const Text('Object Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedObjectType, 'Select object type', [
                  ..._objectTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedObjectType = v ?? _objectTypes.first)),
                const SizedBox(height: 10),
                const Text('Field Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedFieldType, 'Select field type', [
                  ..._fieldTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedFieldType = v ?? _fieldTypes.first)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) { _msg('Label is required', error: true); return; }
                      if (!isEdit && keyCtrl.text.trim().isEmpty) { _msg('Field key is required', error: true); return; }
                      Navigator.pop(ctx);
                      setState(() => _loading = true);
                      try {
                        if (isEdit) {
                          await _api.updateCrmProperty(existing!['id'] as String, {
                            'label': nameCtrl.text.trim(),
                            if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
                          });
                          _msg('Property updated');
                        } else {
                          await _api.createCrmProperty(
                            name: nameCtrl.text.trim(),
                            fieldKey: keyCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
                            fieldType: selectedFieldType,
                            objectType: selectedObjectType,
                            description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          );
                          _msg('Property created');
                        }
                        _load();
                      } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEdit ? 'Update Property' : 'Create Property'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Property', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${property['label'] ?? property['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deleteCrmProperty(property['id'] as String); _msg('Property deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdown<T>(T value, String hint, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(value: value, isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 14)), items: items, onChanged: onChanged),
      ),
    );
  }

  Color _fieldTypeColor(String? type) {
    switch (type) {
      case 'TEXT': case 'EMAIL': case 'URL': return AppColors.primary;
      case 'NUMBER': return AppColors.success;
      case 'DATE': return AppColors.accent;
      case 'BOOLEAN': return AppColors.warning;
      case 'SELECT': case 'MULTI_SELECT': return AppColors.error;
      case 'PHONE': return AppColors.primary;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProperties;
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _objectTypes.map((t) => Tab(text: t)).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Text('${filtered.length} properties', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showForm(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : filtered.isEmpty
            ? Center(child: Text('No ${_currentObjectType.toLowerCase()} properties', style: const TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _propertyTile(filtered[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _propertyTile(Map<String, dynamic> property) {
    final label = property['label'] ?? property['name'] ?? '';
    final fieldKey = property['fieldKey'] ?? '';
    final fieldType = property['fieldType'] as String?;
    final description = property['description'] ?? '';
    final isSystem = property['isSystem'] == true;
    final color = _fieldTypeColor(fieldType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('$label', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              if (isSystem) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.textHint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text('SYSTEM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textHint)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(fieldKey, style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontFamily: 'monospace')),
          ])),
          if (fieldType != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(fieldType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ]),
        if (description.toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('$description', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
        if (!isSystem) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: property)),
            const SizedBox(width: 8),
            _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(property)),
          ]),
        ],
      ]),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
