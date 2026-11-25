import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';

class MindmapScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? topic;

  const MindmapScreen({super.key, this.notebookId, this.topic});

  @override
  ConsumerState<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends ConsumerState<MindmapScreen> {
  Graph _graph = Graph()..isTree = true;
  late final BuchheimWalkerConfiguration _builder;
  late final BuchheimWalkerAlgorithm _algorithm;
  late final TextEditingController _topicCtrl;
  final TransformationController _transformCtrl = TransformationController();
  final Map<String, String> _nodeLabels = {};
  final Map<String, String> _nodeSummaries = {};
  final Map<String, int> _nodeBranchIndex = {};

  String _currentTopic = '';
  String? _selectedNodeId;
  bool _isGenerating = false;
  bool _isFullscreen = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final subs = OfflineCacheService.getUserSubjects();
    final initial = widget.topic?.isNotEmpty == true
        ? widget.topic!
        : (subs.isNotEmpty ? subs.first : '');
    _currentTopic = initial;
    _topicCtrl = TextEditingController(text: initial);

    _builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
      ..siblingSeparation = 28
      ..levelSeparation = 64
      ..subtreeSeparation = 32;

    _algorithm = BuchheimWalkerAlgorithm(_builder, TreeEdgeRenderer(_builder));

    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateMindmap(initial));
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    HapticFeedback.selectionClick();
    final current = _transformCtrl.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.4, 2.4);
    final adjustedFactor = targetScale / currentScale;
    current.scaleByDouble(adjustedFactor, adjustedFactor, 1.0, 1.0);
    setState(() {
      _transformCtrl.value = current;
    });
  }

  void _showTopicPickerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Map a Topic', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: _topicCtrl,
          autofocus: true,
          hintText: 'e.g. Microbiology, Organic Chemistry...',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 42)),
            onPressed: () {
              Navigator.pop(ctx);
              _generateMindmap(_topicCtrl.text);
            },
            child: const Text('Map'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateMindmap(String topic) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _errorText = null;
      _currentTopic = cleanTopic;
      _selectedNodeId = null;
    });

    try {
      String content = '';
      if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
        content = OfflineCacheService.getNotebookCombinedText(widget.notebookId!, maxChars: 12000);
      } else {
        final match = OfflineCacheService.getAllCachedNotebooks().where(
          (n) => (n['title'] as String? ?? '').toLowerCase() == cleanTopic.toLowerCase(),
        );
        if (match.isNotEmpty) {
          content = OfflineCacheService.getNotebookCombinedText(match.first['id'] as String, maxChars: 12000);
        }
      }

      final aiRouter = ref.read(aiRouterProvider);
      final jsonStr = await aiRouter.generateMindmap(topic: cleanTopic, content: content);
      final data = AiRouter.parseJsonObject(jsonStr);

      final newGraph = Graph()..isTree = true;
      _nodeLabels.clear();
      _nodeSummaries.clear();
      _nodeBranchIndex.clear();
      int seq = 0;

      final rootTitle = (data['root'] as String? ?? cleanTopic).trim();
      final rootId = 'node_${seq++}';
      final rootNode = Node.Id(rootId);
      _nodeLabels[rootId] = rootTitle;
      _nodeSummaries[rootId] = 'Core overview & concept hierarchy for $rootTitle.';
      _nodeBranchIndex[rootId] = 0;

      final branches = data['branches'] as List<dynamic>? ?? [];
      int branchIdx = 0;
      for (final b in branches) {
        final bMap = Map<String, dynamic>.from(b as Map);
        final bTitle = (bMap['title'] as String? ?? 'Subtopic').trim();
        final bSummary = (bMap['summary'] as String? ?? 'Key branch of $rootTitle').trim();
        final bId = 'node_${seq++}';
        final bNode = Node.Id(bId);
        _nodeLabels[bId] = bTitle;
        _nodeSummaries[bId] = bSummary;
        _nodeBranchIndex[bId] = branchIdx;
        newGraph.addEdge(rootNode, bNode);

        final children = bMap['children'] as List<dynamic>? ?? [];
        for (final c in children) {
          final cMap = Map<String, dynamic>.from(c as Map);
          final cTitle = (cMap['title'] as String? ?? 'Concept').trim();
          final cSummary = (cMap['summary'] as String? ?? 'Supporting detail of $bTitle').trim();
          final cId = 'node_${seq++}';
          final cNode = Node.Id(cId);
          _nodeLabels[cId] = cTitle;
          _nodeSummaries[cId] = cSummary;
          _nodeBranchIndex[cId] = branchIdx;
          newGraph.addEdge(bNode, cNode);
        }
        branchIdx++;
      }

      if (mounted) {
        _transformCtrl.value = Matrix4.identity();
        setState(() {
          _graph = newGraph;
          _selectedNodeId = rootId;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorText = 'Could not generate mind map: $e';
        });
      }
    }
  }

  void _askSageAboutNode(String nodeId) {
    final title = _nodeLabels[nodeId] ?? nodeId;
    final q = Uri.encodeComponent('Explain "$title" in the context of $_currentTopic');
    context.push('/chat?prompt=$q');
  }

  Color _branchBgColor(int idx, bool isDark) {
    final colorsLight = [
      const Color(0xFFE3F2FF),
      const Color(0xFFE3F6E8),
      const Color(0xFFFDEBD8),
      const Color(0xFFEDE8FF),
    ];
    final colorsDark = [
      const Color(0xFF11233D),
      const Color(0xFF0E2922),
      const Color(0xFF2B2110),
      const Color(0xFF241938),
    ];
    return isDark ? colorsDark[idx % colorsDark.length] : colorsLight[idx % colorsLight.length];
  }

  Color _branchInkColor(int idx, bool isDark) {
    final inksLight = [
      const Color(0xFF0284C7),
      const Color(0xFF15803D),
      const Color(0xFFC2410C),
      const Color(0xFF6D28D9),
    ];
    final inksDark = [
      const Color(0xFF60A5FA),
      const Color(0xFF4ADE80),
      const Color(0xFFFBBF24),
      const Color(0xFFC4B5FD),
    ];
    return isDark ? inksDark[idx % inksDark.length] : inksLight[idx % inksLight.length];
  }

  IconData _branchIcon(int idx) {
    const icons = [
      Icons.biotech_rounded,
      Icons.coronavirus_outlined,
      Icons.shield_outlined,
      Icons.bubble_chart_rounded,
    ];
    return icons[idx % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final activeId = _selectedNodeId ?? (_nodeLabels.isNotEmpty ? _nodeLabels.keys.first : null);
    final activeTitle = activeId != null ? (_nodeLabels[activeId] ?? _currentTopic) : _currentTopic;
    final activeSummary = activeId != null ? (_nodeSummaries[activeId] ?? '') : '';

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Top Bar + Fullscreen Expand Button
              TrueMeTopBar(
                title: 'Mind Map',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/practice');
                  }
                },
                trailing: TrueMeCircleIconButton(
                  icon: _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen canvas',
                  size: 40,
                  onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                ),
              ),

              // Compact Floating Topic Switcher Pill (Hidden in Fullscreen)
              if (!_isFullscreen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: TrueMeTonalPill(
                          label: _currentTopic.isNotEmpty ? _currentTopic : 'Choose Topic to Map',
                          icon: Icons.edit_outlined,
                          backgroundColor: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.94),
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: _showTopicPickerDialog,
                        ),
                      ),
                    ],
                  ),
                ),

              // Interactive Graph Canvas
              Expanded(
                child: _isGenerating
                    ? const GenerationProgressView(
                        title: 'Mapping concept hierarchy...',
                        stages: [
                          'Analyzing core topic...',
                          'Building branches & relationships...',
                          'Generating concept summaries...',
                          'Rendering interactive tree...',
                        ],
                      )
                    : _errorText != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: TrueMeCard(
                                child: Text(
                                  _errorText!,
                                  style: const TextStyle(color: AppColors.error),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : _graph.nodeCount() == 0
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Tap the topic pill above to build an interactive concept tree.',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                    ),
                                ),
                              )
                            : InteractiveViewer(
                                transformationController: _transformCtrl,
                                constrained: false,
                                boundaryMargin: const EdgeInsets.all(140),
                                minScale: 0.35,
                                maxScale: 2.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(36),
                                  child: GraphView(
                                    graph: _graph,
                                    algorithm: _algorithm,
                                    paint: Paint()
                                      ..color = context.accentColor.withValues(alpha: 0.45)
                                      ..strokeWidth = 2.0
                                      ..style = PaintingStyle.stroke,
                                    builder: (Node node) {
                                      final nodeId = node.key!.value as String;
                                      final label = _nodeLabels[nodeId] ?? nodeId;
                                      final isRoot = nodeId == 'node_0';
                                      final isSelected = activeId == nodeId;
                                      final bIdx = _nodeBranchIndex[nodeId] ?? 0;

                                      if (isRoot) {
                                        return GestureDetector(
                                          onTap: () => setState(() => _selectedNodeId = nodeId),
                                          child: Container(
                                            constraints: const BoxConstraints(minWidth: 138, maxWidth: 204),
                                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.indigoButtonGradient,
                                              borderRadius: BorderRadius.circular(42),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.accent.withValues(alpha: 0.34),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 7),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.18),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.hub_rounded, size: 19, color: Colors.white),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  label,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      final bg = _branchBgColor(bIdx, isDark);
                                      final ink = _branchInkColor(bIdx, isDark);

                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _selectedNodeId = nodeId);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 160),
                                          constraints: const BoxConstraints(minWidth: 112, maxWidth: 178),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(24),
                                            border: isSelected ? Border.all(color: ink, width: 2.0) : null,
                                            boxShadow: [
                                              BoxShadow(
                                                color: ink.withValues(alpha: isSelected ? 0.22 : 0.10),
                                                blurRadius: isSelected ? 16 : 12,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: ink,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(_branchIcon(bIdx), size: 16, color: Colors.white),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
              ),

              // Bottom Selected Node Card + Regenerate/Zoom Bar (matching Ref Img 4 Right)
              if (_graph.nodeCount() > 0 && !_isGenerating)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (activeId != null)
                        TrueMeCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(14),
                          onTap: () => _askSageAboutNode(activeId),
                          child: Row(
                            children: [
                              StackedDeckEmblem(accentColor: context.accentColor, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    if (activeSummary.isNotEmpty)
                                      Text(
                                        activeSummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 22, color: context.textSecondary),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _currentTopic.isNotEmpty ? () => _generateMindmap(_currentTopic) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: context.cardShadow,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 17, color: context.accentColor),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Regenerate',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          TrueMeCircleIconButton(
                            icon: Icons.zoom_out_rounded,
                            tooltip: 'Zoom out',
                            size: 42,
                            onPressed: () => _zoomBy(0.8),
                          ),
                          const SizedBox(width: 10),
                          TrueMeCircleIconButton(
                            icon: Icons.zoom_in_rounded,
                            tooltip: 'Zoom in',
                            size: 42,
                            onPressed: () => _zoomBy(1.25),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
