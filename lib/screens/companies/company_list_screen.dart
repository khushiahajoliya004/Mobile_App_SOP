import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});
  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _distributors = [];
  List<Map<String, dynamic>> _industries = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await Future.wait([_loadCompanies(), _loadDistributors(), _loadIndustries()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCompanies() async {
    try {
      final res = await _api.getCompanies();
      _companies = _parseList(res.data);
    } catch (_) {
      _companies = [];
    }
  }

  Future<void> _loadDistributors() async {
    try {
      final res = await _api.getDistributors();
      _distributors = _parseList(res.data)
          .where((d) => d['status'] == 'ACTIVE')
          .toList();
    } catch (_) {
      _distributors = [];
    }
  }

  Future<void> _loadIndustries() async {
    try {
      final res = await _api.getIndustries();
      _industries = _parseList(res.data)
          .where((i) => (i['status'] ?? 'ACTIVE') == 'ACTIVE')
          .toList();
    } catch (_) {
      _industries = [];
    }
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
    if (_search.isEmpty) return _companies;
    final q = _search.toLowerCase();
    return _companies.where((c) {
      return '${c['name'] ?? ''}'.toLowerCase().contains(q) ||
          '${c['email'] ?? ''}'.toLowerCase().contains(q) ||
          '${c['contactPerson'] ?? ''}'.toLowerCase().contains(q);
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
    final contactPerson = TextEditingController(
      text: existing?['contactPerson'] ?? '',
    );
    final gstNumber = TextEditingController(text: existing?['gstNumber'] ?? '');
    final website = TextEditingController(text: existing?['website'] ?? '');
    final password = TextEditingController();
    final state = TextEditingController(text: existing?['state'] ?? '');
    final evaluationFocus = TextEditingController(
      text: existing?['evaluationFocus'] ?? '',
    );

    String? selectedDistributorId = existing?['distributorId'];
    String? selectedIndustryId = existing?['industryId'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Company' : 'New Company',
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

                // Basic fields
                _field(name, 'Company Name *'),
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
                const SizedBox(height: 10),
                _field(website, 'Website', type: TextInputType.url),
                const SizedBox(height: 10),
                _field(state, 'State'),
                const SizedBox(height: 10),
                _field(evaluationFocus, 'Evaluation Focus'),
                const SizedBox(height: 10),

                // Admin password (create only)
                if (!isEdit) ...[
                  _field(password, 'Admin Password (min 6 chars)', obscure: true),
                  const SizedBox(height: 10),
                ],

                // Distributor selector
                const Text(
                  'Distributor *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedDistributorId,
                      isExpanded: true,
                      hint: const Text(
                        'Select distributor',
                        style: TextStyle(fontSize: 14),
                      ),
                      items: _distributors.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'] as String,
                          child: Text(
                            '${d['name']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setSheet(() => selectedDistributorId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Industry selector
                const Text(
                  'Industry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedIndustryId,
                      isExpanded: true,
                      hint: const Text(
                        'Select industry',
                        style: TextStyle(fontSize: 14),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None', style: TextStyle(fontSize: 14)),
                        ),
                        ..._industries.map((i) {
                          return DropdownMenuItem<String>(
                            value: i['id'] as String,
                            child: Text(
                              '${i['name']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) => setSheet(() => selectedIndustryId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Save button
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
                      website: website.text,
                      password: password.text,
                      state: state.text,
                      evaluationFocus: evaluationFocus.text,
                      distributorId: selectedDistributorId,
                      industryId: selectedIndustryId,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEdit ? 'Update Company' : 'Create Company'),
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

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    required String website,
    required String password,
    required String state,
    required String evaluationFocus,
    String? distributorId,
    String? industryId,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _msg('Name and email are required', error: true);
      return;
    }
    if (distributorId == null || distributorId.isEmpty) {
      _msg('Please select a distributor', error: true);
      return;
    }
    Navigator.pop(ctx);
    setState(() => _loading = true);
    try {
      if (isEdit && id != null) {
        final data = <String, dynamic>{
          'name': name.trim(),
          'email': email.trim(),
          'distributorId': distributorId,
          if (phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (address.trim().isNotEmpty) 'address': address.trim(),
          if (contactPerson.trim().isNotEmpty)
            'contactPerson': contactPerson.trim(),
          if (gstNumber.trim().isNotEmpty) 'gstNumber': gstNumber.trim(),
          if (website.trim().isNotEmpty) 'website': website.trim(),
          if (state.trim().isNotEmpty) 'state': state.trim(),
          if (evaluationFocus.trim().isNotEmpty)
            'evaluationFocus': evaluationFocus.trim(),
          if (industryId != null) 'industryId': industryId,
        };
        await _api.updateCompany(id, data);
        _msg('Company updated');
      } else {
        await _api.createCompany(
          name: name.trim(),
          email: email.trim(),
          distributorId: distributorId,
          phone: phone.trim().isNotEmpty ? phone.trim() : null,
          address: address.trim().isNotEmpty ? address.trim() : null,
          contactPerson:
              contactPerson.trim().isNotEmpty ? contactPerson.trim() : null,
          gstNumber: gstNumber.trim().isNotEmpty ? gstNumber.trim() : null,
          website: website.trim().isNotEmpty ? website.trim() : null,
          password: password.trim().isNotEmpty ? password.trim() : null,
          industryId: industryId,
          state: state.trim().isNotEmpty ? state.trim() : null,
          evaluationFocus:
              evaluationFocus.trim().isNotEmpty ? evaluationFocus.trim() : null,
        );
        _msg('Company created');
      }
      await _loadCompanies();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      _msg('Failed: $e', error: true);
      setState(() => _loading = false);
    }
  }

  void _confirmDelete(Map<String, dynamic> company) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Company',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Delete "${company['name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteCompany(company['id']);
                _msg('Company deleted');
                _loadCompanies();
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

  void _confirmToggleStatus(Map<String, dynamic> company) {
    final isActive = company['status'] == 'ACTIVE';
    final action = isActive ? 'Deactivate' : 'Activate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$action Company',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('$action "${company['name']}"?'),
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
                await _api.updateCompanyStatus(company['id'], newStatus);
                _msg('Status updated');
                _loadCompanies();
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
                    hintText: 'Search companies...',
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
                '${_filtered.length} companies',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _init,
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
                    'No companies found',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _init,
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

  Widget _tile(Map<String, dynamic> company) {
    final name = '${company['name'] ?? ''}';
    final email = '${company['email'] ?? ''}';
    final phone = '${company['phone'] ?? ''}';
    final contactPerson = '${company['contactPerson'] ?? ''}';
    final status = '${company['status'] ?? ''}';
    final distributorName = company['distributor']?['name'] ?? '';
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
                  Icons.business_rounded,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            runSpacing: 4,
            children: [
              if (phone.isNotEmpty) _info(Icons.phone_outlined, phone),
              if (contactPerson.isNotEmpty)
                _info(Icons.person_outline_rounded, contactPerson),
              if (distributorName.isNotEmpty)
                _info(Icons.store_mall_directory_rounded, distributorName),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(
                Icons.edit_outlined,
                AppColors.primary,
                () => _showForm(existing: company),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline,
                isActive ? AppColors.warning : AppColors.success,
                () => _confirmToggleStatus(company),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                Icons.delete_outline,
                AppColors.error,
                () => _confirmDelete(company),
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
