import 'package:flutter/material.dart';
import '../main.dart';
import '../models/crm_model.dart';
import '../services/api_service.dart';
import 'call_recorder_screen.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  Map<String, dynamic> _dashboard = {};
  List<CrmLead> _leads = [];
  List<CrmFollowUp> _followUps = [];
  List<CrmVisit> _visits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getCrmDashboard(),
        _api.getLeads(),
        _api.getFollowUps(),
        _api.getVisits(),
      ]);
      setState(() {
        _dashboard = Map<String, dynamic>.from(results[0].data['data'] ?? {});
        _leads = ((results[1].data['data'] ?? []) as List)
            .map((e) => CrmLead.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _followUps = ((results[2].data['data'] ?? []) as List)
            .map((e) => CrmFollowUp.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _visits = ((results[3].data['data'] ?? []) as List)
            .map((e) => CrmVisit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load CRM: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createLead() async {
    if (_nameController.text.trim().isEmpty) return;
    try {
      await _api.createLead(
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      _nameController.clear();
      _phoneController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create lead: $e')),
        );
      }
    }
  }

  Future<void> _setLeadDate(CrmLead lead, String field, String label) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _api.updateLeadStatus(lead.id, {field: value.toUtc().toIso8601String()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label updated')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = Map<String, dynamic>.from(_dashboard['stats'] ?? {});
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _MetricCard(label: 'Leads', value: '${stats['totalLeads'] ?? 0}'),
              _MetricCard(label: 'Converted', value: '${stats['convertedLeads'] ?? 0}'),
              _MetricCard(label: 'Conversion', value: '${stats['conversionRate'] ?? 0}%'),
              _MetricCard(label: 'Overdue', value: '${stats['overdueFollowUps'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 18),
          _CreateLeadCard(
            nameController: _nameController,
            phoneController: _phoneController,
            onCreate: _createLead,
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'My Leads',
            children: _leads.take(8).map((lead) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(lead.customerName, style: const TextStyle(fontWeight: FontWeight.w700))),
                        _StatusChip(lead.status),
                      ],
                    ),
                    if ([lead.phone, lead.source].where((v) => v != null && v.isNotEmpty).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text([lead.phone, lead.source].where((v) => v != null && v.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CallRecorderScreen(leadId: lead.id, leadCustomerName: lead.customerName)),
                          ).then((_) => _load()),
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text('Record'),
                        ),
                        OutlinedButton(
                          onPressed: () => _setLeadDate(lead, 'bookingDate', 'Booking date'),
                          child: const Text('Booking'),
                        ),
                        OutlinedButton(
                          onPressed: () => _setLeadDate(lead, 'deliveryDate', 'Delivery date'),
                          child: const Text('Delivery'),
                        ),
                        TextButton(
                          onPressed: () => _api.updateLeadStatus(lead.id, {'status': 'LOST', 'lostReason': 'Marked lost from mobile app'}).then((_) => _load()),
                          child: const Text('Lost'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Follow-ups',
            children: _followUps.take(5).map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.leadName),
              subtitle: Text('${item.type} · ${item.scheduledAt.toLocal()}'),
              trailing: _StatusChip(item.status),
            )).toList(),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Visits',
            children: _visits.take(5).map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.leadName),
              subtitle: Text(item.scheduledAt.toLocal().toString()),
              trailing: _StatusChip(item.status),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CreateLeadCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onCreate;

  const _CreateLeadCard({
    required this.nameController,
    required this.phoneController,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Customer name')),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            FilledButton(onPressed: onCreate, child: const Text('Create Lead')),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Divider(height: 22),
            if (children.isEmpty) const Text('No records yet', style: TextStyle(color: AppColors.textSecondary)),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }
}
