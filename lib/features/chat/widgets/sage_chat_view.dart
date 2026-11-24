import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/liquid_glass_theme.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/stt_service.dart';
import '../../../shared/widgets/ai_thinking_indicator.dart';
import '../../../shared/widgets/glass_card.dart';
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

class _SageChatViewState extends ConsumerState<SageChatView> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  SttService? _sttService;
  bool _isListening = false;

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
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
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

    // Auto-open generated PDF/DOCX/PPTX immediately so the user gets their file right away
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
        if (action.filePath != null && File(action.filePath!).existsSync()) {
          final bytes = await File(action.filePath!).readAsBytes();
          final name = action.filePath!.split(RegExp(r'[/\\]')).last;
          await Printing.sharePdf(bytes: bytes, filename: name);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Study guide file is not available locally. Ask Sage to regenerate it.')),
          );
        }
        break;
      case SageActionType.exportDocx:
      case SageActionType.exportPptx:
        if (action.filePath != null && File(action.filePath!).existsSync()) {
          final res = await OpenFilex.open(action.filePath!);
          if (mounted && res.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to ${action.filePath} (${res.message})')),
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
    final isDark = context.isDark;
    final chatState = ref.watch(chatProvider(_scopeKey));
    final hasSubject = widget.subject != null && widget.subject!.trim().isNotEmpty;
    final subjectTitle = hasSubject ? widget.subject!.trim() : 'your studies';

    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty && !chatState.isThinking
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSubject ? 'Ask Sage about $subjectTitle' : 'Ask Sage anything',
                        style: AppTypography.sectionHeading,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSubject
                            ? 'Strictly focused on $subjectTitle sources and your $subjectTitle progress. Ask for summaries, PDFs, Word docs, PPT slides, quizzes, flashcards, or mind maps.'
                            : 'Sage reads your uploaded syllabus and notes, and can create PDFs, Word docs, slides, quizzes, flashcards, or mind maps.',
                        style: AppTypography.secondary,
                      ),
                      const SizedBox(height: 18),
                      _buildSuggestionRow(
                        hasSubject
                            ? 'Summarize key concepts from my $subjectTitle sources'
                            : 'Help me build a study strategy for my exams',
                      ),
                      _buildSuggestionRow(
                        hasSubject
                            ? 'What are my weak areas in $subjectTitle and what should I study next?'
                            : 'Explain a difficult concept step by step',
                      ),
                      _buildSuggestionRow(
                        hasSubject
                            ? 'Provide a study guide of $subjectTitle as a PDF'
                            : 'Create a 5-question practice quiz',
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
                    final isDark = context.isDark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.88,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              msg.isUser
                                  ? CustomPaint(
                                      foregroundPainter: SpecularBorderPainter(
                                        borderRadius: 18,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withOpacity(0.35),
                                            Colors.white.withOpacity(0.06),
                                          ],
                                        ),
                                        borderWidth: 1.0,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: LiquidGlassTheme.electricIndigo,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(18),
                                            topRight: Radius.circular(18),
                                            bottomLeft: Radius.circular(18),
                                            bottomRight: Radius.circular(4),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: LiquidGlassTheme.electricIndigo.withOpacity(0.32),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: SelectableText(
                                          msg.text,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.4,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                  : GlassCard(
                                      borderRadius: 18,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      glowColor: LiquidGlassTheme.electricIndigo,
                                      child: FormattedMessageBody(
                                        text: msg.text,
                                        textColor: context.liquidTextPrimary,
                                      ),
                                    ),
                              if (!msg.isUser && msg.action != null) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _runAction(msg.action!),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: LiquidGlassTheme.electricIndigo.withOpacity(isDark ? 0.20 : 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: LiquidGlassTheme.electricIndigo.withOpacity(0.40),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_actionIcon(msg.action!.type), size: 18, color: LiquidGlassTheme.electricIndigo),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            msg.action!.label,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: LiquidGlassTheme.electricIndigo,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: LiquidGlassTheme.electricIndigo),
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
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: LiquidGlassTheme.electricIndigo.withOpacity(isDark ? 0.20 : 0.10),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: LiquidGlassTheme.electricIndigo.withOpacity(0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.menu_book_rounded, size: 11, color: LiquidGlassTheme.electricIndigo),
                                            const SizedBox(width: 4),
                                            Text(
                                              msg.citation!,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: LiquidGlassTheme.electricIndigo,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    _formatTime(msg.timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.liquidTextMuted,
                                    ),
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

        // Quick Study Feature Command Chips
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          decoration: BoxDecoration(
            color: context.liquidCanvas,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _quickCommandChip(context, Icons.picture_as_pdf_outlined, 'Make PDF', 'Provide a study guide of $subjectTitle as a PDF'),
                _quickCommandChip(context, Icons.description_outlined, 'Word', 'Provide a study guide of $subjectTitle as a Word document'),
                _quickCommandChip(context, Icons.slideshow_outlined, 'Slides', 'Create PowerPoint slides for $subjectTitle'),
                _quickCommandChip(context, Icons.quiz_outlined, 'Quiz', 'Quiz me on $subjectTitle'),
                _quickCommandChip(context, Icons.style_outlined, 'Flashcards', 'Create flashcards for $subjectTitle'),
                _quickCommandChip(context, Icons.account_tree_outlined, 'Mind Map', 'Create a mind map for $subjectTitle'),
              ],
            ),
          ),
        ),

        // Elevated Floating Glass Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          color: context.liquidCanvas,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                color: LiquidGlassTheme.electricIndigo,
                tooltip: 'Attach study notes or files',
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
                  style: TextStyle(color: context.liquidTextPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Listening to your voice...'
                        : (hasSubject ? 'Ask Sage about $subjectTitle...' : 'Ask Sage anything...'),
                    hintStyle: TextStyle(color: context.liquidTextSecondary),
                    filled: true,
                    fillColor: context.liquidGlassFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: LiquidGlassTheme.electricIndigo, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_outlined,
                  size: 23,
                  color: _isListening ? LiquidGlassTheme.roseAlert : context.liquidTextSecondary,
                ),
                tooltip: 'Voice speech input',
                onPressed: _toggleVoiceInput,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: LiquidGlassTheme.electricIndigo,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: chatState.isThinking ? null : () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickCommandChip(BuildContext context, IconData icon, String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _sendMessage(prompt),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.liquidGlassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: LiquidGlassTheme.electricIndigo),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.liquidTextPrimary,
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
      backgroundColor: context.liquidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.electricIndigo.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: LiquidGlassTheme.electricIndigo, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Source Citation',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Extracted from your uploaded course notes',
                            style: TextStyle(fontSize: 12, color: context.liquidTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.liquidGlassFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined, size: 20, color: LiquidGlassTheme.electricIndigo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          citation,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.liquidTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiquidGlassTheme.electricIndigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/library');
                    },
                    child: const Text('View Source in Library', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14.5, color: context.textPrimary),
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
