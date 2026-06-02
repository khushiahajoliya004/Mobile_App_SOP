import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmBookingsScreen extends StatefulWidget {
  const CrmBookingsScreen({super.key});

  @override
  State<CrmBookingsScreen> createState() => _CrmBookingsScreenState();
}

class _CrmBookingsScreenState extends State<CrmBookingsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getBookings();
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      setState(() {
        _bookings = list
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
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String paymentMode = 'CASH';

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
                        Icons.bookmark_add,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Booking',
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
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Booking Amount',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: ['CASH', 'UPI', 'CHEQUE', 'BANK_TRANSFER', 'CARD']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => paymentMode = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Reference',
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
                        if (amountCtrl.text.trim().isNotEmpty)
                          'bookingAmount': double.tryParse(
                            amountCtrl.text.trim(),
                          ),
                        'paymentMode': paymentMode,
                        if (refCtrl.text.trim().isNotEmpty)
                          'paymentReference': refCtrl.text.trim(),
                      };
                      await _api.createBooking(data);
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
                  child: const Text('Create Booking'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmBooking(Map<String, dynamic> booking) async {
    try {
      await _api.confirmBooking(booking['id']);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $e')),
        );
      }
    }
  }

  void _cancelBooking(Map<String, dynamic> booking) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Cancellation Reason',
            hintText: 'Why is this booking being cancelled?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await _api.cancelBooking(booking['id'], reasonCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to cancel: $e')),
                  );
                }
              }
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
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
          _bookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (_, i) => _buildBookingCard(_bookings[i]),
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final leadName = booking['lead'] is Map
        ? booking['lead']['customerName'] ?? 'Unknown'
        : (booking['leadName'] ?? 'Unknown');
    final model = booking['vehicleModel'] ?? '';
    final amount = booking['bookingAmount'] ?? 0;
    final paymentMode = booking['paymentMode'] ?? '';

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
                      AppColors.success.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bookmark,
                  color: AppColors.success,
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
                      model.toString(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.currency_rupee,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 2),
              Text(
                _formatAmount(amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentMode.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'PENDING') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => _confirmBooking(booking),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _cancelBooking(booking),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 14,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 100000) return '${(num / 100000).toStringAsFixed(2)} L';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)} K';
    return num.toStringAsFixed(0);
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'CONFIRMED':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'CANCELLED':
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
          Icon(Icons.bookmark_border, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'No bookings',
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
