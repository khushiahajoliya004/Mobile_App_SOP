import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class ForceUpdateSettingsScreen extends StatefulWidget {
  const ForceUpdateSettingsScreen({super.key});

  @override
  State<ForceUpdateSettingsScreen> createState() =>
      _ForceUpdateSettingsScreenState();
}

class _ForceUpdateSettingsScreenState
    extends State<ForceUpdateSettingsScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _forceUpdateEnabled = false;

  final _minAndroidBuildCtrl = TextEditingController();
  final _minIosBuildCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _androidUrlCtrl = TextEditingController();
  final _iosUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _minAndroidBuildCtrl.dispose();
    _minIosBuildCtrl.dispose();
    _messageCtrl.dispose();
    _androidUrlCtrl.dispose();
    _iosUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await _api.getVersionConfig();
      if (res.data['success'] == true) {
        final d = res.data['data'];
        setState(() {
          _forceUpdateEnabled = d['forceUpdateEnabled'] ?? false;
          _minAndroidBuildCtrl.text = (d['minAndroidBuild'] ?? '').toString();
          _minIosBuildCtrl.text = (d['minIosBuild'] ?? '').toString();
          _messageCtrl.text = d['updateMessage'] ?? '';
          _androidUrlCtrl.text = d['androidStoreUrl'] ?? '';
          _iosUrlCtrl.text = d['iosStoreUrl'] ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.saveVersionConfig(
        forceUpdateEnabled: _forceUpdateEnabled,
        minAndroidBuild: int.tryParse(_minAndroidBuildCtrl.text.trim()) ?? 0,
        minIosBuild: int.tryParse(_minIosBuildCtrl.text.trim()) ?? 0,
        updateMessage: _messageCtrl.text.trim(),
        androidStoreUrl: _androidUrlCtrl.text.trim(),
        iosStoreUrl: _iosUrlCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Force update settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Force Update'),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggleCard(),
                      const SizedBox(height: 24),
                      _buildLabel('Version Requirements'),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _minAndroidBuildCtrl,
                        label: 'Min Android Build Number',
                        hint: 'e.g. 10',
                        icon: Icons.android_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _minIosBuildCtrl,
                        label: 'Min iOS Build Number',
                        hint: 'e.g. 10',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('User Message'),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _messageCtrl,
                        label: 'Update Message',
                        hint:
                            'A new version is required to continue.',
                        icon: Icons.message_rounded,
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Store URLs'),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _androidUrlCtrl,
                        label: 'Android (Play Store) URL',
                        hint:
                            'https://play.google.com/store/apps/details?id=...',
                        icon: Icons.android_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _iosUrlCtrl,
                        label: 'iOS (App Store) URL',
                        hint: 'https://apps.apple.com/app/...',
                        icon: Icons.phone_iphone_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Settings'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _forceUpdateEnabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (_forceUpdateEnabled ? AppColors.primary : AppColors.textHint)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.system_update_rounded,
            color: _forceUpdateEnabled ? AppColors.primary : AppColors.textHint,
          ),
        ),
        title: const Text(
          'Force Update Enabled',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _forceUpdateEnabled
              ? 'Users must update to continue'
              : 'Users can skip updates',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: _forceUpdateEnabled,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primaryLight,
          onChanged: (v) => setState(() => _forceUpdateEnabled = v),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
