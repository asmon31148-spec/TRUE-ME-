import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../ai/rag_service.dart';
import '../ai/smai/memory_event_service.dart';
import '../ai/smai/smai_models.dart';
import '../models/ingestion_models.dart';
import 'offline_cache_service.dart';

enum IngestionJobStage { queued, running, done, failed }

class IngestionJob {
  final String jobId;
  final String notebookId;
  final String docId;
  final String fileName;
  final String sectionLabel;
  final String fileType;
  final String subjectName;
  final String fullText;
  final List<ExtractedPage>? pages;
  final ExtractionQualityReport? qualityReport;
  final IngestionJobStage status;
  final double progress;
  final String stageLabel;
  final String? errorMessage;

  const IngestionJob({
    required this.jobId,
    required this.notebookId,
    required this.docId,
    required this.fileName,
    required this.sectionLabel,
    required this.fileType,
    required this.subjectName,
    required this.fullText,
    this.pages,
    this.qualityReport,
    this.status = IngestionJobStage.queued,
    this.progress = 0.10,
    this.stageLabel = 'Queued for background indexing...',
    this.errorMessage,
  });

  IngestionJob copyWith({
    IngestionJobStage? status,
    double? progress,
    String? stageLabel,
    String? errorMessage,
  }) {
    return IngestionJob(
      jobId: jobId,
      notebookId: notebookId,
      docId: docId,
      fileName: fileName,
      sectionLabel: sectionLabel,
      fileType: fileType,
      subjectName: subjectName,
      fullText: fullText,
      pages: pages,
      qualityReport: qualityReport,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      stageLabel: stageLabel ?? this.stageLabel,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'jobId': jobId,
        'notebookId': notebookId,
        'docId': docId,
        'fileName': fileName,
        'sectionLabel': sectionLabel,
        'fileType': fileType,
        'subjectName': subjectName,
        'status': status.name,
        'progress': progress,
        'stageLabel': stageLabel,
        'errorMessage': errorMessage,
      };

  static IngestionJob? fromHiveMap(Map<String, dynamic> m) {
    final notebookId = m['notebookId']?.toString() ?? '';
    final docId = m['docId']?.toString() ?? '';
    if (notebookId.isEmpty || docId.isEmpty) return null;

    final docs = OfflineCacheService.getNotebookDocuments(notebookId);
    final doc = docs.where((d) => d['id']?.toString() == docId).firstOrNull;
    final fullText = doc?['content']?.toString() ?? '';
    if (fullText.trim().length < 20) return null;

    final rawStatus = m['status']?.toString() ?? 'queued';
    final status = IngestionJobStage.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => IngestionJobStage.queued,
    );

    return IngestionJob(
      jobId: m['jobId']?.toString() ?? 'ing_$docId',
      notebookId: notebookId,
      docId: docId,
      fileName: m['fileName']?.toString() ?? doc?['fileName']?.toString() ?? 'Document',
      sectionLabel: m['sectionLabel']?.toString() ?? doc?['section']?.toString() ?? 'Notes',
      fileType: m['fileType']?.toString() ?? doc?['fileType']?.toString() ?? 'pdf',
      subjectName: m['subjectName']?.toString() ?? 'Subject',
      fullText: fullText,
      status: status == IngestionJobStage.running ? IngestionJobStage.queued : status,
      progress: (m['progress'] as num?)?.toDouble() ?? 0.10,
      stageLabel: m['stageLabel']?.toString() ?? 'Resuming background indexing...',
      errorMessage: m['errorMessage']?.toString(),
    );
  }
}

/// Hive-persisted non-blocking background ingestion queue (chunk -> batch_embed -> verify).
/// Survives modal dismissal and app restarts; supports retry and batch re-indexing.
class IngestionJobService {
  IngestionJobService._();

  static const String _boxName = 'ingestion_jobs_box';
  static const String _jobsKey = 'jobs';

