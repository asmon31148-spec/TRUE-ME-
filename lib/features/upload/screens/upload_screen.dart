import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../services/audio_processor.dart';
import '../services/pdf_processor.dart';
import '../services/url_processor.dart';
import '../services/youtube_processor.dart';

class UploadScreen extends StatefulWidget {
  final String? targetNotebookId;

  const UploadScreen({super.key, this.targetNotebookId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';

  final TextEditingController _urlController = TextEditingController();
  AudioProcessor? _audioProcessor;
  OcrService? _ocrService;
  late final UrlProcessor _urlProcessor;
  late final YoutubeProcessor _youtubeProcessor;

  AudioProcessor get audioProcessor => _audioProcessor ??= AudioProcessor();
  OcrService get ocrService => _ocrService ??= OcrService();

  bool _isRecordingAudio = false;

  @override
  void initState() {
    super.initState();
    _urlProcessor = UrlProcessor();
    _youtubeProcessor = YoutubeProcessor();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _audioProcessor?.dispose();
    _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _saveMaterialAndNotify({
    required String title,
    required String subject,
    required String content,
    required String fileName,
  }) async {
    final nbId = widget.targetNotebookId ?? 'nb_${DateTime.now().millisecondsSinceEpoch}';

    // If target notebook exists, add fileRef to it
    final existing = OfflineCacheService.getCachedNotebook(nbId);
    if (existing != null) {
      final fileRefs = List<String>.from(existing['fileRefs'] ?? const []);
      if (!fileRefs.contains(fileName)) fileRefs.add(fileName);
      existing['fileRefs'] = fileRefs;
      existing['lastModified'] = DateTime.now().toIso8601String();
      await OfflineCacheService.cacheNotebook(nbId, existing);
    } else {
      // Create new notebook
      final newNb = {
        'id': nbId,
        'userId': 'local_user',
        'title': title,
        'subject': subject,
        'colorValue': 0xFF06B6D4,
        'tags': ['Imported Notes', subject],
        'fileRefs': [fileName],
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      };
      await OfflineCacheService.cacheNotebook(nbId, newNb);
    }

    // Save note text in notesBox
    final noteId = 'note_${DateTime.now().millisecondsSinceEpoch}';
    await OfflineCacheService.cacheNote(noteId, {
      'id': noteId,
      'notebookId': nbId,
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      _showSuccessDialog(
        'Material Ingested & Saved',
        'Saved to "$title" (${content.length} characters indexed).',
        notebookId: nbId,
      );
    }
  }

  Future<void> _pickAndProcessPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Extracting PDF text & indexing into smart notebook...';
      });

      try {
        final file = File(result.files.single.path!);
        final text = await PdfProcessor.extractText(file);
        final fileName = result.files.single.name;
        final docTitle = fileName.replaceAll('.pdf', '');

        await _saveMaterialAndNotify(
          title: docTitle,
          subject: 'Study Notes',
          content: text,
          fileName: fileName,
        );
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickAndProcessImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Running on-device OCR on notes...';
      });

      try {
        final text = await ocrService.recognizeTextFromImage(File(picked.path));
        final fileName = 'Photo_Notes_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await _saveMaterialAndNotify(
          title: 'OCR Whiteboard Notes',
          subject: 'Handwritten Notes',
          content: text,
          fileName: fileName,
        );
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(String title, String body, {String? notebookId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            child: const Text('Back to Library', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/library');
            },
          ),
          if (notebookId != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Open Notebook', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/notebook/$notebookId');
              },
            ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Import Study Material',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card if Processing
            if (_isProcessing) ...[
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                surfaceColor: AppColors.primary.withOpacity(0.2),
                child: Row(
                  children: [
                    const CircularProgressIndicator(color: AppColors.accentCyan),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(_statusMessage, style: AppTypography.bodySmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text('Choose Source', style: AppTypography.headlineMedium),
            const SizedBox(height: 14),

            // Ingestion Options
            _buildSourceCard(
              icon: Icons.picture_as_pdf,
              color: AppColors.error,
              title: 'Upload PDF Document',
              subtitle: 'Extracts text, formulas & creates pgvector chunks',
              onTap: _pickAndProcessPdf,
            ),
            const SizedBox(height: 12),

            _buildSourceCard(
              icon: Icons.document_scanner,
              color: AppColors.accent,
              title: 'Camera / Photo OCR',
              subtitle: 'On-device recognition for handwritten notes & whiteboards',
              onTap: _pickAndProcessImage,
            ),
            const SizedBox(height: 12),

            _buildSourceCard(
              icon: _isRecordingAudio ? Icons.stop_circle : Icons.mic,
              color: _isRecordingAudio ? AppColors.warning : AppColors.secondary,
              title: _isRecordingAudio ? 'Stop Recording' : 'Record Lecture Audio',
              subtitle: 'Transcribed by Groq Whisper Large v3 into structured notes',
              onTap: () async {
                try {
                  if (!_isRecordingAudio) {
                    await audioProcessor.startRecording();
                    setState(() => _isRecordingAudio = true);
                  } else {
                    setState(() {
                      _isProcessing = true;
                      _statusMessage = 'Transcribing audio with Groq Whisper...';
                    });
                    final text = await audioProcessor.stopAndTranscribe();
                    setState(() {
                      _isRecordingAudio = false;
                      _isProcessing = false;
                    });
                    final fileName = 'Audio_Lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
                    await _saveMaterialAndNotify(
                      title: 'Audio Lecture Notes',
                      subject: 'Recorded Lecture',
                      content: text,
                      fileName: fileName,
                    );
                  }
                } catch (e) {
                  setState(() {
                    _isRecordingAudio = false;
                    _isProcessing = false;
                  });
                  _showError(e.toString());
                }
              },
            ),
            const SizedBox(height: 28),

            // Web & YouTube Import
            const Text('Import from Link', style: AppTypography.headlineMedium),
            const SizedBox(height: 12),

            GlassCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste Web URL or YouTube Link...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                      prefixIcon: const Icon(Icons.link, color: AppColors.accentCyan),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassButton(
                    isPrimary: true,
                    width: double.infinity,
                    child: const Text('Fetch & Summarize'),
                    onPressed: () async {
                      final url = _urlController.text.trim();
                      if (url.isEmpty) return;

                      setState(() {
                        _isProcessing = true;
                        _statusMessage = 'Fetching and summarizing content...';
                      });

                      try {
                        if (url.contains('youtube.com') || url.contains('youtu.be')) {
                          final summary = await _youtubeProcessor.summarizeVideoNotes(videoUrl: url);
                          await _saveMaterialAndNotify(
                            title: 'YouTube Lecture Summary',
                            subject: 'Video Study Notes',
                            content: summary,
                            fileName: 'YouTube_${DateTime.now().millisecondsSinceEpoch}',
                          );
                        } else {
                          final res = await _urlProcessor.fetchAndSummarize(url);
                          final summary = res['summary'] ?? '';
                          final title = res['title'] ?? 'Web Article Summary';
                          await _saveMaterialAndNotify(
                            title: title,
                            subject: 'Web Research',
                            content: summary,
                            fileName: 'Web_${DateTime.now().millisecondsSinceEpoch}',
                          );
                        }
                      } catch (e) {
                        _showError(e.toString());
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
        ],
      ),
    );
  }
}
