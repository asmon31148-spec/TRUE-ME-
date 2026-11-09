import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? subject;

  const ChatScreen({super.key, this.notebookId, this.subject});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': true,
      'text': 'What is the difference between Gram-positive and Gram-negative bacteria?',
      'time': '3:41 PM',
    },
    {
      'isUser': false,
      'text':
          'Gram-positive bacteria have a thick peptidoglycan layer and retain the crystal violet stain, appearing purple. Gram-negative bacteria have a thin peptidoglycan layer with an outer membrane and appear pink after counterstaining.',
      'source': 'Notes, page 12',
      'time': '3:42 PM',
    },
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage([String? textToSend]) {
    final text = textToSend ?? _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': 'Now',
      });
      _textCtrl.clear();
    });

    // Simulate grounded response
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'text':
              'Based on your uploaded syllabus and lecture slides, key exam focus includes cell wall synthesis inhibitors and differential diagnostic staining protocols.',
          'source': 'Syllabus, page 4',
          'time': 'Now',
        });
      });
      _scrollToBottom();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.subject ?? 'Microbiology';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sage', style: AppTypography.sectionHeading),
            Text(scope, style: AppTypography.smallLabel),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (val) {
              if (val == 'clear') setState(() => _messages.clear());
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Suggestions', style: AppTypography.sectionHeading),
                            const SizedBox(height: 12),
                            _buildSuggestionRow('Summarize this chapter'),
                            _buildSuggestionRow('Quiz me on this topic'),
                            _buildSuggestionRow('What should I study today?'),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, idx) {
                        final msg = _messages[idx];
                        final isUser = msg['isUser'] == true;
                        final text = msg['text'] as String;
                        final source = msg['source'] as String?;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.78,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isUser ? AppColors.accent : AppColors.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: Radius.circular(isUser ? 14 : 2),
                                        bottomRight: Radius.circular(isUser ? 2 : 14),
                                      ),
                                      border: !isUser
                                          ? Border.all(color: AppColors.border, width: 1)
                                          : null,
                                    ),
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: isUser ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (source != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.link, size: 12, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          source,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Pinned Input Row at Bottom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Ask Sage...',
                          hintStyle: AppTypography.secondary,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.mic_none, color: AppColors.textPrimary, size: 22),
                    tooltip: 'Voice Input',
                    onPressed: () => context.push('/voice-tutor'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.accent, size: 22),
                    tooltip: 'Send',
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
