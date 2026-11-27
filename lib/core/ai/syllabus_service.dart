import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/offline_cache_service.dart';
import '../services/supabase_service.dart';
import '../utils/text_chunker.dart';
import 'ai_router.dart';

/// Syllabus-first hierarchy & source coverage service (Phases C & D).
/// Stores syllabus nodes (`semester -> unit -> topic -> subtopic`),
/// source-to-syllabus coverage mappings, and saved study artifacts per subject.
class SyllabusService {
  SyllabusService._();

  static const String _syllabusBoxPrefix = 'syllabus_nodes_';
  static const String _mappingBoxPrefix = 'source_mappings_';
  static const String _artifactBoxPrefix = 'study_artifacts_';

  static Box get _notebooksBox => Hive.box(OfflineCacheService.notebooksBox);

  static List<Map<String, dynamic>> getSyllabusNodes(String notebookId, {bool includeArchived = false}) {
    try {
      final raw = _notebooksBox.get('$_syllabusBoxPrefix$notebookId') as List? ?? [];
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (includeArchived) return list;
      return list.where((n) => n['archived'] != true).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSyllabusNodes(String notebookId, List<Map<String, dynamic>> nodes) async {
    await _notebooksBox.put('$_syllabusBoxPrefix$notebookId', nodes);
    unawaited(_syncNodesToSupabase(notebookId, nodes));
  }

  static List<Map<String, dynamic>> getSourceMappings(String notebookId) {
    try {
      final raw = _notebooksBox.get('$_mappingBoxPrefix$notebookId') as List? ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSourceMappings(String notebookId, List<Map<String, dynamic>> mappings) async {
    await _notebooksBox.put('$_mappingBoxPrefix$notebookId', mappings);
  }

  /// Saved Study Artifacts per subject (PDF, Word, Slides, Summary, Mind Map, Explainer, Quiz, Flashcards).
  static List<Map<String, dynamic>> getArtifacts(String notebookId, {String? artifactType}) {
    try {
      final raw = _notebooksBox.get('$_artifactBoxPrefix$notebookId') as List? ?? [];
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (artifactType == null || artifactType.isEmpty) return list;
      return list.where((a) => a['artifactType'] == artifactType).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveArtifact({
    String? documentId,
    required String notebookId,
    required String artifactType,
    required String title,
    String? nodeId,
    String? topicLabel,
    String? depthLevel,
    String? styleId,
    String? styleVersion,
    String? filePath,
    int? fileSize,
    int? pageCount,
    int? slideCount,
    String generationState = 'ready',
    String? vaultId,
    String? sourceChatId,
    List<String>? sourceRefs,
    Map<String, dynamic>? contentJson,
  }) async {
      final existing = getArtifacts(notebookId);
      final id = documentId ?? 'art_${DateTime.now().millisecondsSinceEpoch}';
      final entry = {
        'id': id,
        'documentId': id,
        'notebookId': notebookId,
        'nodeId': nodeId,
        'artifactType': artifactType,
        'title': title,
        'topicLabel': topicLabel ?? title,
        'depthLevel': depthLevel ?? 'standard',
        if (styleId != null) 'styleId': styleId,
        if (styleVersion != null) 'styleVersion': styleVersion,
        if (filePath != null) 'filePath': filePath,
        if (fileSize != null) 'fileSize': fileSize,
        if (pageCount != null) 'pageCount': pageCount,
        if (slideCount != null) 'slideCount': slideCount,
        'generationState': generationState,
        if (vaultId != null) 'vaultId': vaultId,
        if (sourceChatId != null) 'sourceChatId': sourceChatId,
        if (sourceRefs != null && sourceRefs.isNotEmpty) 'sourceRefs': sourceRefs,
        if (contentJson != null) 'contentJson': contentJson,
        'archived': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      final idx = existing.indexWhere((a) => a['id'] == id || a['documentId'] == id);
      if (idx >= 0) {
        existing[idx] = entry;
      } else {
        existing.insert(0, entry);
      }
      if (existing.length > 150) existing.removeRange(150, existing.length);
      await _notebooksBox.put('$_artifactBoxPrefix$notebookId', existing);
      unawaited(_syncArtifactToSupabase(entry));
  }

  static Future<void> _syncArtifactToSupabase(Map<String, dynamic> entry) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null) return;
      await client.from('study_artifacts').upsert({
        'id': entry['id'],
        'user_id': uid,
        'notebook_id': entry['notebookId'],
        'node_id': entry['nodeId'],
        'artifact_type': entry['artifactType'],
        'title': entry['title'],
        'topic_label': entry['topicLabel'],
        'depth_level': entry['depthLevel'],
        'file_path': entry['filePath'],
        'vault_id': entry['vaultId'],
        'source_chat_id': entry['sourceChatId'],
        'content_json': entry['contentJson'],
        'archived': entry['archived'] == true,
      });
    } catch (_) {}
  }

  static Future<void> _syncNodesToSupabase(
    String notebookId,
    List<Map<String, dynamic>> nodes,
  ) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || nodes.isEmpty) return;
      final payload = nodes.map((n) => {
        'id': n['id'],
        'user_id': uid,
        'notebook_id': notebookId,
        'parent_id': n['parentId'],
        'node_type': n['nodeType'],
        'title': n['title'],
        'academic_level': n['academicLevel'],
        'source_origin': n['sourceOrigin'] ?? 'official_syllabus',
        'status': n['status'] ?? 'pending',
        'confirmed': n['confirmed'] == true,
        'archived': n['archived'] == true,
        'sort_order': n['sortOrder'] ?? 0,
      }).toList();
      await client.from('syllabus_nodes').upsert(payload);
    } catch (_) {}
  }

  /// Extracts a `semester -> unit -> topic -> subtopic` hierarchy from an uploaded syllabus.
  /// Chunks long syllabi so units are not silently truncated.
  static Future<List<Map<String, dynamic>>> extractAndSaveSyllabus({
    required AiRouter aiRouter,
    required String notebookId,
    required String subject,
    required String syllabusText,
  }) async {
    final trimmed = syllabusText.trim();
    if (trimmed.isEmpty) return [];

    final chunks = trimmed.length > 12000
        ? TextChunker.splitIntoChunks(trimmed, targetChunkChars: 12000, overlapChars: 400)
        : null;
    final segments = chunks != null ? chunks.map((c) => c.content).toList() : [trimmed];

    final List<dynamic> items = [];
    String academicLevel = 'Unknown';

    for (int i = 0; i < segments.length; i++) {
      final raw = await aiRouter.executeHeavyReasoning(
        jsonMode: true,
        prompt: '''
Analyze this syllabus segment (${i + 1}/${segments.length}) for "$subject". Extract the academic hierarchy and course level.
Return ONLY valid JSON:
{
  "academicLevel": "BSc | MSc | High School | Competitive | Unknown",
  "levelConfidence": 0.0,
  "items": [
    {
      "semester": "Semester 1",
      "unit": "Unit 1: Title",
      "topics": [
        {
          "title": "Topic Name",
          "subtopics": ["Subtopic A", "Subtopic B"]
        }
      ]
    }
  ]
}

Syllabus text:
${segments[i]}
''',
      );
      final parsed = AiRouter.parseJsonObject(raw);
      if (academicLevel == 'Unknown' && parsed['academicLevel'] != null) {
        academicLevel = parsed['academicLevel'].toString();
      }
      items.addAll(parsed['items'] as List? ?? []);
    }

    // Archive existing active nodes on syllabus revision (preserving artifact links)
    final previous = getSyllabusNodes(notebookId, includeArchived: true)
        .map((n) => {...n, 'archived': true})
        .toList();

    final List<Map<String, dynamic>> newNodes = [];
    int order = 0;
    final nowTs = DateTime.now().millisecondsSinceEpoch;

    for (final semItem in items) {
      if (semItem is! Map) continue;
      final semTitle = (semItem['semester'] ?? 'Semester 1').toString().trim();
      final unitTitle = (semItem['unit'] ?? 'Unit 1').toString().trim();

      final semId = 'sem_${nowTs}_${order++}';
      newNodes.add({
        'id': semId,
        'parentId': null,
        'nodeType': 'semester',
        'title': semTitle,
        'academicLevel': academicLevel,
        'sourceOrigin': 'official_syllabus',
        'confirmed': true,
        'archived': false,
        'sortOrder': order,
      });

      final unitId = 'unit_${nowTs}_${order++}';
      newNodes.add({
        'id': unitId,
        'parentId': semId,
        'nodeType': 'unit',
        'title': unitTitle,
        'academicLevel': academicLevel,
        'sourceOrigin': 'official_syllabus',
        'confirmed': true,
        'archived': false,
        'sortOrder': order,
      });

      final topics = semItem['topics'] as List? ?? [];
      for (final t in topics) {
        if (t is! Map) continue;
        final tTitle = (t['title'] ?? '').toString().trim();
        if (tTitle.isEmpty) continue;
        final topicId = 'top_${nowTs}_${order++}';
        newNodes.add({
          'id': topicId,
          'parentId': unitId,
          'nodeType': 'topic',
          'title': tTitle,
          'academicLevel': academicLevel,
          'sourceOrigin': 'official_syllabus',
          'confirmed': true,
          'archived': false,
          'sortOrder': order,
        });

        final subs = t['subtopics'] as List? ?? [];
        for (final sub in subs) {
          final subTitle = sub.toString().trim();
          if (subTitle.isEmpty) continue;
          newNodes.add({
            'id': 'sub_${nowTs}_${order++}',
            'parentId': topicId,
            'nodeType': 'subtopic',
            'title': subTitle,
            'academicLevel': academicLevel,
            'sourceOrigin': 'official_syllabus',
            'confirmed': true,
            'archived': false,
            'sortOrder': order,
          });
        }
      }
    }

    await saveSyllabusNodes(notebookId, [...newNodes, ...previous]);
    return newNodes;
  }

  /// Computes syllabus coverage counts across active syllabus nodes.
  static Map<String, int> computeCoverageStats(String notebookId) {
    final nodes = getSyllabusNodes(notebookId)
        .where((n) => n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    final mappings = getSourceMappings(notebookId);
    final coveredIds = mappings
        .where((m) => m['coverageStatus'] == 'covered')
        .map((m) => m['nodeId']?.toString())
        .toSet();
    final partialIds = mappings
        .where((m) => m['coverageStatus'] == 'partial')
        .map((m) => m['nodeId']?.toString())
        .toSet();

    int covered = 0;
    int partial = 0;
    int uncovered = 0;
    for (final n in nodes) {
      final id = n['id']?.toString();
      if (coveredIds.contains(id)) {
        covered++;
      } else if (partialIds.contains(id)) {
        partial++;
      } else {
        uncovered++;
      }
    }
    return {
      'total': nodes.length,
      'covered': covered,
      'partial': partial,
      'uncovered': uncovered,
    };
  }
}
