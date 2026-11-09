import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
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
  String _selectedTheme = 'Light';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final profile = OfflineCacheService.getUserProfile();
    setState(() {
      _userName = (profile['name'] as String?)?.trim().isNotEmpty == true
          ? profile['name']
          : 'Asmon';
      _userEmail = profile['email'] ?? 'asmon@trueme.ai';
      _userSubjects = List<String>.from(
        profile['subjects'] ?? ['Microbiology', 'Biochemistry', 'Immunology'],
      );
      _learningStyle = profile['learningStyle'] ?? 'Visual (Diagrams & Notes)';
      _targetExamDate = OfflineCacheService.getTargetExamDate();
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
          AppSecondaryButton(
            label: 'Cancel',
            height: 40,
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          AppPrimaryButton(
            label: 'Save',
            height: 40,
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
                setState(() => _userName = newName);
              }
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
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
                  ? 'This will delete all local data AND files in Google Drive. Type "DELETE" below to confirm.'
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
          AppSecondaryButton(
            label: 'Cancel',
            height: 40,
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          AppPrimaryButton(
            label: deleteAll ? 'Delete all' : 'Remove',
            height: 40,
            backgroundColor: AppColors.error,
            onPressed: () async {
              if (deleteAll && confirmationController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type DELETE to confirm.')),
                );
                return;
              }
              await OfflineCacheService.clearAllCache();
              await OfflineCacheService.logout();
              if (mounted) {
                Navigator.pop(ctx);
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = _targetExamDate.difference(DateTime.now()).inDays;

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
                        setState(() => _targetExamDate = picked);
                      }
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: _userSubjects.join(', '),
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
                    title: 'Connected',
                    subtitle: 'Google Drive status',
                    trailing: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Google Drive is synced.')),
                        );
                      },
                      child: const Text('Reconnect', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const AppListRow(
                    title: 'True Me',
                    subtitle: 'Folder location',
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  AppListRow(
                    title: 'Clear local cache',
                    subtitle: 'Frees temporary files stored on phone',
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
                            onTap: () => setState(() => _selectedTheme = theme),
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
                    subtitle: 'Current version: v1.0.32',
                    trailing: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checking for updates...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      final info = await UpdateService().checkForUpdate();
                      if (!mounted) return;
                      if (info != null && info.hasUpdate) {
                        UpdateService.showUpdateDialog(context: context, info: info);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('True Me is up to date (v1.0.32)'),
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
