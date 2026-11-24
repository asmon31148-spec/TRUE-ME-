import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/liquid_glass_theme.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../providers/chat_provider.dart';
import '../widgets/sage_chat_view.dart';

/// NotebookLM-Style Research Chat Screen.
///
/// Features:
/// - Single-file or Full-Notebook Context Selector Pill at top
/// - Liquid Glass visual hierarchy (anti-AI slop: zero neon gradient bubbles)
/// - Scope persistence and fast switching across enrolled subjects
class ChatScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? subject;
  final String? initialPrompt;

  const ChatScreen({
    super.key,
    this.notebookId,
    this.subject,
    this.initialPrompt,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _activeSubject;

  @override
  void initState() {
    super.initState();
    _activeSubject = widget.subject;
  }

  String get _scopeKey {
    if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
      return widget.notebookId!;
    }
    if (_activeSubject != null && _activeSubject!.trim().isNotEmpty) {
      return 'sub_${_activeSubject!.trim().toLowerCase()}';
    }
    return 'global';
  }

  @override
  Widget build(BuildContext context) {
    final subjects = OfflineCacheService.getUserSubjects();
    final isDark = context.isDark;
    final isFullNotebook = _activeSubject == null || _activeSubject!.isEmpty;

    return Scaffold(
      backgroundColor: context.liquidCanvas,
      appBar: GlassAppBar(
        title: 'Sage AI',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.liquidTextPrimary,
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/today');
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, size: 22, color: context.liquidTextSecondary),
            color: isDark ? const Color(0xFF1E2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'clear') {
                HapticFeedback.mediumImpact();
                ref.read(chatProvider(_scopeKey).notifier).clearHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 18, color: LiquidGlassTheme.roseAlert),
                    const SizedBox(width: 8),
                    Text('Clear Chat History', style: TextStyle(color: LiquidGlassTheme.roseAlert)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // NotebookLM-Style Context Selector Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? LiquidGlassTheme.darkCanvas.withOpacity(0.6)
                    : LiquidGlassTheme.lightCanvas.withOpacity(0.6),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.electricIndigo.withOpacity(isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: LiquidGlassTheme.electricIndigo.withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFullNotebook ? Icons.auto_stories_rounded : Icons.bookmark_rounded,
                          size: 13,
                          color: LiquidGlassTheme.electricIndigo,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isFullNotebook ? 'FULL NOTEBOOK' : 'SUBJECT SCOPE',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: LiquidGlassTheme.electricIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: subjects.isNotEmpty && widget.notebookId == null
                          ? () {
                              HapticFeedback.lightImpact();
                              _showScopePicker(context, subjects);
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.liquidGlassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isFullNotebook
                                    ? (subjects.isNotEmpty
                                        ? 'All Notebook Sources (${subjects.length} enrolled)'
                                        : 'Global Study Context')
                                    : _activeSubject!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.liquidTextPrimary,
                                ),
                              ),
                            ),
                            if (subjects.isNotEmpty && widget.notebookId == null)
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: context.liquidTextSecondary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Chat Stream View
            Expanded(
              child: SageChatView(
                key: ValueKey(_scopeKey),
                notebookId: widget.notebookId,
                subject: _activeSubject,
                initialPrompt: widget.initialPrompt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScopePicker(BuildContext context, List<String> subjects) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.liquidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Research Context',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.liquidTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_stories_rounded, color: LiquidGlassTheme.electricIndigo),
                  title: const Text('Entire Notebook (All Sources)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Search across all ${subjects.length} subjects and notes'),
                  trailing: _activeSubject == null
                      ? const Icon(Icons.check_circle_rounded, color: LiquidGlassTheme.electricIndigo)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _activeSubject = null);
                  },
                ),
                const Divider(height: 1),
                ...subjects.map((sub) {
                  final isSelected = _activeSubject == sub;
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(sub, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Strictly scoped to this subject\'s notes'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: LiquidGlassTheme.electricIndigo)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _activeSubject = sub);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
