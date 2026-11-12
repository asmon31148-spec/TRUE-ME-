import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
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
  String _sortBy = 'Recent'; // 'Recent', 'A-Z', 'Files'
  bool _isConnectingDrive = false;

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

  Future<void> _connectDrive() async {
    setState(() => _isConnectingDrive = true);
    final ok = await DriveService.instance.signIn();
    if (!mounted) return;
    setState(() => _isConnectingDrive = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected Google Drive (${DriveService.instance.userEmail ?? 'Ready'})'),
        ),
      );
    } else {
      final err = DriveService.instance.lastError ?? 'Google Drive sign-in cancelled or failed.';
      if (err.contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ctx.borderColor),
            ),
            title: const Text('Google Drive Connection Error', style: AppTypography.sectionHeading),
            content: SelectableText(err, style: AppTypography.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ctx.borderColor, width: 1),
        ),
        title: const Text('Add subject', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: controller,
          autofocus: true,
          hintText: 'e.g. Biology, Linear Algebra, Physics...',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                await OfflineCacheService.createNotebook(title: title, subject: title);
                _loadNotebooks();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRenameSubjectDialog(String notebookId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ctx.borderColor, width: 1),
        ),
        title: const Text('Rename subject', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: controller,
          autofocus: true,
          hintText: 'Subject name',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                await OfflineCacheService.renameNotebook(notebookId, title);
                _loadNotebooks();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _buildSubjectSubtitle(List docs) {
    final fileCount = docs.length;
    if (fileCount == 0) return 'No files yet • Tap to add sources';
    final sections = docs
        .map((d) => ((d as Map)['section'] as String? ?? 'Notes'))
        .toSet()
        .toList();
    final secLabel = sections.take(3).join(', ');
    return '$fileCount ${fileCount == 1 ? 'file' : 'files'} • $secLabel';
  }

  @override
  Widget build(BuildContext context) {
    final driveConnected = DriveService.instance.isSignedIn || OfflineCacheService.isDriveConnected();
    final filtered = _notebooks.where((nb) {
      final title = (nb['title'] as String? ?? '').toLowerCase();
      final sub = (nb['subject'] as String? ?? '').toLowerCase();
      final docs = (nb['documents'] as List? ?? []);
      final docMatch = docs.any((d) =>
          ((d as Map)['fileName'] as String? ?? '').toLowerCase().contains(_filter.toLowerCase()));
      return title.contains(_filter.toLowerCase()) ||
          sub.contains(_filter.toLowerCase()) ||
          docMatch;
    }).toList();

    if (_sortBy == 'A-Z') {
      filtered.sort((a, b) => (a['title'] as String? ?? '').toLowerCase().compareTo((b['title'] as String? ?? '').toLowerCase()));
    } else if (_sortBy == 'Files') {
      filtered.sort((a, b) => ((b['documents'] as List? ?? []).length).compareTo((a['documents'] as List? ?? []).length));
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Library', style: AppTypography.screenTitle),
        actions: [
          if (_notebooks.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, size: 22),
              tooltip: 'Sort subjects',
              onSelected: (val) => setState(() => _sortBy = val),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'Recent', child: Text(_sortBy == 'Recent' ? '✓ Recent' : 'Recent')),
                PopupMenuItem(value: 'A-Z', child: Text(_sortBy == 'A-Z' ? '✓ A–Z' : 'A–Z')),
                PopupMenuItem(value: 'Files', child: Text(_sortBy == 'Files' ? '✓ Most files' : 'Most files')),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () => context.push('/chat'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.accentColor,
          onRefresh: () async {
            await OfflineCacheService.syncFromCloud();
            if (mounted) _loadNotebooks();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
            // Search field
            AppInput(
              controller: _searchCtrl,
              hintText: 'Search subjects and uploaded files',
              prefixIcon: Icon(Icons.search, size: 20, color: context.textSecondary),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 14),

            // Drive Status Line
            InkWell(
              onTap: driveConnected || _isConnectingDrive ? null : _connectDrive,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      driveConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 16,
                      color: driveConnected ? AppColors.success : context.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isConnectingDrive
                            ? 'Connecting to Google Drive...'
                            : (driveConnected
                                ? 'Google Drive connected (${DriveService.instance.userEmail ?? 'True Me'})'
                                : 'Saved on device • Tap to connect Google Drive'),
                        style: AppTypography.smallLabel.copyWith(
                          color: driveConnected ? AppColors.success : context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Subject Rows
            if (_notebooks.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: AppEmptyState(
                  icon: Icons.folder_open_outlined,
                  message: 'No subjects yet. Add your first subject and upload syllabus or notes to get started.',
                  buttonLabel: 'Add subject',
                  onButtonPressed: _showAddSubjectDialog,
                ),
              ),
            ] else if (filtered.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No subjects or files match your search.', style: AppTypography.secondary),
                ),
              ),
            ] else ...[
              ...filtered.map((nb) {
                final id = nb['id'] as String? ?? '';
                final title = nb['title'] as String? ?? 'Untitled';
                final docs = List.from(nb['documents'] ?? []);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppListRow(
                    leading: const AppIconBadge(icon: Icons.folder_outlined),
                    title: title,
                    subtitle: _buildSubjectSubtitle(docs),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, size: 20, color: context.textSecondary),
                          onSelected: (val) async {
                            if (val == 'rename') {
                              _showRenameSubjectDialog(id, title);
                            } else if (val == 'delete') {
                              await OfflineCacheService.deleteNotebook(id);
                              _loadNotebooks();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete subject', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right, size: 18, color: context.textSecondary),
                      ],
                    ),
                    onTap: () async {
                      await context.push('/notebook/$id');
                      if (mounted) _loadNotebooks();
                    },
                  ),
                );
              }),
              const SizedBox(height: 12),

              AppSecondaryButton(
                label: 'Add subject',
                icon: const Icon(Icons.add, size: 20),
                onPressed: _showAddSubjectDialog,
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }
}
