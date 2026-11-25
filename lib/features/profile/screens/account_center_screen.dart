import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/cloud_vault_service.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/mega_vault_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../widgets/mega_connect_sheet.dart';

class AccountCenterScreen extends ConsumerStatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  ConsumerState<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends ConsumerState<AccountCenterScreen> {
  late String _userName;
  late String _userEmail;
  late List<String> _userSubjects;
  late String _learningStyle;
  late DateTime _targetExamDate;
  String _appVersion = '...';
  String _cacheSizeLabel = 'Calculating...';
  bool _isConnectingDrive = false;

  static const List<String> _learningStyles = [
    'Visual & Practice',
    'Auditory & Socratic',
    'Reading & Writing',
    'Active Recall Sprint',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadVersion();
    _computeLocalCacheSize();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.0');
    }
  }

  Future<void> _computeLocalCacheSize() async {
    try {
      int totalBytes = 0;
      final docsDir = await getApplicationDocumentsDirectory();
      if (await docsDir.exists()) {
        await for (final entity in docsDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
      if (!mounted) return;
      String label;
      if (totalBytes < 1024) {
        label = '$totalBytes B';
      } else if (totalBytes < 1024 * 1024) {
        label = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        label = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      setState(() => _cacheSizeLabel = label);
    } catch (_) {
      if (mounted) setState(() => _cacheSizeLabel = 'Local Hive storage');
    }
  }

  void _loadProfile() {
    final profile = OfflineCacheService.getUserProfile();
    setState(() {
      _userName = OfflineCacheService.getUserName();
      _userEmail = OfflineCacheService.getUserEmail();
      _userSubjects = OfflineCacheService.getUserSubjects();
      _learningStyle = profile['learningStyle'] ?? 'Visual & Practice';
      _targetExamDate = OfflineCacheService.getTargetExamDate();
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile', style: AppTypography.sectionHeading),
        content: AppInput(
          label: 'Display Name',
          controller: controller,
          hintText: 'Enter your name',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(92, 42)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await OfflineCacheService.saveUserProfile(
                  name: newName,
                  email: _userEmail,
                  subjects: _userSubjects,
                  learningStyle: _learningStyle,
                  targetExamDate: _targetExamDate,
                );
                _loadProfile();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLearningStylePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Learning Style', style: AppTypography.sectionHeading),
              const SizedBox(height: 12),
              ..._learningStyles.map((style) {
                final isSelected = _learningStyle == style;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListRow(
                    title: style,
                    trailing: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? context.accentColor : context.textSecondary,
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await OfflineCacheService.saveUserProfile(
                        name: _userName,
                        email: _userEmail,
                        subjects: _userSubjects,
                        learningStyle: style,
                        targetExamDate: _targetExamDate,
                      );
                      _loadProfile();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker(String currentTheme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance Theme', style: AppTypography.sectionHeading),
              const SizedBox(height: 12),
              ...['Light', 'System', 'Dark'].map((theme) {
                final isSelected = currentTheme == theme;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListRow(
                    title: theme,
                    subtitle: theme == 'Light'
                        ? 'Soft Ivory & Lavender (Recommended)'
                        : (theme == 'Dark' ? 'Quiet Twilight Obsidian' : 'Match device setting'),
                    trailing: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? context.accentColor : context.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(themeModeProvider.notifier).setTheme(theme);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectDrive() async {
    setState(() => _isConnectingDrive = true);
    final ok = await DriveService.instance.signIn();
    if (!mounted) return;
    setState(() => _isConnectingDrive = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Drive connected (${DriveService.instance.userEmail ?? 'Ready'}).')),
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
          'Your notes, quizzes, and decks will remain safely on this device. You can connect another Google Drive account anytime.',
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
        SnackBar(content: Text('Connected Google Drive (${DriveService.instance.userEmail ?? 'Ready'}).')),
      );
    } else {
      final err = DriveService.instance.lastError ?? 'Google Drive sign-in cancelled or failed.';
      if (!err.contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  void _showConfirmDeleteDialog({required bool deleteAll}) {
    final confirmationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          deleteAll ? 'Delete everything' : 'Remove from app',
          style: AppTypography.sectionHeading.copyWith(color: AppColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deleteAll
                  ? 'This will delete all local data AND your True Me folder in Google Drive. Type "DELETE" below to confirm.'
                  : 'This will reset local data on this phone. Your Google Drive files will remain safe.',
              style: AppTypography.bodySmall.copyWith(color: context.textSecondary),
            ),
            if (deleteAll) ...[
              const SizedBox(height: 12),
              AppInput(
                controller: confirmationController,
                hintText: 'Type DELETE',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(96, 42),
            ),
            onPressed: () async {
              if (deleteAll && confirmationController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type DELETE to confirm.')),
                );
                return;
              }
              if (deleteAll) {
                await SupabaseService.instance.deleteAllUserData(OfflineCacheService.getUserId());
                await CloudVaultService.deleteAllCloudVaults();
              }
              await OfflineCacheService.clearAllCache();
              await OfflineCacheService.logout();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.go('/login');
              }
            },
            child: Text(deleteAll ? 'Delete all' : 'Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final daysRemaining = OfflineCacheService.daysUntil(_targetExamDate);
    final driveConnected = DriveService.instance.isSignedIn || OfflineCacheService.isDriveConnected();
    final driveEmail = DriveService.instance.userEmail;
    final currentThemeMode = ref.watch(themeModeProvider);
    final selectedTheme = currentThemeMode == ThemeMode.dark
        ? 'Dark'
        : (currentThemeMode == ThemeMode.light ? 'Light' : 'System');

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                TrueMeTopBar(
                  title: 'Account',
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/today');
                    }
                  },
                  trailing: TrueMeCircleIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Theme Settings',
                    onPressed: () => _showThemePicker(selectedTheme),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Profile Hero Card with Botanical Lavender Foliage Accent
                      TrueMeEntrance(
                        delayMs: 30,
                        child: TrueMeCard(
                          borderRadius: 24,
                          padding: EdgeInsets.zero,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [const Color(0xFF1A1D2D), const Color(0xFF212239)]
                                : [Colors.white, const Color(0xFFF1EDFC)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(painter: BotanicalCornerPainter(isDark: isDark)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      TrueMeAvatar(name: _userName, size: 70, onTap: _showEditNameDialog),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _userName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.sectionHeading.copyWith(
                                                fontSize: 21,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _userEmail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                            ),
                                            const SizedBox(height: 10),
                                            TrueMeTonalPill(
                                              label: 'Edit Profile',
                                              icon: Icons.edit_outlined,
                                              backgroundColor: isDark
                                                  ? AppColors.darkAccentWash
                                                  : AppColors.milkyLavender,
                                              foregroundColor: context.textPrimary,
                                              onTap: _showEditNameDialog,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. Study Section
                      _SectionTitle(icon: Icons.school_rounded, title: 'Study'),
                      const SizedBox(height: 10),
                      TrueMeCard(
                        borderRadius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _AccountItemRow(
                              icon: Icons.calendar_today_rounded,
                              iconBg: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                              iconColor: context.accentColor,
                              title: 'Target Exam Deadline',
                              subtitle: _formatDate(_targetExamDate),
                              trailing: TrueMeTonalPill(
                                label: '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left',
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              ),
                              onTap: () async {
                                final now = DateTime.now();
                                final safeInitial = _targetExamDate.isAfter(now) ? _targetExamDate : now;
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: safeInitial,
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 730)),
                                );
                                if (picked != null) {
                                  await OfflineCacheService.saveTargetExamDate(picked);
                                  _loadProfile();
                                }
                              },
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.menu_book_rounded,
                              iconBg: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                              iconColor: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                              title: 'Active Subjects',
                              subtitle: _userSubjects.isNotEmpty
                                  ? _userSubjects.join(', ')
                                  : 'No subjects added yet',
                              onTap: () async {
                                await context.push('/setup-profile');
                                if (mounted) _loadProfile();
                              },
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.psychology_rounded,
                              iconBg: isDark ? const Color(0xFF241938) : AppColors.pastelLavender,
                              iconColor: isDark ? const Color(0xFFC4B5FD) : AppColors.pastelLavenderInk,
                              title: 'Learning Style',
                              subtitle: _learningStyle,
                              onTap: _showLearningStylePicker,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 3. Storage Section (MEGA 20 GB Primary + Google Drive Optional)
                      _SectionTitle(icon: Icons.cloud_rounded, title: 'Storage'),
                      const SizedBox(height: 10),
                      TrueMeCard(
                        borderRadius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _AccountItemRow(
                              icon: Icons.cloud_done_rounded,
                              iconBg: MegaVaultService.instance.isSignedIn
                                  ? (isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen)
                                  : (isDark ? AppColors.darkAccentWash : AppColors.accentWash),
                              iconColor: MegaVaultService.instance.isSignedIn
                                  ? AppColors.success
                                  : context.accentColor,
                              title: 'MEGA 20 GB Vault',
                              subtitle: MegaVaultService.instance.isSignedIn
                                  ? (MegaVaultService.instance.userEmail ?? 'Connected (20 GB Free)')
                                  : 'Free 20 GB personal file backup (Recommended)',
                              trailing: TrueMeTonalPill(
                                label: MegaVaultService.instance.isSignedIn ? 'Manage' : 'Connect',
                                onTap: () async {
                                  final changed = await MegaConnectSheet.show(context);
                                  if (changed && mounted) setState(() {});
                                },
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onTap: () async {
                                final changed = await MegaConnectSheet.show(context);
                                if (changed && mounted) setState(() {});
                              },
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.add_to_drive_rounded,
                              iconBg: driveConnected
                                  ? (isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen)
                                  : (isDark ? AppColors.darkAccentWash : AppColors.accentWash),
                              iconColor: driveConnected ? AppColors.success : context.accentColor,
                              title: 'Google Drive',
                              subtitle: driveConnected
                                  ? (driveEmail ?? 'Connected')
                                  : 'Local storage only (offline)',
                              trailing: _isConnectingDrive
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : (driveConnected
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TrueMeTonalPill(
                                              label: 'Disconnect',
                                              onTap: _disconnectDrive,
                                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert, size: 18, color: context.textSecondary),
                                              onSelected: (val) {
                                                if (val == 'switch') _switchDriveAccount();
                                                if (val == 'disconnect') _disconnectDrive();
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(value: 'switch', child: Text('Switch Account')),
                                                PopupMenuItem(
                                                  value: 'disconnect',
                                                  child: Text('Disconnect', style: TextStyle(color: AppColors.error)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : TrueMeTonalPill(
                                          label: 'Connect',
                                          onTap: _connectDrive,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        )),
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.folder_rounded,
                              iconBg: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                              iconColor: context.accentColor,
                              title: 'True Me Drive Folder',
                              subtitle: '/True Me',
                              onTap: driveConnected ? null : _connectDrive,
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.delete_sweep_rounded,
                              iconBg: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                              iconColor: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                              title: 'Clear Local Cache',
                              subtitle: _cacheSizeLabel,
                              trailing: TrueMeTonalPill(
                                label: 'Clear',
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear Local Cache?'),
                                      content: const Text(
                                        'This will remove cached quizzes, offline flashcards, notes, and study logs from this device. Are you sure?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                          child: const Text('Clear Cache'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await OfflineCacheService.clearAllCache();
                                    _computeLocalCacheSize();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Local cache cleared successfully.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 4. App Section
                      _SectionTitle(icon: Icons.palette_rounded, title: 'App'),
                      const SizedBox(height: 10),
                      TrueMeCard(
                        borderRadius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _AccountItemRow(
                              icon: Icons.contrast_rounded,
                              iconBg: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                              iconColor: context.accentColor,
                              title: 'Theme',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    selectedTheme,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
                                ],
                              ),
                              onTap: () => _showThemePicker(selectedTheme),
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.refresh_rounded,
                              iconBg: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                              iconColor: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                              title: 'Check for Updates',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _appVersion,
                                    style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
                                ],
                              ),
                              onTap: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checking GitHub Releases for updates...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                final info = await UpdateService().checkForUpdate(force: true);
                                if (!mounted) return;
                                if (info != null && info.hasUpdate) {
                                  UpdateService.showUpdateDialog(context: context, info: info);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('True Me is up to date ($_appVersion)')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 5. Data Section
                      _SectionTitle(icon: Icons.storage_rounded, title: 'Data'),
                      const SizedBox(height: 10),
                      TrueMeCard(
                        borderRadius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _AccountItemRow(
                              icon: Icons.delete_outline_rounded,
                              iconBg: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                              iconColor: AppColors.error,
                              title: 'Remove from App',
                              titleColor: AppColors.error,
                              onTap: () => _showConfirmDeleteDialog(deleteAll: false),
                            ),
                            Divider(height: 1, color: context.borderColor),
                            _AccountItemRow(
                              icon: Icons.warning_amber_rounded,
                              iconBg: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                              iconColor: AppColors.error,
                              title: 'Delete Everything',
                              titleColor: AppColors.error,
                              onTap: () => _showConfirmDeleteDialog(deleteAll: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 6. Sign Out Button Card
                      TrueMeCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign Out?'),
                              content: const Text('Are you sure you want to sign out of True Me?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await OfflineCacheService.logout();
                            if (mounted) {
                              context.go('/login');
                            }
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 19, color: AppColors.error),
                            SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: context.textPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
        ),
      ],
    );
  }
}

class _AccountItemRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AccountItemRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? context.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}
