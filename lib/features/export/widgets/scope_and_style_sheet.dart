import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/true_me_ui.dart';
import 'style_picker_sheet.dart';

class ScopeAndStyleSelection {
  final String scopeType; // 'last_answer' | 'topic' | 'full_subject'
  final String scopeLabel;
  final String topic;
  final String styleId;

  const ScopeAndStyleSelection({
    required this.scopeType,
    required this.scopeLabel,
    required this.topic,
    required this.styleId,
  });
}

/// Compact Scope + Style confirmation sheet (Spec Section 7.2 & 14.3):
/// Clarifies whether to generate from the current explanation, a specific topic/chapter,
/// or full subject sources, and picks 1 of the 4 format styles in one sheet.
class ScopeAndStyleSheet extends StatefulWidget {
  final String format;
  final String subject;
  final String defaultTopic;
  final bool hasLastAnswer;
  final String? preselectedStyleId;

  const ScopeAndStyleSheet({
    super.key,
    required this.format,
    required this.subject,
    required this.defaultTopic,
    required this.hasLastAnswer,
    this.preselectedStyleId,
  });

  static Future<ScopeAndStyleSelection?> show(
    BuildContext context, {
    required String format,
    required String subject,
    String? defaultTopic,
    bool hasLastAnswer = false,
    String? preselectedStyleId,
  }) {
    return showModalBottomSheet<ScopeAndStyleSelection>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScopeAndStyleSheet(
        format: format,
        subject: subject,
        defaultTopic: defaultTopic ?? subject,
        hasLastAnswer: hasLastAnswer,
        preselectedStyleId: preselectedStyleId,
      ),
    );
  }

  @override
  State<ScopeAndStyleSheet> createState() => _ScopeAndStyleSheetState();
}

class _ScopeAndStyleSheetState extends State<ScopeAndStyleSheet> {
  late String _scopeType;
  late String _selectedStyleId;
  late final TextEditingController _topicCtrl;

  @override
  void initState() {
    super.initState();
    _scopeType = widget.hasLastAnswer ? 'last_answer' : 'full_subject';
    final opts = StylePickerSheet.optionsFor(widget.format);
    _selectedStyleId = widget.preselectedStyleId ?? opts.first.id;
    _topicCtrl = TextEditingController(text: widget.defaultTopic);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = StylePickerSheet.optionsFor(widget.format);
    final fmtUpper = widget.format.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create $fmtUpper · ${widget.subject}',
                  style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  '1. What should be included?',
                  style: AppTypography.smallLabel.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (widget.hasLastAnswer)
                      ChoiceChip(
                        label: const Text('Last Answer'),
                        selected: _scopeType == 'last_answer',
                        onSelected: (_) => setState(() => _scopeType = 'last_answer'),
                      ),
                    ChoiceChip(
                      label: const Text('Specific Topic / Chapter'),
                      selected: _scopeType == 'topic',
                      onSelected: (_) => setState(() => _scopeType = 'topic'),
                    ),
                    ChoiceChip(
                      label: const Text('Full Subject Sources'),
                      selected: _scopeType == 'full_subject',
                      onSelected: (_) => setState(() => _scopeType = 'full_subject'),
                    ),
                  ],
                ),
                if (_scopeType == 'topic') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _topicCtrl,
                    decoration: InputDecoration(
                      labelText: 'Topic or Chapter Name',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '2. Choose $fmtUpper Style',
                  style: AppTypography.smallLabel.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...options.map((opt) {
                  final selected = _selectedStyleId == opt.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TrueMeCard(
                      borderRadius: 14,
                      borderColor: selected ? context.accentColor : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStyleId = opt.id);
                      },
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: selected ? context.accentColor : context.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  opt.description,
                                  style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TrueMePrimaryButton(
                    label: 'Generate $fmtUpper',
                    height: 48,
                    onPressed: () {
                      final topic = _scopeType == 'topic' && _topicCtrl.text.trim().isNotEmpty
                          ? _topicCtrl.text.trim()
                          : widget.defaultTopic;
                      final label = _scopeType == 'last_answer'
                          ? 'Last Explanation'
                          : (_scopeType == 'topic' ? 'Topic: $topic' : 'Full Subject Sources');
                      Navigator.of(context).pop(
                        ScopeAndStyleSelection(
                          scopeType: _scopeType,
                          scopeLabel: label,
                          topic: topic,
                          styleId: _selectedStyleId,
                        ),
                      );
                    },
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
