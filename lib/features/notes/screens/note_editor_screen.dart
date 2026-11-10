import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';

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
    _titleController = TextEditingController(
      text: widget.initialTitle ?? '',
    );
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
        title: TextField(
          controller: _titleController,
          style: AppTypography.screenTitle,
          decoration: const InputDecoration(
            hintText: 'Untitled note',
            hintStyle: TextStyle(
              color: AppColors.textMuted,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _previewMode = !_previewMode;
              });
            },
            child: Text(
              _previewMode ? 'Edit' : 'Preview',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () async {
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
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Full-height writing area (white/background color, no card)
            Expanded(
              child: _previewMode
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectionArea(
                        child: Text(
                          _contentController.text.isEmpty
                              ? 'Nothing to preview.'
                              : _contentController.text,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textPrimary,
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
                      style: AppTypography.bodyMedium.copyWith(height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'Start writing your note...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20),
                      ),
                    ),
            ),

            // Single horizontal formatting row just above the keyboard
            if (!_previewMode)
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        label: '[ ] Checklist',
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
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
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
