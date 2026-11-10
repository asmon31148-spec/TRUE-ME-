import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../services/audio_processor.dart';
import '../services/pdf_processor.dart';
import '../services/url_processor.dart';
import '../services/youtube_processor.dart';

class AddFilesSheet extends StatefulWidget {
  final String notebookId;
  final String subjectName;
  final VoidCallback? onFileAdded;

  const AddFilesSheet({
    super.key,
    required this.notebookId,
    required this.subjectName,
    this.onFileAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String notebookId,
    required String subjectName,
    VoidCallback? onFileAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AddFilesSheet(
        notebookId: notebookId,
        subjectName: subjectName,
        onFileAdded: onFileAdded,
      ),
    );
  }

  @override
  State<AddFilesSheet> createState() => _AddFilesSheetState();
}

class _AddFilesSheetState extends State<AddFilesSheet> {
  String _targetSection = 'Notes';
  String _mode = 'menu'; // 'menu', 'link', 'text', 'audio', 'drive'
  bool _isBusy = false;
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
        setState(() => _statusText = 'Syncing to Google Drive...');
        uploadedDriveId = await DriveService.instance.uploadFile(originalFile, customName: fileName);
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
        setState(() {
          _isRecording = true;
          _errorText = null;
        });
      } catch (e) {
        setState(() => _errorText = 'Microphone access denied or unavailable: $e');
      }
    }
  }

  Future<void> _loadDriveFiles() async {
    setState(() {
      _mode = 'drive';
      _isBusy = true;
      _errorText = null;
      _statusText = 'Connecting to Google Drive...';
    });

    final files = await DriveService.instance.listFiles();
    if (!mounted) return;

    setState(() {
      _driveFiles = files;
      _isBusy = false;
      if (!DriveService.instance.isSignedIn) {
        _errorText = 'Google Drive sign-in was cancelled or failed.';
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
      final bytes = await DriveService.instance.downloadFile(dFile.id!);
      final tmpDir = await getTemporaryDirectory();
      final fName = dFile.name ?? 'drive_file.pdf';
      final tmpFile = File('${tmpDir.path}/$fName');
      await tmpFile.writeAsBytes(bytes);

      String extracted = '';
      if (fName.toLowerCase().endsWith('.pdf')) {
        extracted = await PdfProcessor.extractText(tmpFile);
      } else {
        extracted = await tmpFile.readAsString();
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _mode == 'menu' ? 'Add files to ${widget.subjectName}' : 'Add to $_targetSection',
                    style: AppTypography.sectionHeading,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Section target selector always visible
              const Text('Save under section:', style: AppTypography.smallLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sections.map((sec) {
                  return AppChip(
                    label: sec,
                    isSelected: _targetSection == sec,
                    onTap: _isBusy ? null : () => setState(() => _targetSection = sec),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (_errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_isBusy) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      const SizedBox(height: 16),
                      Text(_statusText, style: AppTypography.secondary, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ] else if (_mode == 'menu') ...[
                _buildSourceRow(
                  icon: Icons.upload_file_outlined,
                  label: 'Upload PDF or text file',
                  subtitle: 'Extracts full text for Sage chat & quizzes',
                  onTap: _pickFromPhone,
                ),
                _buildSourceRow(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a photo (Camera)',
                  subtitle: 'Reads printed or whiteboard notes via OCR',
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
                _buildSourceRow(
                  icon: Icons.photo_library_outlined,
                  label: 'Pick photo from gallery',
                  subtitle: 'Extracts text from saved screenshots or photos',
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
                _buildSourceRow(
                  icon: Icons.link_outlined,
                  label: 'Paste a website or YouTube link',
                  subtitle: 'Fetches article text or lecture notes',
                  onTap: () => setState(() => _mode = 'link'),
                ),
                _buildSourceRow(
                  icon: Icons.notes_outlined,
                  label: 'Write or paste text directly',
                  subtitle: 'Paste syllabus points or lecture notes',
                  onTap: () => setState(() => _mode = 'text'),
                ),
                _buildSourceRow(
                  icon: Icons.mic_none_outlined,
                  label: 'Record lecture audio',
                  subtitle: 'Records and transcribes voice notes',
                  onTap: () => setState(() => _mode = 'audio'),
                ),
                _buildSourceRow(
                  icon: Icons.add_to_drive_outlined,
                  label: 'Import from Google Drive',
                  subtitle: DriveService.instance.isSignedIn
                      ? 'Connected (${DriveService.instance.userEmail ?? 'Drive'})'
                      : 'Connect your Google Drive',
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
                AppPrimaryButton(
                  label: 'Fetch & Add to $_targetSection',
                  onPressed: _processLink,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _mode = 'menu'),
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
                AppPrimaryButton(
                  label: 'Save to $_targetSection',
                  onPressed: _savePastedText,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _mode = 'menu'),
                    child: const Text('Back to options'),
                  ),
                ),
              ] else if (_mode == 'audio') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isRecording ? Icons.graphic_eq : Icons.mic_none,
                        size: 40,
                        color: _isRecording ? AppColors.error : AppColors.accent,
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
                  backgroundColor: _isRecording ? AppColors.error : AppColors.accent,
                  onPressed: _toggleAudioRecording,
                ),
                if (!_isRecording) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _mode = 'menu'),
                      child: const Text('Back to options'),
                    ),
                  ),
                ],
              ] else if (_mode == 'drive') ...[
                if (_driveFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No compatible PDF or text files found in your Drive.',
                      style: AppTypography.secondary,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _driveFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (ctx, i) {
                        final f = _driveFiles[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.accent),
                          title: Text(f.name ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Text('Import', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                          onTap: () => _importDriveFile(f),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _mode = 'menu'),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  Text(subtitle, style: AppTypography.smallLabel),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
