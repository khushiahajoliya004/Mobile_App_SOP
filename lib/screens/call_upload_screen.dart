import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AudioSource { local, device }

class CallUploadScreen extends StatefulWidget {
  const CallUploadScreen({super.key});

  @override
  State<CallUploadScreen> createState() => _CallUploadScreenState();
}

class _CallUploadScreenState extends State<CallUploadScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();

  UserModel? _user;
  bool _uploading = false;
  bool _loadingData = true;
  String? _statusMessage;
  bool _isError = false;

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
  PlatformFile? _selectedDeviceFile;

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickDeviceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'wma'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedDeviceFile = result.files.first;
        _statusMessage = null;
      });
    }
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
      await _api.createCall(
        customerName: _customerNameController.text.trim(),
        companyId: _user!.companyId!,
        userId: _user!.id,
        categoryId: _sopCategoryId,
        salesStageId: _sopSalesStageId,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        audioFilePath: _audioFilePath,
        audioFileName: _audioFileName,
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Call submitted for approval';
          _isError = false;
          _selectedDeviceFile = null;
          _selectedLocalRecording = null;
          _customerNameController.clear();
          _notesController.clear();
        });
        _showSnack('Call submitted for approval', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Upload failed. Check credits or try again.';
          _isError = true;
        });
        _showSnack('Upload failed. Try again.');
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

  @override
  void dispose() {
    _customerNameController.dispose();
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
              const SizedBox(height: 18),
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
      onTap: _uploading ? null : _pickDeviceFile,
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
        child: _selectedDeviceFile != null
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
