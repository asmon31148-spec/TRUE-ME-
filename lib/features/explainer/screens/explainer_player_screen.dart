import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../models/explainer_script_model.dart';
import '../services/explainer_generator.dart';

/// Audio Explainer Screen aligned with Reference Image 1 Panel 1.
/// Preserves real scene-by-scene TTS narration, speed control, scene jumping, and Save-to-Notes.
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

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

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

  Future<void> _goToScene(int targetIdx) async {
    if (_script == null || _script!.scenes.isEmpty) return;
    HapticFeedback.selectionClick();
    final wasPlaying = _isPlaying;
    await _tts.stop();
    if (!mounted) return;
    final clamped = targetIdx.clamp(0, _script!.scenes.length - 1);
    setState(() {
      _sceneIndex = clamped;
      _isPlaying = wasPlaying;
    });
    if (wasPlaying) {
      _playFromScene(clamped);
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

  void _showTopicOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Explainer Settings', style: AppTypography.sectionHeading),
            const SizedBox(height: 14),
            AppInput(
              label: 'Topic to Explain',
              hintText: 'e.g. Bacterial Cell Structure',
              controller: _topicCtrl,
            ),
            const SizedBox(height: 16),
            TrueMePrimaryButton(
              label: 'Generate Walkthrough',
              onPressed: () {
                Navigator.pop(ctx);
                _generateExplainer(_topicCtrl.text);
              },
            ),
            if (_script != null) ...[
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: 'Save Script to Notes',
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveScriptToNotes();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final scenes = _script?.scenes ?? [];
    final currentScene = scenes.isNotEmpty ? scenes[_sceneIndex.clamp(0, scenes.length - 1)] : null;
    final progress = scenes.isNotEmpty ? (_sceneIndex + 1) / scenes.length : 0.0;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Header Bar
              TrueMeTopBar(
                title: 'Audio Explainer',
                onBack: () {
                  _tts.stop();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/practice');
                  }
                },
                trailing: TrueMeCircleIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Topic & save options',
                  size: 40,
                  onPressed: _showTopicOptionsSheet,
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: _isGenerating
                      ? const GenerationProgressView(
                          title: 'Preparing your narrated walkthrough...',
                          stages: [
                            'Reading your syllabus and notes...',
                            'Structuring key learning scenes...',
                            'Highlighting formulas & definitions...',
                            'Setting up audio playback...',
                          ],
                        )
                      : _errorText != null
                          ? Center(
                              child: TrueMeCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.error, size: 42),
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorText!,
                                      style: const TextStyle(color: AppColors.error),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    TrueMePrimaryButton(
                                      label: 'Try Again',
                                      onPressed: () => _generateExplainer(_topicCtrl.text),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : currentScene == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TrueMeCard(
                                      padding: const EdgeInsets.all(22),
                                      child: Column(
                                        children: [
                                          AppIconBadge(
                                            icon: Icons.headphones_rounded,
                                            size: 56,
                                            iconSize: 28,
                                            color: context.accentColor,
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'Listen & Learn Hands-Free',
                                            style: AppTypography.sectionHeading,
                                          ),
                                          const SizedBox(height: 8),
                                          AppInput(
                                            hintText: 'Enter topic to narrate...',
                                            controller: _topicCtrl,
                                          ),
                                          const SizedBox(height: 16),
                                          TrueMePrimaryButton(
                                            label: 'Create Explainer',
                                            onPressed: () => _generateExplainer(_topicCtrl.text),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    // Illustrated Artwork & Narration Stage Card
                                    Expanded(
                                      child: TrueMeCard(
                                        borderRadius: 24,
                                        padding: EdgeInsets.zero,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: Column(
                                            children: [
                                              // Pastel Header Stage Banner with Play Overlay
                                              GestureDetector(
                                                onTap: _togglePlay,
                                                child: Container(
                                                  height: 144,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    gradient: isDark
                                                        ? AppColors.heroFocusDarkGradient
                                                        : AppColors.heroFocusLightGradient,
                                                  ),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Positioned.fill(
                                                        child: CustomPaint(
                                                          painter: _StageArtworkPainter(isDark: isDark),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 58,
                                                        height: 58,
                                                        decoration: BoxDecoration(
                                                          color: context.textPrimary.withValues(alpha: 0.72),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          _isPlaying
                                                              ? Icons.pause_rounded
                                                              : Icons.play_arrow_rounded,
                                                          size: 34,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        top: 12,
                                                        left: 14,
                                                        child: TrueMeTonalPill(
                                                          label: 'Scene ${_sceneIndex + 1} / ${scenes.length}',
                                                          backgroundColor: context.surfaceColor.withValues(alpha: 0.88),
                                                          foregroundColor: context.textPrimary,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // Scene Title, Key Elements & Scrollable Narration
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  physics: const BouncingScrollPhysics(),
                                                  padding: const EdgeInsets.all(18),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        currentScene.title,
                                                        textAlign: TextAlign.center,
                                                        style: AppTypography.sectionHeading.copyWith(
                                                          fontSize: 20,
                                                          color: context.textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 10),
                                                      if (currentScene.elements.isNotEmpty) ...[
                                                        Wrap(
                                                          alignment: WrapAlignment.center,
                                                          spacing: 6,
                                                          runSpacing: 6,
                                                          children: currentScene.elements.map((el) {
                                                            return Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 10, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: isDark
                                                                    ? AppColors.darkAccentWash
                                                                    : AppColors.accentWash,
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Text(
                                                                el,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: context.accentColor,
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                        const SizedBox(height: 12),
                                                      ],
                                                      SelectableText(
                                                        currentScene.narrationText,
                                                        textAlign: TextAlign.center,
                                                        style: AppTypography.body.copyWith(
                                                          fontSize: 14.5,
                                                          color: context.textSecondary,
                                                          height: 1.55,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Scrubber Bar & Scene Counter
                                    AppProgressBar(value: progress),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _isPlaying ? 'Narrating...' : 'Paused',
                                          style: AppTypography.smallLabel.copyWith(
                                            color: _isPlaying ? context.accentColor : context.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Scene ${_sceneIndex + 1} of ${scenes.length}',
                                          style: AppTypography.smallLabel.copyWith(color: context.textPrimary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Play / Pause + Skip Controls
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        TrueMeCircleIconButton(
                                          icon: Icons.replay_10_rounded,
                                          tooltip: 'Previous scene',
                                          size: 48,
                                          onPressed: () => _goToScene(_sceneIndex - 1),
                                        ),
                                        const SizedBox(width: 24),
                                        GestureDetector(
                                          onTap: _togglePlay,
                                          child: Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: AppColors.indigoButtonGradient,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.accent.withValues(alpha: 0.30),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                              size: 34,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        TrueMeCircleIconButton(
                                          icon: Icons.forward_10_rounded,
                                          tooltip: 'Next scene',
                                          size: 48,
                                          onPressed: () => _goToScene(_sceneIndex + 1),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Speed Pills: 0.5x | 1x | 1.5x | 2x
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: _speeds.map((spd) {
                                        final selected = (_playbackSpeed - spd).abs() < 0.05;
                                        final label = spd == 1.0 || spd == 2.0 ? '${spd.toInt()}x' : '${spd}x';
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                          child: GestureDetector(
                                            onTap: () async {
                                              HapticFeedback.selectionClick();
                                              setState(() => _playbackSpeed = spd);
                                              await _tts.setSpeechRate(spd);
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                gradient: selected ? AppColors.indigoButtonGradient : null,
                                                color: selected ? null : context.surfaceColor,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: selected ? Colors.transparent : context.borderColor,
                                                ),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: selected ? Colors.white : context.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),

                                    // Previous / Next Scene Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppSecondaryButton(
                                            label: '< Previous',
                                            height: 46,
                                            onPressed: _sceneIndex > 0 ? () => _goToScene(_sceneIndex - 1) : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TrueMeTonalPill(
                                            label: 'Next Scene >',
                                            backgroundColor: context.surfaceColor,
                                            foregroundColor: context.textPrimary,
                                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                                            onTap: _sceneIndex < scenes.length - 1
                                                ? () => _goToScene(_sceneIndex + 1)
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageArtworkPainter extends CustomPainter {
  final bool isDark;

  const _StageArtworkPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = (isDark ? const Color(0xFF4F46E5) : const Color(0xFFC8C2FA)).withValues(alpha: 0.40);
    final p2 = Paint()
      ..color = (isDark ? const Color(0xFF2DD4BF) : const Color(0xFFBFEAD4)).withValues(alpha: 0.45);

    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.78), 52, p2);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.25), 64, p1);
  }

  @override
  bool shouldRepaint(covariant _StageArtworkPainter oldDelegate) => oldDelegate.isDark != isDark;
}
