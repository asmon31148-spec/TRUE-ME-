import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/true_me_ui.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String? notebookId;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.notebookId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  bool _previewMode = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _insertFormatting(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) {
      _contentController.text = text + prefix + suffix;
      return;
    }

    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      ),
    );
    _contentFocusNode.requestFocus();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    final resolvedTitle = title.isNotEmpty ? title : 'Untitled Note';
    final id = widget.noteId ?? 'note_${DateTime.now().millisecondsSinceEpoch}';
    await OfflineCacheService.cacheNote(id, {
      'id': id,
      'notebookId': widget.notebookId,
      'title': resolvedTitle,
      'content': content,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
      await OfflineCacheService.addDocumentToNotebook(widget.notebookId!, {
        'id': id,
        'fileName': '$resolvedTitle.md',
        'section': 'Notes',
        'content': content,
        'fileType': 'markdown',
        'sizeBytes': content.length,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/library');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Top Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    TrueMeCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/library');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: AppTypography.screenTitle.copyWith(fontSize: 21, color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Untitled note',
                          hintStyle: AppTypography.screenTitle.copyWith(
                            fontSize: 21,
                            color: context.textSecondary.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    TrueMeTonalPill(
                      label: _previewMode ? 'Edit' : 'Preview',
                      backgroundColor: context.surfaceColor,
                      foregroundColor: context.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      onTap: () => setState(() => _previewMode = !_previewMode),
                    ),
                    const SizedBox(width: 8),
                    TrueMeTonalPill(
                      label: 'Save',
                      onTap: _saveNote,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TrueMeCard(
                    borderRadius: 22,
                    padding: EdgeInsets.zero,
                    child: _previewMode
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: SelectionArea(
                              child: Text(
                                _contentController.text.isEmpty
                                    ? 'Nothing to preview.'
                                    : _contentController.text,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.6,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          )
                        : TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: AppTypography.body.copyWith(height: 1.65, color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Start writing your study note...',
                              hintStyle: TextStyle(color: context.textSecondary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                  ),
                ),
              ),

              if (!_previewMode)
                Container(
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    border: Border(top: BorderSide(color: context.borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FormatButton(
                          label: 'B',
                          isBold: true,
                          tooltip: 'Bold',
                          onTap: () => _insertFormatting('**', '**'),
                        ),
                        _FormatButton(
                          label: 'I',
                          isItalic: true,
                          tooltip: 'Italic',
                          onTap: () => _insertFormatting('*', '*'),
                        ),
                        _FormatButton(
                          label: 'H1',
                          tooltip: 'Heading 1',
                          onTap: () => _insertFormatting('\n# '),
                        ),
                        _FormatButton(
                          label: 'H2',
                          tooltip: 'Heading 2',
                          onTap: () => _insertFormatting('\n## '),
                        ),
                        _FormatButton(
                          label: '• List',
                          tooltip: 'Bullet list',
                          onTap: () => _insertFormatting('\n- '),
                        ),
                        _FormatButton(
                          label: '[ ] Task',
                          tooltip: 'Checklist',
                          onTap: () => _insertFormatting('\n- [ ] '),
                        ),
                        _FormatButton(
                          label: '" Quote',
                          tooltip: 'Quote',
                          onTap: () => _insertFormatting('\n> '),
                        ),
                        _FormatButton(
                          label: '</> Code',
                          tooltip: 'Code',
                          onTap: () => _insertFormatting('\n```\n', '\n```\n'),
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

class _FormatButton extends StatelessWidget {
  final String label;
  final bool isBold;
  final bool isItalic;
  final String tooltip;
  final VoidCallback onTap;

  const _FormatButton({
    required this.label,
    this.isBold = false,
    this.isItalic = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
