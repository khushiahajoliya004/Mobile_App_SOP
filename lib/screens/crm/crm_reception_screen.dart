import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import 'crm_lead_detail_screen.dart';

class CrmReceptionScreen extends StatefulWidget {
  const CrmReceptionScreen({super.key});

  @override
  State<CrmReceptionScreen> createState() => _CrmReceptionScreenState();
}

class _CrmReceptionScreenState extends State<CrmReceptionScreen> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();

  bool _searching = false;
  bool _searched = false;
  Map<String, dynamic>? _foundLead;
  String? _searchError;

  // Create new lead state
  bool _showCreate = false;
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _source = 'Walk-in';
  String _priority = 'MEDIUM';
  bool _creating = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _foundLead = null;
      _searched = false;
      _showCreate = false;
    });
    try {
      final res = await _api.checkDuplicateLead(phone);
      final raw = res.data;
      // Response: { isDuplicate: bool, lead: {...} } or { data: { isDuplicate, lead } }
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      final isDuplicate = data['isDuplicate'] == true || data['exists'] == true;
      final leadData = data['lead'] ?? data['existingLead'];

      setState(() {
        _searched = true;
        if (isDuplicate && leadData != null) {
          _foundLead = Map<String, dynamic>.from(leadData as Map);
        } else {
          _foundLead = null;
        }
      });
    } catch (e) {
      setState(() {
        _searched = true;
        _searchError = e.toString();
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _createNewLead() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Enter customer name');
      return;
    }
    setState(() => _creating = true);
    try {
      final res = await _api.createLead(
        customerName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        source: _source,
        priority: _priority,
      );
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      _showSnack('Lead created successfully', success: true);
      if (mounted) {
        setState(() {
          _showCreate = false;
          _searched = false;
          _foundLead = null;
        });
        _nameCtrl.clear();
        _notesCtrl.clear();
        // Navigate to the new lead detail
        final newLead = data is Map ? Map<String, dynamic>.from(data as Map) : {};
        if (newLead['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CrmLeadDetailScreen(
                leadId: newLead['id'].toString(),
                leadName: _nameCtrl.text.trim().isEmpty
                    ? newLead['customerName']?.toString() ?? 'New Lead'
                    : _nameCtrl.text.trim(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showSnack('Failed to create: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSearchCard(),
          const SizedBox(height: 16),
          if (_searched && !_searching) _buildResult(),
          if (_showCreate) ...[
            const SizedBox(height: 16),
            _buildCreateForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reception Desk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Search customer by phone number',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Phone Lookup',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Enter phone number...',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _phoneCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _phoneCtrl.clear();
                              setState(() {
                                _searched = false;
                                _foundLead = null;
                                _showCreate = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FilledButton(
                  onPressed: _searching ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_searchError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Search failed. Try again.',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_foundLead != null) {
      return _buildFoundLead(_foundLead!);
    }

    // Not found
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_search_rounded, size: 40, color: AppColors.warning),
          const SizedBox(height: 10),
          const Text(
            'No customer found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No lead with phone "${_phoneCtrl.text.trim()}"',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => setState(() => _showCreate = !_showCreate),
            icon: Icon(_showCreate ? Icons.keyboard_arrow_up : Icons.person_add_rounded),
            label: Text(_showCreate ? 'Cancel' : 'Create New Lead'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundLead(Map<String, dynamic> lead) {
    final status = lead['status']?.toString() ?? 'OPEN';
    final phone = lead['phone']?.toString() ?? _phoneCtrl.text.trim();
    String assignedName = 'Unassigned';
    final assignedTo = lead['assignedTo'];
    if (assignedTo is Map) {
      assignedName = '${assignedTo['firstName'] ?? ''} ${assignedTo['lastName'] ?? ''}'.trim();
    }

    Color statusColor;
    switch (status.toUpperCase()) {
      case 'CONVERTED':
        statusColor = AppColors.success;
        break;
      case 'LOST':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Customer Found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lead['customerName']?.toString() ?? 'Unknown',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                'Assigned: $assignedName',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrmLeadDetailScreen(
                      leadId: lead['id'].toString(),
                      leadName: lead['customerName']?.toString() ?? 'Lead',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'View Full Lead Details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create New Lead',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer Name *',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _source,
            decoration: const InputDecoration(labelText: 'Source'),
            items: ['Walk-in', 'Call', 'Website', 'Facebook', 'Instagram', 'Google Ads', 'Reference', 'Event', 'Other']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _source = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(value: 'HOT', child: Text('Hot')),
              DropdownMenuItem(value: 'WARM', child: Text('Warm')),
              DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
              DropdownMenuItem(value: 'COLD', child: Text('Cold')),
            ],
            onChanged: (v) => setState(() => _priority = v!),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _creating ? null : _createNewLead,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Create Lead',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
