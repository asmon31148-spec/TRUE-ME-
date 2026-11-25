import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../services/audio_processor.dart';
import '../services/pdf_processor.dart';
import '../services/url_processor.dart';
import '../services/youtube_processor.dart';

class AddFilesSheet extends StatefulWidget {
  final String notebookId;
  final String subjectName;
  final String initialSection;
  final VoidCallback? onFileAdded;

  const AddFilesSheet({
    super.key,
    required this.notebookId,
    required this.subjectName,
    this.initialSection = 'Notes',
    this.onFileAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String notebookId,
    required String subjectName,
    String initialSection = 'Notes',
    VoidCallback? onFileAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddFilesSheet(
        notebookId: notebookId,
        subjectName: subjectName,
        initialSection: initialSection,
        onFileAdded: onFileAdded,
      ),
    );
  }

  @override
  State<AddFilesSheet> createState() => _AddFilesSheetState();
}

class _AddFilesSheetState extends State<AddFilesSheet> {
  late String _targetSection;
  String _mode = 'menu'; // 'menu', 'link', 'text', 'audio', 'drive'
  bool _isBusy = false;
  bool _onlyTrueMeVault = false;
  String _statusText = '';
  String? _errorText;

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();

  AudioProcessor? _audioProcessor;
  OcrService? _ocrService;
  bool _isRecording = false;
  List<drive.File> _driveFiles = [];

  final List<String> _sections = const ['Syllabus', 'Notes', 'Books', 'Previous papers'];

  @override
  void initState() {
    super.initState();
    _targetSection = _sections.contains(widget.initialSection) ? widget.initialSection : 'Notes';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _audioProcessor?.dispose();
    _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _saveExtractedDocument({
    required String fileName,
    required String content,
    required String fileType,
    File? originalFile,
    String? driveFileId,
  }) async {
    String? uploadedDriveId = driveFileId;
    if (uploadedDriveId == null && originalFile != null && DriveService.instance.isSignedIn) {
      try {
        setState(() => _statusText = 'Syncing to True Me / ${widget.subjectName} / $_targetSection...');
        uploadedDriveId = await DriveService.instance.uploadFile(
          originalFile,
          customName: fileName,
          subject: widget.subjectName,
          section: _targetSection,
        );
      } catch (_) {}
    }

    await OfflineCacheService.addDocumentToNotebook(widget.notebookId, {
      'id': 'doc_${DateTime.now().millisecondsSinceEpoch}',
      'fileName': fileName,
      'section': _targetSection,
      'content': content,
      'fileType': fileType,
      'sizeBytes': content.length,
      'driveFileId': uploadedDriveId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (content.trim().length > 40) {
      unawaited(
        RagService()
            .ingestDocument(
              userId: OfflineCacheService.getUserId(),
              notebookId: widget.notebookId,
              fileName: fileName,
              fullText: content,
            )
            .catchError((_) => 0),
      );
    }

    widget.onFileAdded?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$fileName" (${content.length} chars) to $_targetSection'),
        ),
      );
    }
  }

