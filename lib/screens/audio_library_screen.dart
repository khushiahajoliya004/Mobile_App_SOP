import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../main.dart';
import '../models/audio_file_model.dart';
import '../services/audio_file_service.dart';

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final _audioService = AudioFileService();
  final _audioPlayer = AudioPlayer();
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

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _totalDuration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _currentPosition = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _playingId = null;
      });
    });
  }

  Future<void> _loadAudioFiles() async {
    setState(() => _loading = true);
    final files = await _audioService.getAllAudioFiles();
    setState(() {
      _audioFiles = files;
      _loading = false;
    });
  }

  Future<void> _playAudio(AudioFile file) async {
    try {
      if (_playingId == file.id && _isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      } else if (_playingId == file.id) {
        await _audioPlayer.resume();
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      } else {
        await _audioPlayer.play(DeviceFileSource(file.path));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _deleteAudio(AudioFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Audio'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio deleted')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _audioFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Audio Files',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record or upload audio files to see them here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textHint,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAudioFiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _audioFiles.length,
                    itemBuilder: (ctx, i) {
                      final audio = _audioFiles[i];
                      final isPlaying = _playingId == audio.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPlaying
                                    ? [AppColors.primary, AppColors.primaryDark]
                                    : [AppColors.accent, AppColors.primaryLight],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          title: Text(
                            audio.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    audio.formattedDuration,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    audio.formattedSize,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    audio.formattedDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                              if (isPlaying) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _totalDuration.inMilliseconds > 0
                                        ? _currentPosition.inMilliseconds /
                                            _totalDuration.inMilliseconds
                                        : 0,
                                    minHeight: 3,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')} / ${_totalDuration.inMinutes}:${(_totalDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 20),
                                    SizedBox(width: 12),
                                    Text('Delete'),
                                  ],
                                ),
                                onTap: () => _deleteAudio(audio),
                              ),
                            ],
                          ),
                          onTap: () => _playAudio(audio),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
