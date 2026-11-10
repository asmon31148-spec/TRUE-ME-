import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/app_components.dart';

class AccountCenterScreen extends StatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  State<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends State<AccountCenterScreen> {
  late String _userName;
  late String _userEmail;
  late List<String> _userSubjects;
  late String _learningStyle;
  late DateTime _targetExamDate;
  late String _selectedTheme;
  String _appVersion = '...';
  bool _isConnectingDrive = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadVersion();
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

  void _loadProfile() {
    final profile = OfflineCacheService.getUserProfile();
    setState(() {
      _userName = OfflineCacheService.getUserName();
      _userEmail = OfflineCacheService.getUserEmail();
      _userSubjects = OfflineCacheService.getUserSubjects();
      _learningStyle = profile['learningStyle'] ?? 'Visual & Practice';
      _targetExamDate = OfflineCacheService.getTargetExamDate();
      _selectedTheme = OfflineCacheService.getThemeMode();
    });
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Edit name', style: AppTypography.sectionHeading),
        content: AppInput(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
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

  Future<void> _connectDrive() async {
    setState(() => _isConnectingDrive = true);
    final ok = await DriveService.instance.signIn();
    if (!mounted) return;
    setState(() => _isConnectingDrive = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Google Drive connected.' : 'Google Drive sign-in cancelled or failed.'),
      ),
    );
  }

  void _showConfirmDeleteDialog({required bool deleteAll}) {
    final confirmationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
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
              style: AppTypography.bodySmall,
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
              minimumSize: const Size(90, 40),
            ),
            onPressed: () async {
              if (deleteAll && confirmationController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type DELETE to confirm.')),
                );
                return;
              }
              if (deleteAll) {
                await DriveService.instance.deleteVaultFolder();
                await DriveService.instance.signOut();
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
    final daysRemaining = _targetExamDate.difference(DateTime.now()).inDays.clamp(0, 999);
    final driveConnected = DriveService.instance.isSignedIn || OfflineCacheService.isDriveConnected();
    final driveEmail = DriveService.instance.userEmail;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account', style: AppTypography.screenTitle),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/today');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            const Text('Profile', style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: _userName,
                    subtitle: 'Name',
                    trailing: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                    onTap: _showEditNameDialog,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: _userEmail,
                    subtitle: 'Email',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Study Section
            const Text('Study', style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: '${_targetExamDate.day}/${_targetExamDate.month}/${_targetExamDate.year}',
                    subtitle: 'Target exam deadline ($daysRemaining days left)',
                    trailing: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetExamDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        await OfflineCacheService.saveTargetExamDate(picked);
                        _loadProfile();
                      }
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: _userSubjects.isNotEmpty ? _userSubjects.join(', ') : 'No subjects added yet',
                    subtitle: 'Active subjects (${_userSubjects.length})',
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                    onTap: () => context.push('/setup-profile'),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: _learningStyle,
                    subtitle: 'Learning style',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Storage Section
            const Text('Storage', style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: driveConnected ? 'Connected' : 'Not connected',
                    subtitle: driveConnected
                        ? (driveEmail != null ? 'Google Drive ($driveEmail)' : 'Google Drive linked')
                        : 'Files are currently stored only on this phone',
                    trailing: _isConnectingDrive
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: _connectDrive,
                            child: Text(
                              driveConnected ? 'Reconnect' : 'Connect',
                              style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const AppListRow(
                    title: 'True Me',
                    subtitle: 'Google Drive folder location',
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: 'Clear local cache',
                    subtitle: 'Clears locally stored quizzes, cards, and study logs',
                    trailing: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                    onTap: () async {
                      await OfflineCacheService.clearAllCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Local cache cleared successfully.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Section
            const Text('App', style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: _selectedTheme,
                    subtitle: 'Theme',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['System', 'Light', 'Dark'].map((theme) {
                        final isSelected = _selectedTheme == theme;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            onTap: () async {
                              await OfflineCacheService.saveThemeMode(theme);
                              setState(() => _selectedTheme = theme);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                ),
                              ),
                              child: Text(
                                theme,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: 'Check for updates',
                    subtitle: 'Installed version: $_appVersion',
                    trailing: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
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
                          SnackBar(
                            content: Text('True Me is up to date ($_appVersion)'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Section
            const Text('Data', style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: 'Remove from app',
                    subtitle: 'Clears local data, leaves Drive files intact',
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                    onTap: () => _showConfirmDeleteDialog(deleteAll: false),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: 'Delete everything',
                    subtitle: 'Permanently deletes Drive files and local data',
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.error),
                    onTap: () => _showConfirmDeleteDialog(deleteAll: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out
            Center(
              child: TextButton(
                onPressed: () async {
                  await OfflineCacheService.logout();
                  if (mounted) {
                    context.go('/login');
                  }
                },
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
