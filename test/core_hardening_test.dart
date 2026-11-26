import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueme/core/ai/ai_gateway_client.dart';
import 'package:trueme/core/ai/ai_router.dart';
import 'package:trueme/core/ai/cognitive/student_cognitive_profile.dart';
import 'package:trueme/core/ai/rag_service.dart';
import 'package:trueme/core/ai/syllabus_service.dart';
import 'package:trueme/core/config/env_config.dart';
import 'package:trueme/core/models/document_chunk_model.dart';
import 'package:trueme/features/export/docx_exporter.dart';
import 'package:trueme/features/export/pptx_exporter.dart';
import 'package:trueme/features/export/services/document_parser_service.dart';
import 'package:trueme/features/export/widgets/style_picker_sheet.dart';
import 'package:trueme/features/quiz/providers/quiz_provider.dart';
import 'package:trueme/features/upload/services/url_processor.dart';

void main() {
  group('LEARN-03 Quiz Question Validation', () {
    test('rejects out-of-range correctOptionIndex instead of clamping', () {
      final invalid = QuizNotifier.validateQuestionMap({
        'question': 'What is osmosis?',
        'options': ['Diffusion of water', 'Active transport'],
        'correctOptionIndex': 5,
      }, 0);
      expect(invalid, isNull);
    });

    test('rejects duplicate options (case-insensitive)', () {
      final dup = QuizNotifier.validateQuestionMap({
        'question': 'Pick one',
        'options': ['ATP', 'atp', 'ADP'],
        'correctOptionIndex': 0,
      }, 0);
      expect(dup, isNull);
    });

    test('accepts valid question preserving exact correctOptionIndex', () {
      final valid = QuizNotifier.validateQuestionMap({
        'question': 'Powerhouse of the cell?',
        'options': ['Nucleus', 'Mitochondria', 'Ribosome'],
        'correctOptionIndex': 1,
        'explanation': 'Mitochondria generate ATP.',
      }, 0);
      expect(valid, isNotNull);
      expect(valid!.correctOptionIndex, 1);
    });
  });

  group('AiRouter JSON parsing', () {
    test('extracts fenced JSON object cleanly', () {
      final parsed = AiRouter.parseJsonObject('```json\n{"cards": [{"front":"A","back":"B"}],}\n```');
      expect(parsed['cards'], isA<List>());
    });
  });

  group('INGEST-01 SSRF URL Guard', () {
    test('blocks localhost and private IPs', () {
      expect(() => UrlProcessor.validateSafeUri('http://localhost:8080/admin'), throwsArgumentError);
      expect(() => UrlProcessor.validateSafeUri('http://127.0.0.1/secret'), throwsArgumentError);
      expect(() => UrlProcessor.validateSafeUri('http://192.168.1.1/router'), throwsArgumentError);
      expect(() => UrlProcessor.validateSafeUri('http://10.0.0.5/internal'), throwsArgumentError);
      expect(() => UrlProcessor.validateSafeUri('http://169.254.169.254/latest/meta-data'), throwsArgumentError);
      expect(() => UrlProcessor.validateSafeUri('file:///etc/passwd'), throwsArgumentError);
    });

    test('allows valid https URLs', () {
      final uri = UrlProcessor.validateSafeUri('en.wikipedia.org/wiki/Cell_(biology)');
      expect(uri.scheme, 'https');
      expect(uri.host, 'en.wikipedia.org');
    });
  });

  group('RAG-02 Grounded Citations', () {
    test('discloses low evidence when chunks are empty', () {
      final ctx = RagService.formatGroundedContextWithCitations(const []);
      expect(ctx, contains('NO_MATCHING_STUDY_CHUNKS'));
    });

    test('includes source file and chunk index metadata', () {
      final ctx = RagService.formatGroundedContextWithCitations([
        const DocumentChunkModel(
          id: 'c1',
          userId: 'u1',
          notebookId: 'n1',
          fileName: 'Biology.pdf',
          chunkIndex: 3,
          content: 'Mitosis produces two identical daughter cells.',
          similarity: 0.92,
        ),
      ]);
      expect(ctx, contains('Biology.pdf'));
      expect(ctx, contains('Chunk #3'));
    });
  });

  group('SEC-01 Client Credential Removal & Gateway Auth', () {
    test('EnvConfig does not expose private AI provider keys', () {
      expect(EnvConfig.get('GEMINI_API_KEY'), isEmpty);
      expect(EnvConfig.get('GROQ_API_KEY'), isEmpty);
      expect(EnvConfig.get('COHERE_API_KEY'), isEmpty);
      expect(EnvConfig.get('OPENROUTER_API_KEY'), isEmpty);
      expect(EnvConfig.get('CLOUDFLARE_API_TOKEN'), isEmpty);
      expect(EnvConfig.get('CLOUDFLARE_ACCOUNT_ID'), isEmpty);
    });

    test('AiGatewayClient rejects unauthenticated calls', () async {
      await expectLater(
        () => AiGatewayClient.instance.chat(prompt: 'Hello'),
        throwsStateError,
      );
    });
  });

  group('Foundation Brief Acceptance Checks', () {
    test('StudentCognitiveProfile tracks activeSubject isolation fields', () {
      const scoped = StudentCognitiveProfile(
        studentName: 'Test',
        overallMasteryPercentage: 0,
        tier: CognitiveTier.foundational,
        daysToExam: 14,
        urgencyTier: ExamUrgencyTier.approaching,
        weakTopics: [],
        dueFlashcardsCount: 0,
        totalFlashcardsCount: 0,
        quizzesTakenCount: 0,
        todayMinutesStudied: 0,
        streakDays: 0,
        activeSubject: 'Chemistry',
        activeSubjectMasteryPercentage: 0,
        activeSubjectTier: CognitiveTier.foundational,
      );
      expect(scoped.activeSubject, 'Chemistry');
      expect(scoped.toSageContextString(), contains('Chemistry'));
    });

    test('SyllabusService computeCoverageStats handles empty syllabus cleanly', () {
      final stats = SyllabusService.computeCoverageStats('nonexistent_nb');
      expect(stats['total'], 0);
      expect(stats['uncovered'], 0);
    });
  });

  group('Document Styles & Native Viewer Parser', () {
    test('All 12 approved styles are selectable per format', () {
      expect(StylePickerSheet.optionsFor('pdf').length, 4);
      expect(StylePickerSheet.optionsFor('docx').length, 4);
      expect(StylePickerSheet.optionsFor('pptx').length, 4);
    });

    test('DocxExporter generates valid DOCX across all 4 styles and parses natively', () {
      for (final style in DocxStudyStyle.values) {
        final bytes = DocxExporter.createDocument(
          title: 'Cell Biology',
          subject: 'Biology',
          content: '# Introduction\n- Prokaryotic cells\nNote: Key exam point',
          style: style,
        );
        expect(DocumentParserService.detectFormat(bytes, 'out.docx'), ParsedDocFormat.docx);
        final blocks = DocumentParserService.parseDocx(bytes);
        expect(blocks, isNotEmpty);
      }
    });

    test('PptxExporter generates valid PPTX and parses natively', () {
      final bytes = PptxExporter.createPresentation(
        presentationTitle: 'Cell Biology',
        slides: const [
          PptxSlideData(
            title: 'Prokaryotic vs Eukaryotic',
            bulletPoints: ['No membrane-bound nucleus', 'Membrane-bound organelles'],
          ),
        ],
      );
      expect(DocumentParserService.detectFormat(bytes, 'slides.pptx'), ParsedDocFormat.pptx);
      final slides = DocumentParserService.parsePptx(bytes);
      expect(slides.length, 1);
      expect(slides.first.title, 'Prokaryotic vs Eukaryotic');
    });

    test('DocumentParserService rejects corrupt/empty files', () {
      expect(
        DocumentParserService.detectFormat(Uint8List.fromList([1, 2, 3]), 'bad.pdf'),
        ParsedDocFormat.unknown,
      );
    });
  });
}
