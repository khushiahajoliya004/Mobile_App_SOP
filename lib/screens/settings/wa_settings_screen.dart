import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/recording_download_service.dart';

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

  // Daily Call Report (WhatsApp, 7 PM)
  bool _dailyEnabled = false;
  bool _dailyPdf = true;
  bool _dailyText = false;
  bool _isCompanyAdmin = false;
  String? _dailyBusy; // 'pdf' | 'send'

  @override
  void initState() {
    super.initState();
    _load();
    AuthService().getUser().then((u) {
      if (mounted) setState(() => _isCompanyAdmin = u?.userType == 'COMPANY' || u?.userType == 'SUPER_ADMIN');
    });
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
        _dailyEnabled = data['dailyReportEnabled'] == true;
        _dailyPdf = data['dailyReportPdf'] != false;
        _dailyText = data['dailyReportText'] == true;
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
        dailyReportEnabled: _isCompanyAdmin ? _dailyEnabled : null,
        dailyReportPdf: _isCompanyAdmin ? _dailyPdf : null,
        dailyReportText: _isCompanyAdmin ? _dailyText : null,
      );
      _msg('Settings saved');
    } catch (e) { _msg('Failed: $e', error: true); }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _downloadDailyReport() async {
    setState(() => _dailyBusy = 'pdf');
    try {
      final res = await _api.downloadDailyCallReportPdf();
      final data = res.data;
      if (data is List<int> && data.isNotEmpty) {
        final now = DateTime.now();
        final name = 'Daily_Call_Report_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.pdf';
        final bytes = Uint8List.fromList(data);
        final saved = await RecordingDownloadService.saveToDevice(bytes, name);
        if (saved) _msg('Saved $name');
      } else {
        _msg('Could not create the report', error: true);
      }
    } catch (_) {
      _msg('Could not create the report. Please try again.', error: true);
    }
    if (mounted) setState(() => _dailyBusy = null);
  }

  Future<void> _sendDailyReportNow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Send today's report now?"),
        content: const Text(
          'Everyone who uploaded calls today gets their count, and seniors get the team report on WhatsApp. The 7 PM report will still be sent as usual.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send now')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _dailyBusy = 'send');
    try {
      final res = await _api.sendDailyCallReportNow();
      final d = (res.data is Map ? (res.data['data'] ?? {}) : {}) as Map;
      final issues = [
        if ((d['failed'] ?? 0) > 0) '${d['failed']} failed',
        if ((d['noPhone'] ?? 0) > 0) '${d['noPhone']} without phone number',
      ];
      _msg('Sent: ${d['self'] ?? 0} personal, ${d['teamPdf'] ?? 0} team PDF, ${d['teamText'] ?? 0} team text'
          '${issues.isEmpty ? '' : ' · ${issues.join(', ')}'}');
    } on DioException catch (e) {
      _msg(e.response?.data?['message']?.toString() ?? 'Could not send the report', error: true);
    } catch (_) {
      _msg('Could not send the report', error: true);
    }
    if (mounted) setState(() => _dailyBusy = null);
  }

  Widget _dailyReportCard() {
    final busy = _dailyBusy != null;
    Widget check(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => CheckboxListTile(
          value: value,
          onChanged: (_isCompanyAdmin && _dailyEnabled) ? (v) => setState(() => onChanged(v ?? false)) : null,
          title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.primary,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily Call Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('WhatsApp every day at 7:00 PM', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Switch(
            value: _dailyEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: _isCompanyAdmin ? (v) => setState(() => _dailyEnabled = v) : null,
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Everyone who uploaded calls gets their own count. Seniors get their whole team\'s report (Team Mapping) with each member\'s name, mobile and calls, and the team total.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: _dailyEnabled ? 1 : 0.5,
          child: Column(children: [
            check('PDF report', 'Detailed table with team totals', _dailyPdf, (v) => _dailyPdf = v),
            check('Text message', "Short summary with each member's calls", _dailyText, (v) => _dailyText = v),
          ]),
        ),
        if (!_isCompanyAdmin)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Only the company admin can change these settings.', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : _downloadDailyReport,
              icon: _dailyBusy == 'pdf'
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_dailyBusy == 'pdf' ? 'Preparing...' : "Today's PDF"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_isCompanyAdmin) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _sendDailyReportNow,
                icon: _dailyBusy == 'send'
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_dailyBusy == 'send' ? 'Sending...' : 'Send now'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: error ? AppColors.error : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Material(color: Colors.white, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
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
              'After a call is analysed, the person who uploaded it gets the Manager Review PDF on WhatsApp. If the review can\'t be created, nothing is sent until it is (Re-Analyze).',
              style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Audit number
        const Text('Audit Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Saved for reference — automatic WhatsApp messages currently go only to the person who uploaded the call', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              Text('Auto-Send on WhatsApp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Send the Manager Review PDF to the uploader after processing', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Switch(
              value: _autoSendEnabled,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _autoSendEnabled = v),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        _dailyReportCard(),
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
