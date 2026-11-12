import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../providers/chat_provider.dart';
import '../widgets/sage_chat_view.dart';

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
              if (val == 'clear') {
                ref.read(chatProvider(_scopeKey).notifier).clearHistory();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SageChatView(
          key: ValueKey(_scopeKey),
          notebookId: widget.notebookId,
          subject: _activeSubject,
          initialPrompt: widget.initialPrompt,
        ),
      ),
    );
  }
}
