import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AudioSource { local, device }

class _MediaStoreFile {
  final String name;
  final String path;
  final int size;
  final int durationMs;
  final int dateModifiedSec;

  const _MediaStoreFile({
    required this.name,
    required this.path,
    required this.size,
    required this.durationMs,
    required this.dateModifiedSec,
  });

  factory _MediaStoreFile.fromMap(Map map) => _MediaStoreFile(
        name: map['name'] as String? ?? 'Unknown',
        path: map['path'] as String? ?? '',
        size: (map['size'] as num?)?.toInt() ?? 0,
        durationMs: (map['duration'] as num?)?.toInt() ?? 0,
        dateModifiedSec: (map['dateModified'] as num?)?.toInt() ?? 0,
      );

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(dateModifiedSec * 1000);
}

class CallUploadScreen extends StatefulWidget {
  final String? leadId;
  final String? leadName;
  final String? leadPhone;

  const CallUploadScreen({super.key, this.leadId, this.leadName, this.leadPhone});

  @override
  State<CallUploadScreen> createState() => _CallUploadScreenState();
}

class _CallUploadScreenState extends State<CallUploadScreen> {
  static const _recorderChannel =
      MethodChannel('com.callrecorder/native_recorder');

  final _api = ApiService();
  final _auth = AuthService();
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  UserModel? _user;
  bool _uploading = false;
  bool _loadingData = true;
  String? _statusMessage;
  bool _isError = false;

  // Phone lookup state
  bool _lookingUp = false;
  String? _linkedLeadId;
  String? _linkedLeadName;

  // SOP-resolved fields (fetched automatically from user's assigned SOP)
  String? _sopCategoryId;
  String? _sopSalesStageId;
  String? _sopName;
  bool _hasSop = false;
  bool _sopLoading = false;

  // Audio source
  AudioSource _audioSource = AudioSource.local;
  List<File> _localRecordings = [];
  File? _selectedLocalRecording;
  _MediaStoreFile? _selectedDeviceFile;
  bool _isLoadingMediaStore = false;

