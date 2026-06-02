import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file_model.dart';

class AudioFileService {
  /// Get all audio files from app storage
  Future<List<AudioFile>> getAllAudioFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(appDir.path);

      if (!audioDir.existsSync()) {
        return [];
      }

      final files = audioDir.listSync();
      final audioFiles = <AudioFile>[];

      for (var file in files) {
        if (file is File) {
          final name = file.path.split('/').last;
          // Only include audio files
          if (_isAudioFile(name)) {
            final stat = file.statSync();
            final duration = await _getAudioDuration(file.path);

            audioFiles.add(AudioFile(
              id: name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), ''),
              name: name,
              path: file.path,
              duration: duration,
              fileSize: stat.size,
              createdAt: stat.modified,
            ));
          }
        }
      }

      // Sort by creation date (newest first)
      audioFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return audioFiles;
    } catch (e) {
      print('Error getting audio files: $e');
      return [];
    }
  }

  /// Check if file is an audio file
  bool _isAudioFile(String filename) {
    final audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'webm', 'flac', 'wma'];
    final ext = filename.split('.').last.toLowerCase();
    return audioExtensions.contains(ext);
  }

  /// Get audio duration (simplified - returns 0 for now)
  /// In production, use audio_metadata or similar package
  Future<int> _getAudioDuration(String path) async {
    try {
      // This is a placeholder - in production use:
      // final metadata = await MetadataRetriever.fromFile(File(path));
      // return (metadata.duration ?? 0).toInt();
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Delete an audio file
  Future<bool> deleteAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting audio file: $e');
      return false;
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final stat = file.statSync();
        return stat.size;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Rename audio file
  Future<bool> renameAudioFile(String oldPath, String newName) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        final dir = file.parent;
        final newPath = '${dir.path}/$newName';
        await file.rename(newPath);
        return true;
      }
      return false;
    } catch (e) {
      print('Error renaming audio file: $e');
      return false;
    }
  }
}
