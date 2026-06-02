import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmQuotationsScreen extends StatefulWidget {
  const CrmQuotationsScreen({super.key});

  @override
  State<CrmQuotationsScreen> createState() => _CrmQuotationsScreenState();
}

class _CrmQuotationsScreenState extends State<CrmQuotationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getQuotations();
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      setState(() {
        _quotations = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLeads() async {
    try {
      final res = await _api.getCrmDeals();
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      _leads = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  void _showCreateSheet() async {
    await _loadLeads();
    if (!mounted) return;

    String? selectedLeadId;
    final modelCtrl = TextEditingController();
    final variantCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final exShowroomCtrl = TextEditingController();
    final rtoCtrl = TextEditingController();
    final insuranceCtrl = TextEditingController();
    final accessoriesCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final exchangeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.accent.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Quotation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedLeadId,
                  decoration: const InputDecoration(labelText: 'Select Lead *'),
                  items: _leads
                      .map(
                        (l) => DropdownMenuItem(
                          value: l['id']?.toString(),
                          child: Text((l['contact'] is Map ? l['contact']['name'] : null) ?? l['name']?.toString() ?? l['customerName']?.toString() ?? 'Unknown'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedLeadId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: variantCtrl,
                  decoration: const InputDecoration(labelText: 'Variant'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exShowroomCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ex-Showroom Price',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rtoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'RTO'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: insuranceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Insurance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accessoriesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Accessories'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exchangeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Exchange Value',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (selectedLeadId == null) return;
                    try {
                      final data = <String, dynamic>{
                        'leadId': selectedLeadId,
                        if (modelCtrl.text.trim().isNotEmpty)
                          'vehicleModel': modelCtrl.text.trim(),
                        if (variantCtrl.text.trim().isNotEmpty)
                          'variant': variantCtrl.text.trim(),
                        if (colorCtrl.text.trim().isNotEmpty)
                          'color': colorCtrl.text.trim(),
                        if (exShowroomCtrl.text.trim().isNotEmpty)
                          'exShowroomPrice': double.tryParse(
                            exShowroomCtrl.text.trim(),
                          ),
                        if (rtoCtrl.text.trim().isNotEmpty)
                          'rto': double.tryParse(rtoCtrl.text.trim()),
                        if (insuranceCtrl.text.trim().isNotEmpty)
                          'insurance': double.tryParse(
                            insuranceCtrl.text.trim(),
                          ),
                        if (accessoriesCtrl.text.trim().isNotEmpty)
                          'accessories': double.tryParse(
                            accessoriesCtrl.text.trim(),
                          ),
                        if (discountCtrl.text.trim().isNotEmpty)
                          'discount': double.tryParse(discountCtrl.text.trim()),
                        if (exchangeCtrl.text.trim().isNotEmpty)
                          'exchangeValue': double.tryParse(
                            exchangeCtrl.text.trim(),
                          ),
                      };
                      await _api.createQuotation(data);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  child: const Text('Create Quotation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendQuotation(Map<String, dynamic> quotation) async {
    try {
      await _api.updateQuotationStatus(quotation['id'], 'SENT');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send quotation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }
    return Container(
      color: AppColors.scaffoldBg,
      child: Stack(
        children: [
          _quotations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _quotations.length,
                    itemBuilder: (_, i) => _buildQuotationCard(_quotations[i]),
                  ),
                ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: null,
              backgroundColor: AppColors.primary,
              onPressed: _showCreateSheet,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> q) {
    final status = (q['status'] ?? 'DRAFT').toString().toUpperCase();
    final leadName = q['lead'] is Map
        ? q['lead']['customerName'] ?? 'Unknown'
        : (q['leadName'] ?? 'Unknown');
    final model = q['vehicleModel'] ?? '';
    final variant = q['variant'] ?? '';
    final price = q['finalOnRoadPrice'] ?? q['exShowroomPrice'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName.toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$model $variant'.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.currency_rupee,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 2),
              Text(
                _formatPrice(price),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (status == 'DRAFT')
                InkWell(
                  onTap: () => _sendQuotation(q),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    if (num >= 100000) {
      return '${(num / 100000).toStringAsFixed(2)} L';
    }
    return num.toStringAsFixed(0);
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'SENT':
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        break;
      case 'ACCEPTED':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'REJECTED':
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          const Text(
            'No quotations',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to create one',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
