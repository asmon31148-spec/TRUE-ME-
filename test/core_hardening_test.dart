import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trueme/core/ai/ai_gateway_client.dart';
import 'package:trueme/core/ai/ai_router.dart';
import 'package:trueme/core/ai/monitor/ai_model_registry.dart';
import 'package:trueme/core/ai/monitor/ai_monitor_models.dart';
import 'package:trueme/core/ai/monitor/ai_telemetry_service.dart';
import 'package:trueme/core/ai/monitor/provider_quota_adapters.dart';
import 'package:trueme/core/ai/monitor/quota_calculation_engine.dart';
import 'package:trueme/core/ai/cognitive/student_cognitive_profile.dart';
import 'package:trueme/core/ai/rag_service.dart';
import 'package:trueme/core/ai/sage_context_builder.dart';
import 'package:trueme/core/ai/syllabus_service.dart';
import 'package:trueme/core/config/env_config.dart';
import 'package:trueme/core/models/document_chunk_model.dart';
import 'package:trueme/core/services/offline_cache_service.dart';
import 'package:trueme/features/export/docx_exporter.dart';
import 'package:trueme/features/export/models/structured_study_document.dart';
import 'package:trueme/features/export/pdf_exporter.dart';
import 'package:trueme/features/export/pptx_exporter.dart';
import 'package:trueme/features/export/services/document_generation_service.dart';
import 'package:trueme/features/export/services/document_parser_service.dart';
import 'package:trueme/features/export/services/document_pipeline_service.dart';
import 'package:trueme/features/export/services/generation_job_service.dart';
import 'package:trueme/features/export/widgets/style_picker_sheet.dart';
import 'package:trueme/features/quiz/providers/quiz_provider.dart';
import 'package:trueme/features/upload/services/pdf_processor.dart';
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

    test('PdfProcessor handles malformed PDF gracefully without crashing', () async {
      final tmp = await Directory.systemTemp.createTemp('trueme_pdf_test_');
      try {
        final badPdf = File('${tmp.path}/large_broken.pdf');
        await badPdf.writeAsString('%PDF-1.4\nBT (Microbiology Chapter One) Tj ET\n%%EOF');
        final text = await PdfProcessor.extractText(badPdf);
        expect(text, contains('Microbiology Chapter One'));
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });

  group('AI Model & Quota Monitor', () {
    setUp(() {
      AiTelemetryService.resetForTest();
    });

    test('AiModelRegistry discovers all configured providers without catalog bloat', () {
      final base = AiModelRegistry.discoverModels();
      final providers = base.map((m) => m.provider).toSet();
      expect(providers, containsAll(['gemini', 'groq', 'openrouter', 'cohere', 'cloudflare']));
      expect(base.length, greaterThanOrEqualTo(16));
      expect(base.length, lessThan(30));

      final enriched = AiModelRegistry.discoverModels(
        snapshots: {
          'gemini': ProviderSnapshot(
            provider: 'gemini',
            status: DataSourceBadge.official,
            fetchedAt: DateTime.now(),
            discoveredModelIds: const ['gemini-2.5-flash'],
            modelContextLimits: const {'gemini-2.5-flash': 2000000},
          ),
        },
      );
      final g25 = enriched.firstWhere((m) => m.modelId == 'gemini-2.5-flash');
      expect(g25.contextWindow, 2000000);
    });

    test('QuotaCalculationEngine prioritizes official OpenRouter credits & Groq headers over estimates', () {
      final orModel = AiModelRegistry.discoverModels()
          .firstWhere((m) => m.provider == 'openrouter');
      final orSnap = ProviderSnapshot(
        provider: 'openrouter',
        status: DataSourceBadge.official,
        fetchedAt: DateTime.now(),
        officialCreditLimit: 10.0,
        officialCreditUsed: 2.5,
        officialCreditRemaining: 7.5,
        limitReset: 'monthly',
      );
      final orState = QuotaCalculationEngine.evaluateModel(
        model: orModel,
        records: const [],
        todayRecords: const [],
        snapshot: orSnap,
      );
      expect(orState.primaryQuota?.source, DataSourceBadge.official);
      expect(orState.primaryQuota?.total, 10.0);
      expect(orState.primaryQuota?.remaining, 7.5);

      final groqModel = AiModelRegistry.discoverModels()
          .firstWhere((m) => m.modelId == 'openai/gpt-oss-120b');
      final groqState = QuotaCalculationEngine.evaluateModel(
        model: groqModel,
        records: const [],
        todayRecords: const [],
        latestRateHeaders: const {
          'x-ratelimit-limit-requests': '1000',
          'x-ratelimit-remaining-requests': '940',
        },
      );
      expect(groqState.primaryQuota?.source, DataSourceBadge.official);
      expect(groqState.primaryQuota?.used, 60.0);
      expect(groqState.primaryQuota?.remaining, 940.0);
    });

    test('QuotaCalculationEngine produces range estimates when official RPD is unavailable', () {
      final geminiModel = AiModelRegistry.discoverModels()
          .firstWhere((m) => m.modelId == 'gemini-2.5-flash');
      final state = QuotaCalculationEngine.evaluateModel(
        model: geminiModel,
        records: const [],
        todayRecords: const [],
      );
      expect(state.primaryQuota?.source, DataSourceBadge.estimated);
      expect(state.primaryQuota?.isRangeEstimate, isTrue);
      expect(state.primaryQuota?.totalMin, 250);
      expect(state.primaryQuota?.totalMax, 1500);
    });

    test('AiTelemetryService deduplicates requestIds and isolates provider adapter failures', () async {
      await AiTelemetryService.recordFromGateway(
        requestId: 'req_unique_1',
        featureName: 'Study Assistant (Sage)',
        callbackRoute: 'AiGatewayClient.chat(heavy_reasoning)',
        fallbackProvider: 'groq',
        fallbackModel: 'openai/gpt-oss-120b',
        promptChars: 400,
        responseChars: 800,
        status: 'success',
        gatewayTelemetry: {
          'provider': 'gemini',
          'model': 'gemini-2.5-flash',
          'inputTokens': 110,
          'outputTokens': 220,
          'totalTokens': 330,
          'tokenSource': 'OFFICIAL',
          'fallbackUsed': true,
          'attemptCount': 2,
        },
      );
      await AiTelemetryService.recordFromGateway(
        requestId: 'req_unique_1',
        featureName: 'Study Assistant (Sage)',
        callbackRoute: 'AiGatewayClient.chat(heavy_reasoning)',
        fallbackProvider: 'groq',
        fallbackModel: 'openai/gpt-oss-120b',
        promptChars: 400,
        responseChars: 800,
        status: 'success',
      );

      final records = await AiTelemetryService.getRecords(range: MonitorDateRange.allTime);
      expect(records.length, 1);
      expect(records.first.provider, 'gemini');
      expect(records.first.modelId, 'gemini-2.5-flash');
      expect(records.first.totalTokens, 330);
      expect(records.first.tokenSource, DataSourceBadge.official);
      expect(records.first.fallbackUsed, isTrue);

      final snaps = ProviderQuotaAdapterRegistry.normalizeAll({
        'fetchedAt': DateTime.now().toIso8601String(),
        'providers': {
          'openrouter': {'status': 'UNAVAILABLE', 'error': 'HTTP 503'},
          'groq': {
            'status': 'OFFICIAL',
            'models': [
              {'id': 'openai/gpt-oss-120b', 'contextWindow': 131072}
            ],
          },
        },
      });
      expect(snaps['openrouter']?.status, DataSourceBadge.unavailable);
      expect(snaps['groq']?.status, DataSourceBadge.official);
      expect(snaps['groq']?.discoveredModelIds, contains('openai/gpt-oss-120b'));
    });
  });

  group('Unified Document Generation & 12-Style QA', () {
    const sampleDoc = StructuredStudyDocument(
      title: 'Cellular Respiration',
      subject: 'Biology',
      topic: 'Metabolism',
      purpose: 'Exam Study Guide',
      academicLevel: 'Course Level',
      executiveSummary: 'ATP synthesis via glycolysis, Krebs cycle, and oxidative phosphorylation.',
      learningObjectives: ['Explain glycolysis', 'Compare aerobic vs anaerobic yield'],
      sections: [
        StudySectionBlock(
          heading: 'Glycolysis',
          body: 'Occurs in the cytosol. Converts glucose into two pyruvate molecules. Produces 2 net ATP.',
          definitions: ['Substrate-level phosphorylation: direct ATP synthesis'],
          keyPoints: ['Investment phase uses 2 ATP', 'Payoff phase yields 4 ATP and 2 NADH'],
          examples: ['Muscle cells under hypoxia'],
          processSteps: ['Hexokinase', 'PFK-1', 'Pyruvate kinase'],
          tableRows: [
            ['Pathway', 'Location', 'Net ATP'],
            ['Glycolysis', 'Cytosol', '2 ATP'],
            ['Krebs Cycle', 'Mitochondrial Matrix', '2 GTP'],
          ],
          calloutWarning: 'PFK-1 is the committed rate-limiting step.',
        ),
      ],
      takeaways: ['Aerobic respiration yields ~30-32 ATP per glucose'],
    );

    test('All 4 PDF styles generate valid PDFs without leaking #### markers', () async {
      for (final opt in StylePickerSheet.pdfStyles) {
        final bytes = await PdfExporter.generateStudyGuidePdf(
          title: sampleDoc.title,
          subject: sampleDoc.subject,
          content: '#### Deep Heading\nBody text',
          structuredDoc: sampleDoc,
          style: PdfExporter.fromStyleId(opt.id),
        );
        expect(DocumentParserService.detectFormat(bytes, 'out.pdf'), ParsedDocFormat.pdf);
        expect(bytes.length, greaterThan(500));
      }
    });

    test('All 4 DOCX styles generate semantic DOCX with <w:tbl> tables', () {
      for (final opt in StylePickerSheet.docxStyles) {
        final bytes = DocxExporter.createDocument(
          title: sampleDoc.title,
          subject: sampleDoc.subject,
          content: '',
          structuredDoc: sampleDoc,
          style: DocxExporter.fromStyleId(opt.id),
        );
        expect(DocumentParserService.detectFormat(bytes, 'out.docx'), ParsedDocFormat.docx);
        final blocks = DocumentParserService.parseDocx(bytes);
        expect(blocks.any((b) => b.kind == 'table' && b.rows.length == 3), isTrue);
      }
    });

    test('All 4 PPTX styles use 16:9 widescreen and lossless slide splitting', () {
      final slides = DocumentPipelineService.toSlideDeck(sampleDoc);
      // 1 overview + >1 split slides for dense Glycolysis section + 1 takeaways
      expect(slides.length, greaterThanOrEqualTo(4));

      for (final opt in StylePickerSheet.pptxStyles) {
        final bytes = PptxExporter.createPresentation(
          presentationTitle: sampleDoc.title,
          slides: slides,
          style: PptxExporter.fromStyleId(opt.id),
        );
        expect(DocumentParserService.detectFormat(bytes, 'out.pptx'), ParsedDocFormat.pptx);
        expect(DocumentParserService.parsePptxAspectRatio(bytes), closeTo(16 / 9, 0.01));
        final parsed = DocumentParserService.parsePptx(bytes);
        expect(parsed.length, slides.length);
      }
    });

    test('DocumentGenerationService detects explicit user styles and returns null otherwise', () {
      expect(
        DocumentGenerationService.detectExplicitStyleId('Make a Handwritten Notes PDF', 'pdf'),
        'handwritten_notes',
      );
      expect(
        DocumentGenerationService.detectExplicitStyleId('Create a PDF of chapter 2', 'pdf'),
        isNull,
      );
      expect(
        DocumentGenerationService.detectExplicitStyleId('Build an Infographic Presentation', 'pptx'),
        'infographic_presentation',
      );
    });

    test('GenerationJob persists 7 honest pipeline stages and recovers interrupted state', () {
      expect(GenerationJob.pipelineStages.length, 7);
      final interrupted = GenerationJob.fromMap({
        'jobId': 'job_1',
        'userId': 'u1',
        'subject': 'Microbiology',
        'notebookId': 'nb_1',
        'topic': 'Bacterial Cell Wall',
        'scopeLabel': 'Topic',
        'format': 'pdf',
        'styleId': 'handwritten_notes',
        'status': 'running',
        'stageIndex': 3,
        'stageLabel': 'Building & validating learning content...',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(interrupted.status, GenerationJobStatus.failed);
      expect(interrupted.errorMessage, contains('Retry'));
    });

    test('SageContextBuilder enforces subject isolation and discloses missing sources', () {
      final ctxNoSrc = SageContextBuilder.build(
        studentName: 'Asha',
        subject: 'Microbiology',
      );
      expect(ctxNoSrc.systemPrompt, contains('Microbiology'));
      expect(ctxNoSrc.systemPrompt, contains('No matching uploaded source excerpt'));

      final ctxWithSrc = SageContextBuilder.build(
        studentName: 'Asha',
        subject: 'Microbiology',
        retrievedExcerpts: const ['[Source: Chapter1.pdf]\nGram-positive bacteria have thick peptidoglycan.'],
      );
      expect(ctxWithSrc.systemPrompt, contains('VERIFIED SOURCE EXCERPTS'));
      expect(ctxWithSrc.systemPrompt, contains('peptidoglycan'));
    });

    test('DocumentGenerationService detects unreadable scanned PDF placeholders', () {
      expect(
        DocumentGenerationService.isUnreadableSourcePlaceholder(
          'Uploaded file: Book.pdf (112.0 MB). No selectable text could be extracted automatically.',
        ),
        isTrue,
      );
      expect(
        DocumentGenerationService.isUnreadableSourcePlaceholder(
          'Gram-positive bacteria possess a thick peptidoglycan cell wall.',
        ),
        isFalse,
      );
    });

    test('DocumentParserService preserves DOCX callout shading and accent colors', () {
      final bytes = DocxExporter.createDocument(
        title: 'Microbiology',
        subject: 'Biology',
        content: '# Cell Wall\nNote: Gram-positive stains purple.',
        style: DocxStudyStyle.professionalResearchReport,
      );
      final blocks = DocumentParserService.parseDocx(bytes);
      expect(blocks.any((b) => b.kind == 'title' && b.fillHex == '1E3A8A'), isTrue);
      expect(blocks.any((b) => b.kind == 'callout' && b.fillHex == 'EFF6FF'), isTrue);
    });

    test('DocumentParserService extracts PPTX tag and takeaway separately', () {
      final bytes = PptxExporter.createPresentation(
        presentationTitle: 'Microbiology',
        slides: const [
          PptxSlideData(
            title: 'Gram Stain',
            tag: 'DIAGNOSTICS',
            bulletPoints: ['Crystal violet primary stain', 'Safranin counterstain'],
            takeaway: 'Gram-positive retains purple crystal violet.',
          ),
        ],
      );
      final slides = DocumentParserService.parsePptx(bytes);
      expect(slides.length, 1);
      expect(slides.first.tag, 'DIAGNOSTICS');
      expect(slides.first.takeaway, contains('Gram-positive retains purple'));
      expect(slides.first.bullets.any((b) => b.contains('KEY TAKEAWAY')), isFalse);
    });

    test('Subject chat sessions preserve history and build cross-session mentor memory', () async {
      final tempDir = Directory.systemTemp.createTempSync('trueme_chat_test_');
      Hive.init(tempDir.path);
      if (!Hive.isBoxOpen(OfflineCacheService.chatBox)) {
        await Hive.openBox(OfflineCacheService.chatBox);
      }
      try {
        const scope = 'nb_physics_mem_test';
        final s1 = await OfflineCacheService.createChatSession(scope);
      await OfflineCacheService.saveChatHistory(scope, [
        {
          'id': 'm1',
          'isUser': true,
          'text': 'Explain Newton second law and friction',
          'timestamp': DateTime.now().toIso8601String(),
        },
        {
          'id': 'm2',
          'isUser': false,
          'text': 'F = ma and kinetic friction opposes motion.',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ], sessionId: s1);
      await OfflineCacheService.saveMentorMemory(scope, {
        'summary': '- Covered Newton laws\n- Needs practice on friction free-body diagrams',
      });

      final s2 = await OfflineCacheService.createChatSession(scope);
      expect(s2, isNot(equals(s1)));
      expect(OfflineCacheService.getChatHistory(scope, sessionId: s2), isEmpty);
      expect(OfflineCacheService.getChatHistory(scope, sessionId: s1).length, 2);

      final memoryBlock = OfflineCacheService.buildSubjectMentorMemoryBlock(
        scope,
        excludeSessionId: s2,
      );
      expect(memoryBlock, contains('Needs practice on friction'));
      expect(memoryBlock, contains('Explain Newton second law and friction'));

      final ctx = SageContextBuilder.build(
        studentName: 'Aarav',
        subject: 'Physics',
        mentorMemory: memoryBlock,
        recentTurns: const ['Student: Ready for a new topic'],
      );
        expect(ctx.systemPrompt, contains('LONG-TERM SUBJECT MENTOR MEMORY'));
        expect(ctx.systemPrompt, contains('CURRENT CONVERSATION TURNS'));
      } finally {
        await Hive.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
