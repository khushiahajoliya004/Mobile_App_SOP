import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AiCallConfigScreen extends StatefulWidget {
  const AiCallConfigScreen({super.key});
  @override
  State<AiCallConfigScreen> createState() => _AiCallConfigScreenState();
}

class _AiCallConfigScreenState extends State<AiCallConfigScreen> {
  final _api = ApiService();

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getAiCallNumbers(),
        _api.getCategories(),
      ]);

      final numRaw = results[0].data;
      List<dynamic> nums = numRaw is List ? numRaw : (numRaw is Map ? (numRaw['data'] ?? []) : []);

      final catRaw = results[1].data;
      List<dynamic> cats = catRaw is List ? catRaw : (catRaw is Map ? (catRaw['data'] ?? []) : []);

      if (mounted) {
        setState(() {
          _items = nums.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _categories = cats.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((n) =>
      (n['name'] ?? '').toString().toLowerCase().contains(q) ||
      (n['phoneNumber'] ?? '').toString().toLowerCase().contains(q) ||
      (n['category']?['name'] ?? '').toString().toLowerCase().contains(q),
    ).toList();
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _toggleStatus(Map<String, dynamic> item) async {
    final newStatus = item['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus == 'ACTIVE' ? 'Activate' : 'Deactivate'} "${item['name']}"?'),
        content: Text('Are you sure you want to ${newStatus == 'ACTIVE' ? 'activate' : 'deactivate'} this AI call number?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus == 'ACTIVE' ? 'Activate' : 'Deactivate',
                style: TextStyle(color: newStatus == 'ACTIVE' ? AppColors.success : AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.updateAiCallNumber(item['id'] as String, {'status': newStatus});
      _msg('Status updated');
      _load();
    } catch (_) {
      _msg('Failed to update status', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete AI Call Number'),
        content: Text('Delete "${item['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteAiCallNumber(item['id'] as String);
      _msg('Deleted');
      _load();
    } catch (_) {
      _msg('Failed to delete', error: true);
    }
  }

  void _openForm({Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiCallNumberForm(
        categories: _categories,
        existing: item,
        onSaved: (data) async {
          if (item != null) {
            await _api.updateAiCallNumber(item['id'] as String, data);
          } else {
            await _api.createAiCallNumber(data);
          }
          _load();
        },
      ),
    );
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
                Text('Call Configuration', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Manage AI calling numbers & scripts', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
            GestureDetector(
              onTap: () => _openForm(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),

        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by name or number...',
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
                  ? _buildEmpty()
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

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.phone_rounded, size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        const Text('No AI call numbers yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Tap "Add" to configure your first AI call number', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add AI Number'),
        ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final phone = item['phoneNumber']?.toString() ?? '';
    final category = item['category'] is Map ? item['category']['name']?.toString() : null;
    final isActive = item['status'] == 'ACTIVE';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.success : AppColors.textHint).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.textHint),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_rounded, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            if (category != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.account_tree_rounded, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Flexible(child: Text(category, style: const TextStyle(fontSize: 11, color: AppColors.textHint), overflow: TextOverflow.ellipsis)),
              ]),
            ] else ...[
              const SizedBox(height: 3),
              const Text('No script linked', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
            const SizedBox(height: 10),
            // Action buttons
            Row(children: [
              _actionChip(Icons.edit_rounded, 'Edit', AppColors.primary, () => _openForm(item: item)),
              const SizedBox(width: 8),
              _actionChip(
                isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                isActive ? 'Deactivate' : 'Activate',
                isActive ? AppColors.warning : AppColors.success,
                () => _toggleStatus(item),
              ),
              const SizedBox(width: 8),
              _actionChip(Icons.delete_outline_rounded, 'Delete', AppColors.error, () => _delete(item)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ─── Create / Edit Form ───────────────────────────────────────────────────────

class _AiCallNumberForm extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  const _AiCallNumberForm({required this.categories, this.existing, required this.onSaved});

  @override
  State<_AiCallNumberForm> createState() => _AiCallNumberFormState();
}

class _AiCallNumberFormState extends State<_AiCallNumberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _promptCtrl;
  String? _selectedCategoryId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: e?['phoneNumber']?.toString() ?? '');
    _promptCtrl = TextEditingController(text: e?['promptIntro']?.toString() ?? '');
    _selectedCategoryId = e?['categoryId']?.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty)
          'categoryId': _selectedCategoryId,
        if (_promptCtrl.text.trim().isNotEmpty)
          'promptIntro': _promptCtrl.text.trim(),
      };
      await widget.onSaved(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String msg = 'Failed to save';
      final s = e.toString();
      final match = RegExp(r'"message":"([^"]+)"').firstMatch(s);
      if (match != null) msg = match.group(1)!;
      if (mounted) setState(() { _saving = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.textHint.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: Row(children: [
              Expanded(child: Text(
                _isEdit ? 'Edit AI Call Number' : 'New AI Call Number',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              )),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 16),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _field('Name', _nameCtrl, hint: 'e.g. Hyundai Call Feedback', required: true),
                  const SizedBox(height: 14),
                  _field('AI Phone Number', _phoneCtrl, hint: 'e.g. +15550198234', required: true, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  // Category dropdown
                  const Text('Question Flow (Category)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        hint: const Text('Select category (optional)', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 13, color: AppColors.textHint))),
                          ...widget.categories.map((c) => DropdownMenuItem<String>(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                          )),
                        ],
                        onChanged: (v) => setState(() => _selectedCategoryId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Prompt intro
                  const Text('Prompt Intro (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _promptCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. You are Priya, an assistant for Hyundai. Speak warmly and professionally.',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEdit ? 'Update' : 'Create', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, bool required = false, TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        if (required) const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    ]);
  }
}
