import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class CrmDashboardSubScreen extends StatefulWidget {
  const CrmDashboardSubScreen({super.key});

  @override
  State<CrmDashboardSubScreen> createState() => _CrmDashboardSubScreenState();
}

class _CrmDashboardSubScreenState extends State<CrmDashboardSubScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _salespersonPerformance = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getCrmDashboard();
      final raw = res.data;
      final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      setState(() {
        _stats = (data['stats'] as Map<String, dynamic>?) ?? data;
        final perf = data['salespersonPerformance'];
        _salespersonPerformance = perf is List
            ? perf.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          Text(
            'Salesperson Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_salespersonPerformance.isEmpty)
            _buildEmptyState('No performance data available')
          else
            ..._salespersonPerformance.map(_buildPerformanceCard),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final statItems = [
      _StatItem(
        'Total Leads',
        _stats['totalLeads'],
        Icons.people,
        AppColors.primary,
      ),
      _StatItem(
        'Open Leads',
        _stats['openLeads'],
        Icons.folder_open,
        AppColors.accent,
      ),
      _StatItem(
        'Converted',
        _stats['convertedLeads'],
        Icons.check_circle,
        AppColors.success,
      ),
      _StatItem('Lost', _stats['lostLeads'], Icons.cancel, AppColors.error),
      _StatItem(
        'Conversion Rate',
        '${_stats['conversionRate'] ?? 0}%',
        Icons.trending_up,
        AppColors.warning,
      ),
      _StatItem(
        'Pending Follow-ups',
        _stats['pendingFollowUps'],
        Icons.schedule,
        AppColors.warning,
      ),
      _StatItem(
        'Overdue Follow-ups',
        _stats['overdueFollowUps'],
        Icons.warning_amber,
        AppColors.error,
      ),
      _StatItem(
        'Test Drives',
        _stats['testDrivesPlanned'],
        Icons.directions_car,
        AppColors.accent,
      ),
      _StatItem(
        'Bookings',
        _stats['confirmedBookings'],
        Icons.bookmark,
        AppColors.success,
      ),
      _StatItem(
        'Deliveries',
        _stats['totalDeliveries'],
        Icons.local_shipping,
        AppColors.primary,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, index) {
        final item = statItems[index];
        return Container(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.color.withValues(alpha: 0.15),
                      item.color.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              Text(
                '${item.value ?? 0}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> person) {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Leads: ${person['totalLeads'] ?? 0} • Converted: ${person['converted'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${person['conversionRate'] ?? 0}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}
