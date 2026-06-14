import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_reception_screen.dart';
import 'crm_screen.dart';

class CrmContactsScreen extends StatefulWidget {
  const CrmContactsScreen({super.key});
  @override
  State<CrmContactsScreen> createState() => _CrmContactsScreenState();
}

class _CrmContactsScreenState extends State<CrmContactsScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _owners = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;

  String? _stageFilter;
  String? _sourceFilter;
  String? _ownerFilter;

  Timer? _debounce;

  static const _stages = ['LEAD', 'PROSPECT', 'QUALIFIED', 'CUSTOMER', 'CHURNED'];
  static const _sources = ['WALK_IN', 'WEBSITE', 'REFERRAL', 'PHONE', 'SOCIAL', 'ADVERTISEMENT'];

  @override
  void initState() {
    super.initState();
    _loadOwners();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    try {
      final res = await _api.getUsers();
      final raw = res.data;
      List items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        final inner = raw['data'];
        if (inner is List) items = inner;
        else if (inner is Map) items = inner['data'] ?? inner['users'] ?? [];
        else items = raw['users'] ?? [];
      }
      if (mounted) {
        setState(() {
          _owners = items.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            // normalise display name
            if (m['name'] == null || m['name'].toString().isEmpty) {
              final fn = m['firstName']?.toString() ?? '';
              final ln = m['lastName']?.toString() ?? '';
              m['_displayName'] = '$fn $ln'.trim();
            } else {
              m['_displayName'] = m['name'].toString();
            }
            return m;
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      if (mounted) setState(() { _loading = true; _contacts = []; _page = 1; _hasMore = true; });
    } else {
      if (!_hasMore || _loadingMore) return;
      if (mounted) setState(() => _loadingMore = true);
    }

    try {
      final res = await _api.getCrmContacts(
        search: _searchCtrl.text.trim(),
        page: reset ? 1 : _page,
        limit: 20,
        lifecycleStage: _stageFilter,
        source: _sourceFilter,
        ownerUserId: _ownerFilter,
      );
      final raw = res.data;
      List items = [];
      int total = 0;
      if (raw is Map) {
        final data = raw['data'] ?? raw['contacts'] ?? raw;
        if (data is List) {
          items = data;
          total = (raw['total'] ?? raw['count'] ?? items.length) as int;
        } else if (data is Map) {
          items = (data['data'] ?? data['contacts'] ?? []) as List;
          total = (data['total'] ?? data['count'] ?? items.length) as int;
        }
      } else if (raw is List) {
        items = raw;
        total = raw.length;
      }
      final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          if (reset) {
            _contacts = parsed;
            _page = 2;
          } else {
            _contacts.addAll(parsed);
            _page++;
          }
          _total = total;
          _hasMore = _contacts.length < total && parsed.length == 20;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  void _showQuickLead() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CrmSubWrapper(
          title: 'Quick Lead',
          child: CrmReceptionScreen(),
        ),
      ),
    ).then((_) => _load(reset: true));
  }

  bool get _hasActiveFilter => _stageFilter != null || _sourceFilter != null || _ownerFilter != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(child: _searchBar()),
              const SizedBox(width: 8),
              _quickLeadBtn(),
            ],
          ),
        ),
        // Filter dropdowns row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: _stageDropdown()),
              const SizedBox(width: 6),
              Expanded(child: _sourceDropdown()),
              const SizedBox(width: 6),
              Expanded(child: _ownerDropdown()),
              if (_hasActiveFilter) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() { _stageFilter = null; _sourceFilter = null; _ownerFilter = null; });
                    _load(reset: true);
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Count row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text(
                '$_total contact${_total == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _load(reset: true),
                  child: _contacts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Icon(Icons.people_outline_rounded, size: 60, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            const Text('No contacts found', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Try adjusting your search or filters', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _contacts.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _contacts.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                              );
                            }
                            return _ContactCard(contact: _contacts[i]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, phone, email...',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 18),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
                  onPressed: () { _searchCtrl.clear(); _load(reset: true); },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _quickLeadBtn() {
    return GestureDetector(
      onTap: _showQuickLead,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Quick Lead', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _stageDropdown() {
    return _compactDropdown<String>(
      value: _stageFilter,
      hint: 'All Stages',
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All Stages')),
        ..._stages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))),
      ],
      onChanged: (v) { setState(() => _stageFilter = v); _load(reset: true); },
      activeColor: _stageFilter != null ? AppColors.primary : null,
    );
  }

  Widget _sourceDropdown() {
    return _compactDropdown<String>(
      value: _sourceFilter,
      hint: 'All Sources',
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All Sources')),
        ..._sources.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))),
      ],
      onChanged: (v) { setState(() => _sourceFilter = v); _load(reset: true); },
      activeColor: _sourceFilter != null ? const Color(0xFF0EA5E9) : null,
    );
  }

  Widget _ownerDropdown() {
    final ownerItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('All Owners')),
      ..._owners.map((u) {
        final id = u['id']?.toString() ?? '';
        final name = (u['_displayName']?.toString() ?? '').isNotEmpty
            ? u['_displayName'].toString()
            : id;
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }),
    ];
    return _compactDropdown<String>(
      value: _ownerFilter,
      hint: _owners.isEmpty ? 'Loading...' : 'All Owners',
      items: ownerItems,
      onChanged: (v) { setState(() => _ownerFilter = v); _load(reset: true); },
      activeColor: _ownerFilter != null ? AppColors.warning : null,
    );
  }

  Widget _compactDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    Color? activeColor,
  }) {
    final active = activeColor != null;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? activeColor : AppColors.textHint.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 10, color: active ? activeColor : AppColors.textHint, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          isExpanded: true,
          style: TextStyle(fontSize: 10, color: active ? activeColor : AppColors.textPrimary, fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: active ? activeColor : AppColors.textHint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  const _ContactCard({required this.contact});

  Color _stageColor(String? stage) {
    switch (stage?.toUpperCase()) {
      case 'LEAD': return AppColors.primary;
      case 'PROSPECT': return const Color(0xFF8B5CF6);
      case 'QUALIFIED': return AppColors.accent;
      case 'CUSTOMER': return AppColors.success;
      case 'CHURNED': return AppColors.error;
      default: return AppColors.textHint;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final name = contact['name']?.toString() ?? 'Unknown';
    final phone = contact['phone']?.toString() ?? '';
    final email = contact['email']?.toString() ?? '';
    final stage = contact['lifecycleStage']?.toString();
    final source = contact['source']?.toString() ?? '';
    final city = contact['city']?.toString() ?? '';
    final owner = contact['owner'];
    final ownerName = owner is Map
        ? (owner['name'] ?? owner['firstName'] ?? '').toString()
        : '';
    final stageColor = _stageColor(stage);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stageColor.withValues(alpha: 0.7), stageColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(name),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (stage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: stageColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: stageColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(stage,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stageColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (phone.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.phone_rounded, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.email_rounded, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(email,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (city.isNotEmpty || source.isNotEmpty || ownerName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (source.isNotEmpty) _chip(Icons.source_rounded, source),
                        if (city.isNotEmpty) _chip(Icons.location_on_rounded, city),
                        if (ownerName.isNotEmpty) _chip(Icons.person_rounded, ownerName),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: AppColors.textHint),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
