/// Typed structured content model shared across PDF, DOCX, and PPTX renderers.
/// Separates content intelligence & verification from visual style rendering.
class StudySectionBlock {
  final String heading;
  final String body;
  final List<String> keyPoints;
  final List<String> definitions;
  final List<String> examples;
  final String? calloutWarning;
  final List<List<String>> tableRows;
  final List<String> processSteps;
  final String? diagramSvg;
  final String? diagramPrompt;

  const StudySectionBlock({
    required this.heading,
    this.body = '',
    this.keyPoints = const [],
    this.definitions = const [],
    this.examples = const [],
    this.calloutWarning,
    this.tableRows = const [],
    this.processSteps = const [],
    this.diagramSvg,
    this.diagramPrompt,
  });

  factory StudySectionBlock.fromMap(Map<String, dynamic> map) {
    return StudySectionBlock(
      heading: (map['heading'] ?? 'Key Concepts').toString().trim(),
      body: (map['body'] ?? '').toString().trim(),
      keyPoints: (map['keyPoints'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      definitions: (map['definitions'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      examples: (map['examples'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      calloutWarning: map['calloutWarning']?.toString().trim(),
      tableRows: (map['tableRows'] as List? ?? [])
          .whereType<List>()
          .map((r) => r.map((c) => c.toString().trim()).toList())
          .where((r) => r.isNotEmpty)
          .toList(),
      processSteps: (map['processSteps'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      diagramSvg: map['diagramSvg']?.toString().trim(),
      diagramPrompt: map['diagramPrompt']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'heading': heading,
        'body': body,
        'keyPoints': keyPoints,
        'definitions': definitions,
        'examples': examples,
        if (calloutWarning != null && calloutWarning!.isNotEmpty) 'calloutWarning': calloutWarning,
        'tableRows': tableRows,
        'processSteps': processSteps,
        if (diagramSvg != null && diagramSvg!.isNotEmpty) 'diagramSvg': diagramSvg,
        if (diagramPrompt != null && diagramPrompt!.isNotEmpty) 'diagramPrompt': diagramPrompt,
      };
}

class StructuredStudyDocument {
  final String title;
  final String subject;
  final String topic;
  final String purpose;
  final String academicLevel;
  final String executiveSummary;
  final List<String> learningObjectives;
  final List<StudySectionBlock> sections;
  final List<String> takeaways;
  final List<String> sourceReferences;
  final String? uncertaintyNote;

  const StructuredStudyDocument({
    required this.title,
    required this.subject,
    required this.topic,
    required this.purpose,
    required this.academicLevel,
    required this.executiveSummary,
    this.learningObjectives = const [],
    required this.sections,
    this.takeaways = const [],
    this.sourceReferences = const [],
    this.uncertaintyNote,
  });

  factory StructuredStudyDocument.fromMap(
    Map<String, dynamic> map, {
    required String fallbackTitle,
    required String subject,
    required String topic,
  }) {
    final rawSections = (map['sections'] as List? ?? [])
        .whereType<Map>()
        .map((m) => StudySectionBlock.fromMap(Map<String, dynamic>.from(m)))
        .where((s) =>
            s.heading.isNotEmpty &&
            (s.body.isNotEmpty ||
                s.keyPoints.isNotEmpty ||
                s.definitions.isNotEmpty ||
                s.examples.isNotEmpty ||
                s.processSteps.isNotEmpty))
        .toList();

    return StructuredStudyDocument(
      title: (map['title'] ?? fallbackTitle).toString().trim(),
      subject: subject,
      topic: topic,
      purpose: (map['purpose'] ?? 'Exam & Course Study Guide').toString().trim(),
      academicLevel: (map['academicLevel'] ?? 'Course Level').toString().trim(),
      executiveSummary: (map['executiveSummary'] ?? '').toString().trim(),
      learningObjectives: (map['learningObjectives'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      sections: rawSections,
      takeaways: (map['takeaways'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      sourceReferences: (map['sourceReferences'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      uncertaintyNote: map['uncertaintyNote']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'subject': subject,
        'topic': topic,
        'purpose': purpose,
        'academicLevel': academicLevel,
        'executiveSummary': executiveSummary,
        'learningObjectives': learningObjectives,
        'sections': sections.map((s) => s.toMap()).toList(),
        'takeaways': takeaways,
        'sourceReferences': sourceReferences,
        if (uncertaintyNote != null && uncertaintyNote!.isNotEmpty)
          'uncertaintyNote': uncertaintyNote,
      };

  /// Converts verified structured blocks to clean Markdown for PDF/DOCX renderers.
  String toStructuredMarkdown() {
    final buf = StringBuffer();
    if (executiveSummary.isNotEmpty) {
      buf.writeln('# Overview');
      buf.writeln(executiveSummary);
      buf.writeln();
    }
    if (learningObjectives.isNotEmpty) {
      buf.writeln('## Learning Objectives');
      for (final obj in learningObjectives) {
        buf.writeln('- $obj');
      }
      buf.writeln();
    }
    for (final s in sections) {
      buf.writeln('# ${s.heading}');
      if (s.body.isNotEmpty) {
        buf.writeln(s.body);
        buf.writeln();
      }
      for (final def in s.definitions) {
        buf.writeln('- Definition: $def');
      }
      for (final kp in s.keyPoints) {
        buf.writeln('- $kp');
      }
      for (final ex in s.examples) {
        buf.writeln('Note: Example — $ex');
      }
      if (s.processSteps.isNotEmpty) {
        buf.writeln('### Process Flow');
        for (int i = 0; i < s.processSteps.length; i++) {
          buf.writeln('- Step ${i + 1}: ${s.processSteps[i]}');
        }
      }
      if (s.tableRows.isNotEmpty) {
        buf.writeln('### Comparison Table');
        for (final row in s.tableRows) {
          buf.writeln('- ${row.join(' | ')}');
        }
      }
      if (s.calloutWarning != null && s.calloutWarning!.isNotEmpty) {
        buf.writeln('Exam Alert: ${s.calloutWarning}');
      }
      buf.writeln();
    }
    if (takeaways.isNotEmpty) {
      buf.writeln('# Key Takeaways');
      for (final t in takeaways) {
        buf.writeln('- $t');
      }
      buf.writeln();
    }
    if (uncertaintyNote != null && uncertaintyNote!.isNotEmpty) {
      buf.writeln('Note: Grounding & Scope — $uncertaintyNote');
      buf.writeln();
    }
    if (sourceReferences.isNotEmpty) {
      buf.writeln('## Source References');
      for (final ref in sourceReferences) {
        buf.writeln('- $ref');
      }
    }
    return buf.toString().trim();
  }
}
