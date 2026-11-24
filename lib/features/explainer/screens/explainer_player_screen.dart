import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/liquid_glass_theme.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/explainer_script_model.dart';
import '../services/explainer_generator.dart';

/// In-App Animated Explainer Video Player Screen.
///
/// Features:
/// - Liquid Glass presentation canvas with specular highlights
/// - Timeline scrubber with segmented scene progress
/// - Synchronized narration with speed controls (0.5x, 1x, 1.5x, 2x)
/// - Rewind/forward 10s skip controls and flutter_animate scene transitions
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
    if (!mounted) return;
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
    HapticFeedback.mediumImpact();
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

  Future<void> _skipSeconds(int deltaSeconds) async {
    if (_script == null || _script!.scenes.isEmpty) return;
    HapticFeedback.lightImpact();
    await _tts.stop();
    if (!mounted) return;

    int nextIdx = _sceneIndex;
    if (deltaSeconds > 0) {
      nextIdx = (_sceneIndex + 1).clamp(0, _script!.scenes.length - 1);
    } else {
      nextIdx = (_sceneIndex - 1).clamp(0, _script!.scenes.length - 1);
    }

    setState(() {
      _sceneIndex = nextIdx;
      _isPlaying = false;
    });

    if (_isPlaying) {
      _playFromScene(nextIdx);
    }
  }

  Future<void> _saveScriptToNotes() async {
    if (_script == null) return;
    HapticFeedback.lightImpact();
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
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.liquidCanvas,
      appBar: GlassAppBar(
        title: 'Explainer Studio',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.liquidTextPrimary,
          onPressed: () {
            HapticFeedback.lightImpact();
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
              icon: const Icon(Icons.bookmark_add_outlined, size: 22),
              color: LiquidGlassTheme.electricIndigo,
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
              // Topic input bar in Liquid Glass styling
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.liquidGlassFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _topicCtrl,
                        style: TextStyle(color: context.liquidTextPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter topic to explain...',
                          hintStyle: TextStyle(color: context.liquidTextSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                        onSubmitted: (v) => _generateExplainer(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidGlassTheme.electricIndigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isGenerating ? null : () => _generateExplainer(_topicCtrl.text),
                      child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Presentation Stage
              Expanded(
                child: _isGenerating
                    ? const GenerationProgressView(
                        title: 'Synthesizing interactive explainer...',
                        stages: [
                          'Reading your syllabus and notes...',
                          'Decomposing into cognitive scenes...',
                          'Highlighting essential formulas & concepts...',
                          'Preparing voice narration timeline...',
                        ],
                      )
                    : _errorText != null
                        ? Center(
                            child: Text(
                              _errorText!,
                              style: const TextStyle(color: LiquidGlassTheme.roseAlert),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : currentScene == null
                            ? Center(
                                child: Text(
                                  'Enter any topic above and tap Generate to build a narrated walkthrough.',
                                  style: TextStyle(color: context.liquidTextSecondary, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : GlassCard(
                                key: ValueKey('scene_$_sceneIndex'),
                                borderRadius: 20,
                                padding: const EdgeInsets.all(22),
                                glowColor: LiquidGlassTheme.electricIndigo,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: LiquidGlassTheme.electricIndigo.withOpacity(isDark ? 0.22 : 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: LiquidGlassTheme.electricIndigo.withOpacity(0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              'SCENE ${_sceneIndex + 1} OF ${scenes.length}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                                color: LiquidGlassTheme.electricIndigo,
                                              ),
                                            ),
                                          ),
                                          if (_isPlaying)
                                            Row(
                                              children: [
                                                const Icon(Icons.graphic_eq_rounded, size: 16, color: LiquidGlassTheme.emeraldFocus),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Narrating',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: LiquidGlassTheme.emeraldFocus,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        currentScene.title,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: context.liquidTextPrimary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      if (currentScene.elements.isNotEmpty) ...[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: currentScene.elements.map((el) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEEF2FF),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: LiquidGlassTheme.electricIndigo.withOpacity(0.25),
                                                ),
                                              ),
                                              child: Text(
                                                el,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFFA5B4FC) : LiquidGlassTheme.electricIndigo,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 18),
                                      ],
                                      SelectableText(
                                        currentScene.narrationText,
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          height: 1.65,
                                          color: context.liquidTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
              ),
              const SizedBox(height: 16),

              // Presentation Scrubber & Controls
              if (scenes.isNotEmpty) ...[
                // Segmented Timeline Bar
                Row(
                  children: List.generate(scenes.length, (i) {
                    final isPassed = i <= _sceneIndex;
                    final isCurrent = i == _sceneIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _tts.stop();
                          setState(() {
                            _sceneIndex = i;
                            _isPlaying = false;
                          });
                        },
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? LiquidGlassTheme.electricIndigo
                                : (isPassed
                                    ? LiquidGlassTheme.electricIndigo.withOpacity(0.45)
                                    : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0))),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Controls Dock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Speed Selector Pill: 0.5x, 1x, 1.5x, 2x
                    PopupMenuButton<double>(
                      onSelected: (v) async {
                        HapticFeedback.lightImpact();
                        setState(() => _playbackSpeed = v);
                        await _tts.setSpeechRate(v);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: context.liquidGlassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.liquidTextPrimary,
                          ),
                        ),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0.5, child: Text('0.5x (Slow)')),
                        PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                        PopupMenuItem(value: 1.5, child: Text('1.5x (Fast)')),
                        PopupMenuItem(value: 2.0, child: Text('2.0x (Speed)')),
                      ],
                    ),

                    // Media Buttons (Skip -10s, Play/Pause, Skip +10s)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, size: 28),
                          color: context.liquidTextPrimary,
                          onPressed: () => _skipSeconds(-10),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFF4F46E5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: LiquidGlassTheme.electricIndigo.withOpacity(0.40),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, size: 28),
                          color: context.liquidTextPrimary,
                          onPressed: () => _skipSeconds(10),
                        ),
                      ],
                    ),

                    const SizedBox(width: 48), // Balancing spacer
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
