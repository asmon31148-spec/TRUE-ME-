import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../providers/chat_provider.dart';
import '../widgets/sage_chat_view.dart';

/// NotebookLM-Style Sage AI Companion Screen.
///
/// Preserves scope selection (Full Notebook vs Subject), chat history clearing,
/// and embeds the redesigned [SageChatView].
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
    final isFullNotebook = _activeSubject == null || _activeSubject!.isEmpty;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        intenseLavender: true,
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Top Header matching Sage Reference
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
                          context.go('/today');
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sage',
                                style: AppTypography.screenTitle.copyWith(
                                  fontSize: 22,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.auto_awesome_rounded, size: 17, color: context.accentColor),
                            ],
                          ),
                          Text(
                            'Your AI Learning Companion',
                            style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TrueMeCircleIconButton(
                      icon: Icons.volume_up_rounded,
                      tooltip: 'Voice Tutor',
                      size: 40,
                      onPressed: () => context.push('/voice-tutor'),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, size: 22, color: context.textSecondary),
                      onSelected: (val) {
                        if (val == 'clear') {
                          HapticFeedback.mediumImpact();
                          ref.read(chatProvider(_scopeKey).notifier).clearHistory();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Clear Chat History', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Compact Subject Scope Selector Pill
              if (subjects.isNotEmpty || widget.notebookId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: GestureDetector(
                    onTap: subjects.isNotEmpty && widget.notebookId == null
                        ? () {
                            HapticFeedback.selectionClick();
                            _showScopePicker(context, subjects);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFullNotebook ? Icons.auto_stories_rounded : Icons.bookmark_rounded,
                            size: 14,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isFullNotebook
                                  ? (subjects.isNotEmpty
                                      ? 'All Sources (${subjects.length} subjects)'
                                      : 'Global Study Context')
                                  : _activeSubject!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          if (subjects.isNotEmpty && widget.notebookId == null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.textSecondary),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Live Sage Chat Body
              Expanded(
                child: SageChatView(
                  notebookId: widget.notebookId,
                  subject: _activeSubject,
                  initialPrompt: widget.initialPrompt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScopePicker(BuildContext context, List<String> subjects) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Study Context', style: AppTypography.sectionHeading),
              const SizedBox(height: 4),
              Text(
                'Choose whether Sage reads across your entire library or narrows into one subject.',
                style: AppTypography.secondary.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: _activeSubject == null ? context.accentTint : context.bgColor,
                leading: Icon(Icons.auto_stories_rounded, color: context.accentColor),
                title: const Text('Full Notebook Context', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Cross-reference all enrolled subjects', style: TextStyle(fontSize: 12)),
                trailing: _activeSubject == null ? Icon(Icons.check_circle, color: context.accentColor) : null,
                onTap: () {
                  setState(() => _activeSubject = null);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              ...subjects.map((sub) {
                final isSelected = _activeSubject == sub;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: isSelected ? context.accentTint : context.bgColor,
                    leading: Icon(Icons.bookmark_outline_rounded, color: context.accentColor),
                    title: Text(sub, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: context.accentColor) : null,
                    onTap: () {
                      setState(() => _activeSubject = sub);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
