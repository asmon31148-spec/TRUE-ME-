import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/stt_service.dart';
import '../../../shared/widgets/ai_thinking_indicator.dart';
import '../providers/chat_provider.dart';

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
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  SttService? _sttService;
  bool _isListening = false;
  String? _activeSubject;

  @override
  void initState() {
    super.initState();
    _activeSubject = widget.subject;
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
    await ref.read(chatProvider.notifier).sendMessage(
          question: text,
          userId: 'current_user',
          notebookId: widget.notebookId,
          subject: _activeSubject,
          studentName: OfflineCacheService.getUserName(),
        );
    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    _sttService ??= SttService();
    if (_isListening) {
      await _sttService!.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      try {
        await _sttService!.startListening(
          onResult: (text) {
            if (mounted) {
              setState(() {
                _textCtrl.text = text;
              });
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
          _scrollCtrl.position.maxScrollExtent + 100,
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final subjects = OfflineCacheService.getUserSubjects();
    final scope = _activeSubject?.isNotEmpty == true
        ? _activeSubject!
        : (subjects.isNotEmpty ? 'All subjects (${subjects.length})' : 'General study');

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/today');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sage', style: AppTypography.sectionHeading),
            Text(scope, style: AppTypography.smallLabel),
          ],
        ),
        actions: [
          if (subjects.isNotEmpty && widget.notebookId == null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list, size: 22),
              tooltip: 'Switch subject focus',
              onSelected: (val) {
                setState(() {
                  _activeSubject = val == '__ALL__' ? null : val;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: '__ALL__', child: Text('All subjects')),
                ...subjects.map((s) => PopupMenuItem(value: s, child: Text(s))),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (val) {
              if (val == 'clear') ref.read(chatProvider.notifier).clearHistory();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty && !chatState.isThinking
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeSubject != null
                                  ? 'Ask Sage about $_activeSubject'
                                  : 'Ask Sage anything',
                              style: AppTypography.sectionHeading,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sage reads your uploaded syllabus and notes when answering.',
                              style: AppTypography.secondary,
                            ),
                            const SizedBox(height: 16),
                            _buildSuggestionRow(
                              _activeSubject != null
                                  ? 'Summarize key concepts in $_activeSubject'
                                  : 'Help me build a study strategy for my exams',
                            ),
                            _buildSuggestionRow('Explain a difficult concept step by step'),
                            _buildSuggestionRow('Give me 3 practice questions with explanations'),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: chatState.messages.length + (chatState.isThinking ? 1 : 0),
                      itemBuilder: (context, idx) {
                        if (idx == chatState.messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: AiThinkingIndicator(label: 'Sage is thinking...'),
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
                                maxWidth: MediaQuery.of(context).size.width * 0.82,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: msg.isUser ? context.accentColor : context.surfaceColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: msg.isUser
                                          ? null
                                          : Border.all(color: context.borderColor, width: 1),
                                    ),
                                    child: SelectableText(
                                      msg.text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: msg.isUser ? Colors.white : context.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!msg.isUser && msg.citation != null) ...[
                                        Text(
                                          msg.citation!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.accentColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Text(' • ', style: AppTypography.smallLabel),
                                      ],
                                      Text(_formatTime(msg.timestamp), style: AppTypography.smallLabel),
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

            // Pinned Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.bgColor,
                border: Border(top: BorderSide(color: context.borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(color: context.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Ask Sage...',
                        hintStyle: TextStyle(color: context.textSecondary),
                        filled: true,
                        fillColor: context.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.borderColor, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.borderColor, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.accentColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_outlined,
                      size: 22,
                      color: _isListening ? AppColors.error : context.textSecondary,
                    ),
                    tooltip: 'Voice input',
                    onPressed: _toggleVoiceInput,
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, size: 22, color: context.accentColor),
                    onPressed: chatState.isThinking ? null : () => _sendMessage(),
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
                  style: TextStyle(fontSize: 15, color: context.textPrimary),
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
