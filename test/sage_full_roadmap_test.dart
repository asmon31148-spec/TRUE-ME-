import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trueme/core/ai/answer_verifier.dart';
import 'package:trueme/core/ai/rag_service.dart';
import 'package:trueme/core/ai/retrieval_engine.dart';
import 'package:trueme/core/ai/sage_benchmark_service.dart';
import 'package:trueme/core/ai/sage_orchestrator.dart';
import 'package:trueme/core/ai/study_loop_service.dart';
import 'package:trueme/core/ai/syllabus_service.dart';
import 'package:trueme/core/models/document_chunk_model.dart';
import 'package:trueme/core/services/offline_cache_service.dart';
import 'package:trueme/core/services/supabase_service.dart';
import 'package:trueme/features/export/docx_exporter.dart';
import 'package:trueme/features/export/models/structured_study_document.dart';
import 'package:trueme/features/export/pdf_exporter.dart';
import 'package:trueme/features/export/pptx_exporter.dart';
import 'package:trueme/features/export/services/document_generation_service.dart';
import 'package:trueme/features/export/services/document_layout_validator.dart';

class _StubRagService extends RagService {
  _StubRagService() : super(supabaseService: SupabaseService.forTesting());

  @override
  Future<List<DocumentChunkModel>> retrieveContext({
    required String query,
    required String userId,
    String? notebookId,
    int topK = 5,
  }) async {
    return const [];
  }
}

