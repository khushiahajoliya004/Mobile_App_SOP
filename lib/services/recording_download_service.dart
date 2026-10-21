import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_service.dart';

/// Downloads call recordings and hands them to the user.
///
/// Fetches straight from the recording's storage URL (the same URL the
/// in-app player streams, so it shows real progress) and falls back to the
/// backend's `/calls/bulk-download` when that URL can't be reached. Saving
/// goes through the system "Save to…" dialog (Storage Access Framework on
/// Android, Files on iOS), which needs no storage permission and lands the
/// file somewhere the user can actually find — unlike the app's private
/// folder.
class RecordingDownloadService {
  RecordingDownloadService._();

  static const _audioExts = {
    'mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus', 'webm', 'mp4', 'amr', '3gp', 'flac',
  };

  static bool hasRecording(Map<String, dynamic> call) =>
      (call['audioUrl'] as String?)?.trim().isNotEmpty == true;

  /// `CustomerName_2026-10-21_15-18.m4a` — keeps non-Latin names (Gujarati,
  /// Hindi) and only strips characters file systems reject.
  static String fileNameFor(Map<String, dynamic> call) {
    final rawName = (call['aiAnalysis']?['customerName'] ??
            call['customerName'] ??
            'call')
        .toString();
    var name = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    if (name.isEmpty) name = 'call';
    if (name.length > 40) name = name.substring(0, 40);

    final created = DateTime.tryParse(call['createdAt']?.toString() ?? '')?.toLocal();
    final stamp = created == null
        ? (call['id']?.toString() ?? '').split('-').first
        : '${created.year}-${_two(created.month)}-${_two(created.day)}_${_two(created.hour)}-${_two(created.minute)}';

    return '${name}_$stamp.${extensionFor(call)}';
  }

  static String extensionFor(Map<String, dynamic> call) {
    final url = (call['audioUrl'] as String?) ?? '';
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
    return _audioExts.contains(ext) ? ext : 'mp3';
  }

  static String mimeTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'm4a':
      case 'mp4':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'zip':
        return 'application/zip';
      default:
        return 'audio/$ext';
    }
  }

  /// Recording bytes. [onProgress] gets 0..1, or null while the total size
  /// is unknown.
  static Future<Uint8List> fetch(
    Map<String, dynamic> call,
    ApiService api, {
    void Function(double? progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    void report(int received, int total) =>
        onProgress?.call(total > 0 ? received / total : null);

    final url = (call['audioUrl'] as String?)?.trim() ?? '';
    if (url.startsWith('http')) {
      try {
        // Plain Dio on purpose: storage URLs must not get the app's auth
        // header or base URL.
        final res = await Dio().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 5),
          ),
          onReceiveProgress: report,
          cancelToken: cancelToken,
        );
        final data = res.data;
        if (data != null && data.isNotEmpty) return Uint8List.fromList(data);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
      }
    }

    final res = await api.bulkDownloadRecordings(
      [call['id'].toString()],
      onReceiveProgress: report,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is List<int> && data.isNotEmpty) return Uint8List.fromList(data);
    throw Exception('Recording is empty');
  }

  /// Opens the system "Save to…" dialog. Returns false if the user cancelled.
  /// Falls back to the share sheet where the platform has no save dialog.
  static Future<bool> saveToDevice(Uint8List bytes, String fileName) async {
    try {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save recording',
        fileName: fileName,
        bytes: bytes,
      );
      return saved != null;
    } catch (_) {
      await share(bytes, fileName);
      return true;
    }
  }

  /// Share sheet — WhatsApp, Drive, email, "Save to Files", etc.
  static Future<void> share(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeTypeFor(fileName), name: fileName)],
      subject: fileName,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
