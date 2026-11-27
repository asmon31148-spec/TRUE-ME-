import 'retrieval_engine.dart';
import 'syllabus_service.dart';

enum EvidenceTrustLevel {
  grounded,
  partiallyGrounded,
  generalKnowledge,
  insufficientEvidence;

  String get badgeLabel {
    switch (this) {
      case EvidenceTrustLevel.grounded:
        return 'Source-Grounded';
      case EvidenceTrustLevel.partiallyGrounded:
        return 'Partially Grounded';
      case EvidenceTrustLevel.generalKnowledge:
        return 'General Knowledge';
      case EvidenceTrustLevel.insufficientEvidence:
        return 'Limited Evidence';
    }
  }
}

/// Post-generation verification report attached to Sage answers (SAGE-005).
class AnswerVerificationReport {
  final EvidenceTrustLevel trustLevel;
  final double supportRatio;
  final List<String> citedSources;
  final String? gapDisclosure;

  const AnswerVerificationReport({
    required this.trustLevel,
    required this.supportRatio,
    this.citedSources = const [],
    this.gapDisclosure,
  });

  Map<String, dynamic> toMap() => {
        'trustLevel': trustLevel.name,
        'supportRatio': supportRatio,
        'citedSources': citedSources,
        if (gapDisclosure != null) 'gapDisclosure': gapDisclosure,
      };

  factory AnswerVerificationReport.fromMap(Map<String, dynamic> map) {
    return AnswerVerificationReport(
      trustLevel: EvidenceTrustLevel.values.firstWhere(
        (e) => e.name == map['trustLevel'],
        orElse: () => EvidenceTrustLevel.generalKnowledge,
      ),
      supportRatio: (map['supportRatio'] as num?)?.toDouble() ?? 0.0,
      citedSources: (map['citedSources'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      gapDisclosure: map['gapDisclosure'] as String?,
    );
  }
}

/// SAGE-005 Grounded Reasoning & Answer Verification Engine.
class AnswerVerifier {
  AnswerVerifier._();

  static AnswerVerificationReport verify({
    required String query,
    required String answer,
    required EvidenceBundle evidence,
    String? notebookId,
  }) {
    final cited = evidence.passages.map((p) => p.provenanceLabel).toSet().toList();

    if (!evidence.hasSufficientEvidence || evidence.passages.isEmpty) {
      String gapNote =
          'No matching passages were found in your uploaded sources; this response uses general academic explanation.';
      if (notebookId != null && notebookId.isNotEmpty) {
        final topicStatus = SyllabusService.classifyTopicStatus(
          notebookId,
          query,
          hasEvidenceInUploadedDocs: false,
        );
        if (topicStatus == 'not_part_of_syllabus') {
          gapNote =
              'This topic does not appear in your uploaded syllabus or notes; answered using general knowledge.';
        } else if (topicStatus == 'in_syllabus_not_found_in_uploaded_material') {
          gapNote =
              'This topic is in your syllabus, but no supporting notes were found in your uploaded files yet.';
        }
      }
      return AnswerVerificationReport(
        trustLevel: EvidenceTrustLevel.generalKnowledge,
        supportRatio: 0.0,
        citedSources: const [],
        gapDisclosure: gapNote,
      );
    }

    // Measure lexical overlap between answer content terms and retrieved evidence
    final answerTerms = RetrievalEngine.extractQueryTerms(answer);
    final evidenceText =
        evidence.passages.map((p) => p.content.toLowerCase()).join(' ');
    int supported = 0;
    for (final term in answerTerms) {
      if (evidenceText.contains(term)) supported++;
    }
    final ratio = answerTerms.isEmpty
        ? 0.0
        : (supported / answerTerms.length).clamp(0.0, 1.0);

    final trustLevel = ratio >= 0.45
        ? EvidenceTrustLevel.grounded
        : (ratio >= 0.2
            ? EvidenceTrustLevel.partiallyGrounded
            : EvidenceTrustLevel.insufficientEvidence);

    final gapDisclosure = trustLevel == EvidenceTrustLevel.grounded
        ? null
        : 'Parts of this answer extend beyond the retrieved source excerpts.';

    return AnswerVerificationReport(
      trustLevel: trustLevel,
      supportRatio: double.parse(ratio.toStringAsFixed(2)),
      citedSources: cited,
      gapDisclosure: gapDisclosure,
    );
  }
}