void main() {
  group('SAGE-002 through SAGE-007 End-to-End Contracts', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('trueme_sage_full_');
      Hive.init(tempDir.path);
      if (!Hive.isBoxOpen(OfflineCacheService.notebooksBox)) {
        await Hive.openBox(OfflineCacheService.notebooksBox);
      }
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('SAGE-002 RetrievalEngine decomposes queries, rejects zero-score junk, and preserves provenance', () async {
      final sub = RetrievalEngine.decomposeQuery(
        'Compare Ascomycota and Basidiomycota reproduction',
      );
      expect(sub.length, greaterThanOrEqualTo(2));

      final engine = RetrievalEngine(ragService: _StubRagService());
      final docs = [
        {
          'fileName': 'Teacher_Fungi_Notes.pdf',
          'section': 'Notes',
          'content':
              'Ascomycota produce sexual ascospores inside an ascus. Basidiomycota produce basidiospores on a basidium.',
        },
        {
          'fileName': 'Unrelated_Physics.pdf',
          'section': 'Notes',
          'content': 'Ohm law relates voltage, current, and resistance in electrical circuits.',
        },
      ];

      final bundle = await engine.retrieveEvidence(
        query: 'Ascomycota vs Basidiomycota',
        userId: 'u1',
        notebookId: 'nb_botany',
        overrideLocalDocs: docs,
      );
      expect(bundle.hasSufficientEvidence, isTrue);
      expect(bundle.passages.length, 1);
      expect(bundle.passages.first.fileName, 'Teacher_Fungi_Notes.pdf');

      final uncovered = await engine.retrieveEvidence(
        query: 'Quantum chromodynamics gluons',
        userId: 'u1',
        notebookId: 'nb_botany',
        overrideLocalDocs: docs,
      );
      expect(uncovered.hasSufficientEvidence, isFalse);
      expect(uncovered.passages, isEmpty);
    });

    test('SAGE-003 SyllabusService maps sources, detects gaps, and distinguishes out-of-syllabus vs missing material', () async {
      const nbId = 'nb_fungi';
      await SyllabusService.saveSyllabusNodes(nbId, [
        {
          'id': 'top_1',
          'nodeType': 'topic',
          'title': 'Fungi Cell Wall and Chitin',
          'archived': false,
        },
        {
          'id': 'top_2',
          'nodeType': 'topic',
          'title': 'Mycorrhizal Symbiosis',
          'archived': false,
        },
        {
          'id': 'top_3',
          'nodeType': 'topic',
          'title': 'Fungal Secondary Metabolites',
          'archived': false,
        },
      ]);

      final docs = [
        {
          'fileName': 'Teacher_Fungi_Notes.pdf',
          'section': 'Notes',
          'content': 'Fungi cell wall is composed of chitin and glucan layers.',
        },
        {
          'fileName': 'Mixed_PYQ_2024.pdf',
          'section': 'Previous papers',
          'content': 'Q1: Explain fungi cell wall chitin structure (5 marks).',
        },
      ];

      final mappings = await SyllabusService.mapSourcesToTopics(nbId, overrideDocs: docs);
      expect(mappings, isNotEmpty);

      final topicMap = SyllabusService.getTopicKnowledgeMap(nbId, 'top_1');
      expect(topicMap['coverageStatus'], 'covered');
      expect((topicMap['pyqs'] as List).length, 1);

      expect(
        SyllabusService.classifyTopicStatus(nbId, 'Mycorrhizal Symbiosis',
            hasEvidenceInUploadedDocs: false),
        'in_syllabus_not_found_in_uploaded_material',
      );
      expect(
        SyllabusService.classifyTopicStatus(nbId, 'Astrophysics Black Holes',
            hasEvidenceInUploadedDocs: false),
        'not_part_of_the_syllabus',
      );

      final gaps = SyllabusService.detectDuplicateAndMissingTopics(nbId);
      expect(gaps['missingCoverage'], contains('Mycorrhizal Symbiosis'));
    });

    test('SAGE-004 SageOrchestrator classifies intent, scope boundaries, style constraints, and clarifications', () {
      final ambiguous = SageOrchestrator.classify(query: 'make a ppt');
      expect(ambiguous.intent, SageIntentType.exportPptx);
      expect(ambiguous.scopeMode, SageScopeMode.globalSage);
      expect(ambiguous.needsClarification, isTrue);

      final scoped = SageOrchestrator.classify(
        query: 'Create a handwritten cornell pdf from my teacher notes on Fungi',
        notebookId: 'nb_fungi',
        subject: 'Botany',
      );
      expect(scoped.intent, SageIntentType.exportPdf);
      expect(scoped.scopeMode, SageScopeMode.subjectSage);
      expect(scoped.sourcePriority, SourcePriority.teacherNotesFirst);
      expect(scoped.explicitStyleId, 'handwritten_notes');
      expect(scoped.needsClarification, isFalse);
    });

    test('SAGE-005 & SAGE-006 AnswerVerifier and DocumentGenerationService enforce provenance & gap disclosure', () async {
      const nbId = 'nb_fungi_v';
      await SyllabusService.saveSyllabusNodes(nbId, [
        {
          'id': 'top_chitin',
          'nodeType': 'topic',
          'title': 'Chitin Synthesis',
          'archived': false,
        },
      ]);

      final groundedReport = AnswerVerifier.verify(
        query: 'Chitin Synthesis',
        answer: 'Chitin synthesis occurs at the fungal plasma membrane using UDP-GlcNAc.',
        evidence: const EvidenceBundle(
          query: 'Chitin Synthesis',
          passages: [
            EvidencePassage(
              fileName: 'Fungi_Notes.pdf',
              sectionLabel: 'Notes',
              pageNumber: 4,
              chunkIndex: 0,
              content: 'Chitin synthesis occurs at the fungal plasma membrane using UDP-GlcNAc.',
              score: 0.9,
              retrievalMethod: 'lexical',
              relevanceReason: 'Matched 4/4 terms',
            ),
          ],
          hasSufficientEvidence: true,
          diagnosticNote: '1 passage',
        ),
        notebookId: nbId,
      );
      expect(groundedReport.trustLevel, EvidenceTrustLevel.grounded);
      expect(groundedReport.citedSources, contains('Fungi_Notes.pdf · Notes · p.4'));

      final gapReport = AnswerVerifier.verify(
        query: 'Chitin Synthesis',
        answer: 'General explanation',
        evidence: const EvidenceBundle(
          query: 'Chitin Synthesis',
          passages: [],
          hasSufficientEvidence: false,
          diagnosticNote: 'None',
        ),
        notebookId: nbId,
      );
      expect(gapReport.trustLevel, EvidenceTrustLevel.generalKnowledge);
      expect(gapReport.gapDisclosure, contains('in your syllabus'));

      expect(
        DocumentGenerationService.isUnreadableSourcePlaceholder(
          'Uploaded file: scan.pdf. No selectable text could be extracted automatically.',
        ),
        isTrue,
      );
    });

    test('SAGE-007 Reference Benchmark (Mixed PYQs + Fungi Material) passes all quality metrics', () async {
      const nbId = 'nb_bench';
      await SyllabusService.saveSyllabusNodes(nbId, [
        {'id': 't1', 'nodeType': 'topic', 'title': 'Fungi Cell Wall Chitin', 'archived': false},
        {'id': 't2', 'nodeType': 'topic', 'title': 'Ascomycota Ascospores', 'archived': false},
        {'id': 't3', 'nodeType': 'topic', 'title': 'Lichen Mutualism', 'archived': false},
      ]);

      final docs = [
        {
          'fileName': 'Teacher_Fungi_Lecture.pdf',
          'section': 'Notes',
          'content':
              'Fungi cell wall contains chitin and beta-glucans. Ascomycota form sexual ascospores inside an ascus.',
        },
        {
          'fileName': 'Mixed_PYQ_Paper.pdf',
          'section': 'Previous papers',
          'content':
              'Q1 (Fungi): Describe fungi cell wall chitin composition. Q2 (Physics): State Faraday law.',
        },
      ];

      final report = await SageBenchmarkService.evaluateRetrievalAndVerification(
        notebookId: nbId,
        docs: docs,
        retrievalEngine: RetrievalEngine(ragService: _StubRagService()),
        cases: const [
          SageBenchmarkCase(
            query: 'Fungi cell wall chitin',
            expectedKeywords: ['chitin', 'glucans'],
            expectSourceSupport: true,
            expectedTopicStatus: 'in_syllabus_and_covered',
          ),
          SageBenchmarkCase(
            query: 'Ascomycota ascospores',
            expectedKeywords: ['ascospores', 'ascus'],
            expectSourceSupport: true,
            expectedTopicStatus: 'in_syllabus_and_covered',
          ),
          SageBenchmarkCase(
            query: 'Lichen mutualism',
            expectedKeywords: [],
            expectSourceSupport: false,
            expectedTopicStatus: 'in_syllabus_not_found_in_uploaded_material',
          ),
          SageBenchmarkCase(
            query: 'Thermodynamics entropy',
            expectedKeywords: [],
            expectSourceSupport: false,
            expectedTopicStatus: 'not_part_of_the_syllabus',
          ),
        ],
      );

      expect(report.allPassed, isTrue, reason: report.failures.join('\n'));
      expect(report.retrievalRecall, 1.0);
      expect(report.citationPrecision, 1.0);
      expect(report.gapAbstentionScore, 1.0);
      expect(report.syllabusMappingAccuracy, 1.0);
    });

    test('Compound Orchestrator resolves subject, clarifies broad scope, and renders visual Mind Map PDF', () async {
      final notebooks = [
        {'id': 'nb_micro', 'title': 'Microbiology'},
        {'id': 'nb_chem', 'title': 'Chemistry'},
      ];
      final syllabus = [
        {'id': 'u1', 'nodeType': 'unit', 'title': 'Bacterial Genetics'},
        {'id': 'u2', 'nodeType': 'unit', 'title': 'Virology & Immunology'},
      ];

      // 1. Broad request from Main Sage asks concise clarification with quick replies
      final broadPlan = SageOrchestrator.classify(
        query: 'give me the mind map of my microbiology subject and send me as pdf',
        overrideNotebooks: notebooks,
        overrideSyllabusNodes: syllabus,
      );
      expect(broadPlan.resolvedNotebookId, 'nb_micro');
      expect(broadPlan.resolvedSubject, 'Microbiology');
      expect(broadPlan.intent, SageIntentType.mindmap);
      expect(broadPlan.secondaryOutputIntent, SageIntentType.exportPdf);
      expect(broadPlan.needsClarification, isTrue);
      expect(broadPlan.clarificationOptions.length, greaterThanOrEqualTo(2));

      // 2. Clarified request executes compound Mind Map -> PDF without re-asking
      final clarifiedPlan = SageOrchestrator.classify(
        query: 'Full Microbiology Mind Map PDF (complete syllabus)',
        overrideNotebooks: notebooks,
        overrideSyllabusNodes: syllabus,
      );
      expect(clarifiedPlan.needsClarification, isFalse);
      expect(clarifiedPlan.isCompound, isTrue);
      expect(clarifiedPlan.intent, SageIntentType.mindmap);
      expect(clarifiedPlan.secondaryOutputIntent, SageIntentType.exportPdf);

      // 3. Visual Mind Map PDF renders valid %PDF bytes
      final pdfBytes = await PdfExporter.generateMindmapPdf(
        title: 'Microbiology Overview',
        subject: 'Microbiology',
        mindmapData: {
          'root': 'Microbiology Overview',
          'branches': [
            {
              'title': 'Bacterial Genetics',
              'summary': 'Gene transfer mechanisms',
              'children': [
                {'title': 'Conjugation', 'summary': 'F-plasmid transfer via pilus'},
                {'title': 'Transduction', 'summary': 'Bacteriophage-mediated transfer'},
              ],
            },
          ],
        },
      );
      expect(pdfBytes.length, greaterThan(500));
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });

    test('Layout Brain optimizes 16:9 PPTX flowcharts, tables, and PDF sketchy diagrams', () async {
      final rawSlides = [
        const PptxSlideData(
          title: 'Cell Biology',
          subtitle: 'Biology · Course Level',
          bulletPoints: ['Understand organelles', 'Compare prokaryotes and eukaryotes'],
        ),
        const PptxSlideData(
          title: 'Mitosis Phases',
          bulletPoints: [],
          processSteps: ['Prophase', 'Metaphase', 'Anaphase', 'Telophase'],
        ),
        const PptxSlideData(
          title: 'Prokaryote vs Eukaryote',
          bulletPoints: [],
          tableRows: [
            ['Feature', 'Prokaryote', 'Eukaryote'],
            ['Nucleus', 'Absent', 'Present'],
            ['Ribosomes', '70S', '80S'],
          ],
        ),
      ];

      final validated = DocumentLayoutValidator.validateAndOptimizeSlides(rawSlides);
      expect(validated.slides[0].layoutKind, SlideLayoutKind.cover);
      expect(validated.slides[1].layoutKind, SlideLayoutKind.flowchart);
      expect(validated.slides[2].layoutKind, SlideLayoutKind.table);
      expect(validated.report.score, greaterThanOrEqualTo(85));

      final pptxBytes = PptxExporter.createPresentation(
        presentationTitle: 'Cell Biology',
        slides: rawSlides,
        style: PptxExporter.fromStyleId('dark_neon'),
        backgroundImageBytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );
      final archive = ZipDecoder().decodeBytes(pptxBytes);
      expect(archive.any((f) => f.name == 'ppt/media/theme_bg.png'), isTrue);
      final presXml = utf8.decode(
        archive.firstWhere((f) => f.name == 'ppt/presentation.xml').content as List<int>,
      );
      expect(presXml, contains('cx="12192000" cy="6858000"'));

      final flowXml = utf8.decode(
        archive.firstWhere((f) => f.name == 'ppt/slides/slide2.xml').content as List<int>,
      );
      expect(flowXml, contains('prst="rightArrow"'));

      final tableXml = utf8.decode(
        archive.firstWhere((f) => f.name == 'ppt/slides/slide3.xml').content as List<int>,
      );
      expect(tableXml, contains('<a:tbl>'));

      final doc = const StructuredStudyDocument(
        title: 'Cell Biology',
        subject: 'Biology',
        topic: 'Cell Division',
        purpose: 'Study Guide',
        academicLevel: 'Course Level',
        executiveSummary: 'Overview of cell division.',
        sections: [
          StudySectionBlock(
            heading: 'Mitosis',
            body: 'Cell division produces two identical daughter cells.',
            processSteps: ['Prophase', 'Metaphase', 'Anaphase', 'Telophase'],
            diagramSvg: '<svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg"><circle cx="50" cy="40" r="24" fill="#EDE9FE" stroke="#6D28D9" stroke-width="2"/><text x="50" y="44" text-anchor="middle" font-size="10">Cell</text></svg>',
          ),
        ],
      );
      final pdfBytes = await PdfExporter.generateStudyGuidePdf(
        title: doc.title,
        subject: doc.subject,
        content: doc.toStructuredMarkdown(),
        structuredDoc: doc,
        style: PdfStudyStyle.handwritten,
      );
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });

    test('Phases 1-3: PPTX/DOCX diagram embedding, inline citations & Mistake Bank loop', () async {
      final pngStub = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3, 4]);

      // Phase 1: PPTX & DOCX diagram PNG embedding
      final pptxBytes = PptxExporter.createPresentation(
        presentationTitle: 'Cell Biology',
        slides: const [
          PptxSlideData(title: 'Cover', bulletPoints: ['Overview']),
          PptxSlideData(title: 'Organelles', bulletPoints: ['Mitochondria produces ATP']),
        ],
        slideDiagramImages: {1: pngStub},
      );
      final pptxZip = ZipDecoder().decodeBytes(pptxBytes);
      expect(pptxZip.any((f) => f.name == 'ppt/media/diagram_2.png'), isTrue);

      const citedDoc = StructuredStudyDocument(
        title: 'Cell Biology',
        subject: 'Biology',
        topic: 'Organelles',
        purpose: 'Study Guide',
        academicLevel: 'Course Level',
        executiveSummary: 'Summary',
        sections: [
          StudySectionBlock(
            heading: 'Mitochondria',
            body: 'Powerhouse of the cell.',
            citations: ['Lecture2.pdf (p. 4)'],
          ),
        ],
      );
      final docxBytes = DocxExporter.createDocument(
        title: citedDoc.title,
        subject: citedDoc.subject,
        content: '',
        structuredDoc: citedDoc,
        sectionDiagramImages: {0: pngStub},
      );
      final docxZip = ZipDecoder().decodeBytes(docxBytes);
      expect(docxZip.any((f) => f.name == 'word/media/diagram_1.png'), isTrue);
      final docXml = utf8.decode(
        docxZip.firstWhere((f) => f.name == 'word/document.xml').content as List<int>,
      );
      expect(docXml, contains('<w:drawing>'));
      expect(docXml, contains('Lecture2.pdf (p. 4)'));

      // Phase 3: Mistake Bank -> Flashcard -> Weakest Topic
      await StudyLoopService.recordQuizMistake(
        subject: 'Biology',
        notebookId: 'nb_bio',
        topic: 'Glycolysis',
        question: 'Which enzyme catalyzes the committed step of glycolysis?',
        wrongAnswer: 'Hexokinase',
        correctAnswer: 'PFK-1',
        explanation: 'PFK-1 is the rate-limiting committed step.',
      );
      final mistakes = await StudyLoopService.getMistakes(subject: 'Biology');
      expect(mistakes, isNotEmpty);
      final card = await StudyLoopService.convertMistakeToFlashcard(mistakes.first);
      expect(card.back, contains('PFK-1'));
      final rec = await StudyLoopService.findWeakestTopic(
        userId: 'test_user',
        subjectId: 'Biology',
      );
      expect(rec, isNotNull);
      expect(rec!.topic, 'Glycolysis');
    });
  });
}
