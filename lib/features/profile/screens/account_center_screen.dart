import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

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
      _userSubjects = List<String>.from(profile['subjects'] ?? ['Computer Science', 'Calculus', 'Physics']);
      _learningStyle = profile['learningStyle'] ?? 'Visual (Diagrams & Videos)';
      _targetExamDate = OfflineCacheService.getTargetExamDate();
    });
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Student Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your name...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = _targetExamDate.difference(DateTime.now()).inDays;
    final initialLetter = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Account Center',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Profile Header Card
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              surfaceColor: AppColors.primary.withOpacity(0.12),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.sageGlowGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_userName, style: AppTypography.headlineMedium),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showEditNameDialog,
                              child: const Icon(Icons.edit, size: 16, color: AppColors.accentCyan),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                          ),
                          child: const Text(
                            '⭐ PRO SCHOLAR ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Study Metrics & Sage Settings
            const Text('Academic & AI Mentor Setup', style: AppTypography.headlineMedium),
            const SizedBox(height: 12),

            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Streak & Goal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_fire_department, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Study Streak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('7 consecutive days of active recall', style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      const Text(
                        '7 Days 🔥',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 28),

                  // Target Exam Date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.event_available, color: AppColors.accentCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Exam Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(
                              '${_targetExamDate.day}/${_targetExamDate.month}/${_targetExamDate.year}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$daysRemaining days left',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 28),

                  // Learning Style
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.psychology, color: AppColors.secondary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Learning Style', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(_learningStyle, style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Subjects
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Subjects', style: AppTypography.headlineMedium),
                TextButton(
                  onPressed: () => context.go('/setup-profile'),
                  child: const Text('Change', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _userSubjects.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school, size: 14, color: AppColors.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        s,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // System & App Updates
            const Text('System & In-App Updates', style: AppTypography.headlineMedium),
            const SizedBox(height: 12),

            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.system_update_alt_rounded, color: AppColors.accentCyan),
                    ),
                    title: const Text('Check for Updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('True Me v1.0.23 (Latest Engine)', style: AppTypography.bodySmall),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checking GitHub Releases for latest APK...'),
                          backgroundColor: AppColors.surface,
                          duration: Duration(seconds: 1),
                        ),
                      );
                      final info = await UpdateService().checkForUpdate();
                      if (!mounted) return;
                      if (info != null && info.hasUpdate) {
                        UpdateService.showUpdateDialog(context: context, info: info);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 True Me is up to date! (v${info?.latestVersion ?? 'latest'})'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cleaning_services_rounded, color: Colors.white70),
                    ),
                    title: const Text('Clear Offline Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Frees local Hive disk storage', style: AppTypography.bodySmall),
                    trailing: TextButton(
                      child: const Text('Clear', style: TextStyle(color: AppColors.warning)),
                      onPressed: () async {
                        await OfflineCacheService.clearAllCache();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Offline storage cleared successfully.')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            GlassButton(
              width: double.infinity,
              surfaceColor: AppColors.error.withOpacity(0.15),
              borderColor: AppColors.error.withOpacity(0.4),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Text('Sign Out of True Me', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                ],
              ),
              onPressed: () async {
                await OfflineCacheService.logout();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
