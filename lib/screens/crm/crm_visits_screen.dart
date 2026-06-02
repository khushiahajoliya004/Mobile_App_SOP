import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmVisitsScreen extends StatefulWidget {
  const CrmVisitsScreen({super.key});

  @override
  State<CrmVisitsScreen> createState() => _CrmVisitsScreenState();
}

class _CrmVisitsScreenState extends State<CrmVisitsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getVisits();
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] ?? []) as List : []);
      setState(() {
        _visits = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    final notesCtrl = TextEditingController();

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
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Schedule Visit',
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scheduled At'),
                  subtitle: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setSheetState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (selectedLeadId == null) return;
                    try {
                      await _api.createVisit(
                        leadId: selectedLeadId!,
                        scheduledAt: selectedDate,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
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
                  child: const Text('Schedule Visit'),
                ),
              ],
            ),
          ),
        ),
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
          _visits.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _visits.length,
                    itemBuilder: (_, i) => _buildVisitCard(_visits[i]),
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

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final status = (visit['status'] ?? 'SCHEDULED').toString().toUpperCase();
    final leadName = visit['lead'] is Map
        ? visit['lead']['customerName'] ?? 'Unknown'
        : (visit['leadName'] ?? 'Unknown');
    final scheduledAt = visit['scheduledAt'] != null
        ? DateTime.tryParse(visit['scheduledAt'].toString())
        : null;

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.accent,
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
                const SizedBox(height: 4),
                Text(
                  scheduledAt != null
                      ? '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}'
                      : 'No date',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'COMPLETED':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'CANCELLED':
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
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
            Icons.location_off_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          const Text(
            'No visits scheduled',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to schedule a visit',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
