import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Alex');
  final TextEditingController _goalController =
      TextEditingController(text: 'Score GPA 3.8+ & Master Deep Concepts');
  
  String _selectedLearningStyle = 'Visual (Diagrams & Videos)';
  DateTime _targetExamDate = DateTime.now().add(const Duration(days: 45));
  final List<String> _selectedSubjects = ['Computer Science', 'Calculus', 'Physics'];

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
  ];

  final List<String> _learningStyles = [
    'Visual (Diagrams & Videos)',
    'Auditory (Voice Tutor & Audio)',
    'Kinesthetic (Quizzes & Flashcards)',
    'Reading & Text Analysis',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.sageGlowGradient,
                    ),
                    child: const Icon(Icons.psychology, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Personalize Sage', style: AppTypography.headlineLarge),
                      Text('Teach Sage how to coach you', style: AppTypography.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Student Name
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Name', style: AppTypography.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
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

              // Subjects
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Your Subjects', style: AppTypography.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Sage will create distinct notebooks and decks for each.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allSubjects.map((sub) {
                        final isSelected = _selectedSubjects.contains(sub);
                        return FilterChip(
                          label: Text(sub),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSubjects.add(sub);
                              } else {
                                _selectedSubjects.remove(sub);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.35),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Learning Style
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Primary Learning Style', style: AppTypography.titleLarge),
                    const SizedBox(height: 12),
                    ..._learningStyles.map((style) {
                      final isSelected = _selectedLearningStyle == style;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
                        ),
                        title: Text(
                          style,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        onTap: () => setState(() => _selectedLearningStyle = style),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Target Exam Date (Countdown)
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppColors.accentCyan),
                    ),
                    const SizedBox(width: 16),
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
                      icon: const Icon(Icons.edit_calendar, color: Colors.white70),
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
                onPressed: () {
                  context.go('/library');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
