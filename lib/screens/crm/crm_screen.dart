import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'crm_dashboard_screen.dart';
import '../crm_v2/crm_contacts_screen.dart';
import '../crm_v2/crm_deals_screen.dart';
import '../crm_v2/crm_activities_screen.dart';
import '../crm_v2/crm_pipeline_settings_screen.dart';
import '../crm_v2/crm_custom_properties_screen.dart';
import '../crm_v2/crm_master_data_screen.dart';

/// CRM Hub — shows sub-modules as a menu grid (permission-based)
class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});
  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final _auth = AuthService();
  final _api = ApiService();
  UserModel? _user;
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await _auth.getUser();
    debugPrint('[CrmScreen] userType=${_user?.userType} modules=${_user?.allowedModules} permissions=${_user?.permissions}');
    try {
      final res = await _api.getCrmDashboard();
      final raw = res.data is Map ? res.data['data'] ?? res.data : {};
      _stats = raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool _can(String permPrefix) {
    if (_user == null) return false;
    if (_user!.isSuperAdmin || _user!.isCompanyAdmin) return true;
    if (_user!.hasModule(permPrefix)) return true;
    return _user!.hasPermission('${permPrefix}_MENU_VIEW') ||
        _user!.hasPermission('${permPrefix}_VIEW') ||
        _user!.hasPermission('${permPrefix}_LIST') ||
        _user!.hasPermission('${permPrefix}_CREATE');
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

    // Website CRM v2 structure:
    // USER type  → Leads (Deals), Activities
    // Admin/Distributor → Dashboard, Contacts, Deals, Activities, Pipelines*, Custom Fields*, Master Data*
    final isUser = _user?.userType == 'USER';
    final isAdmin = _user?.isSuperAdmin == true || _user?.isCompanyAdmin == true;

    final modules = <_CrmModule>[
      if (!isUser && _can('CRM_DASHBOARD'))
        _CrmModule(
          'Dashboard',
          Icons.dashboard_rounded,
          const Color(0xFF6366F1),
          const Color(0xFF818CF8),
          '${_stats['openDeals'] ?? 0} open deals',
          const CrmDashboardSubScreen(),
        ),
      if (!isUser && (isAdmin || _can('LEAD')))
        _CrmModule(
          'Contacts',
          Icons.contacts_rounded,
          const Color(0xFF0EA5E9),
          const Color(0xFF38BDF8),
          '${_stats['totalContacts'] ?? 0} total contacts',
          const CrmContactsScreen(),
        ),
      if (isUser || isAdmin || _can('LEAD'))
        _CrmModule(
          isUser ? 'Leads' : 'Deals',
          Icons.handshake_rounded,
          const Color(0xFF10B981),
          const Color(0xFF34D399),
          isUser ? 'Manage your leads' : 'Track deals & pipeline',
          const CrmDealsScreen(),
        ),
      if (isUser || isAdmin || _can('LEAD'))
        _CrmModule(
          'Activities',
          Icons.bolt_rounded,
          const Color(0xFFF59E0B),
          const Color(0xFFFBBF24),
          'Calls, emails, meetings & tasks',
          const CrmActivitiesScreen(),
        ),
      if (isAdmin || _can('CRM_PIPELINE'))
        _CrmModule(
          'Pipelines',
          Icons.account_tree_rounded,
          const Color(0xFF8B5CF6),
          const Color(0xFFA78BFA),
          'Manage deal pipelines & stages',
          const CrmPipelineSettingsScreen(),
        ),
      if (isAdmin || _can('CRM_PROPERTY'))
        _CrmModule(
          'Custom Fields',
          Icons.tune_rounded,
          const Color(0xFF06B6D4),
          const Color(0xFF22D3EE),
          'Custom contact & deal properties',
          const CrmCustomPropertiesScreen(),
        ),
      if (isAdmin || _can('CRM_MASTER'))
        _CrmModule(
          'Master Data',
          Icons.dataset_rounded,
          const Color(0xFF64748B),
          const Color(0xFF94A3B8),
          'Sources, stages & lookup values',
          const CrmMasterDataScreen(),
        ),
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _init,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header stats card
          _buildHeaderCard(),
          const SizedBox(height: 16),
          // Module grid
          ...modules.map((m) => _buildModuleTile(context, m)),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales CRM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Pipeline Overview',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat('${_stats['leadsToday'] ?? 0}', 'Today'),
              _headerStat('${_stats['openDeals'] ?? 0}', 'Open'),
              _headerStat('${_stats['wonThisMonth'] ?? 0}', 'Won'),
              _headerStat('${_stats['totalContacts'] ?? 0}', 'Contacts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(BuildContext context, _CrmModule module) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CrmSubWrapper(title: module.label, child: module.screen),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [module.c1, module.c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: module.c1.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(module.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (module.subtitle.isNotEmpty)
                    Text(
                      module.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrmSubWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const CrmSubWrapper({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 4,
              right: 16,
              bottom: 14,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scaffold(
              backgroundColor: AppColors.scaffoldBg,
              body: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmModule {
  final String label;
  final IconData icon;
  final Color c1, c2;
  final String subtitle;
  final Widget screen;
  _CrmModule(
    this.label,
    this.icon,
    this.c1,
    this.c2,
    this.subtitle,
    this.screen,
  );
}
