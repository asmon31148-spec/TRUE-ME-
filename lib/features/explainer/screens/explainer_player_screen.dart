import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../models/explainer_script_model.dart';
import '../services/explainer_generator.dart';

class ExplainerPlayerScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? topic;

  const ExplainerPlayerScreen({super.key, this.notebookId, this.topic});

  @override
  ConsumerState<ExplainerPlayerScreen> createState() => _ExplainerPlayerScreenState();
}

class _ExplainerPlayerScreenState extends ConsumerState<ExplainerPlayerScreen> {
  final TtsService _tts = TtsService();
  final TextEditingController _topicCtrl = TextEditingController();

  ExplainerScriptModel? _script;
  bool _isGenerating = false;
  bool _isPlaying = false;
  int _sceneIndex = 0;
  double _playbackSpeed = 1.0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final subs = OfflineCacheService.getUserSubjects();
    final initialTopic = widget.topic?.isNotEmpty == true
        ? widget.topic!
        : (subs.isNotEmpty ? subs.first : '');
    _topicCtrl.text = initialTopic;

    if (initialTopic.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateExplainer(initialTopic));
    }
  }

  @override
  void dispose() {
    _tts.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateExplainer(String topic) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) return;

    await _tts.stop();
    setState(() {
      _isGenerating = true;
      _isPlaying = false;
      _errorText = null;
      _sceneIndex = 0;
    });

    try {
      String notesContent = '';
      if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
        notesContent = OfflineCacheService.getNotebookCombinedText(widget.notebookId!, maxChars: 14000);
      }
      if (notesContent.isEmpty) {
        notesContent = 'Core concepts, intuition, formulas, and practical examples for $cleanTopic.';
      }

      final generator = ExplainerGenerator(aiRouter: ref.read(aiRouterProvider));
      final script = await generator.generateScript(
        topic: cleanTopic,
        notesContent: notesContent,
      );

      if (mounted) {
        setState(() {
          _script = script;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorText = 'Could not generate explainer: $e';
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_script == null || _script!.scenes.isEmpty) return;
    if (_isPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _playFromScene(_sceneIndex);
    }
  }

  Future<void> _playFromScene(int startIdx) async {
    if (_script == null) return;
    for (int i = startIdx; i < _script!.scenes.length; i++) {
      if (!mounted || !_isPlaying) break;
      setState(() => _sceneIndex = i);
      final scene = _script!.scenes[i];
      await _tts.setSpeechRate(_playbackSpeed);
      await _tts.speak('${scene.title}. ${scene.narrationText}');
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _saveScriptToNotes() async {
    if (_script == null) return;
    final buffer = StringBuffer();
    buffer.writeln('# ${_script!.title}\n');
    for (final s in _script!.scenes) {
      buffer.writeln('## Scene ${s.sceneNumber}: ${s.title}');
      buffer.writeln(s.narrationText);
      if (s.elements.isNotEmpty) {
        buffer.writeln('\nKey points: ${s.elements.join(', ')}\n');
      }
    }

    if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
      await OfflineCacheService.addDocumentToNotebook(widget.notebookId!, {
        'fileName': '${_script!.topic}_Explainer_Script.txt',
        'section': 'Notes',
        'content': buffer.toString(),
        'fileType': 'text',
      });
    } else {
      final noteId = 'note_${DateTime.now().millisecondsSinceEpoch}';
      await OfflineCacheService.cacheNote(noteId, {
        'id': noteId,
        'title': _script!.title,
        'content': buffer.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Explainer script saved to notes.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _script?.scenes ?? [];
    final currentScene = scenes.isNotEmpty ? scenes[_sceneIndex.clamp(0, scenes.length - 1)] : null;
    final progress = scenes.isNotEmpty ? (_sceneIndex + 1) / scenes.length : 0.0;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Audio Explainer', style: AppTypography.screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () {
            _tts.stop();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/practice');
            }
          },
        ),
        actions: [
          if (_script != null)
            IconButton(
              icon: const Icon(Icons.save_alt_outlined, size: 22),
              tooltip: 'Save script to notes',
              onPressed: _saveScriptToNotes,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic input bar
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: _topicCtrl,
                      hintText: 'Enter topic to explain...',
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isGenerating ? null : () => _generateExplainer(_topicCtrl.text),
                      child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stage
              Expanded(
                child: _isGenerating
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: context.accentColor),
                            const SizedBox(height: 16),
                            const Text('Creating structured walkthrough from your notes...', style: AppTypography.secondary),
                          ],
                        ),
                      )
                    : _errorText != null
                        ? Center(
                            child: Text(_errorText!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                          )
                        : currentScene == null
                            ? const Center(
                                child: Text(
                                  'Enter any topic above and tap Create to build a narrated walkthrough.',
                                  style: AppTypography.secondary,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.borderColor, width: 1),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SCENE ${_sceneIndex + 1} OF ${scenes.length}',
                                        style: AppTypography.smallLabel.copyWith(
                                          color: context.accentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(currentScene.title, style: AppTypography.sectionHeading),
                                      const SizedBox(height: 14),
                                      if (currentScene.elements.isNotEmpty) ...[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: currentScene.elements.map((el) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: context.bgColor,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: context.borderColor),
                                              ),
                                              child: Text(el, style: AppTypography.smallLabel),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      SelectableText(
                                        currentScene.narrationText,
                                        style: AppTypography.body.copyWith(height: 1.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
              ),
              const SizedBox(height: 16),

              if (scenes.isNotEmpty) ...[
                AppProgressBar(value: progress),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PopupMenuButton<double>(
                      onSelected: (v) async {
                        setState(() => _playbackSpeed = v);
                        await _tts.setSpeechRate(v);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Text('${_playbackSpeed}x', style: AppTypography.smallLabel),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0.75, child: Text('0.75x')),
                        PopupMenuItem(value: 1.0, child: Text('1.0x')),
                        PopupMenuItem(value: 1.25, child: Text('1.25x')),
                        PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_outlined, size: 28),
                          onPressed: _sceneIndex > 0
                              ? () async {
                                  await _tts.stop();
                                  setState(() {
                                    _sceneIndex--;
                                    _isPlaying = false;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                              elevation: 0,
                            ),
                            onPressed: _togglePlay,
                            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next_outlined, size: 28),
                          onPressed: _sceneIndex < scenes.length - 1
                              ? () async {
                                  await _tts.stop();
                                  setState(() {
                                    _sceneIndex++;
                                    _isPlaying = false;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
