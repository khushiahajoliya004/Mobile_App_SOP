import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'crm_leads_screen.dart';
import 'crm_followups_screen.dart';
import 'crm_visits_screen.dart';
import 'crm_test_drives_screen.dart';
import 'crm_quotations_screen.dart';
import 'crm_bookings_screen.dart';
import 'crm_deliveries_screen.dart';
import 'crm_branches_screen.dart';
import 'crm_pipelines_screen.dart';
import 'crm_dashboard_screen.dart';
import 'crm_more_screens.dart';
import 'my_tasks_screen.dart';

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
    try {
      final res = await _api.getCrmDashboard();
      final raw = res.data is Map ? res.data['data'] ?? res.data : {};
      _stats = raw is Map ? Map<String, dynamic>.from(raw['stats'] ?? {}) : {};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool _can(String permPrefix) {
    if (_user == null) return false;
    if (_user!.isSuperAdmin || _user!.isCompanyAdmin) return true;
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

    final modules = <_CrmModule>[
      // My Tasks — always visible, highest priority
      _CrmModule(
        'My Tasks',
        Icons.task_alt_rounded,
        const Color(0xFF4F46E5),
        const Color(0xFF818CF8),
        'Your assigned tasks',
        const MyTasksScreen(),
      ),
      if (_can('CRM_DASHBOARD'))
        _CrmModule(
          'Dashboard',
          Icons.dashboard_rounded,
          const Color(0xFF6366F1),
          const Color(0xFF818CF8),
          '${_stats['totalLeads'] ?? 0} leads',
          const CrmDashboardSubScreen(),
        ),
      if (_can('LEAD'))
        _CrmModule(
          'Leads',
          Icons.people_rounded,
          const Color(0xFF10B981),
          const Color(0xFF34D399),
          '${_stats['openLeads'] ?? 0} open',
          const CrmLeadsScreen(),
        ),
      if (_can('FOLLOW_UP'))
        _CrmModule(
          'Follow-ups',
          Icons.calendar_today_rounded,
          const Color(0xFFF59E0B),
          const Color(0xFFFBBF24),
          '${_stats['pendingFollowUps'] ?? 0} pending',
          const CrmFollowUpsScreen(),
        ),
      if (_can('VISIT'))
        _CrmModule(
          'Visits',
          Icons.directions_car_rounded,
          const Color(0xFF0EA5E9),
          const Color(0xFF38BDF8),
          '${_stats['plannedVisits'] ?? 0} planned',
          const CrmVisitsScreen(),
        ),
      if (_can('TEST_DRIVE'))
        _CrmModule(
          'Test Drives',
          Icons.speed_rounded,
          const Color(0xFFEC4899),
          const Color(0xFFF472B6),
          '${_stats['testDrivesPlanned'] ?? 0} planned',
          const CrmTestDrivesScreen(),
        ),
      if (_can('QUOTATION'))
        _CrmModule(
          'Quotations',
          Icons.request_quote_rounded,
          const Color(0xFF8B5CF6),
          const Color(0xFFA78BFA),
          '${_stats['quotationsSent'] ?? 0} sent',
          const CrmQuotationsScreen(),
        ),
      if (_can('BOOKING'))
        _CrmModule(
          'Bookings',
          Icons.bookmark_rounded,
          const Color(0xFF14B8A6),
          const Color(0xFF2DD4BF),
          '${_stats['confirmedBookings'] ?? 0} confirmed',
          const CrmBookingsScreen(),
        ),
      if (_can('DELIVERY'))
        _CrmModule(
          'Deliveries',
          Icons.local_shipping_rounded,
          const Color(0xFFF97316),
          const Color(0xFFFB923C),
          '${_stats['totalDeliveries'] ?? 0} delivered',
          const CrmDeliveriesScreen(),
        ),
      if (_can('BRANCH'))
        _CrmModule(
          'Branches',
          Icons.business_rounded,
          const Color(0xFF64748B),
          const Color(0xFF94A3B8),
          '',
          const CrmBranchesScreen(),
        ),
      if (_can('LEAD_PIPELINE'))
        _CrmModule(
          'Pipelines',
          Icons.account_tree_rounded,
          const Color(0xFF06B6D4),
          const Color(0xFF22D3EE),
          '',
          const CrmPipelinesScreen(),
        ),
      if (_can('VEHICLE_INVENTORY'))
        _CrmModule(
          'Vehicle Stock',
          Icons.directions_car_rounded,
          const Color(0xFF0EA5E9),
          const Color(0xFF38BDF8),
          '',
          const CrmVehicleInventoryScreen(),
        ),
      if (_can('EXCHANGE_VEHICLE'))
        _CrmModule(
          'Exchange',
          Icons.swap_horiz_rounded,
          const Color(0xFFF97316),
          const Color(0xFFFB923C),
          '',
          const CrmExchangeVehicleScreen(),
        ),
      if (_can('CRM_INSURANCE'))
        _CrmModule(
          'Insurance',
          Icons.shield_rounded,
          const Color(0xFF10B981),
          const Color(0xFF34D399),
          '',
          const CrmInsuranceScreen(),
        ),
      if (_can('CRM_RTO'))
        _CrmModule(
          'RTO',
          Icons.badge_rounded,
          const Color(0xFF8B5CF6),
          const Color(0xFFA78BFA),
          '',
          const CrmRtoScreen(),
        ),
      if (_can('CRM_ACCESSORIES'))
        _CrmModule(
          'Accessories',
          Icons.build_circle_rounded,
          const Color(0xFF06B6D4),
          const Color(0xFF22D3EE),
          '',
          const CrmAccessoriesScreen(),
        ),
      if (_can('CRM_PDI'))
        _CrmModule(
          'PDI',
          Icons.checklist_rounded,
          const Color(0xFFF59E0B),
          const Color(0xFFFBBF24),
          '',
          const CrmPdiScreen(),
        ),
      if (_can('CRM_PAYMENT'))
        _CrmModule(
          'Payments',
          Icons.payments_rounded,
          const Color(0xFF10B981),
          const Color(0xFF34D399),
          '',
          const CrmPaymentsScreen(),
        ),
      if (_can('CRM_FEEDBACK'))
        _CrmModule(
          'Feedback',
          Icons.star_rounded,
          const Color(0xFFF59E0B),
          const Color(0xFFFBBF24),
          '',
          const CrmFeedbackScreen(),
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
                      'Showroom Operations',
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
              _headerStat('${_stats['totalLeads'] ?? 0}', 'Leads'),
              _headerStat('${_stats['openLeads'] ?? 0}', 'Open'),
              _headerStat('${_stats['confirmedBookings'] ?? 0}', 'Bookings'),
              _headerStat('${_stats['conversionRate'] ?? 0}%', 'Conv.'),
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
          builder: (_) =>
              _CrmSubWrapper(title: module.label, child: module.screen),
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

class _CrmSubWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _CrmSubWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
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
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  AppColors.primary,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
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
          Expanded(child: child),
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
