import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getCrmNotifications();
      final raw = res.data;
      final list = raw is Map
          ? (raw['data'] as List? ?? [])
          : (raw as List? ?? []);
      if (mounted) {
        setState(() {
          _notifications = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
        // Update bell badge to reflect server state
        final unread = _notifications.where((n) => !(n['isRead'] as bool? ?? false)).length;
        NotificationService.unreadCount.value = unread;
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _api.markNotificationRead(id);
      await _load();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllCrmNotificationsRead();
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !(n['isRead'] as bool? ?? false));
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(
        children: [
          _buildHeader(context, hasUnread),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasUnread) {
    return Container(
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
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (hasUnread && !_loading)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('Failed to load notifications',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.textHint), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_notifications.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildTile(_notifications[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text("You're all caught up!",
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> notif) {
    final isRead = notif['isRead'] as bool? ?? false;
    final id = notif['id']?.toString() ?? '';
    final title = notif['title']?.toString() ?? '';
    final message = notif['message']?.toString() ?? '';
    final type = notif['type']?.toString() ?? '';
    final createdAt = notif['createdAt'] != null
        ? DateTime.tryParse(notif['createdAt'].toString())?.toLocal()
        : null;
    final metadata = notif['metadata'] as Map<String, dynamic>?;
    final expiryDate = metadata?['expiryDate'] != null
        ? DateTime.tryParse(metadata!['expiryDate'].toString())?.toLocal()
        : null;

    final isPlanNotif = type == 'PLAN_EXPIRY_WARNING' || type == 'PLAN_EXPIRING_SOON' || type == 'PLAN_EXPIRED';
    final Color iconColor;
    final IconData iconData;
    switch (type) {
      case 'PLAN_EXPIRED':
        iconColor = AppColors.error;
        iconData = Icons.cancel_rounded;
        break;
      case 'PLAN_EXPIRY_WARNING':
      case 'PLAN_EXPIRING_SOON':
        iconColor = AppColors.warning;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'LEAD_ASSIGNED':
        iconColor = AppColors.primary;
        iconData = Icons.person_add_rounded;
        break;
      case 'TASK_ASSIGNED':
      case 'TASK_DUE':
      case 'TASK_OVERDUE':
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.task_alt_rounded;
        break;
      default:
        iconColor = AppColors.primary;
        iconData = Icons.notifications_rounded;
    }

    return GestureDetector(
      onTap: () async {
        if (!isRead) await _markRead(id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : iconColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.grey.shade100 : iconColor.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                  if (expiryDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expires ${_fmtDate(expiryDate)}',
                      style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                  if (isPlanNotif) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        if (!isRead) await _markRead(id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Renew Now',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _fmtDate(dt);
  }
}
