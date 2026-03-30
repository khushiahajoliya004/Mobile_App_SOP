import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../main.dart';
import '../services/foreground_service.dart';
import '../services/call_recorder_service.dart';
import '../services/call_state_service.dart';
import '../services/native_overlay_service.dart';
import '../services/api_service.dart';
import '../services/overlay_stream.dart';

class CallRecorderScreen extends StatefulWidget {
  const CallRecorderScreen({super.key});

  @override
  State<CallRecorderScreen> createState() => _CallRecorderScreenState();
}

class _CallRecorderScreenState extends State<CallRecorderScreen> with WidgetsBindingObserver {
  final _recorder = CallRecorderService();
  final _api = ApiService();
  final _callState = CallStateService();

  bool _serviceRunning = false;
  bool _checkingStatus = true;
  List<FileSystemEntity> _recordings = [];
  bool _loadingFiles = true;
  StreamSubscription? _overlaySubscription;
  StreamSubscription? _callStateSubscription;
  Timer? _refreshTimer;

  // Call state info
  String _currentCallState = 'idle';
  String _currentCallType = '';
  String _currentCallNumber = '';

  // Device capabilities
  Map<String, dynamic>? _deviceCaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _listenOverlayMessages();
    _listenCallState();
    _loadDeviceCapabilities();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_serviceRunning && mounted) _loadRecordings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkServiceStatus();
      _loadRecordings();
    }
  }

  void _listenOverlayMessages() {
    _overlaySubscription?.cancel();
    _overlaySubscription = overlayBroadcast.listen((data) {
      if (data is String && data.startsWith('recording_stopped:')) {
        _loadRecordings();
      }
    });
  }

  void _listenCallState() {
    _callStateSubscription = _callState.callStateStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentCallState = event.state;
          _currentCallType = event.callType;
          _currentCallNumber = event.number;
        });
      }
    });
  }

  Future<void> _loadDeviceCapabilities() async {
    final caps = await _recorder.getDeviceCapabilities();
    if (mounted) setState(() => _deviceCaps = caps);
  }

  Future<void> _init() async {
    await ForegroundServiceManager.initService();
    await _checkServiceStatus();
    await _loadRecordings();
  }

  Future<void> _checkServiceStatus() async {
    final running = await ForegroundServiceManager.isRunning();
    if (mounted) setState(() { _serviceRunning = running; _checkingStatus = false; });
  }

  Future<void> _loadRecordings() async {
    if (!_loadingFiles && mounted) setState(() => _loadingFiles = true);
    try { _recordings = await _recorder.getRecordedFiles(); } catch (_) {}
    if (mounted) setState(() => _loadingFiles = false);
  }

  Future<bool> _requestAllPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.phone,
      Permission.storage,
      Permission.notification,
    ].request();
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    if (!micOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return false;
    }
    return true;
  }

  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await ForegroundServiceManager.stopService();
      if (mounted) {
        setState(() => _serviceRunning = false);
        _loadRecordings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording service stopped')),
        );
      }
    } else {
      final granted = await _requestAllPermissions();
      if (!granted) return;

      final notifResult = await FlutterForegroundTask.requestNotificationPermission();
      if (notifResult != NotificationPermission.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission is required')),
          );
        }
        return;
      }

      // Check overlay permission via native channel
      final hasOverlay = await NativeOverlayService.hasOverlayPermission();
      if (!hasOverlay) {
        await NativeOverlayService.requestOverlayPermission();
        // Wait for user to grant permission
        await Future.delayed(const Duration(seconds: 2));
        final granted2 = await NativeOverlayService.hasOverlayPermission();
        if (!granted2 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Overlay permission is required for floating button')),
          );
          return;
        }
      }

      try {
        final started = await ForegroundServiceManager.startService();
        if (mounted) {
          if (started) {
            await ForegroundServiceManager.showOverlay();
            setState(() => _serviceRunning = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Floating record button is now active')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to start service')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _uploadRecording(FileSystemEntity file) async {
    try {
      final name = file.path.split(Platform.pathSeparator).last;
      await _api.uploadFile(file.path, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
      }
    }
  }

  Future<void> _deleteRecording(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await file.delete();
      // Also delete metadata file
      final metaFile = File('${file.path}.meta.json');
      if (await metaFile.exists()) await metaFile.delete();
      _loadRecordings();
    }
  }

  void _playRecording(FileSystemEntity file) {
    final name = file.path.split(Platform.pathSeparator).last;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AudioPlayerSheet(filePath: file.path, fileName: name),
    );
  }

  /// Show recording metadata in a bottom sheet.
  Future<void> _showRecordingInfo(FileSystemEntity file) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final stat = file.statSync();
    final meta = await _recorder.getRecordingMetadata(file.path);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Recording Info', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _infoRow('File', name),
            _infoRow('Size', '${(stat.size / 1024).toStringAsFixed(1)} KB'),
            _infoRow('Date', '${stat.modified.day}/${stat.modified.month}/${stat.modified.year} ${stat.modified.hour}:${stat.modified.minute.toString().padLeft(2, '0')}'),
            if (meta != null) ...[
              _infoRow('Call Type', meta['callType'] ?? 'manual'),
              _infoRow('Phone', meta['phoneNumber'] ?? 'N/A'),
              _infoRow('Audio Source', meta['audioSource'] ?? 'unknown'),
              _infoRow('Duration', '${((meta['durationMs'] ?? 0) / 1000).toStringAsFixed(1)}s'),
              _infoRow('Device', meta['device'] ?? 'unknown'),
            ] else
              _infoRow('Type', 'Manual recording'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _callStateSubscription?.cancel();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _callState.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Header section with gradient
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _serviceRunning
                          ? [const Color(0xFF059669), AppColors.success]
                          : [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: (_serviceRunning ? AppColors.success : AppColors.primary).withOpacity(0.3),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _checkingStatus
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
                      : Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              width: 84, height: 84,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                                boxShadow: _serviceRunning ? [
                                  BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                                ] : [],
                              ),
                              child: Icon(
                                _serviceRunning ? Icons.mic_rounded : Icons.mic_off_rounded,
                                color: Colors.white, size: 38,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _serviceRunning ? 'Service Active' : 'Call Recorder Off',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _serviceRunning
                                  ? 'Auto-recording calls. Floating button available.'
                                  : 'Tap Start to enable call monitoring & floating button.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: 190, height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _toggleService,
                                icon: Icon(_serviceRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 24),
                                label: Text(_serviceRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _serviceRunning ? AppColors.error : Colors.white,
                                  foregroundColor: _serviceRunning ? Colors.white : AppColors.primary,
                                  elevation: 4,
                                  shadowColor: (_serviceRunning ? AppColors.error : Colors.white).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Call state indicator (when active)
              if (_currentCallState != 'idle')
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentCallState == 'ringing'
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _currentCallState == 'ringing'
                            ? AppColors.warning.withOpacity(0.3)
                            : AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _currentCallState == 'ringing' ? Icons.ring_volume_rounded : Icons.call_rounded,
                          color: _currentCallState == 'ringing' ? AppColors.warning : AppColors.success,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentCallState == 'ringing' ? 'Incoming Call' : 'Call Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14,
                                  color: _currentCallState == 'ringing' ? AppColors.warning : AppColors.success,
                                ),
                              ),
                              if (_currentCallNumber.isNotEmpty)
                                Text('$_currentCallType: $_currentCallNumber',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Recording', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Device capabilities info
              if (_deviceCaps != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _getCapabilityText(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Recordings header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.library_music_rounded, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Text('Saved Recordings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                        onPressed: _loadRecordings,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ]),
                ),
              ),

              // Recordings list
              if (_loadingFiles)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)))
              else if (_recordings.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                      child: const Icon(Icons.mic_off_rounded, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text('No recordings yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('Calls will be auto-recorded when service is active', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                  ])),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final file = _recordings[index];
                      final name = file.path.split(Platform.pathSeparator).last;
                      final stat = file.statSync();
                      final sizeKb = (stat.size / 1024).toStringAsFixed(1);
                      final date = stat.modified;

                      // Determine call type from filename
                      final callTypeIcon = name.startsWith('incoming_') ? Icons.call_received_rounded
                          : name.startsWith('outgoing_') ? Icons.call_made_rounded
                          : Icons.mic_rounded;
                      final callTypeColor = name.startsWith('incoming_') ? AppColors.success
                          : name.startsWith('outgoing_') ? AppColors.primary
                          : AppColors.accent;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          onTap: () => _playRecording(file),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [callTypeColor, callTypeColor.withOpacity(0.7)]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: callTypeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Icon(callTypeIcon, color: Colors.white, size: 24),
                          ),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text(
                            '$sizeKb KB  •  ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                          ),
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: AppColors.textHint),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow, color: AppColors.primary), title: Text('Play'), dense: true)),
                              const PopupMenuItem(value: 'info', child: ListTile(leading: Icon(Icons.info_outline, color: AppColors.accent), title: Text('Info'), dense: true)),
                              const PopupMenuItem(value: 'upload', child: ListTile(leading: Icon(Icons.cloud_upload_outlined, color: AppColors.accent), title: Text('Upload'), dense: true)),
                              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.error), title: Text('Delete', style: TextStyle(color: AppColors.error)), dense: true)),
                            ],
                            onSelected: (val) {
                              if (val == 'play') _playRecording(file);
                              if (val == 'info') _showRecordingInfo(file);
                              if (val == 'upload') _uploadRecording(file);
                              if (val == 'delete') _deleteRecording(file);
                            },
                          ),
                        ),
                      );
                    }, childCount: _recordings.length),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCapabilityText() {
    if (_deviceCaps == null) return '';
    final version = _deviceCaps!['androidVersion'] ?? 0;
    final manufacturer = _deviceCaps!['manufacturer'] ?? 'Unknown';
    final model = _deviceCaps!['model'] ?? '';
    final supportsVoiceComm = _deviceCaps!['supportsVoiceCommunication'] ?? false;

    if (version >= 30 && !supportsVoiceComm) {
      return '$manufacturer $model (Android $version) — Mic-only recording. Both-side capture requires Android 9 or lower.';
    }
    return '$manufacturer $model (Android $version) — Both-side recording may be available.';
  }
}

