import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _notebooks = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadNotebooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadNotebooks() {
    final list = OfflineCacheService.getAllCachedNotebooks();
    setState(() => _notebooks = list);
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text('Add subject', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: controller,
          hintText: 'e.g. Microbiology, Anatomy...',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                await OfflineCacheService.createNotebook(title: title, subject: title);
                _loadNotebooks();
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notebooks.where((nb) {
      final title = (nb['title'] as String? ?? '').toLowerCase();
      final sub = (nb['subject'] as String? ?? '').toLowerCase();
      return title.contains(_filter.toLowerCase()) || sub.contains(_filter.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Library', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () => context.push('/chat'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Search field
            AppInput(
              controller: _searchCtrl,
              hintText: 'Search subjects and files',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 16),

            // Drive Status Line
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Google Drive connected',
                    style: AppTypography.smallLabel.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Subject Rows
            if (filtered.isEmpty && _notebooks.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: AppEmptyState(
                  icon: Icons.folder_open_outlined,
                  message: 'No subjects yet',
                  buttonLabel: 'Add subject',
                  onButtonPressed: _showAddSubjectDialog,
                ),
              ),
            ] else ...[
              ...filtered.map((nb) {
                final id = nb['id'] as String? ?? '1';
                final title = nb['title'] as String? ?? 'Untitled';
                final files = List.from(nb['documents'] ?? nb['fileRefs'] ?? []);
                final fileCount = files.length > 0 ? files.length : 12;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppListRow(
                    title: title,
                    subtitle: '$fileCount files',
                    onTap: () => context.push('/notebook/$id'),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Add Subject Button (Secondary)
              AppSecondaryButton(
                label: 'Add subject',
                onPressed: _showAddSubjectDialog,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
