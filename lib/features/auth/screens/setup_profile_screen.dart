import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  int _currentStep = 1;
  bool _isConnectingDrive = false;

  // Step 1 Fields
  late final TextEditingController _nameController;
  final List<String> _subjects = [];
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final name = OfflineCacheService.getUserName();
    _nameController = TextEditingController(text: name != 'Student' ? name : '');
    _subjects.addAll(OfflineCacheService.getUserSubjects());
    _deadline = OfflineCacheService.getTargetExamDate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
          hintText: 'e.g. Microbiology, Calculus...',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final sub = controller.text.trim();
              if (sub.isNotEmpty && !_subjects.contains(sub)) {
                setState(() => _subjects.add(sub));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _completeSetup({bool connectDrive = false}) async {
    if (connectDrive) {
      setState(() => _isConnectingDrive = true);
      final ok = await DriveService.instance.signIn();
      if (!mounted) return;
      setState(() => _isConnectingDrive = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              DriveService.instance.lastError ??
                  'Could not connect Drive right now. Continuing locally — you can connect later in Account.',
            ),
          ),
        );
      }
    }

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : OfflineCacheService.getUserName();
    final subjectsList = List<String>.from(_subjects);

    await OfflineCacheService.saveUserProfile(
      name: name,
      email: OfflineCacheService.getUserEmail(),
      subjects: subjectsList,
      targetExamDate: _deadline,
      isLoggedIn: true,
      hasCompletedOnboarding: true,
    );

    // Create notebooks for added subjects (createNotebook prevents duplicates)
    for (final s in subjectsList) {
      await OfflineCacheService.createNotebook(title: s, subject: s);
    }

    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _deadline.difference(DateTime.now()).inDays.clamp(0, 999);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Counter
              Text(
                'Step $_currentStep of 2',
                style: AppTypography.smallLabel.copyWith(color: context.accentColor),
              ),
              const SizedBox(height: 8),

              if (_currentStep == 1) ...[
                const Text('About you', style: AppTypography.screenTitle),
                const SizedBox(height: 24),

                AppInput(
                  label: 'Name',
                  hintText: 'Your name',
                  controller: _nameController,
                ),
                const SizedBox(height: 24),

                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._subjects.map(
                      (sub) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sub, style: TextStyle(fontSize: 14, color: context.textPrimary)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _subjects.remove(sub)),
                              child: Icon(Icons.close, size: 16, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showAddSubjectDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.accentColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16, color: context.accentColor),
                            const SizedBox(width: 4),
                            Text('Add subject', style: TextStyle(fontSize: 14, color: context.accentColor, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Exam or syllabus deadline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDeadline,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_deadline.day}/${_deadline.month}/${_deadline.year}',
                          style: TextStyle(fontSize: 16, color: context.textPrimary),
                        ),
                        Icon(Icons.calendar_today_outlined, size: 20, color: context.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$daysLeft days left',
                  style: AppTypography.secondary,
                ),

                const Spacer(),
                AppPrimaryButton(
                  label: 'Continue',
                  onPressed: () => setState(() => _currentStep = 2),
                ),
              ] else ...[
                const Text('Connect Google Drive', style: AppTypography.screenTitle),
                const SizedBox(height: 16),
                const Text(
                  'Your files stay in your Google Drive. True Me creates a folder called True Me for you.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_shared_outlined, size: 28, color: context.accentColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('True Me / [Subject]', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
                            const SizedBox(height: 2),
                            const Text('Syllabus, Notes, Books, Previous papers', style: AppTypography.secondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                AppPrimaryButton(
                  label: 'Connect Google Drive',
                  isLoading: _isConnectingDrive,
                  onPressed: () => _completeSetup(connectDrive: true),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isConnectingDrive ? null : () => _completeSetup(connectDrive: false),
                    child: const Text('Do this later'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
