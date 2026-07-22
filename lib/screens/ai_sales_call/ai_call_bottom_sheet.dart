import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

Future<void> showAiCallBottomSheet(
  BuildContext context, {
  required String targetName,
  String? leadId,
  String? contactId,
  String? dealId,
  VoidCallback? onSuccess,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiCallSheet(
      targetName: targetName,
      leadId: leadId,
      contactId: contactId,
      dealId: dealId,
      onSuccess: onSuccess,
    ),
  );
}

class _AiCallSheet extends StatefulWidget {
  final String targetName;
  final String? leadId;
  final String? contactId;
  final String? dealId;
  final VoidCallback? onSuccess;

  const _AiCallSheet({
    required this.targetName,
    this.leadId,
    this.contactId,
    this.dealId,
    this.onSuccess,
  });

  @override
  State<_AiCallSheet> createState() => _AiCallSheetState();
}

class _AiCallSheetState extends State<_AiCallSheet> {
  final _api = ApiService();

  bool _loadingNumbers = true;
  List<Map<String, dynamic>> _callNumbers = [];
  String? _selectedId;
  bool _calling = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNumbers();
  }

  Future<void> _fetchNumbers() async {
    try {
      final res = await _api.getAiCallNumbers();
      final raw = res.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        final d = raw['data'];
        if (d is List) list = d;
      }
      final active = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => (e['status'] ?? 'ACTIVE') == 'ACTIVE')
          .toList();
      if (mounted) {
        setState(() {
          _callNumbers = active;
          if (active.isNotEmpty) _selectedId = active.first['id'] as String?;
          _loadingNumbers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingNumbers = false; _error = 'Failed to load call numbers'; });
    }
  }

  Future<void> _startCall() async {
    if (_selectedId == null) return;
    final selected = _callNumbers.firstWhere((n) => n['id'] == _selectedId, orElse: () => {});
    final categoryId = selected['categoryId'] as String?;

    setState(() { _calling = true; _error = null; });
    try {
      await _api.initiateAiSalesCall(
        leadId: widget.leadId,
        contactId: widget.contactId,
        dealId: widget.dealId,
        categoryId: categoryId,
      );
      if (mounted) {
        setState(() { _calling = false; _success = true; });
        widget.onSuccess?.call();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      String msg = 'Failed to initiate call';
      final err = e.toString();
      if (err.contains('message')) {
        final match = RegExp(r'"message":"([^"]+)"').firstMatch(err);
        if (match != null) msg = match.group(1)!;
      }
      if (mounted) setState(() { _calling = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.textHint.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('AI Sales Call', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(widget.targetName, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _success
                ? _buildSuccess()
                : _loadingNumbers
                    ? const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                      ))
                    : _callNumbers.isEmpty
                        ? _buildEmpty()
                        : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
      ),
      const SizedBox(height: 14),
      const Text('AI Call Initiated!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('The AI agent will call the customer shortly.\nResults will be available once the call ends.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildEmpty() {
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.phone_disabled_rounded, color: AppColors.warning, size: 28),
      ),
      const SizedBox(height: 12),
      const Text('No AI Call Numbers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('No active AI call numbers are configured.\nPlease set one up in Settings first.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Select AI Call Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedId,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            items: _callNumbers.map((n) {
              final name = n['name']?.toString() ?? 'Unknown';
              final phone = n['phoneNumber']?.toString() ?? '';
              return DropdownMenuItem<String>(
                value: n['id'] as String?,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    if (phone.isNotEmpty)
                      Text(phone, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              );
            }).toList(),
            onChanged: _calling ? null : (v) => setState(() => _selectedId = v),
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _calling || _selectedId == null ? null : _startCall,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: _calling
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.phone_rounded, size: 20),
          label: Text(_calling ? 'Starting Call…' : 'Start AI Call',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 4),
      const Text('The AI agent will call the customer automatically',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textHint)),
    ]);
  }
}
