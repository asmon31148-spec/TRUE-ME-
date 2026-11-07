import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import '../../../app/theme/colors.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class MindmapScreen extends StatefulWidget {
  final String? topic;

  const MindmapScreen({super.key, this.topic});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  final Graph graph = Graph()..isTree = true;
  late final BuchheimWalkerConfiguration builder;

  @override
  void initState() {
    super.initState();

    builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 24
      ..levelSeparation = 48
      ..subtreeSeparation = 32;

    _buildInitialGraph();
  }

  void _buildInitialGraph() {
    // Root Node
    final root = Node.Id('Operating Systems');

    // Level 1 Nodes
    final nodeSync = Node.Id('Synchronization');
    final nodeMemory = Node.Id('Virtual Memory');
    final nodeStorage = Node.Id('File Systems');

    graph.addEdge(root, nodeSync);
    graph.addEdge(root, nodeMemory);
    graph.addEdge(root, nodeStorage);

    // Level 2 Nodes
    final nodeMutex = Node.Id('Mutexes & Locks');
    final nodeDeadlock = Node.Id('Deadlocks (Coffman)');
    final nodePaging = Node.Id('Paging & TLB');

    graph.addEdge(nodeSync, nodeMutex);
    graph.addEdge(nodeSync, nodeDeadlock);
    graph.addEdge(nodeMemory, nodePaging);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Concept Mind Map',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.accentCyan),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Regenerating mind map with Sage...')),
              );
            },
          ),
        ],
      ),
      body: InteractiveViewer(
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
            final isRoot = text == 'Operating Systems';

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
    );
  }
}
