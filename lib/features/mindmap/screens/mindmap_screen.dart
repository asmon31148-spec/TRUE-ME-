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
    final rootTopic = widget.topic ?? 'Operating Systems';
    final root = Node.Id(rootTopic);

    final lower = rootTopic.toLowerCase();
    Node nodeA, nodeB, nodeC;
    Node sub1, sub2, sub3;

    if (lower.contains('calc') || lower.contains('math') || lower.contains('matr')) {
      nodeA = Node.Id('Linear Algebra');
      nodeB = Node.Id('Vector Spaces');
      nodeC = Node.Id('Eigenvalues');
      sub1 = Node.Id('Diagonalization');
      sub2 = Node.Id('Spectral Theorem');
      sub3 = Node.Id('Null Space & Rank');
    } else if (lower.contains('phys') || lower.contains('mechanic')) {
      nodeA = Node.Id('Classical Mechanics');
      nodeB = Node.Id('Lagrangian & Action');
      nodeC = Node.Id('Hamiltonian Formulation');
      sub1 = Node.Id('Least Action Principle');
      sub2 = Node.Id('Conservation Laws');
      sub3 = Node.Id('Phase Space');
    } else if (lower.contains('bio') || lower.contains('chem') || lower.contains('cell')) {
      nodeA = Node.Id('Cellular Biology');
      nodeB = Node.Id('Metabolic Pathways');
      nodeC = Node.Id('Genetics & DNA');
      sub1 = Node.Id('Krebs Cycle');
      sub2 = Node.Id('Transcription');
      sub3 = Node.Id('Enzyme Kinetics');
    } else {
      nodeA = Node.Id('Core Foundations');
      nodeB = Node.Id('Core Mechanisms');
      nodeC = Node.Id('Advanced Synthesis');
      sub1 = Node.Id('Theoretical Basis');
      sub2 = Node.Id('High-Yield Rules');
      sub3 = Node.Id('Problem Solving');
    }

    graph.addEdge(root, nodeA);
    graph.addEdge(root, nodeB);
    graph.addEdge(root, nodeC);

    graph.addEdge(nodeA, sub1);
    graph.addEdge(nodeB, sub2);
    graph.addEdge(nodeC, sub3);
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
