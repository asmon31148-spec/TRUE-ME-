import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/app_components.dart';

class MindmapScreen extends StatefulWidget {
  final String? topic;

  const MindmapScreen({super.key, this.topic});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  late Graph graph;
  late final BuchheimWalkerConfiguration builder;
  late final TextEditingController _topicCtrl;
  late String _currentTopic;

  @override
  void initState() {
    super.initState();
    _currentTopic = widget.topic ?? 'Bacterial cell structure';
    _topicCtrl = TextEditingController(text: _currentTopic);

    builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 20
      ..levelSeparation = 48
      ..subtreeSeparation = 24;

    _buildGraph(_currentTopic);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  void _buildGraph(String topic) {
    graph = Graph()..isTree = true;
    _currentTopic = topic;

    final root = Node.Id(topic);
    final n1 = Node.Id('Cell envelope');
    final n2 = Node.Id('Cytoplasm & organelles');
    final n3 = Node.Id('External structures');

    final sub1 = Node.Id('Peptidoglycan wall');
    final sub2 = Node.Id('Plasma membrane');
    final sub3 = Node.Id('70S Ribosomes');
    final sub4 = Node.Id('Flagella & Pili');

    graph.addEdge(root, n1);
    graph.addEdge(root, n2);
    graph.addEdge(root, n3);

    graph.addEdge(n1, sub1);
    graph.addEdge(n1, sub2);
    graph.addEdge(n2, sub3);
    graph.addEdge(n3, sub4);

    setState(() {});
  }

  void _showNodeSheet(String title) {
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
                Text(title, style: AppTypography.sectionHeading),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A critical sub-concept in $_currentTopic referenced across your syllabus notes.',
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Ask Sage about this',
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/chat?prompt=Explain%20$title');
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
                      hintText: 'Topic',
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final t = _topicCtrl.text.trim();
                        if (t.isNotEmpty) _buildGraph(t);
                      },
                      child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Canvas
            Expanded(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.3,
                maxScale: 2.0,
                child: GraphView(
                  graph: graph,
                  algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                  paint: Paint()
                    ..color = AppColors.border
                    ..strokeWidth = 1.5
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final text = node.key!.value as String;
                    final isRoot = text == _currentTopic;

                    return InkWell(
                      onTap: () => _showNodeSheet(text),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isRoot ? AppColors.accent : AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRoot ? FontWeight.w600 : FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
