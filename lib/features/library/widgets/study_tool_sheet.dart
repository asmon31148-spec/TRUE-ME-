import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/syllabus_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../../export/screens/document_viewer_screen.dart';

class StudyToolScopeSelection {
  final String? nodeId;
  final String topicLabel;
  final String? sourceDocId;
  final String? sourceFileName;
  final String depthLevel;
  final String customInstructions;

  const StudyToolScopeSelection({
    this.nodeId,
    required this.topicLabel,
    this.sourceDocId,
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
  String? _selectedSourceId;
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

  Future<void> _promptRenameArtifact(String artId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Rename Study Material'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await SyllabusService.renameArtifact(widget.notebookId, artId, newName);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmDeleteArtifact(String artId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Study Material?'),
        content: Text(
          'Delete "$title"? This removes it from your Study Library, device storage, and MEGA Vault if backed up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SyllabusService.deleteArtifact(
        widget.notebookId,
        artId,
        subject: widget.subject,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$title"')),
        );
      }
    }
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
                                await DocumentViewerScreen.open(
                                  context,
                                  filePath: path,
                                  title: art['title']?.toString(),
                                );
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
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded,
                                      size: 18, color: context.textSecondary),
                                  onSelected: (val) async {
                                    final artId = art['id']?.toString() ??
                                        art['documentId']?.toString() ??
                                        '';
                                    if (artId.isEmpty) return;
                                    if (val == 'rename') {
                                      await _promptRenameArtifact(artId,
                                          art['title']?.toString() ?? widget.toolTitle);
                                    } else if (val == 'delete') {
                                      await _confirmDeleteArtifact(artId,
                                          art['title']?.toString() ?? widget.toolTitle);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 17),
                                          SizedBox(width: 8),
                                          Text('Rename'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded,
                                              size: 17, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(color: AppColors.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                              initialValue: _selectedSourceId,
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
                                  final id = d['id']?.toString() ?? d['fileName']?.toString() ?? '';
                                  final name = d['fileName']?.toString() ?? 'Document';
                                  return DropdownMenuItem<String?>(
                                    value: id,
                                    child: Text(name, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedSourceId = val;
                                  final match = docs.where((d) => (d['id']?.toString() ?? d['fileName']?.toString()) == val).firstOrNull;
                                  _selectedSourceName = match?['fileName']?.toString();
                                });
                              },
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
                                  sourceDocId: _selectedSourceId,
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
