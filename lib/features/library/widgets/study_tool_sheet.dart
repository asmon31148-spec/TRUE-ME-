import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/syllabus_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

class StudyToolScopeSelection {
  final String? nodeId;
  final String topicLabel;
  final String? sourceFileName;
  final String depthLevel;
  final String customInstructions;

  const StudyToolScopeSelection({
    this.nodeId,
    required this.topicLabel,
    this.sourceFileName,
    required this.depthLevel,
    required this.customInstructions,
  });
}

/// Guided Study Material History + Scope Creation Sheet (Section 5).
/// Shows saved artifacts first (preventing accidental random generation on tile tap)
/// and provides a structured syllabus-driven scope form for creating new artifacts.
class StudyToolSheet extends StatefulWidget {
  final String notebookId;
  final String subject;
  final String artifactType;
  final String toolTitle;

  const StudyToolSheet({
    super.key,
    required this.notebookId,
    required this.subject,
    required this.artifactType,
    required this.toolTitle,
  });

  static Future<StudyToolScopeSelection?> show(
    BuildContext context, {
    required String notebookId,
    required String subject,
    required String artifactType,
    required String toolTitle,
  }) {
    return Navigator.of(context, rootNavigator: true).push<StudyToolScopeSelection>(
      MaterialPageRoute(
        builder: (_) => StudyToolSheet(
          notebookId: notebookId,
          subject: subject,
          artifactType: artifactType,
          toolTitle: toolTitle,
        ),
      ),
    );
  }

  @override
  State<StudyToolSheet> createState() => _StudyToolSheetState();
}

class _StudyToolSheetState extends State<StudyToolSheet> {
  final TextEditingController _topicCtrl = TextEditingController();
  final TextEditingController _instructionsCtrl = TextEditingController();

  String? _selectedNodeId;
  String? _selectedSourceName;
  String _selectedDepth = 'Course Level';

  static const List<String> _depthOptions = [
    'Concise Revision',
    'Course Level',
    'Exam Prep',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    _topicCtrl.text = widget.subject;
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = SyllabusService.getArtifacts(
      widget.notebookId,
      artifactType: widget.artifactType,
    );
    final syllabusNodes = SyllabusService.getSyllabusNodes(widget.notebookId)
        .where((n) => n['nodeType'] == 'unit' || n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    final notebook = OfflineCacheService.getCachedNotebook(widget.notebookId);
    final docs = (notebook?['documents'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrueMeTopBar(
                title: '${widget.toolTitle} · ${widget.subject}',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    // 1. Saved Artifacts History
                    TrueMeSectionHeader(title: 'Saved ${widget.toolTitle}s (${artifacts.length})'),
                    const SizedBox(height: 10),
                    if (artifacts.isEmpty)
                      TrueMeCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No saved ${widget.toolTitle.toLowerCase()}s yet for ${widget.subject}. Configure a focused scope below to create one.',
                          style: AppTypography.secondary.copyWith(color: context.textSecondary),
                        ),
                      )
                    else
                      ...artifacts.take(8).map((art) {
                        final path = art['filePath']?.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TrueMeCard(
                            borderRadius: 16,
                            padding: const EdgeInsets.all(14),
                            onTap: () async {
                              if (path != null && File(path).existsSync()) {
                                await OpenFilex.open(path);
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${art['title']} (${art['topicLabel']})')),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_added_outlined, color: context.accentColor, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        art['title']?.toString() ?? widget.toolTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${art['topicLabel'] ?? widget.subject} · ${art['depthLevel'] ?? 'Course Level'}',
                                        style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.open_in_new_rounded, size: 17, color: context.textSecondary),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 22),
                    TrueMeSectionHeader(title: 'Create Focused ${widget.toolTitle}'),
                    const SizedBox(height: 10),

                    TrueMeCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (syllabusNodes.isNotEmpty) ...[
                            Text(
                              'Syllabus Unit / Topic',
                              style: AppTypography.smallLabel.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedNodeId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: context.surfaceColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                              ),
                              hint: const Text('Select detected syllabus topic'),
                              items: syllabusNodes.map((n) {
                                final prefix = n['nodeType'] == 'unit'
                                    ? '📘 '
                                    : (n['nodeType'] == 'topic' ? '• ' : '  ↳ ');
                                return DropdownMenuItem<String>(
                                  value: n['id'].toString(),
                                  child: Text(
                                    '$prefix${n['title']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedNodeId = val;
                                  final match = syllabusNodes.where((n) => n['id'].toString() == val).firstOrNull;
                                  if (match != null) {
                                    _topicCtrl.text = match['title'].toString();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          AppInput(
                            label: 'Topic / Subtopic Focus',
                            hintText: 'e.g. Food Fermentation',
                            controller: _topicCtrl,
                          ),
                          const SizedBox(height: 14),

                          if (docs.isNotEmpty) ...[
                            Text(
                              'Source Material',
                              style: AppTypography.smallLabel.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              initialValue: _selectedSourceName,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: context.surfaceColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All relevant mapped sources'),
                                ),
                                ...docs.map((d) {
                                  final name = d['fileName']?.toString() ?? 'Document';
                                  return DropdownMenuItem<String?>(
                                    value: name,
                                    child: Text(name, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _selectedSourceName = val),
                            ),
                            const SizedBox(height: 14),
                          ],

                          Text(
                            'Depth / Academic Level',
                            style: AppTypography.smallLabel.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _depthOptions.map((d) {
                              final selected = _selectedDepth == d;
                              return ChoiceChip(
                                label: Text(d),
                                selected: selected,
                                selectedColor: context.accentColor.withValues(alpha: 0.16),
                                onSelected: (_) => setState(() => _selectedDepth = d),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          AppInput(
                            label: 'Optional Instructions',
                            hintText: 'e.g. Include diagrams, high-yield exam questions...',
                            controller: _instructionsCtrl,
                          ),
                          const SizedBox(height: 18),

                          TrueMePrimaryButton(
                            label: 'Generate ${widget.toolTitle}',
                            leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                            onPressed: () {
                              final topic = _topicCtrl.text.trim().isEmpty
                                  ? widget.subject
                                  : _topicCtrl.text.trim();
                              Navigator.of(context).pop(
                                StudyToolScopeSelection(
                                  nodeId: _selectedNodeId,
                                  topicLabel: topic,
                                  sourceFileName: _selectedSourceName,
                                  depthLevel: _selectedDepth,
                                  customInstructions: _instructionsCtrl.text.trim(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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
