import 'dart:async';
import 'package:flutter/foundation.dart';
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
}

/// Non-blocking background ingestion queue for uploaded sources (chunk -> batch_embed -> verify).
/// Allows AddFilesSheet to return immediately while indexing continues with live progress.
class IngestionJobService {
  IngestionJobService._();

  static final ValueNotifier<List<IngestionJob>> jobsNotifier =
      ValueNotifier<List<IngestionJob>>([]);
  static final List<VoidCallback> _completionListeners = [];
  static bool _isPumping = false;

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

  static void _upsertJob(IngestionJob job) {
    final list = List<IngestionJob>.from(jobsNotifier.value);
    final idx = list.indexWhere((j) => j.jobId == job.jobId);
    if (idx >= 0) {
      list[idx] = job;
    } else {
      list.insert(0, job);
    }
    jobsNotifier.value = list;
  }

  /// Queues a document for background chunking, embedding, and verification.
  /// Returns immediately so the upload UI never blocks.
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
