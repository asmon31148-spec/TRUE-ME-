import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  int _currentStep = 1;
  bool _isConnectingDrive = false;

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
        title: const Text('Add Subject', style: AppTypography.sectionHeading),
        content: AppInput(
          controller: controller,
          autofocus: true,
          hintText: 'e.g. Microbiology, Calculus...',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(88, 42)),
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
    final now = DateTime.now();
    final safeInitial = _deadline.isAfter(now) ? _deadline : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
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

    for (final s in subjectsList) {
      await OfflineCacheService.createNotebook(title: s, subject: s);
    }

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _deadline.difference(DateTime.now()).inDays.clamp(0, 999);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        intenseLavender: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrueMeTonalPill(
                  label: 'Step $_currentStep of 2',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                ),
                const SizedBox(height: 14),

                if (_currentStep == 1) ...[
                  Text(
                    'About You',
                    style: AppTypography.editorialHero.copyWith(
                      fontSize: 28,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Personalize your subjects and exam schedule.',
                    style: AppTypography.secondary.copyWith(color: context.textSecondary),
                  ),
                  const SizedBox(height: 22),

                  AppInput(
                    label: 'Name',
                    hintText: 'Your name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'Active Subjects',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._subjects.map(
                        (sub) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.borderColor),
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
                      TrueMeTonalPill(
                        label: 'Add Subject',
                        icon: Icons.add_rounded,
                        onTap: _showAddSubjectDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'Exam or Syllabus Deadline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TrueMeCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    onTap: _pickDeadline,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_deadline.day}/${_deadline.month}/${_deadline.year}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            TrueMeTonalPill(
                              label: '$daysLeft days left',
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today_outlined, size: 19, color: context.textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TrueMePrimaryButton(
                    label: 'Continue',
                    trailingIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    onPressed: () => setState(() => _currentStep = 2),
                  ),
                ] else ...[
                  Text(
                    'Connect Google Drive',
                    style: AppTypography.editorialHero.copyWith(
                      fontSize: 28,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your files stay safely in your Google Drive. True Me creates a dedicated folder called "True Me" for you.',
                    style: AppTypography.body.copyWith(color: context.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TrueMeCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        AppIconBadge(icon: Icons.folder_shared_outlined, color: context.accentColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'True Me / [Subject]',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Syllabus, Notes, Books, Previous papers',
                                style: AppTypography.secondary.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TrueMePrimaryButton(
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
      ),
    );
  }
}
