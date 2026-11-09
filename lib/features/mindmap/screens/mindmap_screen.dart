import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class MindmapScreen extends StatefulWidget {
  final String? topic;

  const MindmapScreen({super.key, this.topic});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  late Graph graph;
  late final BuchheimWalkerConfiguration builder;
  late final TextEditingController _topicController;
  late String _currentTopic;

  @override
  void initState() {
    super.initState();
    final userSubjects = OfflineCacheService.getUserSubjects();
    _currentTopic = widget.topic ?? (userSubjects.isNotEmpty ? userSubjects.first : 'Computer Science');
    _topicController = TextEditingController(text: _currentTopic);

    builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 24
      ..levelSeparation = 54
      ..subtreeSeparation = 36;

    _rebuildGraphForTopic(_currentTopic);
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _rebuildGraphForTopic(String topic) {
    graph = Graph()..isTree = true;
    _currentTopic = topic;

    final root = Node.Id(topic);

    // Dynamic semantic concept tree nodes
    final pillar1 = Node.Id('$topic Core Principles');
    final pillar2 = Node.Id('$topic Key Mechanisms');
    final pillar3 = Node.Id('$topic Problem Applications');

    final sub1 = Node.Id('Definitions & Assumptions');
    final sub2 = Node.Id('Fundamental Equations & Rules');
    final sub3 = Node.Id('Empirical Models & Flows');
    final sub4 = Node.Id('Edge Cases & Invariants');
    final sub5 = Node.Id('Real-World Scenarios');
    final sub6 = Node.Id('Exam Verification Patterns');

    graph.addEdge(root, pillar1);
    graph.addEdge(root, pillar2);
    graph.addEdge(root, pillar3);

    graph.addEdge(pillar1, sub1);
    graph.addEdge(pillar1, sub2);

    graph.addEdge(pillar2, sub3);
    graph.addEdge(pillar2, sub4);

    graph.addEdge(pillar3, sub5);
    graph.addEdge(pillar3, sub6);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Concept Mind Map',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Dynamic Topic Input Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter any topic to map...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.psychology, color: AppColors.accentCyan, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final t = _topicController.text.trim();
                    if (t.isNotEmpty) _rebuildGraphForTopic(t);
                  },
                  child: const Text('Map Concept', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Interactive Graph Canvas
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(120),
              minScale: 0.2,
              maxScale: 2.5,
              child: GraphView(
                graph: graph,
                algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                paint: Paint()
                  ..color = AppColors.primaryLight.withOpacity(0.4)
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final text = node.key!.value as String;
                  final isRoot = text == _currentTopic;

                  return GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    surfaceColor: isRoot
                        ? AppColors.primary.withOpacity(0.35)
                        : Colors.white.withOpacity(0.08),
                    borderGradient: isRoot
                        ? const LinearGradient(
                            colors: [AppColors.accentCyan, AppColors.primaryLight],
                          )
                        : null,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isRoot ? 14 : 12,
                        fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
                        color: isRoot ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
