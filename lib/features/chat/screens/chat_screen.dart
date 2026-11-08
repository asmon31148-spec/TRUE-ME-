import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/ai_thinking_indicator.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? notebookId;

  const ChatScreen({super.key, this.notebookId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final studentName = OfflineCacheService.getUserName();

    ref.read(chatProvider.notifier).sendMessage(
          question: text,
          userId: 'local_student',
          notebookId: widget.notebookId,
          studentName: studentName,
        );

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isThinking = chatState.isThinking;

    // Trigger auto-scroll on new messages
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Sage AI Study Chat',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Clear Chat History',
            onPressed: () {
              ref.read(chatProvider.notifier).clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat conversation reset.'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Chat message list
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.sageGlowGradient,
                            ),
                            child: const Icon(Icons.psychology, size: 36, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hey ${OfflineCacheService.getUserName()}!',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ask me any question from your lectures, formulas, or flashcards.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        final bool isUser = msg.isUser;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment:
                                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 10, top: 4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.sageGlowGradient,
                                  ),
                                  child: const Icon(Icons.psychology, size: 18, color: Colors.white),
                                ),
                              ],
                              Flexible(
                                child: GlassCard(
                                  borderRadius: 20,
                                  padding: const EdgeInsets.all(16),
                                  surfaceColor: isUser
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.06),
                                  borderGradient: isUser
                                      ? const LinearGradient(
                                          colors: [Color(0x99818CF8), Color(0x336366F1)],
                                        )
                                      : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        msg.text,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: Colors.white,
                                          height: 1.45,
                                        ),
                                      ),
                                      if (msg.citation != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentCyan.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.accentCyan.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.auto_stories,
                                                size: 13,
                                                color: AppColors.accentCyan,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  msg.citation!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.accentCyan,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      OfflineCacheService.getUserName().isNotEmpty
                                          ? OfflineCacheService.getUserName()[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            if (isThinking) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AiThinkingIndicator(),
              ),
            ],

            // Input Bar with Glassmorphism
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.92),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.accentCyan),
                    tooltip: 'Launch Voice Tutor',
                    onPressed: () => context.go('/voice-tutor'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Ask Sage about your notes & exams...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.sageGlowGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
