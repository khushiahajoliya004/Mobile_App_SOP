import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class DistributorListScreen extends StatefulWidget {
  const DistributorListScreen({super.key});
  @override
  State<DistributorListScreen> createState() => _DistributorListScreenState();
}

class _DistributorListScreenState extends State<DistributorListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _distributors = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDistributors();
      _distributors = _parseList(res.data);
    } catch (_) {
      _distributors = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map) {
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _distributors;
    final q = _search.toLowerCase();
    return _distributors.where((d) {
      return '${d['name'] ?? ''}'.toLowerCase().contains(q) ||
          '${d['email'] ?? ''}'.toLowerCase().contains(q) ||
          '${d['contactPerson'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
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
    final name = TextEditingController(text: existing?['name'] ?? '');
    final email = TextEditingController(text: existing?['email'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final address = TextEditingController(text: existing?['address'] ?? '');
    final contactPerson = TextEditingController(text: existing?['contactPerson'] ?? '');
    final gstNumber = TextEditingController(text: existing?['gstNumber'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Distributor' : 'New Distributor',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(name, 'Name *'),
              const SizedBox(height: 10),
              _field(email, 'Email *', type: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _field(phone, 'Phone', type: TextInputType.phone),
              const SizedBox(height: 10),
              _field(contactPerson, 'Contact Person'),
              const SizedBox(height: 10),
              _field(address, 'Address'),
              const SizedBox(height: 10),
              _field(gstNumber, 'GST Number'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _save(
                    ctx,
                    isEdit: isEdit,
                    id: existing?['id'],
                    name: name.text,
                    email: email.text,
                    phone: phone.text,
                    address: address.text,
                    contactPerson: contactPerson.text,
                    gstNumber: gstNumber.text,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isEdit ? 'Update Distributor' : 'Create Distributor'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _save(
    BuildContext ctx, {
    required bool isEdit,
    String? id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required String contactPerson,
    required String gstNumber,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _msg('Name and email are required', error: true);
      return;
    }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        await _api.updateDistributor(id, {
          'name': name.trim(),
          'email': email.trim(),
          if (phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (address.trim().isNotEmpty) 'address': address.trim(),
          if (contactPerson.trim().isNotEmpty) 'contactPerson': contactPerson.trim(),
          if (gstNumber.trim().isNotEmpty) 'gstNumber': gstNumber.trim(),
        });
        _msg('Distributor updated');
      } else {
        await _api.createDistributor(
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          address: address.trim().isNotEmpty ? address.trim() : null,
          contactPerson: contactPerson.trim().isNotEmpty ? contactPerson.trim() : null,
          gstNumber: gstNumber.trim().isNotEmpty ? gstNumber.trim() : null,
        );
        _msg('Distributor created');
      }
      _load();
    } catch (e) {
      _msg('Failed: $e', error: true);
      setState(() => _loading = false);
    }
  }

  void _confirmDelete(Map<String, dynamic> dist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Distributor',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${dist['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteDistributor(dist['id']);
                _msg('Distributor deleted');
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

  void _confirmToggleStatus(Map<String, dynamic> dist) {
    final isActive = dist['status'] == 'ACTIVE';
    final action = isActive ? 'Deactivate' : 'Activate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$action Distributor',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('$action "${dist['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final newStatus = isActive ? 'INACTIVE' : 'ACTIVE';
                await _api.updateDistributorStatus(dist['id'], newStatus);
                _msg('Status updated');
                _load();
              } catch (e) {
                _msg('Failed: $e', error: true);
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + Add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search distributors...',
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
                onTap: () => _showForm(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_filtered.length} distributors',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
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
                    'No distributors found',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
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

  Widget _tile(Map<String, dynamic> dist) {
    final name = '${dist['name'] ?? ''}';
    final email = '${dist['email'] ?? ''}';
    final phone = '${dist['phone'] ?? ''}';
    final contactPerson = '${dist['contactPerson'] ?? ''}';
    final status = '${dist['status'] ?? ''}';
    final companiesCount = (dist['companies'] as List?)?.length ?? 0;
    final isActive = status == 'ACTIVE';

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
                  color: isActive
                      ? AppColors.primarySurface
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store_mall_directory_rounded,
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  size: 20,
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
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              if (phone.isNotEmpty)
                _info(Icons.phone_outlined, phone),
              if (contactPerson.isNotEmpty)
                _info(Icons.person_outline_rounded, contactPerson),
              _info(
                Icons.business_rounded,
                '$companiesCount ${companiesCount == 1 ? 'company' : 'companies'}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(
                Icons.edit_outlined,
                AppColors.primary,
                () => _showForm(existing: dist),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline,
                isActive ? AppColors.warning : AppColors.success,
                () => _confirmToggleStatus(dist),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                Icons.delete_outline,
                AppColors.error,
                () => _confirmDelete(dist),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
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
