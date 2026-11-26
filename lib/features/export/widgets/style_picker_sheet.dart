import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/true_me_ui.dart';

class StyleOption {
  final String id;
  final String name;
  final String description;

  const StyleOption({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// Compact single-select Style Picker (Spec Section 2.2):
/// One tap selects the visual design system for PDF, DOCX, or PPTX.
/// No typing and no preview images in this popup.
class StylePickerSheet extends StatelessWidget {
  final String format; // 'pdf' | 'docx' | 'pptx'

  const StylePickerSheet({super.key, required this.format});

  static const List<StyleOption> pdfStyles = [
    StyleOption(
      id: 'handwritten_notes',
      name: 'Handwritten Notes',
      description: 'Notebook paper, margin cues & pen-colour hierarchy',
    ),
    StyleOption(
      id: 'vintage_academic',
      name: 'Vintage Academic',
      description: 'Warm archival paper, classic serif & framed callouts',
    ),
    StyleOption(
      id: 'cute_aesthetic',
      name: 'Cute Aesthetic',
      description: 'Pastel cards, friendly type & visual memory cues',
    ),
    StyleOption(
      id: 'modern_academic',
      name: 'Modern Academic',
      description: 'Clean grid, contemporary type & crisp diagrams',
    ),
  ];

  static const List<StyleOption> docxStyles = [
    StyleOption(
      id: 'elegant_academic_notes',
      name: 'Elegant Academic Notes',
      description: 'Refined typography, strong headings & structured definitions',
    ),
    StyleOption(
      id: 'professional_research_report',
      name: 'Professional Research Report',
      description: 'Formal title block, numbered sections, tables & references',
    ),
    StyleOption(
      id: 'cute_creative_notes',
      name: 'Cute Creative Notes',
      description: 'Pastel panels, highlighted vocabulary & comparison cards',
    ),
    StyleOption(
      id: 'modern_minimal',
      name: 'Modern Minimal',
      description: 'Disciplined grid, restrained type & generous whitespace',
    ),
  ];

  static const List<StyleOption> pptxStyles = [
    StyleOption(
      id: 'creative_illustrated',
      name: 'Creative Illustrated',
      description: 'Story-led slides, visual metaphors & concise points',
    ),
    StyleOption(
      id: 'professional_scientific',
      name: 'Professional Scientific',
      description: 'Restrained palette, precise labels & evidence-led flow',
    ),
    StyleOption(
      id: 'minimal_editorial',
      name: 'Minimal Editorial',
      description: 'One main idea per slide, bold type & negative space',
    ),
    StyleOption(
      id: 'infographic_presentation',
      name: 'Infographic Presentation',
      description: 'Process flows, comparison matrices & visual takeaways',
    ),
  ];

  static List<StyleOption> optionsFor(String format) {
    switch (format.toLowerCase()) {
      case 'docx':
        return docxStyles;
      case 'pptx':
        return pptxStyles;
      default:
        return pdfStyles;
    }
  }

  static Future<StyleOption?> show(BuildContext context, {required String format}) {
    return showModalBottomSheet<StyleOption>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StylePickerSheet(format: format),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = optionsFor(format);
    final label = format.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose $label Style',
                style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap one visual style to generate your document.',
                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 14),
              ...options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TrueMeCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(opt);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.description,
                                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.accentColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
