import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _api = ApiService();
  List<dynamic> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _api.getCalls();
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      setState(() {
        _calls = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load call history'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadCalls,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No calls found', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Your call history will appear here', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCalls,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _calls.length,
        itemBuilder: (context, index) {
          final call = _calls[index];
          final customerName = call['customerName'] ?? 'Unknown';
          final categoryName = call['category']?['name'] ?? '';
          final stageName = call['salesStage']?['name'] ?? '';
          final analysisStatus = call['analysisStatus'] ?? 'PENDING';
          final sopScore = call['sopScore'];
          final date = call['createdAt'] ?? '';
          final userName = call['user'] != null
              ? '${call['user']['firstName'] ?? ''} ${call['user']['lastName'] ?? ''}'.trim()
              : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customerName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                            if (userName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('by $userName',
                                    style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      _buildStatusChip(analysisStatus),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (categoryName.isNotEmpty)
                        _buildTag(Icons.category_outlined, categoryName, AppColors.primary),
                      if (stageName.isNotEmpty)
                        _buildTag(Icons.trending_up_rounded, stageName, AppColors.accent),
                      if (sopScore != null)
                        _buildTag(Icons.score_rounded, 'Score: $sopScore', AppColors.warning),
                      _buildTag(Icons.calendar_today_rounded, _formatDate(date), AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'COMPLETED':
        color = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'PROCESSING':
        color = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'FAILED':
        color = AppColors.error;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = AppColors.textHint;
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
