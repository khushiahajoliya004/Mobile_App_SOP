import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _data = {};
  String _selectedPeriod = '30d';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getAnalyticsOverview(period: _selectedPeriod);
      _data = res.data is Map
          ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
          : {};
    } catch (e) {
      _data = {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gradient header card
          _buildHeaderCard(),
          const SizedBox(height: 16),
          // Period selector
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          // Section header
          _buildSectionHeader('PERFORMANCE METRICS', Icons.insights_rounded),
          const SizedBox(height: 12),
          // Stat cards grid
          _buildStatGrid(),
          const SizedBox(height: 20),
          // Section header
          _buildSectionHeader('TEAM OVERVIEW', Icons.people_rounded),
          const SizedBox(height: 12),
          // Team stats
          _buildTeamCards(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
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
                      'Analytics Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Track your team performance',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _headerMetric('${_data['totalCalls'] ?? 0}', 'Total Calls'),
              const SizedBox(width: 24),
              _headerMetric('${_data['avgScore'] ?? 0}%', 'Avg Score'),
              const SizedBox(width: 24),
              _headerMetric('${_data['analyzedCalls'] ?? 0}', 'Analyzed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['7d', '30d', '90d'];
    final labels = ['7 Days', '30 Days', '90 Days'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(periods.length, (i) {
          final isSelected = _selectedPeriod == periods[i];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = periods[i]);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textHint),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.phone_in_talk_rounded,
                iconColor: AppColors.primary,
                label: 'Total Calls',
                value: '${_data['totalCalls'] ?? 0}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
                label: 'Analyzed',
                value: '${_data['analyzedCalls'] ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.score_rounded,
                iconColor: AppColors.warning,
                label: 'Avg Score',
                value: '${_data['avgScore'] ?? 0}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.accent,
                label: 'High Performers',
                value: '${_data['highPerformers'] ?? 0}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamCards() {
    return Column(
      children: [
        _teamStatCard(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.error,
          label: 'Needs Improvement',
          value: '${_data['needsImprovement'] ?? 0}',
          subtitle: 'Team members below threshold',
        ),
        const SizedBox(height: 12),
        _teamStatCard(
          icon: Icons.people_rounded,
          iconColor: AppColors.primary,
          label: 'Active Users',
          value: '${_data['uniqueUsers'] ?? 0}',
          subtitle: 'Users with recorded calls',
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
