import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_contact_detail_screen.dart';

class CrmContactsScreen extends StatefulWidget {
  const CrmContactsScreen({super.key});
  @override
  State<CrmContactsScreen> createState() => _CrmContactsScreenState();
}

class _CrmContactsScreenState extends State<CrmContactsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  String _search = '';
  String? _filterStage;

  static const _stages = ['LEAD', 'QUALIFIED', 'OPPORTUNITY', 'CUSTOMER'];
  static const _sources = ['WALK_IN', 'WEBSITE', 'REFERRAL', 'PHONE', 'SOCIAL', 'ADVERTISEMENT'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCrmContacts(search: _search.isNotEmpty ? _search : null);
      _contacts = _parseList(res.data);
      if (_filterStage != null) {
        _contacts = _contacts.where((c) => c['lifecycleStage'] == _filterStage).toList();
      }
    } catch (_) { _contacts = []; }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) return ((raw['data'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
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
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final email = TextEditingController(text: existing?['email'] ?? '');
    final companyName = TextEditingController(text: existing?['companyName'] ?? '');
    final city = TextEditingController(text: existing?['city'] ?? '');
    final state = TextEditingController(text: existing?['state'] ?? '');
    String? selectedSource = existing?['source'];
    String? selectedStage = existing?['lifecycleStage'] ?? 'LEAD';

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
                  Expanded(child: Text(isEdit ? 'Edit Contact' : 'New Contact', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                _field(name, 'Full Name *'),
                const SizedBox(height: 10),
                _field(phone, 'Phone', type: TextInputType.phone),
                const SizedBox(height: 10),
                _field(email, 'Email', type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(companyName, 'Company Name'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(city, 'City')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(state, 'State')),
                ]),
                const SizedBox(height: 10),
                const Text('Source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedSource, 'Select source', [
                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 14))),
                  ..._sources.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedSource = v)),
                const SizedBox(height: 10),
                const Text('Lifecycle Stage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _dropdown<String>(selectedStage, 'Select stage', [
                  ..._stages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))),
                ], (v) => setSheet(() => selectedStage = v)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _save(ctx, isEdit: isEdit, id: existing?['id'], name: name.text, phone: phone.text, email: email.text, companyName: companyName.text, city: city.text, state: state.text, source: selectedSource, lifecycleStage: selectedStage),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isEdit ? 'Update Contact' : 'Create Contact'),
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

  Future<void> _save(BuildContext ctx, {required bool isEdit, String? id, required String name, required String phone, required String email, required String companyName, required String city, required String state, String? source, String? lifecycleStage}) async {
    if (name.trim().isEmpty) { _msg('Name is required', error: true); return; }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        await _api.updateCrmContact(id, {
          'name': name.trim(),
          if (phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (email.trim().isNotEmpty) 'email': email.trim(),
          if (companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
          if (city.trim().isNotEmpty) 'city': city.trim(),
          if (state.trim().isNotEmpty) 'state': state.trim(),
          if (source != null) 'source': source,
          if (lifecycleStage != null) 'lifecycleStage': lifecycleStage,
        });
        _msg('Contact updated');
      } else {
        await _api.createCrmContact(
          name: name.trim(),
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          email: email.trim().isNotEmpty ? email.trim() : null,
          companyName: companyName.trim().isNotEmpty ? companyName.trim() : null,
          city: city.trim().isNotEmpty ? city.trim() : null,
          state: state.trim().isNotEmpty ? state.trim() : null,
          source: source,
          lifecycleStage: lifecycleStage,
        );
        _msg('Contact created');
      }
      _load();
    } catch (e) { _msg('Failed: $e', error: true); setState(() => _loading = false); }
  }

  void _confirmDelete(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete "${contact['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try { await _api.deleteCrmContact(contact['id']); _msg('Contact deleted'); _load(); } catch (e) { _msg('Failed: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _stageColor(String? stage) {
    switch (stage) {
      case 'LEAD': return AppColors.primary;
      case 'QUALIFIED': return AppColors.accent;
      case 'OPPORTUNITY': return AppColors.warning;
      case 'CUSTOMER': return AppColors.success;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) { _search = v; _load(); },
              decoration: InputDecoration(
                hintText: 'Search contacts...',
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
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22)),
          ),
        ]),
      ),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _stageChip('All', null),
            ..._stages.map((s) => _stageChip(s, s)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text('${_contacts.length} contacts', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          GestureDetector(onTap: _load, child: const Icon(Icons.refresh, size: 16, color: AppColors.primary)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _contacts.isEmpty
            ? const Center(child: Text('No contacts found', style: TextStyle(color: AppColors.textHint)))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) => _tile(_contacts[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _stageChip(String label, String? stage) {
    final selected = _filterStage == stage;
    return GestureDetector(
      onTap: () { setState(() => _filterStage = stage); _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> contact) {
    final name = '${contact['name'] ?? ''}';
    final phone = '${contact['phone'] ?? ''}';
    final email = '${contact['email'] ?? ''}';
    final stage = contact['lifecycleStage'];
    final source = contact['source'];
    final leadScore = (contact['leadScore'] as num?)?.toInt() ?? 0;
    final stageColor = _stageColor(stage);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: stageColor.withValues(alpha: 0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: stageColor, fontWeight: FontWeight.w700, fontSize: 14))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (phone.isNotEmpty) Text(phone, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (email.isNotEmpty && phone.isEmpty) Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (stage != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(stage, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stageColor)),
            ),
            if (leadScore > 0) ...[
              const SizedBox(height: 4),
              Text('Score: $leadScore', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ]),
        ]),
        if (source != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
            child: Text(source, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _actionBtn(Icons.open_in_new_rounded, AppColors.accent, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CrmContactDetailScreen(contactId: contact['id'].toString(), contactName: name)));
          }),
          const SizedBox(width: 8),
          _actionBtn(Icons.edit_outlined, AppColors.primary, () => _showForm(existing: contact)),
          const SizedBox(width: 8),
          _actionBtn(Icons.delete_outline, AppColors.error, () => _confirmDelete(contact)),
        ]),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
  );
}