  static final ValueNotifier<List<IngestionJob>> jobsNotifier =
      ValueNotifier<List<IngestionJob>>([]);
  static final List<VoidCallback> _completionListeners = [];
  static bool _isPumping = false;
  static bool _restored = false;

  static void addCompletionListener(VoidCallback listener) {
    if (!_completionListeners.contains(listener)) {
      _completionListeners.add(listener);
    }
  }

  static void removeCompletionListener(VoidCallback listener) {
    _completionListeners.remove(listener);
  }

  static void _notifyCompletion() {
    for (final listener in List<VoidCallback>.from(_completionListeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  static Future<void> _persist() async {
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      final activeOrRecent = jobsNotifier.value
          .where((j) => j.status != IngestionJobStage.done)
          .take(25)
          .map((j) => j.toHiveMap())
          .toList();
      await box.put(_jobsKey, activeOrRecent);
    } catch (_) {
      // Safe no-op in tests where Hive is not initialized
    }
  }

  static Future<void> restoreAndResume() async {
    if (_restored) return;
    _restored = true;
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      final raw = box.get(_jobsKey) as List? ?? [];
      final restored = <IngestionJob>[];
      for (final item in raw) {
        if (item is Map) {
          final job = IngestionJob.fromHiveMap(Map<String, dynamic>.from(item));
          if (job != null && job.status != IngestionJobStage.done) {
            restored.add(job);
          }
        }
      }
      if (restored.isNotEmpty) {
        final merged = List<IngestionJob>.from(jobsNotifier.value);
        for (final r in restored) {
          if (!merged.any((m) => m.docId == r.docId)) {
            merged.add(r);
          }
        }
        jobsNotifier.value = merged;
        unawaited(_pumpQueue());
      }
    } catch (_) {}
  }

  static void _upsertJob(IngestionJob job) {
    final list = List<IngestionJob>.from(jobsNotifier.value);
    final idx = list.indexWhere((j) => j.jobId == job.jobId);
    if (idx >= 0) {
      list[idx] = job;
    } else {
      list.insert(0, job);
    }
    jobsNotifier.value = list;
    unawaited(_persist());
  }

  /// Queues a document for background chunking, embedding, and verification.
  static IngestionJob enqueue({
    required String notebookId,
    required String docId,
    required String fileName,
    required String sectionLabel,
    required String fileType,
    required String subjectName,
    required String fullText,
    List<ExtractedPage>? pages,
    ExtractionQualityReport? qualityReport,
  }) {
    final job = IngestionJob(
      jobId: 'ing_${DateTime.now().millisecondsSinceEpoch}_${docId.hashCode}',
      notebookId: notebookId,
      docId: docId,
      fileName: fileName,
      sectionLabel: sectionLabel,
      fileType: fileType,
      subjectName: subjectName,
      fullText: fullText,
      pages: pages,
      qualityReport: qualityReport,
    );
    _upsertJob(job);
    unawaited(_pumpQueue());
    return job;
  }

  static void retryJob(String jobId) {
    final idx = jobsNotifier.value.indexWhere((j) => j.jobId == jobId);
    if (idx < 0) return;
    final job = jobsNotifier.value[idx];
    _upsertJob(job.copyWith(
      status: IngestionJobStage.queued,
      progress: 0.10,
      stageLabel: 'Retrying "${job.fileName}"...',
      errorMessage: null,
    ));
    unawaited(_pumpQueue());
  }

  static int enqueuePendingDocsForNotebook(String notebookId, String subjectName) {
    final docs = OfflineCacheService.getNotebookDocuments(notebookId);
    int count = 0;
    for (final doc in docs) {
      final status = (doc['ingestionStatus']?.toString() ?? '').toLowerCase();
      final needsSync = status == 'partial' || status == 'failed';
      final content = doc['content']?.toString() ?? '';
      final docId = doc['id']?.toString() ?? '';
      if (!needsSync || content.trim().length < 20 || docId.isEmpty) continue;
      final alreadyActive = jobsNotifier.value.any(
        (j) =>
            j.docId == docId &&
            (j.status == IngestionJobStage.queued || j.status == IngestionJobStage.running),
      );
      if (alreadyActive) continue;
      enqueue(
        notebookId: notebookId,
        docId: docId,
        fileName: doc['fileName']?.toString() ?? 'Document',
        sectionLabel: doc['section']?.toString() ?? 'Notes',
        fileType: doc['fileType']?.toString() ?? 'pdf',
        subjectName: subjectName,
        fullText: content,
      );
      count++;
    }
    return count;
  }

  static Future<void> _pumpQueue() async {
    if (_isPumping) return;
    _isPumping = true;
    try {
      while (true) {
        final next = jobsNotifier.value
            .where((j) => j.status == IngestionJobStage.queued)
            .lastOrNull;
        if (next == null) break;

        var current = next.copyWith(
          status: IngestionJobStage.running,
          progress: 0.15,
          stageLabel: 'Chunking "${next.fileName}"...',
        );
        _upsertJob(current);

        try {
          final ingestResult = await RagService().ingestDocumentWithVerification(
            userId: OfflineCacheService.getUserId(),
            notebookId: next.notebookId,
            fileName: next.fileName,
            fullText: next.fullText,
            pages: next.pages,
            sectionLabel: next.sectionLabel,
            onStage: (stage) {
              final pct = stage == IngestionStatus.chunking
                  ? 0.25
                  : (stage == IngestionStatus.embedding
                      ? 0.40
                      : (stage == IngestionStatus.verifying ? 0.94 : current.progress));
              current = current.copyWith(
                progress: pct,
                stageLabel: '${stage.displayLabel} "${next.fileName}"...',
              );
              _upsertJob(current);
            },
            onProgress: (done, total) {
              final pct = total > 0 ? (0.40 + 0.50 * (done / total)) : 0.65;
              current = current.copyWith(
                progress: pct.clamp(0.40, 0.92),
                stageLabel: 'Indexing "${next.fileName}" ($done/$total chunks)...',
              );
              _upsertJob(current);
            },
          );

          await OfflineCacheService.updateDocumentIngestionState(
            next.notebookId,
            next.docId,
            ingestionStatus: ingestResult.status.name,
            qualityReport: next.qualityReport?.toMap(),
            chunksCount: ingestResult.chunksCreated,
            chunksVerified: ingestResult.chunksVerified,
            ingestionError: ingestResult.errorMessage,
          );

          unawaited(
            MemoryEventService.capture(
              eventType: SmaiEventType.sourceProcessed,
              idempotencyKey: 'src_${next.docId}',
              subjectId: next.notebookId,
              provenanceRefs: [next.fileName],
              payload: {
                'docId': next.docId,
                'fileName': next.fileName,
                'section': next.sectionLabel,
                'fileType': next.fileType,
                'ingestionStatus': ingestResult.status.name,
                'chunksVerified': ingestResult.chunksVerified,
              },
              searchText: '${next.fileName} ${next.sectionLabel} ${next.subjectName}',
            ).catchError((_) => LearningEvent(
                  id: '',
                  userId: '',
                  eventType: SmaiEventType.sourceProcessed,
                  idempotencyKey: 'err',
                  occurredAt: DateTime.now(),
                )),
          );

          _upsertJob(current.copyWith(
            status: IngestionJobStage.done,
            progress: 1.0,
            stageLabel: 'Indexed ${ingestResult.chunksVerified} chunks',
          ));
          _notifyCompletion();
        } catch (e) {
          await OfflineCacheService.updateDocumentIngestionState(
            next.notebookId,
            next.docId,
            ingestionStatus: IngestionStatus.failed.name,
            qualityReport: next.qualityReport?.toMap(),
            chunksCount: 0,
            chunksVerified: 0,
            ingestionError: e.toString(),
          );
          _upsertJob(current.copyWith(
            status: IngestionJobStage.failed,
            stageLabel: 'Indexing failed',
            errorMessage: e.toString(),
          ));
          _notifyCompletion();
        }
      }
    } finally {
      _isPumping = false;
    }
  }
}
