import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _notebooks = [];
  List<Map<String, dynamic>> _recentItems = [];
  String _filter = '';
  String _sortBy = 'Recent'; // 'Recent', 'A-Z', 'Files'
  bool _isGridMode = true;
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
    final notes = OfflineCacheService.getAllCachedNotes();

    final items = <Map<String, dynamic>>[];
    for (final nb in list) {
      final nbId = nb['id'] as String? ?? '';
      final nbTitle = nb['title'] as String? ?? 'Subject';
      final docs = (nb['documents'] as List? ?? []);
      for (final d in docs) {
        final docMap = Map<String, dynamic>.from(d as Map);
        items.add({
          'kind': 'doc',
          'notebookId': nbId,
          'subject': nbTitle,
          'title': docMap['fileName'] as String? ?? 'Document',
          'section': docMap['section'] as String? ?? 'Notes',
          'timestamp': docMap['createdAt'] as String? ?? '',
        });
      }
    }

    for (final n in notes) {
      items.add({
        'kind': 'note',
        'noteId': n['id'] as String?,
        'notebookId': n['notebookId'] as String?,
        'subject': 'Quick Note',
        'title': n['title'] as String? ?? 'Untitled Note',
        'content': n['content'] as String? ?? '',
        'section': 'Notes',
        'timestamp': n['updatedAt'] as String? ?? '',
      });
    }

    items.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));

    if (mounted) {
      setState(() {
        _notebooks = list;
        _recentItems = items;
      });
    }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: AppColors.success, size: 24),
                  SizedBox(width: 10),
                  Text('Google Drive Vault', style: AppTypography.sectionHeading),
                ],
              ),
              const SizedBox(height: 14),
              TrueMeCard(
                borderRadius: 14,
                padding: const EdgeInsets.all(14),
                showShadow: false,
                color: ctx.bgColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Account', style: AppTypography.smallLabel.copyWith(color: ctx.textSecondary)),
                    const SizedBox(height: 3),
                    Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Target folder: Google Drive / True Me', style: AppTypography.secondary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppIconBadge(icon: Icons.switch_account_outlined, color: ctx.accentColor),
                title: const Text('Switch Google Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Pick another Google Drive account to sync notes', style: TextStyle(fontSize: 12.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _switchDriveAccount();
                },
              ),
              Divider(color: ctx.borderColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppIconBadge(
                  icon: Icons.link_off,
                  color: AppColors.error,
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                ),
                title: const Text('Disconnect Drive', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Unlinks this account; local files stay on your phone', style: TextStyle(fontSize: 12.5)),
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
            style: ElevatedButton.styleFrom(minimumSize: const Size(92, 42)),
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
        title: const Text('Rename subject', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: controller,
          autofocus: true,
          hintText: 'Subject name',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(92, 42)),
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

  String _relativeDateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _buildSubjectSubtitle(List docs) {
    final fileCount = docs.length;
    if (fileCount == 0) return '0 resources';
    return '$fileCount ${fileCount == 1 ? 'resource' : 'resources'}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
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
      filtered.sort((a, b) => (a['title'] as String? ?? '')
          .toLowerCase()
          .compareTo((b['title'] as String? ?? '').toLowerCase()));
    } else if (_sortBy == 'Files') {
      filtered.sort((a, b) =>
          ((b['documents'] as List? ?? []).length).compareTo((a['documents'] as List? ?? []).length));
    }

    final visibleRecent = _filter.isEmpty
        ? _recentItems
        : _recentItems.where((r) {
            final t = (r['title'] as String? ?? '').toLowerCase();
            final s = (r['subject'] as String? ?? '').toLowerCase();
            return t.contains(_filter.toLowerCase()) || s.contains(_filter.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.accentColor,
            onRefresh: () async {
              await OfflineCacheService.syncFromCloud();
              if (mounted) _loadNotebooks();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
              children: [
                // 1. Editorial Serif Header + Subtitle + Drive/Add Controls
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: AppTypography.editorialHero.copyWith(
                              fontSize: 29,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your Knowledge Hub',
                            style: AppTypography.secondary.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TrueMeCircleIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Add subject',
                      onPressed: _showAddSubjectDialog,
                    ),
                    const SizedBox(width: 8),
                    TrueMeCircleIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Drive & Account',
                      onPressed: _isConnectingDrive
                          ? () {}
                          : (driveConnected ? _showDriveAccountSheet : _connectDrive),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Pill Search Bar + View Toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: context.borderColor),
                          boxShadow: context.cardShadow,
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _filter = val),
                          style: TextStyle(fontSize: 14.5, color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search notes, subjects...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textSecondary),
                            suffixIcon: _filter.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded, size: 18, color: context.textSecondary),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _filter = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TrueMeCircleIconButton(
                      icon: _isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      tooltip: _isGridMode ? 'List view' : 'Grid view',
                      size: 46,
                      onPressed: () => setState(() => _isGridMode = !_isGridMode),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Sort Filter Chips + Drive Pill
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppChip(
                        label: 'Recent',
                        isSelected: _sortBy == 'Recent',
                        onTap: () => setState(() => _sortBy = 'Recent'),
                      ),
                      const SizedBox(width: 8),
                      AppChip(
                        label: 'A – Z',
                        isSelected: _sortBy == 'A-Z',
                        onTap: () => setState(() => _sortBy = 'A-Z'),
                      ),
                      const SizedBox(width: 8),
                      AppChip(
                        label: 'Most Files',
                        isSelected: _sortBy == 'Files',
                        onTap: () => setState(() => _sortBy = 'Files'),
                      ),
                      const SizedBox(width: 8),
                      TrueMeTonalPill(
                        label: _isConnectingDrive
                            ? 'Connecting...'
                            : (driveConnected ? 'Drive Connected' : 'Connect Drive'),
                        icon: driveConnected ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined,
                        backgroundColor: driveConnected
                            ? (isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen)
                            : context.surfaceColor,
                        foregroundColor: driveConnected
                            ? (isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk)
                            : context.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onTap: _isConnectingDrive
                            ? null
                            : (driveConnected ? _showDriveAccountSheet : _connectDrive),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Subject Cards Grid / List or Empty State
                if (_notebooks.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: AppEmptyState(
                      icon: Icons.folder_open_outlined,
                      message: 'No subjects yet. Add your first subject and upload notes or PDFs to get started.',
                      buttonLabel: 'Add subject',
                      onButtonPressed: _showAddSubjectDialog,
                    ),
                  ),
                ] else if (filtered.isEmpty) ...[
                  TrueMeCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No subjects or files match your search.',
                        style: AppTypography.secondary.copyWith(color: context.textSecondary),
                      ),
                    ),
                  ),
                ] else ...[
                  if (_isGridMode)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.96,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final nb = filtered[idx];
                        final id = nb['id'] as String? ?? '';
                        final title = nb['title'] as String? ?? 'Untitled';
                        final docs = List.from(nb['documents'] ?? []);
                        final pastel = SubjectPastelStyle.forSubject(title, isDark: isDark);

                        return TrueMeCard(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(14),
                          gradient: pastel.gradient,
                          borderColor: pastel.border,
                          onTap: () async {
                            await context.push('/notebook/$id');
                            if (mounted) _loadNotebooks();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: context.surfaceColor.withValues(alpha: isDark ? 0.25 : 0.80),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(pastel.icon, size: 26, color: pastel.accent),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.more_horiz_rounded, size: 20, color: pastel.accent),
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
                                ],
                              ),
                              const Spacer(),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cardTitle.copyWith(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _buildSubjectSubtitle(docs),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.smallLabel.copyWith(
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    ...filtered.map((nb) {
                      final id = nb['id'] as String? ?? '';
                      final title = nb['title'] as String? ?? 'Untitled';
                      final docs = List.from(nb['documents'] ?? []);
                      final pastel = SubjectPastelStyle.forSubject(title, isDark: isDark);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppListRow(
                          leading: AppIconBadge(
                            icon: pastel.icon,
                            color: pastel.accent,
                            backgroundColor: pastel.bgEnd,
                          ),
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
                              Icon(Icons.chevron_right_rounded, size: 18, color: context.textSecondary),
                            ],
                          ),
                          onTap: () async {
                            await context.push('/notebook/$id');
                            if (mounted) _loadNotebooks();
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  AppSecondaryButton(
                    label: 'Add New Subject',
                    icon: const Icon(Icons.add_rounded, size: 20),
                    height: 48,
                    onPressed: _showAddSubjectDialog,
                  ),
                ],

                // 5. Recent Items Section (from real uploaded documents & notes)
                if (visibleRecent.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  TrueMeSectionHeader(
                    title: 'Recent Items',
                    actionLabel: 'New Note',
                    onActionTap: () async {
                      await context.push('/note-editor');
                      if (mounted) _loadNotebooks();
                    },
                  ),
                  const SizedBox(height: 12),
                  ...visibleRecent.take(5).map((item) {
                    final isNote = item['kind'] == 'note';
                    final title = item['title'] as String? ?? 'Document';
                    final subject = item['subject'] as String? ?? 'Notes';
                    final section = item['section'] as String? ?? 'Notes';
                    final ago = _relativeDateLabel(item['timestamp'] as String?);
                    final meta = [subject, section, if (ago.isNotEmpty) ago].join(' · ');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppListRow(
                        leading: AppIconBadge(
                          icon: isNote ? Icons.edit_note_rounded : Icons.description_outlined,
                          color: isNote ? AppColors.pastelGreenInk : context.accentColor,
                          backgroundColor: isNote
                              ? (isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen)
                              : (isDark ? AppColors.darkAccentWash : AppColors.accentWash),
                        ),
                        title: title,
                        subtitle: meta,
                        onTap: () async {
                          if (isNote) {
                            final qTitle = Uri.encodeComponent(title);
                            final qContent = Uri.encodeComponent(item['content'] as String? ?? '');
                            final qId = Uri.encodeComponent(item['noteId'] as String? ?? '');
                            final qNb = Uri.encodeComponent(item['notebookId'] as String? ?? '');
                            await context.push('/note-editor?noteId=$qId&notebookId=$qNb&title=$qTitle&content=$qContent');
                          } else {
                            final nbId = item['notebookId'] as String? ?? '';
                            if (nbId.isNotEmpty) {
                              await context.push('/notebook/$nbId');
                            }
                          }
                          if (mounted) _loadNotebooks();
                        },
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
