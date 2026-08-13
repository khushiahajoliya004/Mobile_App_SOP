import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../models/audio_file_model.dart';
import '../services/audio_file_service.dart';

class AudioLibraryScreen extends StatefulWidget {
  final bool showAppBar;
  const AudioLibraryScreen({super.key, this.showAppBar = false});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final _audioService = AudioFileService();
  final _audioPlayer = AudioPlayer();
  final _subscriptions = <StreamSubscription>[];
  List<AudioFile> _audioFiles = [];
  bool _loading = true;
  String? _playingId;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
    _setupAudioPlayer();
  }

  static final _audioCtx = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {},
    ),
  );

  void _setupAudioPlayer() {
    _subscriptions.addAll([
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      }),
      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _totalDuration = duration);
      }),
      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) setState(() => _currentPosition = position);
      }),
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentPosition = Duration.zero;
            _playingId = null;
          });
        }
      }),
    ]);
  }

  Future<void> _loadAudioFiles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final files = await _audioService.getAllAudioFiles();
    if (!mounted) return;
    setState(() {
      _audioFiles = files;
      _loading = false;
    });
  }

  Future<void> _playAudio(AudioFile file) async {
    try {
      if (_playingId == file.id && _isPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else if (_playingId == file.id) {
        await _audioPlayer.resume();
        if (mounted) setState(() => _isPlaying = true);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer.setPlaybackRate(1.0);
        await _audioPlayer.play(
          DeviceFileSource(file.path),
          volume: 1.0,
          ctx: _audioCtx,
        );
        if (mounted) {
          setState(() {
            _playingId = file.id;
            _isPlaying = true;
            _currentPosition = Duration.zero;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
      }
    }
  }

  Future<void> _downloadAudio(AudioFile file) async {
    try {
      final sourceFile = File(file.path);
      if (!await sourceFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('File not found')));
        }
        return;
      }

      // file.name already includes the extension (see AudioFileService,
      // which derives it from the actual filename on disk) — appending
      // '.m4a' again produced 'xxx.m4a.m4a'.
      final fileName = file.name;
      final bytes = await sourceFile.readAsBytes();

      // Write via the platform's native "save as" flow (passing `bytes`
      // makes file_picker use Android's Storage Access Framework under the
      // hood) instead of picking a raw directory path and copying into it —
      // modern Android blocks direct filesystem writes to arbitrary
      // user-picked folders, which is what caused
      // "PathAccessException: Operation not permitted".
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select folder to save audio',
        fileName: fileName,
        bytes: bytes,
      );

      if (savedPath == null) return; // User cancelled

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $fileName'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _deleteAudio(AudioFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Audio',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text('Delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_playingId == file.id) {
        await _audioPlayer.stop();
        setState(() {
          _playingId = null;
          _isPlaying = false;
        });
      }

      final success = await _audioService.deleteAudioFile(file.path);
      if (success) {
        await _loadAudioFiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Audio deleted')));
        }
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Audio Library',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _loadAudioFiles,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            )
          : _audioFiles.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAudioFiles,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _audioFiles.length,
                itemBuilder: (ctx, i) => _buildAudioTile(_audioFiles[i]),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Audio Files',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Record or upload audio files to see them here',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadAudioFiles,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTile(AudioFile audio) {
    final isPlaying = _playingId == audio.id;
    final isCurrentlyPlaying = isPlaying && _isPlaying;

    return Container(
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
        border: isPlaying
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play button
              GestureDetector(
                onTap: () => _playAudio(audio),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCurrentlyPlaying
                          ? [AppColors.primary, AppColors.primaryDark]
                          : [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCurrentlyPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title + metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _metaChip(
                          Icons.timer_outlined,
                          audio.formattedDuration,
                        ),
                        const SizedBox(width: 8),
                        _metaChip(Icons.storage_rounded, audio.formattedSize),
                        const SizedBox(width: 8),
                        _metaChip(
                          Icons.calendar_today_rounded,
                          audio.formattedDate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Download button
              GestureDetector(
                onTap: () => _downloadAudio(audio),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Delete button
              GestureDetector(
                onTap: () => _deleteAudio(audio),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          // Progress bar when playing
          if (isPlaying) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _totalDuration.inMilliseconds > 0
                    ? _currentPosition.inMilliseconds /
                          _totalDuration.inMilliseconds
                    : 0,
                minHeight: 4,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_totalDuration.inMinutes}:${(_totalDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
