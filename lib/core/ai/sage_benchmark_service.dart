import 'answer_verifier.dart';
import 'retrieval_engine.dart';
import 'syllabus_service.dart';

class SageBenchmarkCase {
  final String query;
  final List<String> expectedKeywords;
  final bool expectSourceSupport;
  final String? expectedTopicStatus;

  const SageBenchmarkCase({
    required this.query,
    required this.expectedKeywords,
    required this.expectSourceSupport,
    this.expectedTopicStatus,
  });
}

class SageBenchmarkReport {
  final int datasetSize;
  final double retrievalRecall;
  final double citationPrecision;
  final double gapAbstentionScore;
  final double syllabusMappingAccuracy;
  final List<String> failures;

  const SageBenchmarkReport({
    required this.datasetSize,
    required this.retrievalRecall,
    required this.citationPrecision,
    required this.gapAbstentionScore,
    required this.syllabusMappingAccuracy,
    required this.failures,
  });

  bool get allPassed => failures.isEmpty;
}

/// SAGE-007 Benchmarking & Regression Evaluation Service.
/// Implements deterministic evaluation against the Master Roadmap Section 6
/// reference workflow (mixed PYQs, fungi material, teacher notes, syllabus).
class SageBenchmarkService {
  SageBenchmarkService._();

  static Future<SageBenchmarkReport> evaluateRetrievalAndVerification({
    required String notebookId,
    required List<Map<String, dynamic>> docs,
    required List<SageBenchmarkCase> cases,
    required RetrievalEngine retrievalEngine,
  }) async {
    int retrievalHits = 0;
    int retrievalExpected = 0;
    int citationSupported = 0;
    int citationTotal = 0;
    int gapChecksPassed = 0;
    int gapChecksTotal = 0;
    int syllabusChecksPassed = 0;
    int syllabusChecksTotal = 0;
    final failures = <String>[];

    for (final c in cases) {
      final bundle = await retrievalEngine.retrieveEvidence(
        query: c.query,
        userId: 'benchmark_user',
        notebookId: notebookId,
        overrideLocalDocs: docs,
      );

      if (c.expectSourceSupport) {
        retrievalExpected++;
        final combined = bundle.passages.map((p) => p.content.toLowerCase()).join(' ');
        final hit = c.expectedKeywords.every((kw) => combined.contains(kw.toLowerCase()));
        if (hit && bundle.hasSufficientEvidence) {
          retrievalHits++;
        } else {
          failures.add('Retrieval miss for "${c.query}"');
        }

        final report = AnswerVerifier.verify(
          query: c.query,
          answer: c.expectedKeywords.join(' '),
          evidence: bundle,
          notebookId: notebookId,
        );
        citationTotal++;
        if (report.citedSources.isNotEmpty &&
            report.trustLevel != EvidenceTrustLevel.generalKnowledge) {
          citationSupported++;
        } else {
          failures.add('Citation verification failed for "${c.query}"');
        }
      } else {
        gapChecksTotal++;
        final report = AnswerVerifier.verify(
          query: c.query,
          answer: 'General explanation without uploaded source.',
          evidence: bundle,
          notebookId: notebookId,
        );
        if (!bundle.hasSufficientEvidence &&
            report.trustLevel == EvidenceTrustLevel.generalKnowledge &&
            report.gapDisclosure != null) {
          gapChecksPassed++;
        } else {
          failures.add('Gap abstention failed for uncovered query "${c.query}"');
        }
      }

      if (c.expectedTopicStatus != null) {
        syllabusChecksTotal++;
        final status = SyllabusService.classifyTopicStatus(
          notebookId,
          c.query,
          hasEvidenceInUploadedDocs: bundle.hasSufficientEvidence,
        );
        if (status == c.expectedTopicStatus) {
          syllabusChecksPassed++;
        } else {
          failures.add(
            'Syllabus status mismatch for "${c.query}": expected ${c.expectedTopicStatus}, got $status',
          );
        }
      }
    }

    return SageBenchmarkReport(
      datasetSize: cases.length,
      retrievalRecall: retrievalExpected == 0 ? 1.0 : retrievalHits / retrievalExpected,
      citationPrecision: citationTotal == 0 ? 1.0 : citationSupported / citationTotal,
      gapAbstentionScore: gapChecksTotal == 0 ? 1.0 : gapChecksPassed / gapChecksTotal,
      syllabusMappingAccuracy:
          syllabusChecksTotal == 0 ? 1.0 : syllabusChecksPassed / syllabusChecksTotal,
      failures: failures,
    );
  }
}
