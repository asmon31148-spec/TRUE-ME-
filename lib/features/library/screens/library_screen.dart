import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: err));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Details copied to clipboard')),
                  );
                },
                child: const Text('Copy Details'),
              ),
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

  Future<void> _disconnectDrive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ctx.borderColor),
        ),
        title: const Text('Disconnect Google Drive?', style: AppTypography.sectionHeading),
        content: const Text(
          'Your notes and subjects will remain safely stored on this device. You can connect a different Google Drive account at any time.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isConnectingDrive = true);
    await DriveService.instance.disconnect();
    if (!mounted) return;
    setState(() => _isConnectingDrive = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Drive disconnected.')),
    );
  }

  Future<void> _switchDriveAccount() async {
    setState(() => _isConnectingDrive = true);
    await DriveService.instance.disconnect();
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
      if (!err.contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  void _showDriveAccountSheet() {
    final email = DriveService.instance.userEmail ?? 'Connected';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, color: AppColors.success, size: 24),
                  const SizedBox(width: 10),
                  const Text('Google Drive Vault', style: AppTypography.sectionHeading),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ctx.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Account', style: AppTypography.smallLabel.copyWith(color: ctx.textSecondary)),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Target folder: Google Drive / True Me', style: AppTypography.secondary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: ctx.accentTint, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.switch_account_outlined, color: ctx.accentColor, size: 20),
                ),
                title: const Text('Switch Google Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Pick another Google Drive account to sync notes', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _switchDriveAccount();
                },
              ),
              Divider(color: ctx.borderColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.link_off, color: AppColors.error, size: 20),
                ),
                title: const Text('Disconnect Drive', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Unlinks this account; local files stay on your phone', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _disconnectDrive();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
              onTap: _isConnectingDrive ? null : (driveConnected ? _showDriveAccountSheet : _connectDrive),
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
                                ? 'Google Drive (${DriveService.instance.userEmail ?? 'True Me'}) • Tap to manage'
                                : 'Saved on device • Tap to connect Google Drive'),
                        style: AppTypography.smallLabel.copyWith(
                          color: driveConnected ? AppColors.success : context.textSecondary,
                        ),
                      ),
                    ),
                    if (driveConnected) ...[
                      Icon(Icons.more_horiz, size: 16, color: context.textSecondary),
                    ],
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