  Future<void> _pickFromPhone() async {
    setState(() => _errorText = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    setState(() {
      _isBusy = true;
      _statusText = 'Reading & extracting file content...';
    });

    try {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final ext = fileName.split('.').last.toLowerCase();

      String extracted = '';
      if (ext == 'pdf') {
        extracted = await PdfProcessor.extractText(file);
      } else {
        extracted = await file.readAsString();
      }

      if (extracted.trim().isEmpty) {
        extracted = 'Uploaded file: $fileName (No selectable text found; consider using Photo OCR if scanned).';
      }

      await _saveExtractedDocument(
        fileName: fileName,
        content: extracted,
        fileType: ext,
        originalFile: file,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _errorText = 'Could not read file: $e';
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _errorText = null);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _isBusy = true;
      _statusText = 'Extracting text with on-device OCR...';
    });

    try {
      final file = File(picked.path);
      _ocrService ??= OcrService();
      final text = await _ocrService!.recognizeTextFromImage(file);
      final fileName = 'Photo_${DateTime.now().month}_${DateTime.now().day}_${DateTime.now().millisecond}.jpg';

      await _saveExtractedDocument(
        fileName: fileName,
        content: text.trim().isNotEmpty ? text.trim() : 'Image note captured ($fileName).',
        fileType: 'image',
        originalFile: file,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _errorText = 'OCR failed: $e';
        });
      }
    }
  }

  Future<void> _processLink() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      setState(() => _errorText = 'Enter a valid URL starting with http:// or https://');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
      _statusText = 'Fetching & reading link content...';
    });

    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final meta = await YoutubeProcessor.fetchVideoMetadata(url);
        final title = meta['title'] ?? 'YouTube Lecture';
        final notes = await YoutubeProcessor().summarizeVideoNotes(videoUrl: url);
        await _saveExtractedDocument(
          fileName: '$title.txt',
          content: 'Source URL: $url\n\n$notes',
          fileType: 'youtube',
        );
      } else {
        final res = await UrlProcessor().fetchAndSummarize(url);
        final rawText = res['rawText'] ?? '';
        final summary = res['summary'] ?? '';
        final content = summary.isNotEmpty ? '$summary\n\nFull Extract:\n$rawText' : rawText;
        final host = Uri.tryParse(url)?.host ?? 'article';
        await _saveExtractedDocument(
          fileName: '$host.txt',
          content: content.isNotEmpty ? content : 'Saved link: $url',
          fileType: 'url',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _errorText = 'Failed to fetch link: $e';
        });
      }
    }
  }

  Future<void> _savePastedText() async {
    final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Text Note';
    final body = _textCtrl.text.trim();
    if (body.isEmpty) {
      setState(() => _errorText = 'Enter or paste your notes text.');
      return;
    }

    setState(() {
      _isBusy = true;
      _statusText = 'Saving note...';
    });

    await _saveExtractedDocument(
      fileName: title.endsWith('.txt') ? title : '$title.txt',
      content: body,
      fileType: 'text',
    );
  }

  Future<void> _toggleAudioRecording() async {
    _audioProcessor ??= AudioProcessor();
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isBusy = true;
        _statusText = 'Transcribing lecture audio...';
      });
      try {
        final transcript = await _audioProcessor!.stopAndTranscribe();
        final fileName = 'Recording_${DateTime.now().hour}_${DateTime.now().minute}.txt';
        await _saveExtractedDocument(
          fileName: fileName,
          content: transcript.trim().isNotEmpty ? transcript.trim() : 'Voice recording ($fileName)',
          fileType: 'audio',
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _errorText = 'Audio transcription failed: $e';
          });
        }
      }
    } else {
      try {
        await _audioProcessor!.startRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
            _errorText = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _errorText = 'Microphone access denied or unavailable: $e');
        }
      }
    }
  }

  Future<void> _loadDriveFiles({bool? onlyVault}) async {
    final vaultFilter = onlyVault ?? _onlyTrueMeVault;
    setState(() {
      _mode = 'drive';
      _onlyTrueMeVault = vaultFilter;
      _isBusy = true;
      _errorText = null;
      _statusText = 'Connecting to Google Drive...';
    });

    final files = await DriveService.instance.listFiles(onlyTrueMeVault: vaultFilter);
    if (!mounted) return;

    setState(() {
      _driveFiles = files;
      _isBusy = false;
      if (!DriveService.instance.isSignedIn) {
        _errorText = DriveService.instance.lastError ?? 'Google Drive sign-in was cancelled or failed.';
      }
    });
  }

  Future<void> _importDriveFile(drive.File dFile) async {
    if (dFile.id == null) return;
    setState(() {
      _isBusy = true;
      _statusText = 'Downloading "${dFile.name}" from Drive...';
    });

    try {
      final mime = dFile.mimeType ?? '';
      final bytes = await DriveService.instance.downloadFile(dFile.id!, mimeType: mime);
      final tmpDir = await getTemporaryDirectory();
      String fName = dFile.name ?? 'drive_file.pdf';
      if (mime == 'application/vnd.google-apps.document' && !fName.toLowerCase().endsWith('.txt')) {
        fName = '$fName.txt';
      } else if ((mime == 'application/vnd.google-apps.presentation' ||
              mime == 'application/vnd.google-apps.spreadsheet') &&
          !fName.toLowerCase().endsWith('.pdf')) {
        fName = '$fName.pdf';
      }
      final tmpFile = File('${tmpDir.path}/$fName');
      await tmpFile.writeAsBytes(bytes);

      String extracted = '';
      final lower = fName.toLowerCase();
      if (lower.endsWith('.pdf')) {
        extracted = await PdfProcessor.extractText(tmpFile);
      } else if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp')) {
        _ocrService ??= OcrService();
        extracted = await _ocrService!.recognizeTextFromImage(tmpFile);
      } else if (lower.endsWith('.txt') ||
          lower.endsWith('.md') ||
          lower.endsWith('.csv') ||
          lower.endsWith('.json') ||
          mime == 'application/vnd.google-apps.document') {
        extracted = await tmpFile.readAsString();
      } else {
        throw StateError('Unsupported Drive file format "$fName". Import PDF, Google Docs, TXT, MD, or Image files.');
      }

      await _saveExtractedDocument(
        fileName: fName,
        content: extracted.trim().isNotEmpty ? extracted : 'Imported from Google Drive: $fName',
        fileType: fName.split('.').last.toLowerCase(),
        driveFileId: dFile.id,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _errorText = 'Import error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _mode == 'menu' ? 'Add Files to ${widget.subjectName}' : 'Add to $_targetSection',
                      style: AppTypography.sectionHeading,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const Text('Save under section:', style: AppTypography.smallLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sections.map((sec) {
                  return AppChip(
                    label: sec,
                    isSelected: _targetSection == sec,
                    onTap: () {
                      if (!_isBusy) setState(() => _targetSection = sec);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (_errorText != null) ...[
                TrueMeCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.error,
                  child: Text(_errorText!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                ),
                const SizedBox(height: 12),
              ],

              if (_isBusy) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Center(child: CircularProgressIndicator(color: context.accentColor)),
                      const SizedBox(height: 16),
                      Text(_statusText, style: AppTypography.secondary, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ] else if (_mode == 'menu') ...[
                _buildSourceRow(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload PDF or Text File',
                  subtitle: 'Pick from Phone storage or Google Drive menu (no OAuth needed)',
                  bgColor: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                  accentColor: context.accentColor,
                  onTap: _pickFromPhone,
                ),
                _buildSourceRow(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take a Photo (Camera)',
                  subtitle: 'Reads printed or whiteboard notes via OCR',
                  bgColor: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                  accentColor: isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk,
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
                _buildSourceRow(
                  icon: Icons.photo_library_rounded,
                  label: 'Pick Photo from Gallery',
                  subtitle: 'Extracts text from saved screenshots or photos',
                  bgColor: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                  accentColor: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
                _buildSourceRow(
                  icon: Icons.link_rounded,
                  label: 'Paste Website or YouTube Link',
                  subtitle: 'Fetches article text or lecture notes',
                  bgColor: isDark ? const Color(0xFF241938) : AppColors.pastelLavender,
                  accentColor: isDark ? const Color(0xFFC4B5FD) : AppColors.pastelLavenderInk,
                  onTap: () => setState(() => _mode = 'link'),
                ),
                _buildSourceRow(
                  icon: Icons.notes_rounded,
                  label: 'Write or Paste Text Directly',
                  subtitle: 'Paste syllabus points or lecture notes',
                  bgColor: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                  accentColor: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                  onTap: () => setState(() => _mode = 'text'),
                ),
                _buildSourceRow(
                  icon: Icons.mic_rounded,
                  label: 'Record Lecture Audio',
                  subtitle: 'Records and transcribes voice notes',
                  bgColor: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                  accentColor: AppColors.error,
                  onTap: () => setState(() => _mode = 'audio'),
                ),
                _buildSourceRow(
                  icon: Icons.add_to_drive_rounded,
                  label: 'Import from Google Drive',
                  subtitle: DriveService.instance.isSignedIn
                      ? 'Connected (${DriveService.instance.userEmail ?? 'Drive'})'
                      : 'Connect your Google Drive',
                  bgColor: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                  accentColor: AppColors.success,
                  onTap: _loadDriveFiles,
                ),
              ] else if (_mode == 'link') ...[
                AppInput(
                  label: 'Website or YouTube URL',
                  hintText: 'https://...',
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TrueMePrimaryButton(
                  label: 'Fetch & Add to $_targetSection',
                  onPressed: _processLink,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _mode = 'menu';
                      _errorText = null;
                    }),
                    child: const Text('Back to options'),
                  ),
                ),
              ] else if (_mode == 'text') ...[
                AppInput(
                  label: 'Title',
                  hintText: 'e.g. Chapter 1 Syllabus',
                  controller: _titleCtrl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    hintText: 'Paste your syllabus topics or notes here...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                TrueMePrimaryButton(
                  label: 'Save to $_targetSection',
                  onPressed: _savePastedText,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _mode = 'menu';
                      _errorText = null;
                    }),
                    child: const Text('Back to options'),
                  ),
                ),
              ] else if (_mode == 'audio') ...[
                TrueMeCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        _isRecording ? Icons.graphic_eq : Icons.mic_none_rounded,
                        size: 42,
                        color: _isRecording ? AppColors.error : context.accentColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isRecording ? 'Recording audio...' : 'Ready to record',
                        style: AppTypography.sectionHeading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: _isRecording ? 'Stop & Transcribe' : 'Start Recording',
                  backgroundColor: _isRecording ? AppColors.error : context.accentColor,
                  onPressed: _toggleAudioRecording,
                ),
                if (!_isRecording) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _mode = 'menu';
                        _errorText = null;
                      }),
                      child: const Text('Back to options'),
                    ),
                  ),
                ],
              ] else if (_mode == 'drive') ...[
                Row(
                  children: [
                    AppChip(
                      label: 'All Drive',
                      isSelected: !_onlyTrueMeVault,
                      onTap: () => _loadDriveFiles(onlyVault: false),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'True Me Vault',
                      isSelected: _onlyTrueMeVault,
                      onTap: () => _loadDriveFiles(onlyVault: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_driveFiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      _onlyTrueMeVault
                          ? 'No files inside your Google Drive "True Me" folder yet.'
                          : 'No compatible PDF or text files found in your Drive.',
                      style: AppTypography.secondary,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _driveFiles.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: context.borderColor),
                      itemBuilder: (ctx, i) {
                        final f = _driveFiles[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.insert_drive_file_outlined, color: context.accentColor),
                          title: Text(f.name ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            'Import',
                            style: TextStyle(color: context.accentColor, fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _importDriveFile(f),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _mode = 'menu';
                      _errorText = null;
                    }),
                    child: const Text('Back to options'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color bgColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppListRow(
        leading: AppIconBadge(icon: icon, color: accentColor, backgroundColor: bgColor),
        title: label,
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }
}
