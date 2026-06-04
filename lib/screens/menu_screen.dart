import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user_model.dart';
import 'call_history_screen.dart';
import 'call_upload_screen.dart';
import 'ai_insights/ai_insights_screen.dart';
import 'audio_library_screen.dart';
import 'crm/crm_screen.dart';
import 'crm/crm_branches_screen.dart';
import 'analytics/analytics_screen.dart';
import 'call_approvals/call_approvals_screen.dart';
import 'sop_builder/sop_list_screen.dart';
import 'sop_evaluator/sop_evaluator_screen.dart';
import 'categories/category_list_screen.dart';
import 'sales_stages/sales_stage_list_screen.dart';
import 'industries/industry_list_screen.dart';
import 'users/user_list_screen.dart';
import 'credits/credits_screen.dart';
import 'assign_sop/assign_sop_screen.dart';
import 'roles/role_list_screen.dart';
import 'team/team_screen.dart';
import 'companies/company_list_screen.dart';
import 'distributors/distributor_list_screen.dart';
import 'plans/plan_list_screen.dart';
import 'modules/module_list_screen.dart';
import 'operations/operation_list_screen.dart';
import 'permissions/permission_list_screen.dart';
import 'llm_config/llm_config_screen.dart';
import 'call_report/call_report_screen.dart';
import 'employee_performance/employee_performance_screen.dart';
import 'sales_performance/sales_performance_screen.dart';
import 'team_report/team_report_screen.dart';
import 'prompt_settings/prompt_settings_screen.dart';
import 'settings/wa_settings_screen.dart';
import 'crm_v2/crm_contacts_screen.dart';
import 'crm_v2/crm_deals_screen.dart';
import 'crm_v2/crm_activities_screen.dart';
import 'crm_v2/crm_custom_properties_screen.dart';
import 'crm_v2/crm_pipeline_settings_screen.dart';
import 'crm_v2/crm_master_data_screen.dart';
import 'daily_transcripts/daily_transcripts_screen.dart';
import 'salesman_sop/salesman_sop_screen.dart';
import 'analytics/analytics_compare_screen.dart';

class MenuScreen extends StatelessWidget {
  final UserModel? user;
  const MenuScreen({super.key, this.user});

    bool _can(String code) {
    if (user == null) return false;
    if (user!.isSuperAdmin || user!.isCompanyAdmin) return true;
    return user!.hasModule(code) || user!.hasPermission('${code}_VIEW');
  }

