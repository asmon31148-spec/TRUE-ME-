import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/stt_service.dart';
import '../../../shared/widgets/ai_thinking_indicator.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../../export/screens/document_viewer_screen.dart';
import '../providers/chat_provider.dart';
import 'formatted_message_body.dart';

/// Reusable Sage Chat view.
/// Embedded inside a subject's Chat tab (strictly scoped to that subject)
/// and inside the standalone [ChatScreen].
class SageChatView extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? subject;
  final String? initialPrompt;

  const SageChatView({
    super.key,
    this.notebookId,
    this.subject,
    this.initialPrompt,
  });

  @override
  ConsumerState<SageChatView> createState() => _SageChatViewState();
}

class _SageChatViewState extends ConsumerState<SageChatView> with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  SttService? _sttService;
  bool _isListening = false;
  late final AnimationController _orbCtrl;

  String get _scopeKey {
    if (widget.notebookId != null && widget.notebookId!.isNotEmpty) {
      return widget.notebookId!;
    }
    if (widget.subject != null && widget.subject!.trim().isNotEmpty) {
      return 'sub_${widget.subject!.trim().toLowerCase()}';
    }
    return 'global';
  }

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _textCtrl.text).trim();
    if (text.isEmpty) return;

    if (textToSend == null) {
      _textCtrl.clear();
    }

    _scrollToBottom();
    final aiMsg = await ref.read(chatProvider(_scopeKey).notifier).sendMessage(
          question: text,
          userId: OfflineCacheService.getUserId(),
          notebookId: widget.notebookId,
          subject: widget.subject,
          studentName: OfflineCacheService.getUserName(),
        );
    _scrollToBottom();

    if (mounted && aiMsg?.action != null) {
      final action = aiMsg!.action!;
      if (action.type == SageActionType.exportPdf ||
          action.type == SageActionType.exportDocx ||
          action.type == SageActionType.exportPptx) {
        await _runAction(action);
      }
    }
  }

  Future<void> _runAction(SageAction action) async {
    final nbQuery = widget.notebookId != null && widget.notebookId!.isNotEmpty
        ? 'notebookId=${Uri.encodeComponent(widget.notebookId!)}&'
        : '';
    final sub = widget.subject ?? '';
    final subEncoded = Uri.encodeComponent(sub);
    final topicEncoded = Uri.encodeComponent(action.topic.isNotEmpty ? action.topic : sub);

    switch (action.type) {
      case SageActionType.exportPdf:
      case SageActionType.exportDocx:
      case SageActionType.exportPptx:
        if (action.filePath != null && File(action.filePath!).existsSync()) {
          if (mounted) {
            await DocumentViewerScreen.open(
              context,
              filePath: action.filePath!,
              title: action.topic.isNotEmpty ? action.topic : action.label,
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exported file is not available locally. Ask Sage to regenerate it.')),
          );
        }
        break;
      case SageActionType.quiz:
        if (mounted) context.push('/quiz?${nbQuery}subject=$subEncoded&topic=$topicEncoded');
        break;
      case SageActionType.flashcards:
        if (mounted) context.push('/flashcards?${nbQuery}subject=$subEncoded');
        break;
      case SageActionType.mindmap:
        if (mounted) context.push('/mindmap?${nbQuery}topic=$topicEncoded');
        break;
      case SageActionType.explainer:
        if (mounted) context.push('/explainer?${nbQuery}topic=$topicEncoded');
        break;
      case SageActionType.schedule:
        if (mounted) context.push('/schedule');
        break;
      case SageActionType.voiceTutor:
        if (mounted) context.push('/voice-tutor?${nbQuery}subject=$subEncoded&topic=$topicEncoded');
        break;
    }
  }

  Future<void> _toggleVoiceInput() async {
    _sttService ??= SttService();
    if (_isListening) {
      await _sttService!.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (mounted) setState(() => _isListening = true);
      try {
        await _sttService!.startListening(
          onResult: (text) {
            if (mounted) {
              setState(() => _textCtrl.text = text);
            }
          },
        );
      } catch (_) {
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }

  IconData _actionIcon(SageActionType type) {
    switch (type) {
      case SageActionType.exportPdf:
        return Icons.picture_as_pdf_outlined;
      case SageActionType.exportDocx:
        return Icons.description_outlined;
      case SageActionType.exportPptx:
        return Icons.slideshow_outlined;
      case SageActionType.quiz:
        return Icons.quiz_outlined;
      case SageActionType.flashcards:
        return Icons.style_outlined;
      case SageActionType.mindmap:
        return Icons.account_tree_outlined;
      case SageActionType.explainer:
        return Icons.play_circle_outline;
      case SageActionType.schedule:
        return Icons.calendar_today_outlined;
      case SageActionType.voiceTutor:
        return Icons.record_voice_over_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final chatState = ref.watch(chatProvider(_scopeKey));
    final hasSubject = widget.subject != null && widget.subject!.trim().isNotEmpty;
    final subjectTitle = hasSubject ? widget.subject!.trim() : 'your studies';
    final userName = OfflineCacheService.getUserName().trim().split(RegExp(r'\s+')).first;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty && !chatState.isThinking
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Glowing Translucent Lavender Orbital Sphere
                      AnimatedBuilder(
                        animation: _orbCtrl,
                        builder: (context, _) {
                          final breath = disableAnim ? 0.5 : _orbCtrl.value;
                          return SizedBox(
                            width: 204,
                            height: 204,
                            child: CustomPaint(
                              painter: TrueMeOrbPainter(
                                breath: breath,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Friendly Floating Greeting Card
                      TrueMeEntrance(
                        delayMs: 50,
                        child: TrueMeCard(
                          borderRadius: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 22,
                                  color: context.accentColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hey ${userName.isNotEmpty ? userName : 'there'}!',
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hasSubject
                                          ? 'Ready to explore $subjectTitle together?'
                                          : 'What would you like to explore today?',
                                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Staggered Suggestion Prompt Pills matching Reference Img 3 Center
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TrueMeEntrance(
                              delayMs: 110,
                              child: _SuggestionPill(
                                icon: Icons.lightbulb_outline_rounded,
                                label: 'Explain this topic',
                                onTap: () => _sendMessage(
                                  hasSubject
                                      ? 'Explain the core concepts in my $subjectTitle sources simply.'
                                      : 'Explain a challenging concept from my notes step by step.',
                                ),
                              ),
                            ),
                            TrueMeEntrance(
                              delayMs: 160,
                              child: _SuggestionPill(
                                icon: Icons.quiz_outlined,
                                label: 'Make a quiz',
                                onTap: () => _sendMessage(
                                  hasSubject
                                      ? 'Quiz me on $subjectTitle'
                                      : 'Create a 5-question practice quiz from my subjects',
                                ),
                              ),
                            ),
                            TrueMeEntrance(
                              delayMs: 210,
                              child: _SuggestionPill(
                                icon: Icons.summarize_outlined,
                                label: 'Summarise notes',
                                onTap: () => _sendMessage(
                                  hasSubject
                                      ? 'Summarize key concepts from my $subjectTitle sources'
                                      : 'Summarize my uploaded study material for upcoming exams',
                                ),
                              ),
                            ),
                            TrueMeEntrance(
                              delayMs: 260,
                              child: _SuggestionPill(
                                icon: Icons.account_tree_outlined,
                                label: 'Create a mind map',
                                onTap: () => _sendMessage(
                                  hasSubject
                                      ? 'Create a mind map for $subjectTitle'
                                      : 'Create a mind map of my key study topics',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: chatState.messages.length + (chatState.isThinking ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (idx == chatState.messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AiThinkingIndicator(label: 'Sage is working...'),
                        ),
                      );
                    }

                    final msg = chatState.messages[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.86,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              msg.isUser
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.indigoButtonGradient,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(18),
                                          topRight: Radius.circular(18),
                                          bottomLeft: Radius.circular(18),
                                          bottomRight: Radius.circular(5),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(alpha: 0.22),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: SelectableText(
                                        msg.text,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.42,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : TrueMeCard(
                                      borderRadius: 18,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: FormattedMessageBody(
                                        text: msg.text,
                                        textColor: context.textPrimary,
                                      ),
                                    ),
                              if (!msg.isUser && msg.action != null) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _runAction(msg.action!),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: context.accentColor.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_actionIcon(msg.action!.type), size: 18, color: context.accentColor),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            msg.action!.label,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: context.accentColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.arrow_forward_rounded, size: 14, color: context.accentColor),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!msg.isUser && msg.citation != null) ...[
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _showCitationSheet(context, msg.citation!);
                                      },
                                      child: TrueMeTonalPill(
                                        label: msg.citation!,
                                        icon: Icons.menu_book_rounded,
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _formatTime(msg.timestamp),
                                    style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Quick Action Strips when actively chatting
        if (chatState.messages.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _quickCommandChip(context, Icons.picture_as_pdf_outlined, 'Make PDF',
                      'Provide a study guide of $subjectTitle as a PDF'),
                  _quickCommandChip(context, Icons.description_outlined, 'Word',
                      'Provide a study guide of $subjectTitle as a Word document'),
                  _quickCommandChip(
                      context, Icons.slideshow_outlined, 'Slides', 'Create PowerPoint slides for $subjectTitle'),
                  _quickCommandChip(context, Icons.quiz_outlined, 'Quiz', 'Quiz me on $subjectTitle'),
                  _quickCommandChip(context, Icons.style_outlined, 'Flashcards', 'Create flashcards for $subjectTitle'),
                  _quickCommandChip(
                      context, Icons.account_tree_outlined, 'Mind Map', 'Create a mind map for $subjectTitle'),
                ],
              ),
            ),
          ),

        // Borderless Pill Composer Bar matching Reference Img 3 Center
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: isDark ? Border.all(color: AppColors.darkBorder, width: 0.8) : null,
              boxShadow: context.cardShadow,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.auto_awesome_rounded, size: 20, color: context.accentColor),
                  tooltip: 'Add study material in Library',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/library');
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: context.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening to your voice...'
                          : (hasSubject ? 'Ask about $subjectTitle...' : 'Ask anything...'),
                      hintStyle: TextStyle(color: context.textSecondary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 22,
                    color: _isListening ? AppColors.error : context.textSecondary,
                  ),
                  tooltip: 'Voice speech input',
                  onPressed: _toggleVoiceInput,
                ),
                GestureDetector(
                  onTap: chatState.isThinking ? null : () => _sendMessage(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.indigoButtonGradient,
                    ),
                    child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickCommandChip(BuildContext context, IconData icon, String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _sendMessage(prompt),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.accentColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCitationSheet(BuildContext context, String citation) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 20,
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Source Citation',
                            style: AppTypography.cardTitle,
                          ),
                          Text(
                            'Extracted from your uploaded study notes',
                            style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TrueMeCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.all(14),
                  showShadow: false,
                  color: context.bgColor,
                  child: Row(
                    children: [
                      Icon(Icons.article_outlined, size: 20, color: context.accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          citation,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TrueMePrimaryButton(
                  label: 'View Source in Library',
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/library');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TrueMeCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: context.accentColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
