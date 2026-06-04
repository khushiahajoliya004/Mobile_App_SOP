import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class WaSettingsScreen extends StatefulWidget {
  const WaSettingsScreen({super.key});
  @override
  State<WaSettingsScreen> createState() => _WaSettingsScreenState();
}

class _WaSettingsScreenState extends State<WaSettingsScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  bool _autoSendEnabled = false;
  final _auditNumber = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _auditNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getWaSettings();
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      if (data is Map) {
        _autoSendEnabled = data['waAutoSendEnabled'] == true;
        _auditNumber.text = data['waAuditNumber'] ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.updateWaSettings(
        waAuditNumber: _auditNumber.text.trim().isNotEmpty ? _auditNumber.text.trim() : null,
        waAutoSendEnabled: _autoSendEnabled,
      );
      _msg('Settings saved');
    } catch (e) { _msg('Failed: $e', error: true); }
    if (mounted) setState(() => _saving = false);
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'Manager Review PDFs are sent via WhatsApp to the salesperson, their senior, and the audit number below.',
              style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Audit number
        const Text('Audit Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('This number receives all Manager Review PDFs (e.g. +919876543210)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        TextField(
          controller: _auditNumber,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'WhatsApp Number',
            hintText: '+91XXXXXXXXXX',
            prefixIcon: const Icon(Icons.phone_rounded, size: 20),
            filled: true, fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        // Auto send toggle
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Auto-Send PDFs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Automatically send Manager Review PDFs via WhatsApp after processing', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Switch(
              value: _autoSendEnabled,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _autoSendEnabled = v),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Settings'),
          ),
        ),
      ]),
    );
  }
}