  @override
  Widget build(BuildContext context) {
    final sections = <_Section>[
      _Section(
        'Sales & Calls',
        Icons.trending_up_rounded,
        const Color(0xFF6366F1),
        [
          if (_can('CALL'))
            _M(
              'Calls',
              Icons.phone_rounded,
              const Color(0xFF6366F1),
              const Color(0xFF818CF8),
              'View call history',
              const CallHistoryScreen(),
            ),
          if (_can('CALL'))
            _M(
              'Upload',
              Icons.cloud_upload_rounded,
              const Color(0xFF0EA5E9),
              const Color(0xFF38BDF8),
              'Upload audio files',
              const CallUploadScreen(),
            ),
          if (_can('CALL'))
            _M(
              'Approvals',
              Icons.verified_rounded,
              const Color(0xFF8B5CF6),
              const Color(0xFFA78BFA),
              'Approve or reject',
              const CallApprovalsScreen(),
            ),
          if (_can('AI_INSIGHT'))
            _M(
              'AI Insights',
              Icons.auto_awesome_rounded,
              const Color(0xFFF59E0B),
              const Color(0xFFFBBF24),
              'AI call analysis',
              const AiInsightsScreen(),
            ),
          if (_can('CRM_DASHBOARD'))
            _M(
              'CRM',
              Icons.groups_rounded,
              const Color(0xFF10B981),
              const Color(0xFF34D399),
              'Leads & pipeline',
              const CrmScreen(),
            ),
          if (_can('BRANCH'))
            _M(
              'Branches',
              Icons.store_rounded,
              const Color(0xFF0EA5E9),
              const Color(0xFF38BDF8),
              'Manage branches',
              const CrmBranchesScreen(),
            ),
        ],
      ),
      _Section(
        'SOP Management',
        Icons.description_rounded,
        const Color(0xFF14B8A6),
        [
          if (_can('SOP_BUILDER'))
            _M(
              'SOP Builder',
              Icons.build_circle_rounded,
              const Color(0xFF14B8A6),
              const Color(0xFF2DD4BF),
              'Create & edit SOPs',
              const SopListScreen(),
            ),
          if (_can('SOP_BUILDER'))
            _M(
              'Evaluator',
              Icons.quiz_rounded,
              const Color(0xFF0D9488),
              const Color(0xFF14B8A6),
              'Test against SOP',
              const SopEvaluatorScreen(),
            ),
          if (_can('CATEGORY'))
            _M(
              'Categories',
              Icons.label_rounded,
              const Color(0xFFEC4899),
              const Color(0xFFF472B6),
              'Manage categories',
              const CategoriesScreen(),
            ),
          if (_can('SALES_STAGE'))
            _M(
              'Sales Stages',
              Icons.flag_rounded,
              const Color(0xFFF97316),
              const Color(0xFFFB923C),
              'Configure stages',
              const SalesStagesScreen(),
            ),
          if (_can('INDUSTRY'))
            _M(
              'Industries',
              Icons.factory_rounded,
              const Color(0xFF64748B),
              const Color(0xFF94A3B8),
              'Industry types',
              const IndustriesScreen(),
            ),
          _M(
            'SOP Checklist',
            Icons.checklist_rounded,
            const Color(0xFF10B981),
            const Color(0xFF34D399),
            'View assigned SOPs',
            const SalesmanSopScreen(),
          ),
        ],
      ),
      _Section('CRM v2', Icons.contacts_rounded, const Color(0xFF10B981), [
        if (_can('LEAD'))
          _M(
            'Contacts',
            Icons.person_rounded,
            const Color(0xFF10B981),
            const Color(0xFF34D399),
            'Manage CRM contacts',
            const CrmContactsScreen(),
          ),
        if (_can('LEAD'))
          _M(
            'Deals',
            Icons.handshake_rounded,
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
            'Track deals & pipeline',
            const CrmDealsScreen(),
          ),
        if (_can('LEAD'))
          _M(
            'Activities',
            Icons.event_note_rounded,
            const Color(0xFF8B5CF6),
            const Color(0xFFA78BFA),
            'Calls, emails, meetings',
            const CrmActivitiesScreen(),
          ),
        if (_can('LEAD'))
          _M(
            'Properties',
            Icons.tune_rounded,
            const Color(0xFF14B8A6),
            const Color(0xFF2DD4BF),
            'Custom CRM fields',
            const CrmCustomPropertiesScreen(),
          ),
        if (user?.isCompanyAdmin == true || user?.isSuperAdmin == true)
          _M(
            'Pipeline Settings',
            Icons.account_tree_rounded,
            const Color(0xFF6366F1),
            const Color(0xFF818CF8),
            'Manage pipelines & stages',
            const CrmPipelineSettingsScreen(),
          ),
        if (user?.isCompanyAdmin == true || user?.isSuperAdmin == true)
          _M(
            'Master Data',
            Icons.dataset_rounded,
            const Color(0xFF64748B),
            const Color(0xFF94A3B8),
            'Lead sources, stages & more',
            const CrmMasterDataScreen(),
          ),
      ]),
      _Section('Reports', Icons.assessment_rounded, const Color(0xFF3B82F6), [
        if (_can('ANALYTICS'))
          _M(
            'Analytics',
            Icons.bar_chart_rounded,
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
            'Performance data',
            const AnalyticsScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            '360° Compare',
            Icons.compare_arrows_rounded,
            const Color(0xFF8B5CF6),
            const Color(0xFFA78BFA),
            'Compare users side by side',
            const AnalyticsCompareScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            'Daily Transcripts',
            Icons.receipt_long_rounded,
            const Color(0xFF0D9488),
            const Color(0xFF14B8A6),
            'Call transcripts by date',
            const DailyTranscriptsScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            'Call Report',
            Icons.phone_in_talk_rounded,
            const Color(0xFF6366F1),
            const Color(0xFF818CF8),
            'Daily call statistics',
            const CallReportScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            'Employee Performance',
            Icons.person_search_rounded,
            const Color(0xFF0EA5E9),
            const Color(0xFF38BDF8),
            'Individual scores & calls',
            const EmployeePerformanceScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            'Sales Performance',
            Icons.trending_up_rounded,
            const Color(0xFF10B981),
            const Color(0xFF34D399),
            'Leads & conversion funnel',
            const SalesPerformanceScreen(),
          ),
        if (_can('ANALYTICS'))
          _M(
            'Team Report',
            Icons.groups_rounded,
            const Color(0xFFF59E0B),
            const Color(0xFFFBBF24),
            'Team-wide summary',
            const TeamReportScreen(),
          ),
      ]),
      _Section(
        'Administration',
        Icons.admin_panel_settings_rounded,
        const Color(0xFF8B5CF6),
        [
          if (user?.isSuperAdmin == true)
            _M(
              'Companies',
              Icons.business_rounded,
              const Color(0xFF6366F1),
              const Color(0xFF818CF8),
              'Manage companies',
              const CompanyListScreen(),
            ),
          if (user?.isSuperAdmin == true)
            _M(
              'Distributors',
              Icons.store_mall_directory_rounded,
              const Color(0xFF0EA5E9),
              const Color(0xFF38BDF8),
              'Manage distributors',
              const DistributorListScreen(),
            ),
          if (_can('USER'))
            _M(
              'Users',
              Icons.people_rounded,
              const Color(0xFF6366F1),
              const Color(0xFF818CF8),
              'Manage team',
              const UsersScreen(),
            ),
          if (_can('ROLE'))
            _M(
              'Roles',
              Icons.shield_rounded,
              const Color(0xFFF59E0B),
              const Color(0xFFFBBF24),
              'Permissions',
              const RolesScreen(),
            ),
          if (_can('BRANCH'))
            _M(
              'Branches',
              Icons.store_rounded,
              const Color(0xFF14B8A6),
              const Color(0xFF2DD4BF),
              'Manage branches',
              const CrmBranchesScreen(),
            ),
          if (_can('CREDIT'))
            _M(
              'Credits',
              Icons.toll_rounded,
              const Color(0xFF10B981),
              const Color(0xFF34D399),
              'Balance & plans',
              const CreditsScreen(),
            ),
          if (_can('USER'))
            _M(
              'Assign SOP',
              Icons.link_rounded,
              const Color(0xFF8B5CF6),
              const Color(0xFFA78BFA),
              'Link SOP to users',
              const AssignSopScreen(),
            ),
          if (_can('USER'))
            _M(
              'Team Mapping',
              Icons.account_tree_rounded,
              const Color(0xFF0EA5E9),
              const Color(0xFF38BDF8),
              'View team analysis',
              const TeamScreen(),
            ),
        ],
      ),
      _Section(
        'Settings',
        Icons.settings_rounded,
        const Color(0xFF64748B),
        [
          if (user?.isSuperAdmin == true)
            _M(
              'Plans',
              Icons.card_membership_rounded,
              const Color(0xFF6366F1),
              const Color(0xFF818CF8),
              'Subscription plans',
              const PlanListScreen(),
            ),
          if (user?.isSuperAdmin == true)
            _M(
              'Modules',
              Icons.view_module_rounded,
              const Color(0xFF0EA5E9),
              const Color(0xFF38BDF8),
              'System modules',
              const ModuleListScreen(),
            ),
          if (user?.isSuperAdmin == true)
            _M(
              'Operations',
              Icons.settings_applications_rounded,
              const Color(0xFF14B8A6),
              const Color(0xFF2DD4BF),
              'System operations',
              const OperationListScreen(),
            ),
          if (user?.isSuperAdmin == true || user?.isCompanyAdmin == true)
            _M(
              'Permissions',
              Icons.lock_rounded,
              const Color(0xFFF59E0B),
              const Color(0xFFFBBF24),
              'Manage permissions',
              const PermissionListScreen(),
            ),
          if (user?.isSuperAdmin == true || user?.isCompanyAdmin == true)
            _M(
              'LLM Config',
              Icons.auto_awesome_rounded,
              const Color(0xFF8B5CF6),
              const Color(0xFFA78BFA),
              'AI prompt templates',
              const LlmConfigScreen(),
            ),
          if (user?.isCompanyAdmin == true || user?.isSuperAdmin == true)
            _M(
              'Prompt Settings',
              Icons.text_snippet_rounded,
              const Color(0xFF10B981),
              const Color(0xFF34D399),
              'Master prompt config',
              const PromptSettingsScreen(),
            ),
          if (user?.isCompanyAdmin == true || user?.isSuperAdmin == true)
            _M(
              'WhatsApp Settings',
              Icons.message_rounded,
              const Color(0xFF25D366),
              const Color(0xFF128C7E),
              'WA audit & auto-send',
              const WaSettingsScreen(),
            ),
        ],
      ),
      _Section('Tools', Icons.handyman_rounded, const Color(0xFF06B6D4), [
        _M(
          'Audio Library',
          Icons.library_music_rounded,
          const Color(0xFF06B6D4),
          const Color(0xFF22D3EE),
          'Local recordings',
          const AudioLibraryScreen(),
        ),
      ]),
    ].where((s) => s.items.isNotEmpty).toList();

    final totalModules = sections.fold<int>(
      0,
      (s, sec) => s + sec.items.length,
    );

    return Container(
      color: AppColors.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, totalModules),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: sections.length,
                itemBuilder: (_, i) => _buildSection(context, sections[i], i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MysteryMentor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'AI Sales Intelligence Platform',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Feature chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _featureChip(Icons.mic_rounded, 'Record'),
              _featureChip(Icons.auto_awesome_rounded, 'AI'),
              _featureChip(Icons.insights_rounded, 'Insights'),
              _featureChip(Icons.groups_rounded, 'CRM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    _Section section,
    int sectionIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(section.icon, size: 14, color: section.color),
              ),
              const SizedBox(width: 10),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${section.items.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: section.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...section.items.asMap().entries.map(
          (e) => _buildModuleTile(context, e.value, e.key),
        ),
      ],
    );
  }

  Widget _buildModuleTile(BuildContext context, _M item, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ModuleWrapper(title: item.label, child: item.screen),
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
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [item.c1, item.c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: item.c1.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
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

// ═══ MODULE WRAPPER ═════════════════════════════════════════════════════════
class _ModuleWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _ModuleWrapper({required this.title, required this.child});

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
                const SizedBox(width: 4),
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

// ═══ DATA MODELS ════════════════════════════════════════════════════════════
class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final List<_M> items;
  _Section(this.title, this.icon, this.color, this.items);
}

class _M {
  final String label;
  final IconData icon;
  final Color c1, c2;
  final String subtitle;
  final Widget screen;
  _M(this.label, this.icon, this.c1, this.c2, this.subtitle, this.screen);
}
