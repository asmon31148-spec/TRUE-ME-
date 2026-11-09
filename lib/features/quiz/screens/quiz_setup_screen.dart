import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  bool _isPlaying = false;
  bool _isFinished = false;

  // Setup options
  late String _selectedSubject;
  final TextEditingController _topicCtrl = TextEditingController();
  String _selectedSource = 'All sources';
  String _selectedDifficulty = 'Medium';
  int _questionCount = 10;

  // Active Quiz State
  int _currentIdx = 2; // 0-indexed for "Question 3 of 10" like in design
  int? _selectedOptionIdx = 1; // "Flagellum" pre-selected as in wireframe
  bool _hasChecked = false;
  int _score = 8;

  final List<Map<String, dynamic>> _sampleQuestions = [
    {
      'question': 'What is the primary function of peptidoglycan in bacterial cell walls?',
      'options': ['Energy storage', 'Structural rigidity & osmotic protection', 'Protein synthesis', 'Lipid secretion'],
      'correct': 1,
      'explanation': 'Peptidoglycan provides mechanical strength to resist internal osmotic pressure.',
    },
    {
      'question': 'Which phase of microbial growth shows exponential cellular division?',
      'options': ['Lag phase', 'Log (exponential) phase', 'Stationary phase', 'Death phase'],
      'correct': 1,
      'explanation': 'During log phase, cells divide at a constant, maximal rate under the given conditions.',
    },
    {
      'question': 'Which structure is primarily responsible for bacterial movement?',
      'options': ['Capsule', 'Flagellum', 'Pili', 'Ribosome'],
      'correct': 1,
      'explanation': 'Flagella are helical protein filaments that rotate to drive bacterial chemotaxis and motility.',
    },
    {
      'question': 'Autoclaving achieves sterilization primarily by using:',
      'options': ['Dry heat at 100°C', 'Steam under pressure at 121°C', 'Gamma radiation', 'Filtration through 0.45μm pores'],
      'correct': 1,
      'explanation': 'Pressurized saturated steam at 121°C denatures microbial proteins and destroys bacterial endospores.',
    },
    {
      'question': 'Gram-positive bacteria retain which dye after ethanol decolorization?',
      'options': ['Safranin', 'Crystal violet', 'Methylene blue', 'Carbolfuchsin'],
      'correct': 1,
      'explanation': 'The thick peptidoglycan layer dehydrates and traps the crystal violet-iodine complex.',
    },
  ];

  @override
  void initState() {
    super.initState();
    final subs = OfflineCacheService.getUserSubjects();
    _selectedSubject = subs.isNotEmpty ? subs.first : 'Microbiology';
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  void _onCheck() {
    setState(() => _hasChecked = true);
  }

  void _onNext() {
    if (_currentIdx < _sampleQuestions.length - 1) {
      setState(() {
        _currentIdx++;
        _selectedOptionIdx = null;
        _hasChecked = false;
      });
    } else {
      setState(() => _isFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Result', style: AppTypography.screenTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  '$_score / 10',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Good understanding of bacterial structure and staining.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 32),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Topics to review', style: AppTypography.sectionHeading),
                ),
                const SizedBox(height: 12),
                AppListRow(
                  title: 'Sterilization methods',
                  subtitle: 'Missed Question 4',
                ),
                const SizedBox(height: 8),
                AppListRow(
                  title: 'Gram staining mechanisms',
                  subtitle: 'Missed Question 5',
                ),

                const Spacer(),
                AppPrimaryButton(
                  label: 'Review missed questions',
                  onPressed: () => setState(() {
                    _isFinished = false;
                    _currentIdx = 3;
                    _hasChecked = false;
                    _selectedOptionIdx = null;
                  }),
                ),
                const SizedBox(height: 12),
                AppSecondaryButton(
                  label: 'Done',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isPlaying) {
      final q = _sampleQuestions[_currentIdx.clamp(0, _sampleQuestions.length - 1)];
      final isLast = _currentIdx == _sampleQuestions.length - 1;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => setState(() => _isPlaying = false),
          ),
          title: Text(
            'Question ${_currentIdx + 1} of 10',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: AppProgressBar(value: (_currentIdx + 1) / 10.0),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q['question'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Option Rows
                      ...List.generate(4, (i) {
                        final options = q['options'] as List<String>;
                        final optionText = options[i];
                        final letter = String.fromCharCode(65 + i); // A, B, C, D
                        final isSelected = _selectedOptionIdx == i;
                        final isCorrect = i == q['correct'];

                        Color borderColor = AppColors.border;
                        Widget? trailingIcon;

                        if (_hasChecked) {
                          if (isCorrect) {
                            borderColor = AppColors.success;
                            trailingIcon = const Icon(Icons.check, size: 20, color: AppColors.success);
                          } else if (isSelected && !isCorrect) {
                            borderColor = AppColors.error;
                            trailingIcon = const Icon(Icons.close, size: 20, color: AppColors.error);
                          }
                        } else if (isSelected) {
                          borderColor = AppColors.accent;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: _hasChecked ? null : () => setState(() => _selectedOptionIdx = i),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: isSelected || _hasChecked ? 1.5 : 1.0),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  if (trailingIcon != null) trailingIcon,
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Explanation Card
                      if (_hasChecked) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Explanation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(q['explanation'] as String, style: AppTypography.secondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),

              // Pinned Button: "Check", "Next", or "Finish"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: AppPrimaryButton(
                  label: !_hasChecked ? 'Check' : (isLast ? 'Finish' : 'Next'),
                  onPressed: _selectedOptionIdx == null
                      ? null
                      : (!_hasChecked ? _onCheck : _onNext),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Setup Screen
    final subjects = OfflineCacheService.getUserSubjects();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quiz', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubject,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSubject = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              AppInput(
                label: 'Topic (optional)',
                hintText: 'e.g. Bacterial cell structure',
                controller: _topicCtrl,
              ),
              const SizedBox(height: 16),

              const Text('Source', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSource,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: ['All sources', 'Previous papers only']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSource = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Difficulty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: ['Easy', 'Medium', 'Hard'].map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: d,
                      isSelected: _selectedDifficulty == d,
                      onTap: () => setState(() => _selectedDifficulty = d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Number of questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [5, 10, 20].map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: '$c',
                      isSelected: _questionCount == c,
                      onTap: () => setState(() => _questionCount = c),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),
              AppPrimaryButton(
                label: 'Start quiz',
                onPressed: () {
                  setState(() {
                    _isPlaying = true;
                    _currentIdx = 0;
                    _selectedOptionIdx = null;
                    _hasChecked = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
