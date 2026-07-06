import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/user_model.dart';
import '../../models/timesheet_entry_model.dart';
import '../../services/api_service.dart';

class TimesheetDashboardScreen extends StatefulWidget {
  final UserModel user;
  const TimesheetDashboardScreen({super.key, required this.user});

  @override
  State<TimesheetDashboardScreen> createState() =>
      _TimesheetDashboardScreenState();
}

class _TimesheetDashboardScreenState extends State<TimesheetDashboardScreen> {
  final _api = ApiService();
  TimesheetDashboardStats? _adminStats;
  MyTimesheetStats? _myStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.user.isTechnicalAdmin) {
        final res = await _api.getTimesheetDashboardStats(
          widget.user.companyId ?? '',
        );
        setState(() {
          _adminStats = TimesheetDashboardStats.fromJson(res.data['data']);
          _loading = false;
        });
      } else {
        final res = await _api.getMyTimesheetStats(widget.user.id);
        setState(() {
          _myStats = MyTimesheetStats.fromJson(res.data['data']);
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: widget.user.isTechnicalAdmin
          ? _buildAdminView()
          : _buildUserView(),
    );
  }

  Widget _buildAdminView() {
    final s = _adminStats;
    if (s == null) {
      return const Center(child: Text('No data'));
    }

    final pct = s.budgetUsedPercent;
    final budgetColor = pct >= 100
        ? Colors.red
        : pct >= 80
            ? Colors.orange
            : const Color(0xFF10B981);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _kpiCard(
              '${s.totalHoursLogged.toStringAsFixed(1)}h',
              'Total Hours Logged',
              AppColors.primary,
              Icons.access_time_rounded,
            ),
            _kpiCard(
              '${s.activeMembers}',
              'Active Members',
              const Color(0xFF0D9488),
              Icons.people_rounded,
            ),
            _kpiCard(
              '${s.activeProjects}',
              'Active Projects',
              const Color(0xFF3B82F6),
              Icons.folder_rounded,
            ),
            _kpiCard(
              '${pct.toStringAsFixed(0)}%',
              'Budget Used',
              budgetColor,
              Icons.pie_chart_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Hours by Role
        if (s.hoursByRole.isNotEmpty) ...[
          const Text(
            'Hours by Role',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: s.hoursByRole
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                r.roleName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: s.totalHoursLogged > 0
                                      ? (r.hours / s.totalHoursLogged)
                                          .clamp(0.0, 1.0)
                                      : 0,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${r.hours.toStringAsFixed(1)}h',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Hours by Project
        if (s.hoursByProject.isNotEmpty) ...[
          const Text(
            'Logged vs Estimated by Project',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: s.hoursByProject
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    p.projectName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${p.hours.toStringAsFixed(1)} / ${p.estimatedHours.toStringAsFixed(0)}h',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.hours > p.estimatedHours
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: p.estimatedHours > 0
                                      ? (p.hours / p.estimatedHours).clamp(
                                          0.0,
                                          1.0,
                                        )
                                      : 0,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: p.hours > p.estimatedHours
                                          ? Colors.red
                                          : AppColors.primary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Recent entries
        const Text(
          'Recent Team Entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...s.recentEntries.map((e) => _entryTile(e)),
      ],
    );
  }

  Widget _buildUserView() {
    final s = _myStats;
    if (s == null) {
      return const Center(child: Text('No data'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _kpiCard(
              '${s.myHoursThisWeek.toStringAsFixed(1)}h',
              'This Week',
              AppColors.primary,
              Icons.access_time_rounded,
            ),
            _kpiCard(
              '${s.myActiveProjects}',
              'Projects',
              const Color(0xFF0D9488),
              Icons.folder_rounded,
            ),
            _kpiCard(
              '${s.myTotalHoursAllTime.toStringAsFixed(0)}h',
              'All Time',
              const Color(0xFF3B82F6),
              Icons.history_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'My Recent Entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...s.recentEntries.map((e) => _entryTile(e)),
      ],
    );
  }

  Widget _kpiCard(String value, String label, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(TimesheetEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${e.hours}h',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(
          e.projectName ?? e.projectId,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          '${e.userName ?? ''} · ${e.taskName ?? ''}\n${e.narration}',
          style: const TextStyle(fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          e.date,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        isThreeLine: true,
      ),
    );
  }
}
