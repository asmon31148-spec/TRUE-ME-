import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorScreen({
    super.key,
    this.noteId,
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
      text: widget.initialTitle ?? 'Lecture Notes — System Calls & Kernels',
    );
    _contentController = TextEditingController(
      text: widget.initialContent ??
          '# Introduction to System Calls\n\n'
          'A **system call** is the programmatic mechanism by which a computer program requests a service from the kernel of the operating system it is executed on.\n\n'
          '### Core Concepts:\n'
          '• **User Mode vs Kernel Mode**: Hardware-enforced separation for memory security\n'
          '• **Trap Instructions**: Software interrupts that transfer CPU control to the kernel dispatcher\n'
          '• **Context Switching**: Register save/restore cycles causing execution overhead\n\n'
          '```c\n'
          '// Example: fork() and exec() paradigm\n'
          'pid_t pid = fork();\n'
          'if (pid == 0) {\n'
          '    execlp("/bin/ls", "ls", NULL);\n'
          '}\n'
          '```\n',
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
      appBar: GlassAppBar(
        title: 'Study Note',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _previewMode ? Icons.edit_note : Icons.preview,
              color: AppColors.accentCyan,
            ),
            tooltip: _previewMode ? 'Switch to Edit' : 'Preview Note',
            onPressed: () {
              setState(() {
                _previewMode = !_previewMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.accentCyan),
            tooltip: 'Save Note',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note saved to notebook!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Note Title Input in Glass Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: 16,
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Note Title...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Markdown Formatting Toolbar
            if (!_previewMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ToolbarButton(label: 'B', tooltip: 'Bold', onTap: () => _insertFormatting('**', '**')),
                      _ToolbarButton(label: 'I', tooltip: 'Italic', isItalic: true, onTap: () => _insertFormatting('*', '*')),
                      _ToolbarButton(label: 'H1', tooltip: 'Heading 1', onTap: () => _insertFormatting('\n# ')),
                      _ToolbarButton(label: 'H2', tooltip: 'Heading 2', onTap: () => _insertFormatting('\n## ')),
                      _ToolbarButton(label: '• List', tooltip: 'Bullet List', onTap: () => _insertFormatting('\n• ')),
                      _ToolbarButton(label: '[ ] Todo', tooltip: 'Checklist', onTap: () => _insertFormatting('\n[ ] ')),
                      _ToolbarButton(label: '</>', tooltip: 'Code Block', onTap: () => _insertFormatting('\n```\n', '\n```\n')),
                      _ToolbarButton(label: '> Quote', tooltip: 'Blockquote', onTap: () => _insertFormatting('\n> ')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),

            // Note Body Editor or Rendered View
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: _previewMode
                    ? SingleChildScrollView(
                        child: SelectionArea(
                          child: Text(
                            _contentController.text,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ),
                      )
                    : TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Start writing your study notes here...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
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

class _ToolbarButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool isItalic;

  const _ToolbarButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.isItalic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
