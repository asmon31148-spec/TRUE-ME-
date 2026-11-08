import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _goalController =
      TextEditingController(text: 'Master core concepts & score highest GPA');
  
  String _selectedLearningStyle = 'Visual (Diagrams & Videos)';
  DateTime _targetExamDate = DateTime.now().add(const Duration(days: 45));
  final List<String> _selectedSubjects = [];

  final List<String> _allSubjects = [
    'Computer Science',
    'Calculus',
    'Physics',
    'Biology',
    'Chemistry',
    'Literature',
    'History',
    'Psychology',
    'Economics',
    'Data Structures & Algorithms',
    'Machine Learning',
  ];

  final List<String> _learningStyles = [
    'Visual (Diagrams & Videos)',
    'Auditory (Voice Tutor & Audio)',
    'Kinesthetic (Quizzes & Flashcards)',
    'Reading & Text Analysis',
  ];

  @override
  void initState() {
    super.initState();
    final currentName = OfflineCacheService.getUserName();
    _nameController = TextEditingController(
      text: currentName != 'Student' ? currentName : '',
    );
    final cachedSubjects = OfflineCacheService.getUserSubjects();
    if (cachedSubjects.isNotEmpty) {
      _selectedSubjects.addAll(cachedSubjects);
    } else {
      _selectedSubjects.addAll(['Computer Science', 'Calculus']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveAndProceed() async {
    final name = _nameController.text.trim();
    final displayName = name.isNotEmpty ? name : 'Asmon';

    await OfflineCacheService.saveUserProfile(
      name: displayName,
      email: OfflineCacheService.getUserEmail(),
      subjects: _selectedSubjects.isNotEmpty
          ? _selectedSubjects
          : ['Computer Science', 'Calculus'],
      learningStyle: _selectedLearningStyle,
      targetExamDate: _targetExamDate,
      isLoggedIn: true,
      hasCompletedOnboarding: true,
    );

    if (mounted) {
      context.go('/library');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.sageGlowGradient,
                    ),
                    child: const Icon(Icons.psychology, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personalize Sage', style: AppTypography.headlineLarge),
                      Text('Teach Sage who you are & how to coach you', style: AppTypography.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Student Name Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Name', style: AppTypography.titleLarge),
                    const SizedBox(height: 6),
                    const Text('Sage will address you directly by this name', style: AppTypography.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Enter your name (e.g. Asmon)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Subjects Selection Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Your Subjects', style: AppTypography.titleLarge),
                    const SizedBox(height: 4),
                    const Text('Tap to select or unselect courses for your study plan', style: AppTypography.bodySmall),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _allSubjects.map((subject) {
                        final isSelected = _selectedSubjects.contains(subject);
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: isSelected,
                          checkmarkColor: Colors.white,
                          label: Text(
                            subject,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.04),
                          selectedColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppColors.accentCyan : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSubjects.add(subject);
                              } else {
                                _selectedSubjects.remove(subject);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Learning Style Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Primary Learning Style', style: AppTypography.titleLarge),
                    const SizedBox(height: 14),
                    ..._learningStyles.map((style) {
                      final isSelected = _selectedLearningStyle == style;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.accentCyan : Colors.transparent,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            style,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          value: style,
                          groupValue: _selectedLearningStyle,
                          activeColor: AppColors.accentCyan,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLearningStyle = val);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Target Exam Date Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.event_note, color: AppColors.accentCyan, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Exam Date', style: AppTypography.titleLarge),
                          Text(
                            '${_targetExamDate.day}/${_targetExamDate.month}/${_targetExamDate.year} (${_targetExamDate.difference(DateTime.now()).inDays} days remaining)',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.accentCyan),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar, color: Colors.white),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _targetExamDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _targetExamDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Complete Setup Button
              GlassButton(
                isPrimary: true,
                width: double.infinity,
                child: const Text('Complete Setup & Meet Sage'),
                onPressed: _saveAndProceed,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
