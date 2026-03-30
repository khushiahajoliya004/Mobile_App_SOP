import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _salesStages = [];
  String? _selectedCategoryId;
  String? _selectedSalesStageId;
  String? _loadError;

  // Audio source selection
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
    setState(() { _loadingData = true; _loadError = null; });
    try {
      _user = await _auth.getUser();
      debugPrint('[Upload] User loaded: ${_user?.id}, companyId: ${_user?.companyId}');

      // Load categories
      try {
        final catResponse = await _api.getCategories();
        debugPrint('[Upload] Categories raw response: ${catResponse.data}');
        final catData = catResponse.data;
        List rawCats;
        if (catData is List) {
          rawCats = catData;
        } else if (catData is Map) {
          rawCats = catData['data'] ?? [];
        } else {
          rawCats = [];
        }
        _categories = rawCats.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        debugPrint('[Upload] Parsed ${_categories.length} categories');
      } catch (e) {
        debugPrint('[Upload] Categories error: $e');
      }

      // Load sales stages
      try {
        final stageResponse = await _api.getSalesStages();
        debugPrint('[Upload] Sales stages raw response: ${stageResponse.data}');
        final stageData = stageResponse.data;
        List rawStages;
        if (stageData is List) {
          rawStages = stageData;
        } else if (stageData is Map) {
          rawStages = stageData['data'] ?? [];
        } else {
          rawStages = [];
        }
        _salesStages = rawStages.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        debugPrint('[Upload] Parsed ${_salesStages.length} sales stages');
      } catch (e) {
        debugPrint('[Upload] Sales stages error: $e');
      }

      // Load local recordings
      await _loadLocalRecordings();

      if (_categories.isEmpty && _salesStages.isEmpty) {
        _loadError = 'No categories or sales stages found. Please check your permissions or add data from the admin panel.';
      } else if (_categories.isEmpty) {
        _loadError = 'No categories found. Please add categories from the admin panel.';
      } else if (_salesStages.isEmpty) {
        _loadError = 'No sales stages found. Please add sales stages from the admin panel.';
      }
    } catch (e) {
      debugPrint('[Upload] General load error: $e');
      _loadError = 'Failed to load form data. Please check your connection and try again.';
    }
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _loadLocalRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.m4a') || f.path.endsWith('.wav') || f.path.endsWith('.mp3') || f.path.endsWith('.aac'))
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      _localRecordings = files;
      debugPrint('[Upload] Found ${_localRecordings.length} local recordings');
    } catch (e) {
      debugPrint('[Upload] Local recordings error: $e');
      _localRecordings = [];
    }
  }

  String _getFileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _getFileInfo(File file) {
    final stat = file.statSync();
    final sizeKb = (stat.size / 1024).toStringAsFixed(1);
    final date = stat.modified;
    return '$sizeKb KB  •  ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDeviceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'wma'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _selectedDeviceFile = result.files.first; _statusMessage = null; });
    }
  }

  // Get the audio file path for upload based on selected source
  String? get _audioFilePath {
    if (_audioSource == AudioSource.local) {
      return _selectedLocalRecording?.path;
    } else {
      return _selectedDeviceFile?.path;
    }
  }

  String? get _audioFileName {
    if (_audioSource == AudioSource.local && _selectedLocalRecording != null) {
      return _getFileName(_selectedLocalRecording!);
    } else if (_audioSource == AudioSource.device && _selectedDeviceFile != null) {
      return _selectedDeviceFile!.name;
    }
    return null;
  }

  Future<void> _upload() async {
    if (_customerNameController.text.trim().isEmpty) {
      setState(() { _statusMessage = 'Customer name is required'; _isError = true; });
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() { _statusMessage = 'Please select a category'; _isError = true; });
      return;
    }
    if (_selectedSalesStageId == null) {
      setState(() { _statusMessage = 'Please select a sales stage'; _isError = true; });
      return;
    }

    setState(() { _uploading = true; _statusMessage = null; });

    try {
      await _api.createCall(
        customerName: _customerNameController.text.trim(),
        companyId: _user?.companyId ?? '',
        categoryId: _selectedCategoryId!,
        salesStageId: _selectedSalesStageId!,
        userId: _user?.id ?? '',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        audioFilePath: _audioFilePath,
        audioFileName: _audioFileName,
      );
      setState(() {
        _statusMessage = 'Call created successfully. 1 credit deducted.';
        _isError = false;
        _selectedDeviceFile = null;
        _selectedLocalRecording = null;
        _customerNameController.clear();
        _notesController.clear();
        _selectedCategoryId = null;
        _selectedSalesStageId = null;
      });
    } catch (e) {
      setState(() { _statusMessage = 'Upload failed. Check credits or try again.'; _isError = true; });
    } finally {
      setState(() => _uploading = false);
    }
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
    }

    if (_loadError != null && _categories.isEmpty && _salesStages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.error.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              Text(_loadError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Text('New Call Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)),
              ],
            ),
          ),

          // Warning if partial data loaded
          if (_loadError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.orange, fontSize: 13))),
                InkWell(onTap: _loadData, child: const Icon(Icons.refresh_rounded, color: Colors.orange, size: 20)),
              ]),
            ),
          ],

          // Form fields card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _customerNameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary.withOpacity(0.6)),
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary.withOpacity(0.6)),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem<String>(
                    value: cat['id'], child: Text(cat['name'] ?? ''),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _selectedSalesStageId,
                  decoration: InputDecoration(
                    labelText: 'Sales Stage *',
                    prefixIcon: Icon(Icons.trending_up_outlined, color: AppColors.primary.withOpacity(0.6)),
                  ),
                  items: _salesStages.map((s) => DropdownMenuItem<String>(
                    value: s['id'], child: Text(s['name'] ?? ''),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedSalesStageId = val),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_outlined, color: AppColors.primary.withOpacity(0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Audio source selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audio Source (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _audioSource = AudioSource.local;
                          _selectedDeviceFile = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _audioSource == AudioSource.local ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _audioSource == AudioSource.local ? AppColors.primary : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_rounded, size: 20,
                                  color: _audioSource == AudioSource.local ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text('Local Recording',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: _audioSource == AudioSource.local ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _audioSource = AudioSource.device;
                          _selectedLocalRecording = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _audioSource == AudioSource.device ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _audioSource == AudioSource.device ? AppColors.primary : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android_rounded, size: 20,
                                  color: _audioSource == AudioSource.device ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text('Device File',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: _audioSource == AudioSource.device ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // LOCAL RECORDING: dropdown of saved recordings
                if (_audioSource == AudioSource.local) ...[
                  if (_localRecordings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.mic_off_rounded, size: 32, color: AppColors.textHint.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          const Text('No local recordings found',
                              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                          const SizedBox(height: 4),
                          const Text('Record calls using the Call Recorder tab',
                              style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                          const SizedBox(height: 12),
                          InkWell(
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
                                  Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text('Refresh', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedLocalRecording?.path,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Recording',
                            prefixIcon: Icon(Icons.audio_file_rounded, color: AppColors.primary.withOpacity(0.6)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textHint),
                              onPressed: () async {
                                await _loadLocalRecordings();
                                setState(() {});
                              },
                            ),
                          ),
                          items: _localRecordings.map((file) {
                            final name = _getFileName(file);
                            final info = _getFileInfo(file);
                            return DropdownMenuItem<String>(
                              value: file.path,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text(info, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedLocalRecording = _localRecordings.firstWhere((f) => f.path == val);
                                _statusMessage = null;
                              });
                            }
                          },
                          selectedItemBuilder: (context) {
                            return _localRecordings.map((file) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(_getFileName(file), maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              );
                            }).toList();
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
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.audio_file_rounded, size: 20, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_getFileName(_selectedLocalRecording!), maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                      Text(_getFileInfo(_selectedLocalRecording!),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _selectedLocalRecording = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],

                // DEVICE FILE: file picker
                if (_audioSource == AudioSource.device) ...[
                  GestureDetector(
                    onTap: _uploading ? null : _pickDeviceFile,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 110,
                      decoration: BoxDecoration(
                        color: _selectedDeviceFile != null ? AppColors.primarySurface : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedDeviceFile != null ? AppColors.primary.withOpacity(0.4) : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: _selectedDeviceFile != null
                          ? Row(
                              children: [
                                const SizedBox(width: 16),
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.audio_file_rounded, size: 22, color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_selectedDeviceFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(_formatFileSize(_selectedDeviceFile!.size),
                                          style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _selectedDeviceFile = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.cloud_upload_outlined, size: 22, color: AppColors.primary),
                                ),
                                const SizedBox(height: 8),
                                const Text('Tap to select audio file',
                                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
                                const Text('MP3, WAV, M4A, AAC, OGG, WMA',
                                    style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status message
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isError ? AppColors.error.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _isError ? AppColors.error.withOpacity(0.2) : AppColors.success.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(_isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: _isError ? AppColors.error : AppColors.success, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusMessage!,
                    style: TextStyle(color: _isError ? AppColors.error : AppColors.success, fontWeight: FontWeight.w500))),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Submit button
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.upload_rounded),
              label: Text(_uploading ? 'Creating...' : 'Create Call'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
