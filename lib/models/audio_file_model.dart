class AudioFile {
  final String id;
  final String name;
  final String path;
  final int duration; // in milliseconds
  final int fileSize; // in bytes
  final DateTime createdAt;
  final String? notes;

  AudioFile({
    required this.id,
    required this.name,
    required this.path,
    required this.duration,
    required this.fileSize,
    required this.createdAt,
    this.notes,
  });

  String get formattedDuration {
    final minutes = duration ~/ 60000;
    final seconds = (duration % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final fileDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (fileDate == today) {
      return 'Today ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (fileDate == yesterday) {
      return 'Yesterday ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
