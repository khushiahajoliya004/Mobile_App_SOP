import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getCalls();
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      setState(() {
        _calls = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load call history';
        _loading = false;
      });
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final c in _calls) {
        final id = c['id']?.toString();
        if (id != null && c['audioUrl'] != null) _selectedIds.add(id);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedIds.isEmpty) return;

    if (_selectedIds.length > 50) {
      _showSnack('Maximum 50 recordings can be downloaded at once', isError: true);
      return;
    }

    setState(() => _downloading = true);

    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnack('Storage permission is required to save files', isError: true);
          setState(() => _downloading = false);
          return;
        }
      }

      final response = await _api.bulkDownloadCalls(_selectedIds.toList());
      final bytes = response.data;

      if (bytes == null || bytes.isEmpty) {
        _showSnack('No audio files found for selected calls', isError: true);
        setState(() => _downloading = false);
        return;
      }

      // Save to public Downloads (Android) or Files app (iOS)
      Directory? dir;
      String locationLabel;
      if (Platform.isAndroid) {
        dir = await getDownloadsDirectory();
        dir ??= Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) await dir.create(recursive: true);
        locationLabel = 'Downloads folder';
      } else {
        dir = await getApplicationDocumentsDirectory();
        locationLabel = 'Files app → On My iPhone → MysteryMentor';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _selectedIds.length == 1
          ? 'recording_$timestamp.mp3'
          : 'recordings_$timestamp.zip';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() {
        _downloading = false;
        _selectMode = false;
        _selectedIds.clear();
      });

      _showSnack('Saved to $locationLabel\nFile: $fileName');
    } catch (e) {
      setState(() => _downloading = false);
      _showSnack('Download failed. Please try again.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _selectMode ? _buildDownloadBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
      ),
      title: _selectMode
          ? Text('${_selectedIds.length} selected',
              style: const TextStyle(color: Colors.white))
          : const Text('Call History'),
      actions: [
        if (_selectMode) ...[
          TextButton(
            onPressed: _selectAll,
            child: const Text('All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: _toggleSelectMode,
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ] else
          IconButton(
            onPressed: _calls.isEmpty ? null : _toggleSelectMode,
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Select to download',
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 28, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Please check your connection and try again',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadCalls,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Retry',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
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
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No calls found',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Your call history will appear here',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCalls,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: _selectMode ? 100 : 16,
        ),
        itemCount: _calls.length,
        itemBuilder: (context, index) => _buildCallCard(_calls[index]),
      ),
    );
  }

  Widget _buildCallCard(dynamic call) {
    final id = call['id']?.toString() ?? '';
    final customerName = call['customerName'] ?? 'Unknown';
    final categoryName = call['category']?['name'] ?? '';
    final stageName = call['salesStage']?['name'] ?? '';
    final analysisStatus = call['analysisStatus'] ?? 'PENDING';
    final sopScore = call['sopScore'];
    final date = call['createdAt'] ?? '';
    final hasAudio = call['audioUrl'] != null;
    final userName = call['user'] != null
        ? '${call['user']['firstName'] ?? ''} ${call['user']['lastName'] ?? ''}'.trim()
        : '';
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: _selectMode && hasAudio ? () => _toggleSelect(id) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _selectMode && isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox or avatar
              if (_selectMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: hasAudio ? (_) => _toggleSelect(id) : null,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
              ],
              // Avatar
              if (!_selectMode)
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ),
              if (!_selectMode) const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  )),
                              if (userName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('by $userName',
                                      style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(analysisStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (sopScore != null) _buildScoreBadge(sopScore),
                        if (categoryName.isNotEmpty)
                          _buildTag(Icons.label_rounded, categoryName, AppColors.primary),
                        if (stageName.isNotEmpty)
                          _buildTag(Icons.flag_rounded, stageName, AppColors.accent),
                        _buildTag(Icons.calendar_today_rounded, _formatDate(date), AppColors.textSecondary),
                        if (!hasAudio && _selectMode)
                          _buildTag(Icons.no_photography_rounded, 'No audio', AppColors.error),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedIds.isEmpty || _downloading ? null : _downloadSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.textHint.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _downloading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Downloading...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedIds.isEmpty
                            ? 'Select recordings to download'
                            : 'Download ${_selectedIds.length} Recording${_selectedIds.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(dynamic score) {
    final numScore = score is num ? score.toInt() : int.tryParse('$score') ?? 0;
    Color color;
    if (numScore >= 80) {
      color = AppColors.success;
    } else if (numScore >= 60) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.score_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text('$numScore%',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(status,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