  @override
  void initState() {
    super.initState();
    if (widget.leadId != null) {
      _linkedLeadId = widget.leadId;
      _linkedLeadName = widget.leadName;
      _customerNameController.text = widget.leadName ?? '';
      _phoneController.text = widget.leadPhone ?? '';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      _user = await _auth.getUser();
      _hasSop = _user?.sopId != null && _user!.sopId!.isNotEmpty;

      // Fetch SOP details to auto-resolve categoryId + salesStageId
      if (_hasSop) {
        setState(() => _sopLoading = true);
        try {
          final res = await _api.getMySop();
          final sopData = res.data is Map ? res.data['data'] : null;
          if (sopData != null) {
            _sopCategoryId = sopData['categoryId'];
            _sopSalesStageId = sopData['salesStageId'];
            _sopName = sopData['sopName'];
          }
        } catch (e) {
          debugPrint('[Upload] SOP fetch error: $e');
        } finally {
          setState(() => _sopLoading = false);
        }
      }

      await _loadLocalRecordings();
    } catch (e) {
      debugPrint('[Upload] Load error: $e');
    }
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _loadLocalRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.m4a') ||
                f.path.endsWith('.wav') ||
                f.path.endsWith('.mp3') ||
                f.path.endsWith('.aac'),
          )
          .toList();
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      _localRecordings = files;
    } catch (e) {
      _localRecordings = [];
    }
  }

  String _getFileName(File file) =>
      file.path.split(Platform.pathSeparator).last;

  String _getFileInfo(File file) {
    final stat = file.statSync();
    final sizeKb = (stat.size / 1024).toStringAsFixed(1);
    final d = stat.modified;
    return '$sizeKb KB  •  ${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<List<_MediaStoreFile>> _queryMediaStoreAudio() async {
    try {
      if (Platform.isAndroid) {
        await [Permission.audio, Permission.storage].request();
      }
      final List? result =
          await _recorderChannel.invokeMethod('queryAudioFiles');
      if (result == null) return [];
      return result.map((e) => _MediaStoreFile.fromMap(e as Map)).toList();
    } catch (e) {
      debugPrint('[MediaStore] $e');
      return [];
    }
  }

  Future<void> _showAudioFilePicker() async {
    setState(() => _isLoadingMediaStore = true);
    final files = await _queryMediaStoreAudio();
    if (mounted) setState(() => _isLoadingMediaStore = false);
    if (!mounted) return;

    if (files.isEmpty) {
      await _pickDeviceFileFallback();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildAudioPickerSheet(files),
    );
  }

  Future<void> _pickDeviceFileFallback() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'wma'],
    );
    if (result != null && result.files.isNotEmpty) {
      final pf = result.files.first;
      if (mounted) {
        setState(() {
          _selectedDeviceFile = _MediaStoreFile(
            name: pf.name,
            path: pf.path ?? '',
            size: pf.size,
            durationMs: 0,
            dateModifiedSec: 0,
          );
          _statusMessage = null;
        });
      }
    }
  }

  Widget _buildAudioPickerSheet(List<_MediaStoreFile> files) {
    String query = '';
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        final filtered = query.isEmpty
            ? files
            : files
                .where((f) =>
                    f.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Select Audio File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} files',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (v) => setSheetState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search audio files...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No files found',
                            style:
                                TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.grey.shade100,
                            height: 1,
                          ),
                          itemBuilder: (_, i) {
                            if (i == filtered.length) {
                              return _buildFallbackButton(ctx);
                            }
                            return _buildAudioFileItem(
                                filtered[i], ctx);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioFileItem(
      _MediaStoreFile file, BuildContext sheetCtx) {
    final d = file.dateTime;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final sizeStr = _formatFileSize(file.size);
    final dur = Duration(milliseconds: file.durationMs);
    final durationStr = file.durationMs > 0
        ? '  •  ${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}'
        : '';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.audio_file_rounded,
            color: AppColors.primary, size: 22),
      ),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '$sizeStr$durationStr  •  $dateStr',
        style:
            const TextStyle(fontSize: 11, color: AppColors.textHint),
      ),
      onTap: () {
        setState(() {
          _selectedDeviceFile = file;
          _statusMessage = null;
        });
        Navigator.pop(sheetCtx);
      },
    );
  }

  Widget _buildFallbackButton(BuildContext sheetCtx) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: () async {
          Navigator.pop(sheetCtx);
          await _pickDeviceFileFallback();
        },
        icon: const Icon(Icons.folder_open_rounded, size: 18),
        label: const Text('Browse Files Manually'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey.shade300),
          foregroundColor: AppColors.textSecondary,
        ),
      ),
    );
  }

  String? get _audioFilePath => _audioSource == AudioSource.local
      ? _selectedLocalRecording?.path
      : _selectedDeviceFile?.path;

  String? get _audioFileName {
    if (_audioSource == AudioSource.local && _selectedLocalRecording != null) {
      return _getFileName(_selectedLocalRecording!);
    } else if (_audioSource == AudioSource.device &&
        _selectedDeviceFile != null) {
      return _selectedDeviceFile!.name;
    }
    return null;
  }

  Future<void> _upload() async {
    if (_customerNameController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Customer name is required';
        _isError = true;
      });
      return;
    }
    if (_user?.companyId == null) {
      setState(() {
        _statusMessage = 'User data missing. Please re-login.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _uploading = true;
      _statusMessage = null;
    });

    try {
      debugPrint('[Upload] companyId=${_user!.companyId} userId=${_user!.id}');
      debugPrint('[Upload] categoryId=$_sopCategoryId salesStageId=$_sopSalesStageId');
      debugPrint('[Upload] audioPath=$_audioFilePath audioName=$_audioFileName');
      debugPrint('[Upload] leadId=$_linkedLeadId phone=${_phoneController.text.trim()}');

      final customerName = _customerNameController.text.trim();
      final companyId = _user!.companyId!;
      final userId = _user!.id;
      final notes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;
      final phone = _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null;

      try {
        await _api.createCall(
          customerName: customerName,
          companyId: companyId,
          userId: userId,
          categoryId: _sopCategoryId,
          salesStageId: _sopSalesStageId,
          notes: notes,
          audioFilePath: _audioFilePath,
          audioFileName: _audioFileName,
          leadId: _linkedLeadId,
          phoneNumber: phone,
        );
      } on DioException catch (e1) {
        if (e1.response?.statusCode == 500) {
          // Retry without optional relational IDs that may not exist in prod DB
          debugPrint('[Upload] 500 on full payload, retrying without optional IDs...');
          await _api.createCall(
            customerName: customerName,
            companyId: companyId,
            userId: userId,
            notes: notes,
            audioFilePath: _audioFilePath,
            audioFileName: _audioFileName,
            phoneNumber: phone,
          );
        } else {
          rethrow;
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Call submitted for approval';
          _isError = false;
          _selectedDeviceFile = null;
          _selectedLocalRecording = null;
          _customerNameController.clear();
          _phoneController.clear();
          _notesController.clear();
          _linkedLeadId = null;
          _linkedLeadName = null;
        });
        _showSnack('Call submitted for approval', success: true);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = 'Upload failed. Try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            errMsg = data['message']?.toString() ?? data['error']?.toString() ?? errMsg;
          } else if (data is String && data.isNotEmpty) {
            errMsg = data;
          } else if (e.response?.statusCode != null) {
            errMsg = 'Server error ${e.response!.statusCode}. Try again.';
          }
        }
        if (e is DioException) {
          debugPrint('[Upload] status: ${e.response?.statusCode}');
          debugPrint('[Upload] response body: ${e.response?.data}');
        }
        debugPrint('[Upload] error: $e');
        setState(() {
          _statusMessage = errMsg;
          _isError = true;
        });
        _showSnack(errMsg);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _lookupPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _linkedLeadId = null;
      _linkedLeadName = null;
    });
    try {
      final res = await _api.checkDuplicateLead(phone);
      final raw = res.data;
      final data = raw is Map ? (raw['data'] ?? raw) : {};
      final isDuplicate = data['exists'] == true || data['isDuplicate'] == true;
      // Backend returns 'leads' array or 'contact' object (v2 CRM)
      final leadsList = data['leads'];
      final lead = (leadsList is List && leadsList.isNotEmpty)
          ? leadsList.first
          : (data['lead'] ?? data['existingLead'] ?? data['contact']);
      if (isDuplicate && lead != null && lead is Map) {
        final name = (lead['customerName'] ?? lead['name'])?.toString() ?? '';
        setState(() {
          _linkedLeadId = lead['id']?.toString();
          _linkedLeadName = name;
          if (name.isNotEmpty && _customerNameController.text.trim().isEmpty) {
            _customerNameController.text = name;
          }
        });
        _showSnack('Lead found: $name', success: true);
      } else {
        _showSnack('No existing lead found for this number');
      }
    } catch (_) {
      _showSnack('Lookup failed. Continue without linking.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    // No SOP assigned — show warning but still allow upload
    if (!_hasSop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No SOP Assigned',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload will work but AI analysis needs SOP. Ask admin to assign one.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Form card
            _buildUploadForm(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upload Call Recording',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // SOP info chip
          if (_hasSop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sopLoading
                        ? const Text(
                            'Loading SOP...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sopName != null
                                    ? 'SOP: $_sopName'
                                    : 'SOP Assigned',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (_sopCategoryId != null ||
                                  _sopSalesStageId != null)
                                const Text(
                                  'Category & stage auto-resolved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (!_sopLoading)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                ],
              ),
            ),

          _buildUploadForm(),
        ],
      ),
    );
  }

  Widget _buildUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Form card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _customerNameController,
                style: const TextStyle(color: AppColors.textPrimary),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'Enter customer name',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Phone lookup row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      onChanged: (v) {
                        // Auto-lookup when 10 digits entered
                        if (v.trim().length >= 10 && !_lookingUp) {
                          _lookupPhone();
                        }
                      },
                      onSubmitted: (_) => _lookupPhone(),
                      decoration: InputDecoration(
                        labelText: 'Phone (optional)',
                        hintText: 'Lookup existing lead',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        suffixIcon: _linkedLeadId != null
                            ? const Icon(Icons.link_rounded, color: AppColors.success, size: 20)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _lookingUp ? null : _lookupPhone,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: _lookingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    ),
                  ),
                ],
              ),
              if (_linkedLeadName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Linked to lead: $_linkedLeadName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _linkedLeadId = null;
                          _linkedLeadName = null;
                        }),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any call notes...',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Icon(
                      Icons.notes_outlined,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Audio source card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audio File',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sourceTab(
                    AudioSource.local,
                    Icons.folder_rounded,
                    'Local Recording',
                  ),
                  const SizedBox(width: 10),
                  _sourceTab(
                    AudioSource.device,
                    Icons.phone_android_rounded,
                    'Device File',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_audioSource == AudioSource.local) ...[
                if (_localRecordings.isEmpty)
                  _emptyRecordingsPlaceholder()
                else
                  _localRecordingPicker(),
              ],
              if (_audioSource == AudioSource.device) _deviceFilePicker(),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Status message
        if (_statusMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _isError
                  ? AppColors.error.withValues(alpha: 0.08)
                  : AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isError
                    ? AppColors.error.withValues(alpha: 0.2)
                    : AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: _isError ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isError ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Upload button
        FilledButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.cloud_upload_rounded, size: 20),
          label: Text(
            _uploading ? 'Uploading...' : 'Submit for Approval',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '1 credit will be deducted upon admin approval',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sourceTab(AudioSource source, IconData icon, String label) {
    final active = _audioSource == source;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _audioSource = source;
          if (source == AudioSource.local)
            _selectedDeviceFile = null;
          else
            _selectedLocalRecording = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primary : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyRecordingsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mic_off_rounded,
            size: 32,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'No local recordings found',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Record calls using the Recorder tab',
            style: TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await _loadLocalRecordings();
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _localRecordingPicker() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedLocalRecording?.path,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Select Recording',
            prefixIcon: Icon(
              Icons.audio_file_rounded,
              color: AppColors.primary.withOpacity(0.6),
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.textHint,
              ),
              onPressed: () async {
                await _loadLocalRecordings();
                setState(() {});
              },
            ),
          ),
          items: _localRecordings.map((file) {
            return DropdownMenuItem<String>(
              value: file.path,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getFileName(file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _getFileInfo(file),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) => _localRecordings
              .map(
                (file) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getFileName(file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedLocalRecording = _localRecordings.firstWhere(
                  (f) => f.path == val,
                );
                _statusMessage = null;
              });
            }
          },
        ),
        if (_selectedLocalRecording != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.audio_file_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(_selectedLocalRecording!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _getFileInfo(_selectedLocalRecording!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedLocalRecording = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _deviceFilePicker() {
    return GestureDetector(
      onTap: (_uploading || _isLoadingMediaStore) ? null : _showAudioFilePicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 110,
        decoration: BoxDecoration(
          color: _selectedDeviceFile != null
              ? AppColors.primarySurface
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedDeviceFile != null
                ? AppColors.primary.withOpacity(0.4)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: _isLoadingMediaStore
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading audio files...',
                    style:
                        TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              )
            : _selectedDeviceFile != null
            ? Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.audio_file_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDeviceFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(_selectedDeviceFile!.size),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDeviceFile = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 32,
                    color: AppColors.textHint.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to browse audio file',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'MP3, WAV, M4A, AAC (max 100MB)',
                    style: TextStyle(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}
