import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
import 'document_generation_service.dart';

enum GenerationJobStatus { queued, running, ready, failed }

class GenerationJob {
  final String jobId;
  final String userId;
  final String subject;
  final String notebookId;
  final String topic;
  final String scopeLabel;
  final String format;
  final String styleId;
  final GenerationJobStatus status;
  final int stageIndex; // 0..6
  final String stageLabel;
  final String? filePath;
  final String? title;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GenerationJob({
    required this.jobId,
    required this.userId,
    required this.subject,
    required this.notebookId,
    required this.topic,
    required this.scopeLabel,
    required this.format,
    required this.styleId,
    required this.status,
    required this.stageIndex,
    required this.stageLabel,
    this.filePath,
    this.title,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  static const List<String> pipelineStages = [
    'Understanding request & selected scope...',
    'Loading selected syllabus & source material...',
    'Extracting, chunking & analyzing source content...',
    'Building & validating learning content...',
    'Applying selected document design...',
    'Rendering & checking final file...',
    'Saving artifact to Study Library...',
  ];

  GenerationJob copyWith({
    GenerationJobStatus? status,
    int? stageIndex,
    String? stageLabel,
    String? filePath,
    String? title,
    String? errorMessage,
  }) {
    return GenerationJob(
      jobId: jobId,
      userId: userId,
      subject: subject,
      notebookId: notebookId,
      topic: topic,
      scopeLabel: scopeLabel,
      format: format,
      styleId: styleId,
      status: status ?? this.status,
      stageIndex: stageIndex ?? this.stageIndex,
      stageLabel: stageLabel ?? this.stageLabel,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'userId': userId,
        'subject': subject,
        'notebookId': notebookId,
        'topic': topic,
        'scopeLabel': scopeLabel,
        'format': format,
        'styleId': styleId,
        'status': status.name,
        'stageIndex': stageIndex,
        'stageLabel': stageLabel,
        if (filePath != null) 'filePath': filePath,
        if (title != null) 'title': title,
        if (errorMessage != null) 'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GenerationJob.fromMap(Map<String, dynamic> m) {
    final statusStr = m['status']?.toString() ?? 'failed';
    final parsedStatus = GenerationJobStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => GenerationJobStatus.failed,
    );
    return GenerationJob(
      jobId: m['jobId']?.toString() ?? '',
      userId: m['userId']?.toString() ?? '',
      subject: m['subject']?.toString() ?? 'Study',
      notebookId: m['notebookId']?.toString() ?? '',
      topic: m['topic']?.toString() ?? '',
      scopeLabel: m['scopeLabel']?.toString() ?? 'Subject Sources',
      format: m['format']?.toString() ?? 'pdf',
      styleId: m['styleId']?.toString() ?? 'handwritten_notes',
      status: parsedStatus == GenerationJobStatus.running || parsedStatus == GenerationJobStatus.queued
          ? GenerationJobStatus.failed // Interrupted by process death before completion
          : parsedStatus,
      stageIndex: (m['stageIndex'] as num? ?? 0).toInt(),
      stageLabel: m['stageLabel']?.toString() ?? 'Interrupted — tap retry',
      filePath: m['filePath']?.toString(),
      title: m['title']?.toString(),
      errorMessage: parsedStatus == GenerationJobStatus.running
          ? 'App closed before completion. Retry to regenerate.'
          : m['errorMessage']?.toString(),
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Durable, widget-lifecycle-independent generation job runner.
/// Jobs survive page navigation and app switching; state is persisted in Hive.
class GenerationJobService {
  GenerationJobService._();
  static const String _boxName = 'trueme_generation_jobs_v1';
  static const String _jobsKey = 'jobs';

  static final ValueNotifier<List<GenerationJob>> jobsNotifier = ValueNotifier([]);
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
      final raw = box.get(_jobsKey);
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        jobsNotifier.value = decoded
            .map((e) => GenerationJob.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
  }

  static Future<void> _persist() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final box = Hive.box(_boxName);
      await box.put(
        _jobsKey,
        jsonEncode(jobsNotifier.value.take(25).map((j) => j.toMap()).toList()),
      );
    } catch (_) {}
  }

  static void _upsertJob(GenerationJob job) {
    final list = [...jobsNotifier.value];
    final idx = list.indexWhere((j) => j.jobId == job.jobId);
    if (idx >= 0) {
      list[idx] = job;
    } else {
      list.insert(0, job);
    }
    jobsNotifier.value = list;
    _persist();
  }

  static Future<GeneratedDocumentResult?> runDurableJob({
    required AiRouter aiRouter,
    required String format,
    required String styleId,
    required String subject,
    required String topic,
    required String scopeLabel,
    String? notebookId,
    String? sourceContext,
    String? nodeId,
    String? sourceChatId,
    String depthLevel = 'Course Level',
  }) async {
    await ensureInitialized();
    final jobId = 'job_${format}_${DateTime.now().millisecondsSinceEpoch}';
    final userId = OfflineCacheService.getUserId();

    var current = GenerationJob(
      jobId: jobId,
      userId: userId,
      subject: subject,
      notebookId: notebookId ?? '',
      topic: topic,
      scopeLabel: scopeLabel,
      format: format,
      styleId: styleId,
      status: GenerationJobStatus.running,
      stageIndex: 0,
      stageLabel: GenerationJob.pipelineStages[0],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _upsertJob(current);

    try {
      final res = await DocumentGenerationService.generateAndSave(
        aiRouter: aiRouter,
        format: format,
        styleId: styleId,
        subject: subject,
        topic: topic,
        notebookId: notebookId,
        sourceContext: sourceContext,
        nodeId: nodeId,
        sourceChatId: sourceChatId,
        depthLevel: depthLevel,
        idempotencyKey: jobId,
        onStageChanged: (idx, label) {
          current = current.copyWith(
            status: GenerationJobStatus.running,
            stageIndex: idx,
            stageLabel: label,
          );
          _upsertJob(current);
        },
      );

      current = current.copyWith(
        status: GenerationJobStatus.ready,
        stageIndex: 6,
        stageLabel: 'Ready in Study Library',
        filePath: res.filePath,
        title: res.title,
      );
      _upsertJob(current);
      return res;
    } catch (e) {
      current = current.copyWith(
        status: GenerationJobStatus.failed,
        errorMessage: e.toString(),
        stageLabel: 'Generation failed',
      );
      _upsertJob(current);
      rethrow;
    }
  }
}
