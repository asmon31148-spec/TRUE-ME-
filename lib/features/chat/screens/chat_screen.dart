import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/ai_thinking_indicator.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSageThinking = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          "Hello Alex! I am Sage. I have indexed your notebooks using 768-dim embeddings. Ask me anything about your lecture slides, notes, or equations!",
      'citation': null,
    },
    {
      'isUser': true,
      'text':
          "How does Banker's Algorithm avoid deadlocks in Operating Systems?",
      'citation': null,
    },
    {
      'isUser': false,
      'text':
          "The Banker's Algorithm avoids deadlocks by simulating the allocation of predetermined maximum possible amounts of all resources, then testing for a 'safe state'. If an allocation leaves the system in an unsafe state (where a deadlock could occur if processes request their max claim), the request is denied or delayed.\n\nKey vectors tracked:\n• Available[m]: number of available instances of resource m\n• Max[n,m]: max claim of process n\n• Allocation[n,m]: resources currently allocated\n• Need[n,m]: remaining resource claim (Max - Allocation)",
      'citation': 'Chapter 3 — Process Synchronization & Mutexes.pdf (Page 24)',
    },
  ];

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text, 'citation': null});
      _isSageThinking = true;
      _textController.clear();
    });

    // Simulate Sage RAG response
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isSageThinking = false;
          _messages.add({
            'isUser': false,
            'text':
                "Based on your notes on this topic, remember that a safe state is not deadlocked, but not all unsafe states are deadlocks! An unsafe state merely has the vulnerability to deadlock if processes hit their max demand simultaneously.",
            'citation': 'Lecture 7 — Deadlock Prevention & Bankers Algorithm.m4a (Timestamp 18:42)',
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Sage AI Study Chat',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                final bool isUser = msg['isUser'];

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
                          margin: const EdgeInsets.only(right: 10),
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
                              ? AppColors.primary.withOpacity(0.28)
                              : Colors.white.withOpacity(0.06),
                          borderGradient: isUser
                              ? const LinearGradient(
                                  colors: [Color(0x99818CF8), Color(0x336366F1)],
                                )
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text'],
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                              if (msg['citation'] != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.accentCyan.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.library_books,
                                        size: 12,
                                        color: AppColors.accentCyan,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          msg['citation'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.accentCyan,
                                          ),
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
                    ],
                  ),
                );
              },
            ),
          ),

          if (_isSageThinking) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AiThinkingIndicator(),
            ),
          ],

          // Input Bar with Glassmorphism
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.85),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.accentCyan),
                    onPressed: () => context.go('/voice-tutor'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask Sage about your notes...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
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
          ),
        ],
      ),
    );
  }
}