class _AudioPlayerSheet extends StatefulWidget {
  final String filePath;
  final String fileName;
  const _AudioPlayerSheet({required this.filePath, required this.fileName});

  @override
  State<_AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<_AudioPlayerSheet> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onPlayerComplete.listen((_) { if (mounted) setState(() { _playing = false; _position = Duration.zero; }); });
    _player.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _playing = state == PlayerState.playing); });
    _player.play(DeviceFileSource(widget.filePath));
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  String _fmt(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.audio_file_rounded, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(widget.fileName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primarySurface,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayColor: AppColors.primary.withOpacity(0.1),
          ),
          child: Slider(
            min: 0,
            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
            onChanged: (val) => _player.seek(Duration(milliseconds: val.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_fmt(_position), style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w500)),
            Text(_fmt(_duration), style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              color: AppColors.primary,
              onPressed: () { final p = _position - const Duration(seconds: 10); _player.seek(p < Duration.zero ? Duration.zero : p); },
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: IconButton(
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: Colors.white),
              onPressed: () { if (_playing) _player.pause(); else _player.resume(); },
            ),
          ),
          const SizedBox(width: 20),
          Container(
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              color: AppColors.primary,
              onPressed: () { final p = _position + const Duration(seconds: 10); _player.seek(p > _duration ? _duration : p); },
            ),
          ),
        ]),
      ]),
    );
  }
}
