import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

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
  late final TextEditingController _topicCtrl;
  final Map<String, String> _nodeLabels = {};
  final Map<String, String> _nodeSummaries = {};
  String _currentTopic = '';
  bool _isGenerating = false;
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
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 20
      ..levelSeparation = 48
      ..subtreeSeparation = 24;

    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateMindmap(initial));
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateMindmap(String topic) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _errorText = null;
      _currentTopic = cleanTopic;
    });

    try {
      String content = '';
      if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
        content = OfflineCacheService.getNotebookCombinedText(widget.notebookId!, maxChars: 12000);
      } else {
        // Also try matching by subject name
        final match = OfflineCacheService.getAllCachedNotebooks().where(
          (n) => (n['title'] as String? ?? '').toLowerCase() == cleanTopic.toLowerCase(),
        );
        if (match.isNotEmpty) {
          content = OfflineCacheService.getNotebookCombinedText(match.first['id'] as String, maxChars: 12000);
        }
      }

      final aiRouter = ref.read(aiRouterProvider);
      final jsonStr = await aiRouter.generateMindmap(topic: cleanTopic, content: content);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final newGraph = Graph()..isTree = true;
      _nodeLabels.clear();
      _nodeSummaries.clear();
      int seq = 0;

      final rootTitle = (data['root'] as String? ?? cleanTopic).trim();
      final rootId = 'node_${seq++}';
      final rootNode = Node.Id(rootId);
      _nodeLabels[rootId] = rootTitle;
      _nodeSummaries[rootId] = 'Core topic: $rootTitle';

      final branches = data['branches'] as List<dynamic>? ?? [];
      for (final b in branches) {
        final bMap = Map<String, dynamic>.from(b as Map);
        final bTitle = (bMap['title'] as String? ?? 'Subtopic').trim();
        final bSummary = (bMap['summary'] as String? ?? 'Key branch of $rootTitle').trim();
        final bId = 'node_${seq++}';
        final bNode = Node.Id(bId);
        _nodeLabels[bId] = bTitle;
        _nodeSummaries[bId] = bSummary;
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
          newGraph.addEdge(bNode, cNode);
        }
      }

      if (mounted) {
        setState(() {
          _graph = newGraph;
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

  void _showNodeSheet(String nodeId) {
    final title = _nodeLabels[nodeId] ?? nodeId;
    final summary = _nodeSummaries[nodeId] ?? 'Concept related to $_currentTopic.';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: AppTypography.sectionHeading)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: AppTypography.body),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Ask Sage about this',
              onPressed: () {
                Navigator.pop(ctx);
                final q = Uri.encodeComponent('Explain "$title" in the context of $_currentTopic');
                context.push('/chat?prompt=$q');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mind map', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top input row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: _topicCtrl,
                      hintText: 'Enter any topic or chapter...',
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isGenerating ? null : () => _generateMindmap(_topicCtrl.text),
                      child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Canvas or empty/loading state
            Expanded(
              child: _isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.accent),
                          SizedBox(height: 16),
                          Text('Mapping concept hierarchy with AI...', style: AppTypography.secondary),
                        ],
                      ),
                    )
                  : _errorText != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_errorText!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                          ),
                        )
                      : _graph.nodeCount() == 0
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Enter a topic above and tap Create to build an interactive concept mind map.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.secondary,
                                ),
                              ),
                            )
                          : InteractiveViewer(
                              constrained: false,
                              boundaryMargin: const EdgeInsets.all(100),
                              minScale: 0.3,
                              maxScale: 2.5,
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: GraphView(
                                  graph: _graph,
                                  algorithm: BuchheimWalkerAlgorithm(_builder, TreeEdgeRenderer(_builder)),
                                  paint: Paint()
                                    ..color = AppColors.border
                                    ..strokeWidth = 1.5
                                    ..style = PaintingStyle.stroke,
                                  builder: (Node node) {
                                    final nodeId = node.key!.value as String;
                                    final label = _nodeLabels[nodeId] ?? nodeId;
                                    final isRoot = nodeId == 'node_0';
                                    return GestureDetector(
                                      onTap: () => _showNodeSheet(nodeId),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isRoot ? AppColors.accent : AppColors.border,
                                            width: isRoot ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isRoot ? FontWeight.w600 : FontWeight.w500,
                                            color: isRoot ? AppColors.accent : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
